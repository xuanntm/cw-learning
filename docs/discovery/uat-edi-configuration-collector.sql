-- ============================================================
-- UAT EDI Configuration Collector
-- ============================================================
-- Purpose: full inventory of EDI integration configuration in UAT, for two
-- uses: (1) audit what currently exists, (2) reference pattern when setting
-- up a NEW integration - see the "New Integration Checklist" at the bottom.
--
-- Environment: UAT (H56TRN.db.test.wisegrid.net / OdysseyH56TRN).
-- Builds on docs/discovery/edi-communication-mechanism-reference.md and
-- docs/discovery/uat-integration-verification.sql - this script goes wider
-- (adds the legacy transport mechanism and message-type profiling) rather
-- than deeper on traffic volume, which the other script already covers.
--
-- Safety: SELECT-only. NEVER selects credential columns (ECA_Password,
-- ECA_ClientSecret, ECA_Certificate, ECA_EncodedPrivateKey, EK_Password,
-- EK_Certificate) - structure and config only, consistent with this repo's
-- credential-redaction convention.

-- ============================================================
-- STEP 1 — modern mechanism: full party + config + auth inventory
-- (extends uat-integration-verification.sql Query 1 with scoping/recency)
-- ============================================================
SELECT
    ecp.ECP_Name AS PartyName,
    ecp.ECP_ApplicationCode AS ApplicationCode,
    ecp.ECP_IsActive AS PartyIsActive,
    ecc.ECC_Endpoint AS Endpoint,
    ecc.ECC_Direction AS Direction,
    ecc.ECC_Status AS Status,
    ecc.ECC_IsActive AS ConfigIsActive,
    ecc.ECC_IsSelfManaged AS IsSelfManaged,
    eca.ECA_AuthorizationMode AS AuthMode,
    ecc.ECC_GB_Branch AS BranchPK,
    ecc.ECC_GE_Department AS DepartmentPK,
    ecc.ECC_SystemCreateTimeUtc AS ConfigCreatedUtc,
    ecc.ECC_SystemLastEditTimeUtc AS ConfigLastEditedUtc,
    ecc.ECC_SystemLastEditUser AS ConfigLastEditedBy
FROM EDICommunicationPartyConfig ecc
LEFT JOIN EDICommunicationParty ecp ON ecp.ECP_PK = ecc.ECC_ECP_Party
LEFT JOIN EDICommunicationAuth eca ON eca.ECA_PK = ecc.ECC_ECA_Auth
ORDER BY ecp.ECP_Name, ecc.ECC_Direction;


-- ============================================================
-- STEP 2 — legacy mechanism: EDICommunicationsMode (FTP/SFTP-style transport)
-- Separate from the modern ECC/ECA/ECP mechanism above - confirm whether
-- any active rows exist before assuming all integrations use eAdaptor Next.
-- ============================================================
SELECT
    EK_Module AS Module,
    EK_MessagePurpose AS MessagePurpose,
    EK_CommsDirection AS Direction,
    EK_CommunicationsTransport AS Transport,
    EK_Destination AS Destination,
    EK_ServerAddressSubject AS ServerAddress,
    EK_PortNumber AS Port,
    EK_FileFormat AS FileFormat,
    EK_LoginName AS LoginName,
    EK_DestinationFolder AS DestinationFolder,
    EK_SourceFolder AS SourceFolder,
    EK_TransportMode AS TransportMode,
    EK_ParentTableCode AS ParentTableCode,  -- polymorphic pointer pattern - see memory: cw-jobheader-subtype-link-pattern
    EK_ParentID AS ParentID,
    EK_LastFailed AS LastFailedUtc,
    EK_SystemCreateTimeUtc AS CreatedUtc,
    EK_ECC_CommunicationPartyConfig AS LinkedModernConfigPK  -- cross-reference to Step 1 if this legacy row is tied to a modern ECC record
FROM EDICommunicationsMode
ORDER BY EK_Module, EK_CommsDirection;


-- ============================================================
-- STEP 3 — discover the workflow-trigger-to-endpoint bridge
-- ProcessTaskNotification.PQ_ECS_MessageDeliveryContextSelector references
-- EDIMessageDeliveryContextSelector - not yet explored. This is likely how
-- CW decides WHICH EDICommunicationPartyConfig a fired trigger's message
-- actually goes out through. Discover its columns first (don't guess).
-- ============================================================
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'EDIMessageDeliveryContextSelector'
ORDER BY ORDINAL_POSITION;

SELECT
    fk.name AS ConstraintName,
    tp.name AS ParentTable,
    cp.name AS ParentColumn,
    tr.name AS RefTable,
    cr.name AS RefColumn
FROM sys.foreign_keys fk
JOIN sys.foreign_key_columns fkc ON fkc.constraint_object_id = fk.object_id
JOIN sys.tables tp ON tp.object_id = fkc.parent_object_id
JOIN sys.columns cp ON cp.object_id = tp.object_id AND cp.column_id = fkc.parent_column_id
JOIN sys.tables tr ON tr.object_id = fkc.referenced_object_id
JOIN sys.columns cr ON cr.object_id = tr.object_id AND cr.column_id = fkc.referenced_column_id
WHERE tp.name = 'EDIMessageDeliveryContextSelector' OR tr.name = 'EDIMessageDeliveryContextSelector';


-- ============================================================
-- STEP 4 — message-type profile per party (last 90 days)
-- What "shape" of messages currently flows through each integration -
-- useful reference pattern when scoping what a NEW integration should send.
-- ============================================================
SELECT
    ecp.ECP_Name AS PartyName,
    em.EM_ApplicationCode AS ApplicationCode,
    em.EM_MessageType AS MessageType,
    em.EM_MessageSubType AS MessageSubType,
    em.EM_ReceiveTransmit AS Direction,
    COUNT(*) AS MsgCount
FROM EDIMessage em
JOIN EDIInterchange ei ON ei.EI_PK = em.EM_EI
JOIN EDICommunicationPartyConfig ecc ON ecc.ECC_PK = ei.EI_ECC_CommunicationPartyConfig
LEFT JOIN EDICommunicationParty ecp ON ecp.ECP_PK = ecc.ECC_ECP_Party
WHERE em.EM_SystemCreateTimeUtc >= DATEADD(DAY, -90, SYSUTCDATETIME())
GROUP BY ecp.ECP_Name, em.EM_ApplicationCode, em.EM_MessageType, em.EM_MessageSubType, em.EM_ReceiveTransmit
ORDER BY ecp.ECP_Name, MsgCount DESC;


-- ============================================================
-- NEW INTEGRATION CHECKLIST (reference, not a query)
-- Based on the confirmed mechanism in docs/discovery/edi-communication-
-- mechanism-reference.md and this script's results, a new modern
-- (eAdaptor Next style) integration needs, at minimum:
--
--   1. EDICommunicationParty row       - the trading partner identity
--      (ECP_Name, ECP_ApplicationCode)
--   2. EDICommunicationAuth row        - the credential record
--      (pick ECA_AuthorizationMode: Basic / OAuth2 / Certificate, fill only
--      the fields for that mode - see the mechanism reference doc)
--   3. EDICommunicationPartyConfig row(s) - one per direction needed
--      (IN and/or OUT), each with its own ECC_Endpoint and linking to the
--      Party (1) and Auth (2) records above
--   4. Workflow Template wiring - a ProcessTemplateTrigger (and the
--      Notification/DeliveryContextSelector chain Step 3 is investigating)
--      so a CW business event actually fires the outbound send - a
--      Party+Config+Auth record alone does not cause anything to happen
--      without a trigger wired to it
--
-- Cross-check Step 1's "AuthMode" column against existing integrations for
-- a real example of each mode already configured in this environment.
-- ============================================================
