-- ============================================================
-- EDI Full Configuration Finder
-- ============================================================
-- Purpose: given an Organization Code, pull the full end-to-end EDI
-- configuration chain in one query - Organization -> EDI Communications
-- routing -> EDI Client (Party/Config/Auth). Reusable for any real
-- example, not just one specific integration.
--
-- Chain (all columns confirmed earlier this session):
--   OrgHeader (OH_Code)
--     <- EDICommunicationsMode (EK_ParentTableCode='OH', EK_ParentID)
--          -> EDICommunicationPartyConfig (EK_ECC_CommunicationPartyConfig)
--               -> EDICommunicationParty (ECC_ECP_Party)
--               -> EDICommunicationAuth (ECC_ECA_Auth)
--
-- Safety: SELECT-only, no credential values ever selected.

-- ============================================================
-- STEP 1 — full chain for a given Organization Code (fill in the code)
-- ============================================================
SELECT
    oh.OH_Code AS OrgCode,
    oh.OH_FullName AS OrgName,
    ek.EK_Module AS Module,
    ek.EK_CommsDirection AS Direction,
    ek.EK_CommunicationsTransport AS Transport,
    ek.EK_MessagePurpose AS PurposeCode,
    ecp.ECP_Name AS EdiClientName,
    ecp.ECP_ApplicationCode AS ApplicationCode,
    ecc.ECC_Direction AS ConfigDirection,
    ecc.ECC_Endpoint AS Endpoint,
    ecc.ECC_IsActive AS ConfigIsActive,
    ecc.ECC_Status AS ConfigStatus,
    eca.ECA_AuthorizationMode AS AuthMode,
    eca.ECA_Username AS AuthUsername
FROM OrgHeader oh
JOIN EDICommunicationsMode ek ON ek.EK_ParentTableCode = 'OH' AND ek.EK_ParentID = oh.OH_PK
LEFT JOIN EDICommunicationPartyConfig ecc ON ecc.ECC_PK = ek.EK_ECC_CommunicationPartyConfig
LEFT JOIN EDICommunicationParty ecp ON ecp.ECP_PK = ecc.ECC_ECP_Party
LEFT JOIN EDICommunicationAuth eca ON eca.ECA_PK = ecc.ECC_ECA_Auth
WHERE oh.OH_Code = '<ORG_CODE>'   -- e.g. a real Organization Code you want to use as a reference example
ORDER BY ek.EK_Module, ek.EK_MessagePurpose;


-- ============================================================
-- STEP 2 — discover ProcessTemplateTrigger's real columns (not yet
-- confirmed this session) - needed to pull the actual trigger condition
-- expressions/event codes tied to this Organization's message purpose,
-- to see the complete example including workflow-side wiring.
-- ============================================================
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'ProcessTemplateTrigger'
ORDER BY ORDINAL_POSITION;

-- ============================================================
-- STEP 3 — real columns confirmed (tmp/ProcessTemplateTrigger_202608292332.csv).
-- IMPORTANT CORRECTION: there is NO Action/Purpose/RecipientOrg column on
-- this table - the document's "Completion Trigger Action" is a SEPARATE,
-- related table, not columns here. P9T_TriggerConditionValue is varbinary
-- (encoded/serialized) - the readable condition text, if any, is more
-- likely in P9T_TriggerCondition (varchar) or not plainly readable at all.
--
-- Find a recently-created trigger by creator/time rather than guessing
-- which template it's on:
-- ============================================================
SELECT
    tpl.P0_Name AS TemplateName,
    p9t.P9T_PK,
    p9t.P9T_Description,
    p9t.P9T_Sequence,
    p9t.P9T_SE_NKTriggerEvent AS EventCode,
    p9t.P9T_TriggerField,
    p9t.P9T_TriggerCondition,
    p9t.P9T_IsActive,
    p9t.P9T_SystemCreateTimeUtc,
    p9t.P9T_SystemCreateUser
FROM ProcessTemplateTrigger p9t
JOIN ProcessTaskTemplate tpl ON tpl.P0_PK = p9t.P9T_P0_Template
WHERE p9t.P9T_SystemCreateUser = 'SNG'  -- adjust to your own CW username if different
ORDER BY p9t.P9T_SystemCreateTimeUtc DESC;

-- ============================================================
-- STEP 4 — discover the real "Completion Trigger Action" table via FK
-- (don't guess a name - find whatever actually references P9T_PK)
-- ============================================================
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
WHERE tr.name = 'ProcessTemplateTrigger' OR tp.name = 'ProcessTemplateTrigger';
