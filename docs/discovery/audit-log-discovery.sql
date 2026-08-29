-- ============================================================
-- Audit Log Discovery — chasing the eAdaptor 401 root cause
-- ============================================================
-- Purpose: RegistryForm's "Audit Data" tab (Enterprise.AuditDataServices.
-- Business.Audit) suggests CW has a system-wide field-change audit trail.
-- If we can find the real table behind it, filtering to the time the
-- HONEASHKG password was reset in the UI should show EXACTLY which table/
-- record was actually modified - directly answering the core open question
-- in docs/backlog/eadaptor-inbound-auth-401.md ("does the reset even touch
-- the record /eAdaptorNext reads?") without more guessing.
--
-- Two candidates from docs/discovery/prod-db-schema-analysis.md's initial
-- scan: StmALog (33M rows, "System audit/activity log") and StmActivityLog
-- (4.8M rows). "ALog" plausibly = "Audit Log", matching the .NET business
-- object name - but confirm columns before trusting either guess.

-- ============================================================
-- STEP 1 — discover real columns for both candidates (RESULT: WRONG GUESS,
-- kept for record - see Step 1b below)
-- ============================================================
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN ('StmALog', 'StmActivityLog')
ORDER BY TABLE_NAME, ORDINAL_POSITION;

-- Result 2026-08-29 (tmp/ result pasted into chat, not saved as a file):
-- Neither table is a field-level change audit trail.
--   StmActivityLog (S7_) = user session/UI telemetry (keystrokes, mouse
--     clicks, form opened, active/inactive time) - engagement tracking,
--     not data changes.
--   StmALog (SL_) = business Milestone/Event log (SL_SE_NKEvent,
--     SL_FireWorkflow ties into the ProcessTasks trigger mechanism) - the
--     "Milestone/Event" business concept, not an audit trail.
-- "ALog" was a wrong guess at "Audit Log" - do not reuse either table for
-- this purpose.

-- ============================================================
-- STEP 1b — search directly for tables actually named "Audit" instead of
-- guessing a third candidate name
-- ============================================================
SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME LIKE '%Audit%'
ORDER BY TABLE_NAME;

-- Result 2026-08-29: JobDeclarationAuditHistory, WhsAuditVarianceReport,
-- WhsPackageAudit, WhsPackageAuditLineFailure, WorkflowAuditLog - all
-- domain-specific (customs declaration / warehouse / workflow), none look
-- like a generic system-wide "Registry Item field changed" audit trail.

-- ============================================================
-- STEP 1c — check whether CDC (Change Data Capture) is the real mechanism
-- behind the generic "Audit Data" UI tab instead of a bespoke Audit table.
-- This DB already has CDC enabled broadly (docs/discovery/prod-db-schema-
-- analysis.md's first scan found cdc.dbo_<TableName>_CT shadow tables) -
-- if the relevant config table is CDC-tracked, its change history
-- (including literal old/new column values) is directly queryable.
-- ============================================================
SELECT s.name AS SchemaName, t.name AS TableName, t.is_tracked_by_cdc
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE t.is_tracked_by_cdc = 1
ORDER BY t.name;

-- Once this returns, check specifically whether any of the EDI-related
-- tables already explored are in the list: EDICommunicationPartyConfig,
-- EDICommunicationAuth, EDICommunicationParty, GlbExternalPassword,
-- EDICommunicationsMode. If one is CDC-tracked, its cdc.dbo_<TableName>_CT
-- shadow table can be queried directly for the actual change history
-- around the password reset date/time.

-- Result 2026-08-29 (tmp/CDC_Config_202608291711.csv): ALL FIVE are
-- CDC-tracked - EDICommunicationAuth, EDICommunicationParty,
-- EDICommunicationPartyConfig, EDICommunicationsMode, GlbExternalPassword.
-- This is a much more direct path than the Audit Data UI tab - CDC records
-- literal before/after column values for every change, independent of
-- whatever backs that UI screen.

-- ============================================================
-- STEP 2 — confirm the CDC capture table's real columns before querying it
-- (standard SQL Server CDC columns are well-documented - __$start_lsn,
-- __$end_lsn, __$seqval, __$operation, __$update_mask, plus every column
-- from the source table - but confirm rather than assume, same discipline
-- as everywhere else in this file)
-- ============================================================
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'cdc'
  AND TABLE_NAME IN ('dbo_EDICommunicationAuth_CT', 'dbo_GlbExternalPassword_CT', 'dbo_EDICommunicationPartyConfig_CT')
ORDER BY TABLE_NAME, ORDINAL_POSITION;

-- Result 2026-08-29 (tmp/CDC_Config_2_202608291714.csv): confirmed - standard
-- CDC metadata columns (__$start_lsn, __$end_lsn, __$seqval, __$operation,
-- __$update_mask, __$command_id) plus every original source-table column,
-- for all 3 tables.

-- ============================================================
-- STEP 3 — real query, safe to run now. Full EDICommunicationAuth change
-- history (table is small - 15 parties - so pulling everything and
-- eyeballing timestamps is simpler than LSN/time-range mapping).
-- __$operation codes: 1=delete, 2=insert, 3=update(before image),
-- 4=update(after image).
-- NEVER select ECA_Password/ECA_ClientSecret/ECA_Certificate/
-- ECA_EncodedPrivateKey or GP_CurrentPassword/GP_NextPassword/GP_Certificate
-- - identifying and timestamp columns only.
-- ============================================================
SELECT
    __$start_lsn, __$operation,
    ECA_PK, ECA_Username, ECA_AuthorizationMode,
    ECA_SystemCreateTimeUtc, ECA_SystemCreateUser,
    ECA_SystemLastEditTimeUtc, ECA_SystemLastEditUser
FROM cdc.dbo_EDICommunicationAuth_CT
ORDER BY __$start_lsn DESC;

-- Same pattern for GlbExternalPassword, in case a HONEASHKG-related record
-- was ever created there and later removed:
SELECT
    __$start_lsn, __$operation,
    GP_PK, GP_UserID, GP_MailBoxID, GP_Name, GP_PasswordType, GP_PasswordStatus,
    GP_SystemCreateTimeUtc, GP_SystemCreateUser,
    GP_SystemLastEditTimeUtc, GP_SystemLastEditUser
FROM cdc.dbo_GlbExternalPassword_CT
ORDER BY __$start_lsn DESC;

-- ============================================================
-- STEP 2 (template, fill in once Step 1 confirms real columns) — find the
-- audit trail entry for whenever the HONEASHKG password reset happened.
-- Adjust the date range to the actual date/time the reset was done in the
-- CW UI (check tmp/work_history.log or tmp/2026_08_23_eadaptor_checking.log
-- for the timestamp, since that's not tracked in this repo).
-- ============================================================
-- SELECT TOP 50 *
-- FROM StmALog  -- or StmActivityLog, whichever Step 1 confirms is the real one
-- WHERE <CreateTime/EditTime column> >= '2026-08-2X 00:00:00'
--   AND <CreateTime/EditTime column> <  '2026-08-2X 23:59:59'
--   AND (<TableName/EntityType column> LIKE '%EDI%' OR <TableName/EntityType column> LIKE '%Registry%')
-- ORDER BY <CreateTime/EditTime column> DESC;
