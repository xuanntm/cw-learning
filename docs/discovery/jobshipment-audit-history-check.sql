-- ============================================================
-- JobShipment / JobHeader Audit History Check
-- ============================================================
-- Purpose: see what changes (if any) were made to S00075831/S00075832
-- after creation - part of the ongoing investigation into why these
-- shipments have no matching JobHeader row (see docs/backlog/
-- uat-jobheader-replication-stall.md, currently reopened/unconfirmed,
-- and docs/discovery/jobshipment-phase-status-diagnostic.sql, which ruled
-- out a lifecycle-phase difference).
--
-- NOTE on CDC: docs/discovery/audit-log-discovery.sql already hit
-- "SELECT permission denied" on the cdc schema with this reporting-DB
-- login (cwRestrictedReaderRole) while chasing a different issue. That's
-- a schema-wide grant, so Step 2/3 below will very likely fail the same
-- way for JobShipment/JobHeader - included for completeness/in case
-- permissions changed, but don't be surprised if it errors immediately.
-- Step 1 (no extra permission needed) is the one guaranteed to work.

-- ============================================================
-- STEP 1 — cheap, permission-safe check: JobShipment's own built-in audit
-- columns. If JS_SystemLastEditTimeUtc is later than JS_SystemCreateTimeUtc,
-- the record was touched again after the initial save - worth knowing
-- regardless of what Step 2/3 return.
-- ============================================================
SELECT
    JS_PK,
    JS_SystemCreateTimeUtc,
    JS_SystemCreateUser,
    JS_SystemLastEditTimeUtc,
    JS_SystemLastEditUser
FROM JobShipment
WHERE JS_PK IN (
    '69A65D88-0E85-4B6A-9272-DD31DCE44989',  -- S00075831 (or S00075832, confirm which)
    '5E06300A-4C87-4D74-A35C-F2E3B35E40AA',  -- the other one
    'ED00D373-610F-44D8-B441-7FB15623174C'   -- S00075824, known-good control
);

-- ============================================================
-- STEP 2 — check whether JobShipment / JobHeader are CDC-tracked at all
-- (schema-only lookup, no cdc-schema access needed for this part)
-- ============================================================
SELECT s.name AS SchemaName, t.name AS TableName, t.is_tracked_by_cdc
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE t.name IN ('JobShipment', 'JobHeader');

-- ============================================================
-- STEP 3 — ONLY if Step 2 shows is_tracked_by_cdc = 1 for JobShipment.
-- Full change history for the two shipments in question.
-- __$operation codes: 1=delete, 2=insert, 3=update(before image),
-- 4=update(after image).
-- ============================================================
-- SELECT
--     __$start_lsn, __$operation,
--     JS_PK, JS_ShipmentStatus, JS_Phase, JS_IsForwardRegistered,
--     JS_SystemLastEditTimeUtc, JS_SystemLastEditUser
-- FROM cdc.dbo_JobShipment_CT
-- WHERE JS_PK IN (
--     '69A65D88-0E85-4B6A-9272-DD31DCE44989',
--     '5E06300A-4C87-4D74-A35C-F2E3B35E40AA'
-- )
-- ORDER BY __$start_lsn DESC;
