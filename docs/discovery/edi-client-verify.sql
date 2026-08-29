-- ============================================================
-- EDI Client Verification — reusable for any client by name
-- ============================================================
-- Purpose: verify a newly-created EDI Client's config is correct, and
-- (once a real send has been triggered) confirm the resulting EDIMessage/
-- EDIInterchange records. Safe, SELECT-only, no credential values ever
-- selected.

-- ============================================================
-- STEP 1 — confirm the party/config/auth records look right
-- Replace 'Full Integration' with the real EDI Client name.
-- ============================================================
SELECT
    ecp.ECP_Name,
    ecp.ECP_ApplicationCode,
    ecp.ECP_IsActive AS PartyIsActive,
    ecc.ECC_Direction,
    ecc.ECC_Endpoint,
    ecc.ECC_IsActive AS ConfigIsActive,
    ecc.ECC_Status,
    ecc.ECC_GB_Branch,
    ecc.ECC_GE_Department,
    eca.ECA_AuthorizationMode,
    eca.ECA_Username,
    ecc.ECC_SystemCreateTimeUtc,
    ecc.ECC_SystemCreateUser
FROM EDICommunicationParty ecp
LEFT JOIN EDICommunicationPartyConfig ecc ON ecc.ECC_ECP_Party = ecp.ECP_PK
LEFT JOIN EDICommunicationAuth eca ON eca.ECA_PK = ecc.ECC_ECA_Auth
WHERE ecp.ECP_Name = 'Full Integration';

-- Checklist against the result:
--   PartyIsActive = 1, ConfigIsActive = 1 for the Outbound row
--   ECC_Endpoint = your ngrok URL, exactly (https://, no trailing slash mismatch)
--   ECA_AuthorizationMode = 'BAU', ECA_Username = the username you set on
--     the mock listener's -ExpectedUsername
--   No Inbound row active, unless you deliberately enabled it too

-- ============================================================
-- STEP 2 — after triggering a real send, confirm it landed
-- (run after Stage 3 in chat - triggering a real business event)
-- ============================================================
SELECT TOP 20
    em.EM_PK,
    em.EM_Status,
    em.EM_ReceiveTransmit,
    em.EM_MessageType,
    em.EM_MessageSubType,
    em.EM_SystemCreateTimeUtc,
    ei.EI_Status AS InterchangeStatus,
    ei.EI_RetryCount
FROM EDIMessage em
JOIN EDIInterchange ei ON ei.EI_PK = em.EM_EI
JOIN EDICommunicationPartyConfig ecc ON ecc.ECC_PK = ei.EI_ECC_CommunicationPartyConfig
JOIN EDICommunicationParty ecp ON ecp.ECP_PK = ecc.ECC_ECP_Party
WHERE ecp.ECP_Name = 'Full Integration'
ORDER BY em.EM_SystemCreateTimeUtc DESC;

-- If this returns nothing at all after a real trigger attempt, the message
-- never got past CW's own send logic - check EI_RetryCount/EI_Status on
-- any related interchange, or whether the Organization's EDI Communication
-- Mode is actually pointed at this EDI Client (see Stage 3 in chat).
