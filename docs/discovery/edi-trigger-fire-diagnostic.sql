-- ============================================================
-- EDI Trigger Fire Diagnostic — did anything happen at all?
-- ============================================================
-- Purpose: "nothing arrived at ngrok" has 3 possible root causes, in
-- order from earliest to latest in the pipeline:
--   1. The BKC milestone event itself never registered on the job
--   2. The event registered, but the trigger condition never matched
--      (e.g. the Controlling Customer gap found earlier) - no job-
--      instance trigger/message was ever created
--   3. A message WAS created but failed/errored before or during the
--      actual HTTP send to ngrok
-- Each step below isolates one of these.

-- ============================================================
-- STEP 1 — did the BKC milestone event register on this job at all?
-- (StmALog = the Milestone/Event log, confirmed earlier this session)
-- ============================================================
SELECT TOP 20
    SL_Table, SL_Parent, SL_SE_NKEvent, SL_EventTimeUtc,
    SL_GS_NKUser, SL_FireWorkflow, SL_IsCancelled, SL_IsEstimate
FROM StmALog
WHERE SL_SE_NKEvent = 'BKC'
  AND SL_EventTimeUtc >= DATEADD(HOUR, -24, SYSUTCDATETIME())
ORDER BY SL_EventTimeUtc DESC;

-- Look for a row with SL_Parent matching the JobShipment JS_PK for
-- S00075824 (ED00D373-610F-44D8-B441-7FB15623174C, per earlier verify
-- queries). If nothing shows up at all: the document upload didn't
-- register as a BKC milestone event - check the document type in the UI
-- (step 2 above) before going further.

-- ============================================================
-- STEP 2 — did a job-instance Trigger/Task get created from the template
-- trigger for THIS job? (ProcessTasks, job-instance mode this time -
-- P9_FH_ProcessHeader populated, unlike the template-definition row
-- confirmed earlier which had it blank)
-- ============================================================
SELECT
    p9.P9_PK, p9.P9_Type, p9.P9_Status, p9.P9_Description,
    p9.P9_SystemCreateTimeUtc, p9.P9_FH_ProcessHeader,
    fh.FH_P0_Template
FROM ProcessTasks p9
LEFT JOIN ProcessHeader fh ON fh.FH_PK = p9.P9_FH_ProcessHeader
WHERE p9.P9_Description = 'Full Integration Testing'
ORDER BY p9.P9_SystemCreateTimeUtc DESC;

-- If this ONLY returns the original template-definition row (the one
-- confirmed earlier, P9_FH_ProcessHeader blank) and no NEW row with
-- P9_FH_ProcessHeader populated: the trigger condition never matched on
-- this job - most likely the Controlling Customer gap flagged earlier.
-- If a new row DOES exist with P9_FH_ProcessHeader populated, check its
-- P9_Status - that tells you whether it fired successfully or errored.

-- ============================================================
-- STEP 3 — was any EDIMessage/EDIInterchange created for "Full Integration",
-- even a failed one? (reuses the pattern from edi-client-verify.sql Step 2)
-- ============================================================
SELECT TOP 20
    em.EM_PK, em.EM_Status, em.EM_ReceiveTransmit, em.EM_MessageType,
    em.EM_SystemCreateTimeUtc,
    ei.EI_Status AS InterchangeStatus, ei.EI_RetryCount
FROM EDIMessage em
JOIN EDIInterchange ei ON ei.EI_PK = em.EM_EI
JOIN EDICommunicationPartyConfig ecc ON ecc.ECC_PK = ei.EI_ECC_CommunicationPartyConfig
JOIN EDICommunicationParty ecp ON ecp.ECP_PK = ecc.ECC_ECP_Party
WHERE ecp.ECP_Name = 'Full Integration'
ORDER BY em.EM_SystemCreateTimeUtc DESC;

-- Nothing here + nothing in Step 2's job-instance check = the trigger
-- condition never matched (fix the Controlling Customer gap, or whichever
-- condition applies, then retry). A row HERE with EM_Status showing an
-- error = CW attempted the send and failed before/without reaching ngrok -
-- worth checking EI_RetryCount and any error text in the EDI Message
-- module's processing log (mentioned in the setup guide as where malformed/
-- failed sends are recorded).
