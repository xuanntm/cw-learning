-- ============================================================
-- Post-Billing-Edit Check — did editing Billing info create a JobHeader?
-- ============================================================
-- Purpose: causal test. User just edited Billing information on
-- S00075831 and/or S00075832 in the CW UI (JS_PK 69A65D88.../5E06300A...)
-- to test whether JobHeader creation is tied to a follow-up action rather
-- than the initial Shipment save (see docs/discovery/
-- stmalog-shipment-events-check.sql result: both shipments had zero/
-- minimal activity after creation, unlike the known-good S00075824).

-- ============================================================
-- STEP 1 — confirm the edit itself reached the reporting DB (if this
-- still shows the OLD JS_SystemLastEditTimeUtc, the reporting DB hasn't
-- even synced the edit yet - stop here and re-run later, don't bother
-- checking JobHeader until this updates)
-- ============================================================
SELECT
    JS_PK,
    JS_SystemCreateTimeUtc,
    JS_SystemLastEditTimeUtc,
    JS_SystemLastEditUser,
    JS_ShipmentStatus,
    JS_Phase
FROM JobShipment
WHERE JS_PK IN (
    '69A65D88-0E85-4B6A-9272-DD31DCE44989',  -- S00075831
    '5E06300A-4C87-4D74-A35C-F2E3B35E40AA'   -- S00075832
);

-- ============================================================
-- STEP 2 — the actual test: does a JobHeader row exist now?
-- ============================================================
SELECT JH_PK, JH_JobNum, JH_ParentTableCode, JH_ParentID, JH_GC, JH_SystemCreateTimeUtc
FROM JobHeader
WHERE JH_ParentID IN (
    '69A65D88-0E85-4B6A-9272-DD31DCE44989',  -- S00075831
    '5E06300A-4C87-4D74-A35C-F2E3B35E40AA'   -- S00075832
);

-- ============================================================
-- STEP 3 — new StmALog events since the edit (confirms what event code
-- a Billing edit actually generates, for future reference)
-- ============================================================
SELECT SL_PK, SL_Table, SL_Parent, SL_SE_NKEvent, SL_FireWorkflow, SL_EventTimeUtc, SL_GS_NKUser
FROM StmALog
WHERE SL_Parent IN (
    '69A65D88-0E85-4B6A-9272-DD31DCE44989',
    '5E06300A-4C87-4D74-A35C-F2E3B35E40AA'
)
ORDER BY SL_EventTimeUtc DESC;

-- Interpretation:
-- - Step 1 unchanged JS_SystemLastEditTimeUtc -> reporting DB hasn't
--   synced the edit yet; wait and re-run rather than drawing conclusions.
-- - Step 1 updated but Step 2 still empty -> Billing edit alone doesn't
--   create a JobHeader; the mechanism is something else.
-- - Step 2 now returns a row -> confirmed: JobHeader creation is tied to
--   a follow-up action (Billing edit or whatever specifically triggered
--   it), not the initial Shipment save. This is the answer we've been
--   chasing - update docs/backlog/uat-jobheader-replication-stall.md and
--   docs/discovery/jobshipment-phase-status-diagnostic.sql with this
--   finding if so.
