-- ============================================================
-- JobShipment Phase/Status Diagnostic — Job vs Shipment mechanism
-- ============================================================
-- Purpose: test a new theory for why S00075831/S00075832 have a
-- JobShipment row but no JobHeader row, replacing the earlier "replication
-- stall" theory (see docs/backlog/uat-jobheader-replication-stall.md,
-- now downgraded to unconfirmed).
--
-- New theory, based on docs_for_thanh/foundations: "Job" (JobHeader) is
-- described as a distinct branch-execution/billing layer UNDER Shipment/
-- Consol, not automatically the same record. JobShipment has several
-- lifecycle flag columns (JS_ShipmentStatus, JS_Phase, JS_IsBooking,
-- JS_IsForwardRegistered, JS_IsDirectBooking, JS_IsCFSRegistered,
-- JS_IsShipping) that were never inspected - one of these may indicate
-- "this is still a Booking/Quote, not yet promoted to a Job" which would
-- explain a JobShipment existing with zero JobHeader row by design, not
-- by replication failure.
--
-- IMPORTANT: JobShipment has NO job-number column at all (confirmed -
-- see tmp/JobShipment_202608292358.csv full column list). The job number
-- shown in the CW UI comes from JobHeader (JH_JobNum) via the polymorphic
-- JH_ParentID/JH_ParentTableCode pointer. So we cannot look up S00075831/
-- S00075832 by job number directly against JobShipment - use recent
-- creation time + your username instead (Step 1).

-- ============================================================
-- STEP 1 — find S00075831 / S00075832's JobShipment rows directly
-- (adjust JS_SystemCreateUser to your actual CW username if 'SNG' is wrong,
-- and widen/narrow the time filter as needed)
-- ============================================================
SELECT TOP 10
    JS_PK,
    JS_SystemCreateTimeUtc,
    JS_SystemCreateUser,
    JS_SystemCreateBranch,
    JS_SystemCreateDepartment,
    JS_ShipmentStatus,
    JS_Phase,
    JS_IsBooking,
    JS_IsDirectBooking,
    JS_IsForwardRegistered,
    JS_IsCFSRegistered,
    JS_IsShipping,
    JS_IsCancelled,
    JS_IsValid,
    JS_JS_ColoadMasterShipment,
    JS_JS_SplitSwitchShipment,
    JS_IsSplitShipment,
    JS_TH_OneTimeQuote
FROM JobShipment
WHERE JS_SystemCreateTimeUtc >= '2026-08-29 20:00:00'
  AND JS_SystemCreateUser = 'SNG'
ORDER BY JS_SystemCreateTimeUtc DESC;

-- ============================================================
-- STEP 2 — same columns for the KNOWN-WORKING job, S00075824, for
-- side-by-side comparison. JS_PK confirmed from
-- docs/discovery/test-shipment-verify.sql Step 5.
-- ============================================================
SELECT
    JS_PK,
    JS_SystemCreateTimeUtc,
    JS_SystemCreateUser,
    JS_SystemCreateBranch,
    JS_SystemCreateDepartment,
    JS_ShipmentStatus,
    JS_Phase,
    JS_IsBooking,
    JS_IsDirectBooking,
    JS_IsForwardRegistered,
    JS_IsCFSRegistered,
    JS_IsShipping,
    JS_IsCancelled,
    JS_IsValid,
    JS_JS_ColoadMasterShipment,
    JS_JS_SplitSwitchShipment,
    JS_IsSplitShipment,
    JS_TH_OneTimeQuote
FROM JobShipment
WHERE JS_PK = 'ED00D373-610F-44D8-B441-7FB15623174C';

-- Checklist:
-- - If JS_ShipmentStatus or JS_Phase differ between the two groups,
--   that's very likely the actual mechanism (a lifecycle stage, not a
--   sync issue).
-- - If JS_IsForwardRegistered = 0 on S00075831/S00075832 but 1 on
--   S00075824, that's a strong, specific signal: these shipments simply
--   haven't been promoted to a "Job" yet, and JobHeader creation is tied
--   to that promotion action - not to JobShipment save itself.
-- - If JS_JS_ColoadMasterShipment is populated on either failing row,
--   they may be coload children that share a MASTER shipment's Job rather
--   than getting their own JobHeader - in that case, check the master's
--   JS_PK's JobHeader instead.

-- ============================================================
-- STEP 3 — only if Step 1/2 show no obvious flag difference: broaden the
-- JobHeader search in case a JobHeader row DOES exist but under a
-- different JH_ParentTableCode than 'JS' (e.g. a distinct Booking subtype
-- that later converts to 'JS'). Replace the two GUIDs with the JS_PK
-- values found in Step 1.
-- ============================================================
SELECT JH_PK, JH_JobNum, JH_ParentTableCode, JH_ParentID, JH_GC, JH_SystemCreateTimeUtc
FROM JobHeader
WHERE JH_ParentID IN (
    '<JS_PK from Step 1, row 1>',
    '<JS_PK from Step 1, row 2>'
);
