-- ============================================================
-- Inbound/Outbound EDI Request Log — basic info (time + source)
-- ============================================================
-- Purpose: quick operational check of recent EDI traffic (both
-- directions), showing when a message happened and which EDI Client/
-- trading partner it belongs to. Builds on the confirmed table family
-- from docs/discovery/edi-communication-mechanism-reference.md.

-- ============================================================
-- STEP 1 — confirm whether EDIMessage/EDIInterchange have a real
-- Direction column, or whether "direction" was inferred from EM_Status
-- codes in the earlier analysis (don't assume a column name exists)
-- ============================================================
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN ('EDIMessage', 'EDIInterchange')
  AND (COLUMN_NAME LIKE '%Direction%' OR COLUMN_NAME LIKE '%Status%' OR COLUMN_NAME LIKE '%Type%')
ORDER BY TABLE_NAME, ORDINAL_POSITION;

-- ============================================================
-- STEP 2 — real query: last 24 hours of EDI traffic, both directions,
-- with time + source (EDI Client/party name) + status. Adjust the time
-- window as needed. ECC_Direction (IN/OUT) comes from the party's own
-- config, confirmed earlier this session - safe source of direction here.
-- ============================================================
SELECT
    em.EM_SystemCreateTimeUtc AS MessageTimeUtc,
    ecc.ECC_Direction,
    ecp.ECP_Name AS EdiClientName,
    em.EM_MessageType,
    em.EM_Status,
    em.EM_LinkTable,
    em.EM_LinkUniqueID,
    ei.EI_PK,
    ei.EI_Status AS InterchangeStatus
FROM EDIMessage em
LEFT JOIN EDIInterchange ei ON ei.EI_PK = em.EM_EI
LEFT JOIN EDICommunicationPartyConfig ecc ON ecc.ECC_PK = em.EM_ECC_CommunicationPartyConfig
LEFT JOIN EDICommunicationParty ecp ON ecp.ECP_PK = ecc.ECC_ECP_Party
WHERE em.EM_SystemCreateTimeUtc >= DATEADD(HOUR, -24, SYSUTCDATETIME())
ORDER BY em.EM_SystemCreateTimeUtc DESC;

-- Checklist:
-- - ECC_Direction = 'OUT' rows are outbound sends (e.g. the S00075834
--   "Full Integration" traffic from earlier this session).
-- - ECC_Direction = 'IN' rows are inbound requests (e.g. the
--   UNLOCO/Native XML test once the OAuth fix landed).
-- - EM_LinkTable/EM_LinkUniqueID (polymorphic pointer) identifies which
--   job/record the message relates to, when applicable.

-- Result 2026-08-31 (Step 1): confirmed no real Direction column on
-- EDIMessage/EDIInterchange - only EI_InterchangeType/EI_TransportType,
-- EM_MessageType/EM_MessageSubType/EM_TransportType. ECC_Direction (from
-- EDICommunicationPartyConfig) remains the right, confirmed source of
-- direction used in Step 2 above.

-- ============================================================
-- STEP 3 — same as Step 2, but scoped to just the "Full Integration"
-- EDI Client (both directions), and widened to the full week rather than
-- 24 hours since this client's traffic spans this whole session
-- ============================================================
SELECT
    em.EM_SystemCreateTimeUtc AS MessageTimeUtc,
    ecc.ECC_Direction,
    ecp.ECP_Name AS EdiClientName,
    em.EM_MessageType,
    em.EM_MessageSubType,
    em.EM_Status,
    em.EM_LinkTable,
    em.EM_LinkUniqueID,
    ei.EI_PK,
    ei.EI_Status AS InterchangeStatus
FROM EDIMessage em
LEFT JOIN EDIInterchange ei ON ei.EI_PK = em.EM_EI
LEFT JOIN EDICommunicationPartyConfig ecc ON ecc.ECC_PK = em.EM_ECC_CommunicationPartyConfig
LEFT JOIN EDICommunicationParty ecp ON ecp.ECP_PK = ecc.ECC_ECP_Party
WHERE ecp.ECP_Name = 'Full Integration'
ORDER BY em.EM_SystemCreateTimeUtc DESC;
