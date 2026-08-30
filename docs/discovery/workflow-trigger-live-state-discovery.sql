-- ============================================================
-- Workflow Trigger Live State Discovery — chasing TriggerFiredCountdown
-- ============================================================
-- Purpose: field-inspector on ShipmentForm > Workflow > Triggers > Countdown
-- confirmed the UI binds to Enterprise.MasterFiles.Business.
-- WorkflowTriggerCollectionIncludingRelatedView, with TriggerFiredCountdown
-- itself marked [calculated property] (computed in code, not a stored
-- column - consistent with P9_TriggerCondition only holding a type code,
-- not the real formula/timing).
--
-- The user observed this Countdown value actively changing after editing
-- Billing info on a live job - real evidence the EDT trigger condition is
-- now matching. This is the per-job-instance trigger state we couldn't
-- find earlier (docs/discovery/edi-trigger-flow-mechanism-reference.md
-- Stage 5/6 - "Completion Trigger Action" table never located). The
-- "...View" suffix on the business object name is the lead: find the real
-- DB view/table it's actually built from instead of guessing.

-- ============================================================
-- STEP 1 — search for any DB object (view or table) matching the business
-- object name pattern, rather than guessing
-- ============================================================
SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME LIKE '%WorkflowTrigger%'
   OR TABLE_NAME LIKE '%Trigger%Countdown%'
   OR TABLE_NAME LIKE '%Trigger%Fired%'
ORDER BY TABLE_NAME;

-- ============================================================
-- STEP 2 — broader net in case the real name doesn't literally contain
-- "WorkflowTrigger" (CW view names are sometimes abbreviated, e.g. the
-- cvw_ prefix pattern seen on cvw_JobShipmentOrgs)
-- ============================================================
SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME LIKE '%Trigger%'
ORDER BY TABLE_NAME;

-- Result 2026-08-30 (Step 2): Step 1 returned nothing, but Step 2 surfaced
-- ProcessJobTriggerLink (BASE TABLE) - a job-instance-level link table,
-- distinct from both ProcessTasks (template+instance rows, confirmed
-- earlier) and ProcessTemplateTrigger (confirmed NOT the Triggers-tab
-- table). This is the strongest candidate yet for the per-job trigger
-- state / "Completion Trigger Action" mechanism. Also present:
-- SuspendedTriggers (view), vw_GetDisableTriggerScripts/
-- vw_GetEnableTriggerScripts (views, sound like admin tooling not data).

-- ============================================================
-- STEP 3 — confirm ProcessJobTriggerLink's real columns before querying
-- ============================================================
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ProcessJobTriggerLink'
ORDER BY ORDINAL_POSITION;

-- Result 2026-08-30 (confirmed): P9L_PK, P9L_P9T_TemplateTrigger
-- (uniqueidentifier - FK into ProcessTemplateTrigger, so that table IS
-- real and used here, just not for the Triggers-tab Description field as
-- earlier assumed), P9L_GC_Company, P9L_ParentTableCode + P9L_ParentId
-- (standard CW polymorphic pointer - this is the job-instance link),
-- P9L_TriggerFiredCountdown (smallint - the real stored value behind the
-- UI's "[calculated property]" display), plus standard audit columns.

-- ============================================================
-- STEP 4 — confirm ProcessTemplateTrigger's real columns (P9L_P9T_
-- TemplateTrigger's target) before joining to it - don't trust the naming
-- convention alone
-- ============================================================
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ProcessTemplateTrigger'
ORDER BY ORDINAL_POSITION;

-- ============================================================
-- STEP 5 — the real query: live trigger-instance state for the test jobs.
-- Filtered on both known JS_PK values (shipment-level parent) - adjust/
-- add the new JH_PK values too if this returns nothing, in case
-- P9L_ParentId points to JobHeader instead of JobShipment.
-- ============================================================
SELECT
    p9l.P9L_PK,
    p9l.P9L_ParentTableCode,
    p9l.P9L_ParentId,
    p9l.P9L_TriggerFiredCountdown,
    p9l.P9L_SystemCreateTimeUtc,
    p9l.P9L_SystemLastEditTimeUtc,
    p9l.P9L_P9T_TemplateTrigger
FROM ProcessJobTriggerLink p9l
WHERE p9l.P9L_ParentId IN (
    '69A65D88-0E85-4B6A-9272-DD31DCE44989',  -- S00075832 JS_PK
    '5E06300A-4C87-4D74-A35C-F2E3B35E40AA',  -- S00075831 JS_PK
    'ED00D373-610F-44D8-B441-7FB15623174C',  -- S00075824 JS_PK, control
    '67C556AC-601B-4D54-BCFF-5DEB8BD235EE',  -- S00075832 JH_PK, in case ParentId is job-level not shipment-level
    '5EFFFEFF-53E1-4F9C-AD83-4CA0619398AE'   -- S00075831 JH_PK
)
ORDER BY p9l.P9L_SystemLastEditTimeUtc DESC;

-- Result 2026-08-30: all THREE test shipments (S00075824, S00075832,
-- S00075831) link to the SAME THREE ProcessTemplateTrigger GUIDs
-- (7ECF42AA..., 331B1A64..., 5802B162...), with countdown values reset to
-- the same 95/98/99 whenever the shipment is edited. Looks like standard,
-- pre-existing, company-wide triggers - not the user's custom "Full
-- Integration Testing" trigger, which lives in ProcessTasks (P9_), a
-- structurally different table that ProcessJobTriggerLink does NOT
-- reference at all. Possible major finding: the custom trigger may have
-- been built via the wrong mechanism entirely (Workflow Template's
-- Triggers sub-tab -> ProcessTasks) instead of whatever UI actually
-- creates ProcessTemplateTrigger rows - which could fully explain why it
-- never fires. Confirm before concluding:

-- ============================================================
-- STEP 6 — what ARE the 3 standard triggers linked to every shipment?
-- ============================================================
SELECT
    P9T_PK, P9T_Description, P9T_SE_NKTriggerEvent, P9T_TriggerCondition,
    P9T_DelayDurationSeconds, P9T_TriggerFiredCountdown, P9T_IsActive,
    P9T_GC_TriggerCompany, P9T_GB_TriggerBranch, P9T_SuppressDuplicates
FROM ProcessTemplateTrigger
WHERE P9T_PK IN (
    '7ECF42AA-DA0B-4270-94F2-703DA7B96D82',
    '331B1A64-6ADF-4694-8F8D-A113F2C69CE8',
    '5802B162-0D96-42A6-B374-D65A7892C57C'
);

-- ============================================================
-- STEP 7 — does a ProcessTemplateTrigger row for "Full Integration
-- Testing" exist ANYWHERE at all? If this returns zero rows, it confirms
-- the custom trigger was never created in this table/mechanism at all -
-- it only exists as a ProcessTasks row, which this live Countdown UI
-- structurally cannot see.
-- ============================================================
SELECT P9T_PK, P9T_Description, P9T_SE_NKTriggerEvent, P9T_IsActive,
       P9T_SystemCreateTimeUtc, P9T_SystemCreateUser
FROM ProcessTemplateTrigger
WHERE P9T_Description LIKE '%Full Integration%'
   OR P9T_SystemCreateUser = 'SNG';
