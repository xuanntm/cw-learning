-- ============================================================
-- Trigger Config Comparison — your new trigger vs. every existing one
-- on the same template
-- ============================================================
-- Purpose: compare "Full Integration Testing" against real, working
-- triggers on the same global template (H56, SHP, global, system,
-- P0_PK = 6ACE7304-A673-41DF-B2F8-2F63A174AA07) to spot what's actually
-- different. All columns confirmed earlier this session.

-- ============================================================
-- STEP 1 — every trigger-type row on this template, side by side
-- ============================================================
SELECT
    P9_PK,
    P9_Description,
    P9_Sequence,
    P9_Status,
    P9_TriggerField,
    P9_TriggerCondition,
    P9_LineTriggerType,
    P9_SE_NKMilestoneEvent,
    P9_SE_NKTaskCompletionEvent,
    P9_SE_NKExceptionEvent,
    P9_TriggerContext,
    P9_RespondToCascadedEvents,
    P9_CascadedEventsContext,
    P9_GB_TriggerBranch,
    P9_GC,
    P9_GE_TriggerDepartment,
    P9_DelayDurationSeconds,
    P9_SuppressDuplicates,
    P9_SystemCreateTimeUtc,
    P9_SystemCreateUser
FROM ProcessTasks
WHERE P9_ParentID = '6ACE7304-A673-41DF-B2F8-2F63A174AA07'  -- H56, SHP, global, system template
  AND P9_ParentTableCode = 'P0'
  AND P9_Type = 'TRG'
ORDER BY P9_Sequence;

-- Look specifically for any other row with P9_SE_NKMilestoneEvent = 'BKC'
-- (or similar) - if a real, working one exists, compare every column
-- against your own "Full Integration Testing" row line by line: Status,
-- TriggerField, LineTriggerType, TriggerContext, Branch/Company/Department
-- scoping are all worth checking for a difference.

-- ============================================================
-- STEP 2 — find the "Completion Trigger Action" table via FK, corrected
-- target. NOTE: an earlier attempt (edi-full-configuration-finder.sql
-- Step 4) searched for FKs referencing ProcessTemplateTrigger - that was
-- based on the ORIGINAL (wrong) assumption about which table backs the
-- Triggers tab. Now that ProcessTasks is confirmed as the real table,
-- search for FKs referencing ProcessTasks.P9_PK instead - this is the
-- more likely place to find the Action/Purpose/Recipient config that
-- makes a trigger actually dispatch something.
-- ============================================================
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
WHERE tr.name = 'ProcessTasks' OR tp.name = 'ProcessTasks';

-- This will return a LOT of rows (ProcessTasks is referenced from many
-- places - WhsPickLine, ProcessTaskNotification, etc., seen earlier in
-- tmp/UAT_process_constraint_detail_202608291532.csv). Look specifically
-- for anything with "Action"/"Recipient"/"Purpose" in the table name.
