-- ============================================================
-- Full Integration — Success Confirmation (S00075834)
-- ============================================================
-- Purpose: S00075834 successfully sent a real message to the ngrok mock
-- receiver (confirmed via tmp/2026_08_30_first_successful_message.log -
-- full UniversalInterchange/UniversalShipment XML received, ActionPurpose
-- FTI, RecipientID FULTESVIC, SenderID H56SPHTRN, request timestamp
-- 2026-08-30 18:23:13). This confirms the DB-side tracking matches: that
-- CW logged the send as a real EDIMessage/EDIInterchange, and that the
-- workflow trigger actually fired at the job-instance level (ProcessTasks,
-- not just matched at the template-definition level).

-- ============================================================
-- STEP 1 — find S00075834's JobHeader/JobShipment context
-- ============================================================
SELECT
    JH_JobNum, JH_PK, JH_ParentID, JH_ParentTableCode, JH_GC,
    GC_Code AS CompanyCode, JH_SystemCreateTimeUtc
FROM JobHeader
LEFT JOIN GlbCompany ON GC_PK = JH_GC
WHERE JH_JobNum = 'S00075834';

-- ============================================================
-- STEP 2 — confirm CW tracked the actual send: EDIInterchange/EDIMessage
-- for the "Full Integration" EDI Client, around the log's timestamp
-- (2026-08-30 18:23:13 UTC).
--
-- CORRECTED 2026-08-30: real FK is EM_EI (not EM_EI_Interchange) - see
-- docs/discovery/edi-communication-mechanism-reference.md. Also, EDIMessage
-- has its own polymorphic pointer straight to the source record
-- (EM_LinkTable/EM_LinkUniqueID), so filter directly on S00075834's JS_PK
-- (FE127730-840D-49DB-8B48-67C25536146A, from Step 1) instead of only a
-- time window - more precise than guessing the window is wide enough.
-- ============================================================
SELECT
    ei.EI_PK, ei.EI_SystemCreateTimeUtc, ei.EI_Status,
    em.EM_PK, em.EM_MessageType, em.EM_Status, em.EM_SystemCreateTimeUtc,
    em.EM_LinkTable, em.EM_LinkUniqueID
FROM EDIMessage em
LEFT JOIN EDIInterchange ei ON ei.EI_PK = em.EM_EI
WHERE em.EM_LinkUniqueID = 'FE127730-840D-49DB-8B48-67C25536146A'
ORDER BY em.EM_SystemCreateTimeUtc DESC;

-- Fallback if Step 2 returns nothing (in case EM_LinkUniqueID points to
-- JH_PK instead of JS_PK, or the message links some other way): widen back
-- to a time-window search.
-- SELECT
--     ei.EI_PK, ei.EI_SystemCreateTimeUtc, ei.EI_Status,
--     em.EM_PK, em.EM_MessageType, em.EM_Status, em.EM_SystemCreateTimeUtc
-- FROM EDIInterchange ei
-- LEFT JOIN EDIMessage em ON em.EM_EI = ei.EI_PK
-- WHERE ei.EI_SystemCreateTimeUtc >= '2026-08-30 18:15:00'
--   AND ei.EI_SystemCreateTimeUtc <  '2026-08-30 18:35:00'
-- ORDER BY ei.EI_SystemCreateTimeUtc DESC;

-- ============================================================
-- STEP 3 — confirm the trigger fired at job-instance level, not just
-- template-definition level. Same table as the template row (ProcessTasks)
-- but P9_FH_ProcessHeader populated for a real job instance - see
-- docs/discovery/edi-trigger-flow-mechanism-reference.md Stage 5.
-- Use JH_ParentID from Step 1 (the JobShipment JS_PK).
-- ============================================================
SELECT
    P9_PK, P9_Type, P9_Description, P9_SE_NKMilestoneEvent,
    P9_FH_ProcessHeader, P9_ParentID, P9_ParentTableCode,
    P9_SystemCreateTimeUtc
FROM ProcessTasks
WHERE P9_ParentID = 'FE127730-840D-49DB-8B48-67C25536146A'  -- S00075834's JS_PK, from Step 1
  AND P9_Type = 'TRG';

-- Checklist:
-- - Step 2 finding a matching EDIInterchange/EDIMessage row confirms CW's
--   own tracking recorded this as a real send, not just something the
--   mock listener happened to receive independently.
-- - Step 3 finding a row with P9_FH_ProcessHeader POPULATED (not blank)
--   confirms the trigger fired at the job-instance level for this
--   specific job - the final missing piece of Stage 4/5 confirmation.

-- Result 2026-08-30: Step 2 confirmed a PERFECT match - EI_PK
-- FE4FBF2C-DACD-4E4D-87CC-AA3D21C73737 is byte-for-byte identical to the
-- Eadaptor-Trackingid header captured in the mock listener log. Real,
-- confirmed end-to-end trace. BUT: EM_MessageType = 'XDC' on all 6 rows,
-- not 'XUS' (the trigger's configured Action) - meaning needs confirming
-- before declaring this the exact custom trigger's own send. Step 3
-- returned 46 rows - too many to eyeball, likely includes every trigger
-- definition on the global template being evaluated for this job, not
-- just ones that matched/fired. Two follow-ups before closing this out:

-- ============================================================
-- STEP 4 — what does EM_MessageType 'XDC' actually mean? Check for a real
-- lookup/reference table rather than guessing.
-- ============================================================
SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME LIKE '%MessageType%' OR TABLE_NAME LIKE '%RefEDI%'
ORDER BY TABLE_NAME;

-- ============================================================
-- STEP 5 — isolate just the custom trigger's own job-instance row(s) out
-- of the 46, by description, instead of eyeballing everything
-- ============================================================
SELECT
    P9_PK, P9_Type, P9_Description, P9_SE_NKMilestoneEvent,
    P9_FH_ProcessHeader, P9_SystemCreateTimeUtc
FROM ProcessTasks
WHERE P9_ParentID = 'FE127730-840D-49DB-8B48-67C25536146A'
  AND P9_Type = 'TRG'
  AND (P9_Description LIKE '%Full Integration%' OR P9_Description LIKE '%EDI%')
ORDER BY P9_SystemCreateTimeUtc DESC;

-- ============================================================
-- STEP 6 — refocus on Event Code DEX ("Data Export") specifically. StmALog
-- showed DEX events firing at the exact moments things happened (the
-- Billing edit that created JobHeader, and now possibly these XDC sends
-- too) - worth checking directly whether a trigger definition using DEX as
-- its milestone event is what's actually firing, rather than assuming it's
-- the custom BKC/EDT-based "Full Integration Testing" trigger.
--
-- 6a - is there a template-level trigger definition keyed on DEX at all?
-- ============================================================
SELECT
    P9_PK, P9_Type, P9_Description, P9_SE_NKMilestoneEvent,
    P9_ParentID, P9_ParentTableCode, P9_FH_ProcessHeader,
    P9_SystemCreateTimeUtc, P9_SystemCreateUser
FROM ProcessTasks
WHERE P9_Type = 'TRG'
  AND P9_SE_NKMilestoneEvent = 'DEX';

-- ============================================================
-- 6b - job-instance rows for S00075834 specifically keyed on DEX (out of
-- the 46 from Step 3) - if this is where the real firing happened, this
-- should return one or more rows with P9_FH_ProcessHeader populated,
-- timestamped close to the XDC sends (2026-08-30 10:14-10:23 UTC).
-- ============================================================
SELECT
    P9_PK, P9_Type, P9_Description, P9_SE_NKMilestoneEvent,
    P9_FH_ProcessHeader, P9_SystemCreateTimeUtc
FROM ProcessTasks
WHERE P9_ParentID = 'FE127730-840D-49DB-8B48-67C25536146A'
  AND P9_Type = 'TRG'
  AND P9_SE_NKMilestoneEvent = 'DEX'
ORDER BY P9_SystemCreateTimeUtc DESC;
