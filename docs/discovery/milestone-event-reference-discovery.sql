-- ============================================================
-- Milestone/Event Reference Table Discovery
-- ============================================================
-- Purpose: both P9_SE_NKMilestoneEvent (ProcessTasks - what event a
-- trigger listens for) and SL_SE_NKEvent (StmALog - what event actually
-- happened/was logged) use the same "SE_NK" natural-key pattern, but we've
-- never found the actual reference table that defines what codes like
-- BKC/EDT/DEX/STU/AVS/WTA/Z52/DDI mean. User's hypothesis 2026-08-30:
-- "Event Code applies for event information and doesn't apply for trigger
-- information" - i.e. P9_SE_NKMilestoneEvent (trigger's condition) and the
-- actual StmALog event log are two separate concerns, and there should be
-- one shared reference/lookup table describing event codes generally.
--
-- Naming convention lead (confirmed pattern all session): CW's _NK columns
-- encode the referenced table's alias right before _NK (JS_RL_NKOrigin ->
-- RefLocation via alias RL, JS_RS_NKServiceLevel -> RefServiceLevel via RS,
-- JS_F3_NKPackType -> RefPackType via F3). SE_NK... suggests a table with
-- alias "SE" - likely StmEvent, matching StmALog's Stm/SL module prefix.

-- ============================================================
-- STEP 1 — search for the real table instead of guessing the exact name
-- ============================================================
SELECT TABLE_SCHEMA, TABLE_NAME, TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME LIKE 'Stm%'
   OR TABLE_NAME LIKE '%Event%'
   OR TABLE_NAME LIKE '%Milestone%'
ORDER BY TABLE_NAME;

-- Result 2026-08-30: StmEvent confirmed (BASE TABLE), matching the SE_NK
-- naming-convention hypothesis. Two bonus views also surfaced -
-- WorkflowEvent and WorkflowMilestone - possibly an even more direct fit
-- for "event information vs trigger information" than the raw table.

-- ============================================================
-- STEP 2 — confirm StmEvent's real columns before querying
-- ============================================================
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'StmEvent'
ORDER BY ORDINAL_POSITION;

-- ============================================================
-- STEP 2b — also confirm the two view columns, in case one of them is a
-- better fit (e.g. already joins Event to Milestone/Workflow context)
-- ============================================================
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN ('WorkflowEvent', 'WorkflowMilestone')
ORDER BY TABLE_NAME, ORDINAL_POSITION;

-- Result 2026-08-30: StmEvent confirmed real (SE_Code/SE_Desc, plus
-- milestone-type flags SE_IsAirMilestone/SE_IsSeaMilestone/
-- SE_IsCustomsMilestone/SE_IsExceptionEvent/SE_IsDelayFired etc.) - a
-- proper generic event dictionary, separate from trigger config, exactly
-- matching the user's hypothesis. WorkflowMilestone = ProcessTasks
-- filtered to Milestone-type rows (not Trigger-type) - no new info.
-- WorkflowEvent = plain view wrapper around StmALog - no new info.

-- ============================================================
-- STEP 3 — pull descriptions for every event code seen this session
-- ============================================================
SELECT SE_Code, SE_Desc, SE_IsActive, SE_IsExceptionEvent, SE_IsDelayFired,
       SE_IsAirMilestone, SE_IsSeaMilestone, SE_IsRoadMilestone,
       SE_IsCustomsMilestone, SE_IsOrderTrackingMilestone
FROM StmEvent
WHERE SE_Code IN ('BKC', 'EDT', 'DEX', 'STU', 'AVS', 'WTA', 'Z52', 'DDI', 'JOP', 'JED', 'ADD')
ORDER BY SE_Code;
