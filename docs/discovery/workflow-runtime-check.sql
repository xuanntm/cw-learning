-- ============================================================
-- Workflow Runtime Check — Active Templates vs. Actual Job Usage
-- ============================================================
-- Purpose: support the "runtime verification flow" for Workflow Templates
-- (declared config vs. actual behavior) discussed alongside this file.
-- Recommended environment: UAT (H56TRN.db.test.wisegrid.net / OdysseyH56TRN)
-- for any test-flow work — keep PROD for read-only reporting only, per the
-- earlier cost/risk caution on this environment.
--
-- Schema confirmed 2026-08-29 via tmp/UAT_process_table_detail_202608291532.csv
-- and tmp/UAT_process_constraint_detail_202608291532.csv. Real chain:
--
--   ProcessTaskTemplate.P0_PK
--       <- ProcessHeader.FH_P0_Template          (which job ran this template)
--           <- ProcessTasks.P9_FH_ProcessHeader  (actual Task rows that resulted)
--   ProcessTaskTemplate.P0_PK
--       <- ProcessTaskNotification.PQ_P0_WorkflowTemplate  (direct - trigger/
--          notification firings, no intermediate table needed)
--
-- IMPORTANT: ProcessTasks.P9_ParentTemplateID (the column the old guessed
-- query in uat-bastion-runbook.ps1 Section 5 assumed was the template link)
-- has NO FK constraint at all - confirmed a red herring, not the real
-- relationship. Use the ProcessHeader chain above instead.

-- ============================================================
-- STEP 1 — schema discovery (CONFIRMED 2026-08-29, kept for reference/rerun)
-- ============================================================
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN ('ProcessTaskTemplate', 'ProcessTasks', 'ProcessTaskNotification', 'ProcessJobTriggerLink')
ORDER BY TABLE_NAME, ORDINAL_POSITION;

SELECT
    fk.name AS ConstraintName,
    tp.name AS ParentTable,
    cp.name AS ParentColumn,
    tr.name AS RefTable,
    cr.name AS RefColumn
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
JOIN sys.tables tp ON tp.object_id = fkc.parent_object_id
JOIN sys.columns cp ON cp.object_id = tp.object_id AND cp.column_id = fkc.parent_column_id
JOIN sys.tables tr ON tr.object_id = fkc.referenced_object_id
JOIN sys.columns cr ON cr.object_id = tr.object_id AND cr.column_id = fkc.referenced_column_id
WHERE tp.name IN ('ProcessTaskTemplate', 'ProcessTasks', 'ProcessTaskNotification', 'ProcessJobTriggerLink')
   OR tr.name IN ('ProcessTaskTemplate', 'ProcessTasks', 'ProcessTaskNotification', 'ProcessJobTriggerLink');


-- ============================================================
-- STEP 1.5 — check indexes before running Step 2 against full history
-- (ProcessTasks: 16.1M rows, ProcessTaskNotification: 11.9M rows - confirm
-- the join/filter columns are indexed before running unbounded)
-- ============================================================
SELECT
    t.name AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    c.name AS ColumnName,
    ic.key_ordinal
FROM sys.indexes i
JOIN sys.tables t ON t.object_id = i.object_id
JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id
JOIN sys.columns c ON c.object_id = ic.object_id AND c.column_id = ic.column_id
WHERE t.name IN ('ProcessHeader', 'ProcessTasks', 'ProcessTaskNotification')
  AND c.name IN ('FH_P0_Template', 'P9_FH_ProcessHeader', 'PQ_P0_WorkflowTemplate', 'PQ_SystemCreateTimeUtc')
ORDER BY t.name, i.name, ic.key_ordinal;


-- ============================================================
-- STEP 2 — active templates: declared config vs. actual usage
-- Confirmed real columns/FKs (see chain above). Scalar subqueries used
-- instead of JOINs deliberately - joining ProcessHeader/ProcessTasks AND
-- ProcessTaskNotification onto ProcessTaskTemplate in one query would fan
-- out (two independent 1:many branches multiplied together) before
-- COUNT(DISTINCT) could clean it up, which is expensive against 16M/11.9M
-- row tables. Same avoidance pattern used for GenCustomAddOnValue earlier.
-- ============================================================
SELECT
    tpl.P0_Name AS TemplateName,
    tpl.P0_ProcessType AS ProcessType,
    tpl.P0_IsActive AS IsActive,
    tpl.P0_IsUniversal AS IsUniversal,
    tpl.P0_IsPartialTemplate AS IsPartial,
    tpl.P0_TriggerFallbackMethod AS TriggerFallbackMethod,
    tpl.P0_TaskFallbackMethod AS TaskFallbackMethod,
    tpl.P0_MilestoneFallbackMethod AS MilestoneFallbackMethod,
    (SELECT COUNT(*) FROM ProcessHeader fh WHERE fh.FH_P0_Template = tpl.P0_PK) AS ActualProcessInstanceCount,
    (SELECT COUNT(*)
     FROM ProcessTasks p9
     JOIN ProcessHeader fh2 ON fh2.FH_PK = p9.P9_FH_ProcessHeader
     WHERE fh2.FH_P0_Template = tpl.P0_PK) AS ActualTaskCount,
    (SELECT COUNT(*)
     FROM ProcessTaskNotification pq
     WHERE pq.PQ_P0_WorkflowTemplate = tpl.P0_PK
       AND pq.PQ_SystemCreateTimeUtc >= DATEADD(DAY, -90, SYSUTCDATETIME())  -- bounded window; widen/remove once Step 1.5 confirms indexing is safe for full history
    ) AS ActualNotificationCount_Last90Days
FROM ProcessTaskTemplate tpl
WHERE tpl.P0_IsActive = 1
ORDER BY ActualProcessInstanceCount DESC;

-- Flag pattern: any row with IsActive = 1, IsUniversal = 1, a fallback
-- method of 'NFB' (confirm the real code value once Step 2 returns data -
-- 'NFB' was the value seen in the static XML export analysis, not yet
-- confirmed as the literal DB char value), and ActualProcessInstanceCount
-- = 0 (or ActualTaskCount = 0 with ActualProcessInstanceCount > 0, meaning
-- the job matched but produced nothing) - this is the BravoTran risk
-- pattern from docs/discovery/workflow-audit-checklist.md Section B,
-- generalized to catch any other template with the same silent-failure shape.


-- ============================================================
-- STEP 3 (optional) — resolve "What is BravoTran?" directly
-- ProcessTaskTemplate.P0_OH_Client is a real FK to OrgHeader - if the
-- BravoTran templates are scoped to a specific client Org, this answers
-- workflow-audit-checklist.md Section A1 directly without needing the
-- CW UI Organizations search.
-- ============================================================
SELECT
    tpl.P0_Name AS TemplateName,
    tpl.P0_ProcessType AS ProcessType,
    tpl.P0_OH_Client AS ClientOrgPK,
    oh.OH_Code AS ClientOrgCode,
    oh.OH_FullName AS ClientOrgName  -- confirmed real columns per docs/discovery/org-tables-schema-analysis.md's "Controlling Customer" query (OH_A_Name was a wrong guess)
FROM ProcessTaskTemplate tpl
LEFT JOIN OrgHeader oh ON oh.OH_PK = tpl.P0_OH_Client
WHERE tpl.P0_Name LIKE '%BravoTran%';
