-- ============================================================
-- Inbound Certificate Generation — Post-Generate Check
-- ============================================================
-- Purpose: user clicked "Generate Certificate" on the "Full Integration"
-- inbound EDI Client config and noticed other fields auto-populated.
-- Check what actually changed on EDICommunicationAuth (ECA_) - this could
-- reveal whether CW auto-provisions OAuth registration details itself, or
-- whether a separate Entra ID app registration is still needed.
--
-- NEVER select ECA_Certificate, ECA_EncodedPrivateKey,
-- ECA_RenewalEncodedPrivateKey, ECA_ClientSecret, or any other credential/
-- key material - structure and metadata only, per this repo's
-- credential-redaction convention.

-- ============================================================
-- STEP 1 — confirm ECA's full real column list (don't guess names)
-- ============================================================
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'EDICommunicationAuth'
ORDER BY ORDINAL_POSITION;

-- ============================================================
-- STEP 2 — pull non-secret metadata for the "Full Integration" inbound
-- config specifically (ECC_PK CB67A409-1CEC-4E17-AAF4-3D23BB36968D,
-- confirmed earlier via inbound-edi-config-discovery.sql Step 1).
-- Fill in real column names once Step 1 confirms them - this is a
-- starting guess based on the mechanism reference doc, EXCLUDING every
-- secret/key column.
-- ============================================================
SELECT
    eca.ECA_PK,
    eca.ECA_AuthorizationMode,
    eca.ECA_ClientID,
    eca.ECA_AuthorizationEndpoint,
    eca.ECA_Scopes,
    eca.ECA_FlowCode,
    eca.ECA_SystemCreateTimeUtc,
    eca.ECA_SystemCreateUser,
    eca.ECA_SystemLastEditTimeUtc,
    eca.ECA_SystemLastEditUser
FROM EDICommunicationAuth eca
JOIN EDICommunicationPartyConfig ecc ON ecc.ECC_ECA_Auth = eca.ECA_PK
WHERE ecc.ECC_PK = 'CB67A409-1CEC-4E17-AAF4-3D23BB36968D';

-- Result 2026-08-30: ECA_FlowCode='CCT' confirmed, ECA_ClientID and
-- ECA_AuthorizationEndpoint (real tenant GUID) already existed as of
-- ECA_SystemCreateTimeUtc 2026-08-29 13:11 - a day BEFORE today's
-- "Generate Certificate" click (ECA_SystemLastEditTimeUtc 2026-08-30
-- 14:37). This means the Entra ID app registration already existed;
-- Generate Certificate only updated the certificate/key fields on this
-- same pre-existing registration - no separate manual Entra Portal setup
-- needed for THIS app registration.

-- ============================================================
-- STEP 3 — two more non-secret columns for the full picture:
-- ECA_OperationId (likely a tracking ID for the generate-certificate
-- operation) and ECA_Resource
-- ============================================================
SELECT
    eca.ECA_PK, eca.ECA_OperationId, eca.ECA_Resource,
    eca.ECA_RenewalOperationId
FROM EDICommunicationAuth eca
JOIN EDICommunicationPartyConfig ecc ON ecc.ECC_ECA_Auth = eca.ECA_PK
WHERE ecc.ECC_PK = 'CB67A409-1CEC-4E17-AAF4-3D23BB36968D';
