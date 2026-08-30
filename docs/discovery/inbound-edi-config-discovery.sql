-- ============================================================
-- Inbound EDI Configuration Discovery
-- ============================================================
-- Purpose: everything confirmed this session about EDICommunicationsMode
-- (EK_) Org routing was for OUTBOUND only ("EDI Communication mode on
-- Organization now can specify the EDI Client to use when EAM sends
-- outbound eAdaptor messages" - edi-client-setup-guide-summary.md). We
-- don't know whether inbound needs an equivalent EK_ routing row, or
-- whether inbound identifies the sender purely via the EDI Client's own
-- auth (certificate/OAuth), with no Org-level routing needed at all.
-- Base this on real existing inbound configs instead of guessing.

-- ============================================================
-- STEP 1 — any real EDICommunicationPartyConfig rows with Direction=IN?
-- (docs/discovery/edi-communication-mechanism-reference.md's PROD sample
-- only showed OUT rows - confirm whether any IN rows exist at all, here
-- or in UAT)
-- ============================================================
SELECT
    ecc.ECC_PK, ecc.ECC_Direction, ecc.ECC_Status, ecc.ECC_Endpoint,
    ecc.ECC_GB_Branch, ecc.ECC_GE_Department,
    ecp.ECP_Name, ecp.ECP_ApplicationCode, ecp.ECP_IsActive,
    eca.ECA_AuthorizationMode
FROM EDICommunicationPartyConfig ecc
LEFT JOIN EDICommunicationParty ecp ON ecp.ECP_PK = ecc.ECC_ECP_Party
LEFT JOIN EDICommunicationAuth eca ON eca.ECA_PK = ecc.ECC_ECA_Auth
WHERE ecc.ECC_Direction = 'IN'
ORDER BY ecp.ECP_Name;

-- ============================================================
-- STEP 2 — for whichever inbound client(s) Step 1 finds, check whether an
-- EDICommunicationsMode (EK_) row also references it, and what
-- EK_CommsDirection value it uses (confirm whether it's still 'TRX', or a
-- different code for inbound - e.g. 'RCV')
-- ============================================================
SELECT
    ek.EK_PK, ek.EK_Module, ek.EK_CommsDirection, ek.EK_CommunicationsTransport,
    ek.EK_MessagePurpose, ek.EK_ParentTableCode, ek.EK_ParentID,
    ek.EK_ECC_CommunicationPartyConfig
FROM EDICommunicationsMode ek
WHERE ek.EK_ECC_CommunicationPartyConfig IN (
    -- paste ECC_PK values from Step 1 here once known
    SELECT ECC_PK FROM EDICommunicationPartyConfig WHERE ECC_Direction = 'IN'
);

-- Interpretation:
-- - If Step 2 returns rows, inbound DOES use the same Org-routing
--   mechanism as outbound - just check what EK_CommsDirection value marks
--   it as inbound (likely something other than 'TRX').
-- - If Step 2 returns nothing even though Step 1 found real inbound
--   clients, inbound identification happens purely through the EDI
--   Client's own auth (certificate/OAuth ties the sender to a specific
--   ECP_Party directly) - no Org-level routing row needed for inbound at
--   all. This would mean setting up Branch/Department + certificate auth
--   on the EDI Client itself is sufficient, with nothing further needed
--   on any Organization record.
