-- ============================================================
-- StmALog Event History — per-shipment check
-- ============================================================
-- Purpose: StmALog is the confirmed Milestone/Event log backing
-- ShipmentForm > Workflow > Events (see docs/discovery/
-- edi-trigger-flow-mechanism-reference.md Stage 3). Key columns:
-- SL_SE_NKEvent (event code), SL_FireWorkflow (bit), SL_EventTimeUtc,
-- SL_Table + SL_Parent (which record this event belongs to).
--
-- Earlier this session we only ran a system-wide check for a specific
-- event code (BKC) with no results - this time, filter directly by the
-- shipment's own JS_PK to see ALL events recorded against it, whatever
-- the code, which is a more direct way to compare S00075824 (known-good,
-- has JobHeader) against S00075831/S00075832 (no JobHeader).

-- ============================================================
-- STEP 1 — confirm real columns before trusting the guesses above
-- (same discipline as every other table this session)
-- ============================================================
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'StmALog'
ORDER BY ORDINAL_POSITION;

-- ============================================================
-- STEP 2 — all events recorded against the three shipments. SL_Table's
-- actual stored value for a JobShipment-level event is not yet confirmed,
-- so this filters on SL_Parent only, not SL_Table, to avoid missing rows
-- on a wrong guess.
--
-- CORRECTED 2026-08-30 per tmp/StmALog_202608301611.csv: SL_SystemCreate*
-- columns don't exist on this table - swapped for the real audit-ish
-- columns (SL_PostedTimeUtc, SL_GS_NKUser = who logged the event).
-- ============================================================
SELECT
    SL_PK,
    SL_Table,
    SL_Parent,
    SL_SE_NKEvent,
    SL_FireWorkflow,
    SL_IsEstimate,
    SL_IsCancelled,
    SL_EventTime,
    SL_EventTimeUtc,
    SL_PostedTimeUtc,
    SL_GS_NKUser,
    SL_GB_NKBranch,
    SL_GE_NKDepartment,
    SL_DataSource
FROM StmALog
WHERE SL_Parent IN (
    '69A65D88-0E85-4B6A-9272-DD31DCE44989',  -- S00075831 or S00075832
    '5E06300A-4C87-4D74-A35C-F2E3B35E40AA',  -- the other one
    'ED00D373-610F-44D8-B441-7FB15623174C'   -- S00075824, known-good control
)
ORDER BY SL_EventTimeUtc DESC;

-- Checklist:
-- - If S00075824 shows events here but S00075831/S00075832 show ZERO rows
--   at all (not just missing a specific event code), that's meaningful -
--   it would mean nothing has ever registered against these shipments at
--   the milestone/event level, consistent with (but not proof of) the Job
--   itself never having been created.
-- - If all three show comparable events, the gap is specifically about
--   JobHeader creation, not the event/milestone layer.
