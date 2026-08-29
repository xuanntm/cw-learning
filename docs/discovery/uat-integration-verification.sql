-- ============================================================
-- UAT Integration Verification — data collection for QA test planning
-- ============================================================
-- Purpose: give the QA team a concrete, evidence-based starting point for
-- planning UAT integration verification, without requiring deep CW business
-- knowledge upfront. Answers: what integrations are actually configured in
-- UAT, do they mirror PROD (so tests are realistic), and what does recent
-- traffic/health look like.
--
-- Environment: UAT (H56TRN.db.test.wisegrid.net / OdysseyH56TRN).
-- Schema confirmed 2026-08-29 against PROD in
-- docs/discovery/edi-communication-mechanism-reference.md - same CW
-- application schema, so these queries should work unchanged against UAT.
-- If any errors on real column/table names, re-run the discovery pattern
-- from that file rather than guessing further.
--
-- Safety: all SELECT-only, no credential values ever selected (ECA_Password/
-- ECA_ClientSecret/ECA_Certificate/ECA_EncodedPrivateKey excluded on
-- purpose - see the caution in edi-communication-mechanism-reference.md).

-- ============================================================
-- QUERY 1 — every configured integration endpoint in UAT
-- ============================================================
SELECT
    ecp.ECP_Name AS PartyName,
    ecp.ECP_ApplicationCode AS ApplicationCode,
    ecp.ECP_IsActive AS PartyIsActive,
    ecc.ECC_Endpoint AS Endpoint,
    ecc.ECC_Direction AS Direction,
    ecc.ECC_Status AS Status,
    ecc.ECC_IsActive AS ConfigIsActive,
    eca.ECA_AuthorizationMode AS AuthMode
FROM EDICommunicationPartyConfig ecc
LEFT JOIN EDICommunicationParty ecp ON ecp.ECP_PK = ecc.ECC_ECP_Party
LEFT JOIN EDICommunicationAuth eca ON eca.ECA_PK = ecc.ECC_ECA_Auth
ORDER BY ecp.ECP_Name, ecc.ECC_Direction;


-- ============================================================
-- QUERY 2 — UAT vs. PROD endpoint comparison
-- PROD's confirmed endpoints (2026-08-29, docs/discovery/edi-communication-
-- mechanism-reference.md): BravoTrans, SAPI, Sage, Kestrel, VNPT (all
-- ECC_Endpoint LIKE '%eAdaptorNext%', all OUT direction). Run Query 1's
-- result against this list manually, or use this filtered version to check
-- specifically for eAdaptorNext-pattern endpoints in UAT:
-- ============================================================
SELECT
    ecp.ECP_Name AS PartyName,
    ecc.ECC_Endpoint AS Endpoint,
    ecc.ECC_Direction AS Direction,
    ecc.ECC_Status AS Status
FROM EDICommunicationPartyConfig ecc
LEFT JOIN EDICommunicationParty ecp ON ecp.ECP_PK = ecc.ECC_ECP_Party
WHERE ecc.ECC_Endpoint LIKE '%eAdaptorNext%'
ORDER BY ecp.ECP_Name;

-- Manually cross-check the PartyName/Endpoint list above against PROD's:
--   BravoTrans, SAPI, Sage, Kestrel, VNPT
-- Any PROD endpoint missing here = QA can't realistically test that
-- integration in UAT until it's configured. Any UAT-only endpoint = confirm
-- with the team whether it's intentional test scaffolding.


-- ============================================================
-- QUERY 3 — recent message/interchange traffic health (last 30 days)
-- Same pattern as the PROD status breakdown in
-- docs/discovery/edi-communication-mechanism-reference.md. Status codes are
-- inferred from abbreviation, not from a lookup table - treat as plausible,
-- not certain (PRS=Parsed, SNT=Sent, CAP=Captured, WAR=Warning, REJ=Rejected).
-- ============================================================
SELECT EM_Status, EM_ReceiveTransmit, COUNT(*) AS MsgCount
FROM EDIMessage
WHERE EM_SystemCreateTimeUtc >= DATEADD(DAY, -30, SYSUTCDATETIME())
GROUP BY EM_Status, EM_ReceiveTransmit
ORDER BY MsgCount DESC;

-- If this returns near-zero rows across the board, that itself is a finding
-- worth telling QA up front: UAT may not have enough recent real traffic to
-- verify against, and test data/synthetic messages may be needed instead.


-- ============================================================
-- QUERY 4 — per-endpoint message volume (which endpoints actually have
-- recent traffic to test against, not just config that exists)
-- ============================================================
SELECT
    ecp.ECP_Name AS PartyName,
    ecc.ECC_Endpoint AS Endpoint,
    COUNT(em.EM_PK) AS MessageCount_Last30Days
FROM EDICommunicationPartyConfig ecc
LEFT JOIN EDICommunicationParty ecp ON ecp.ECP_PK = ecc.ECC_ECP_Party
LEFT JOIN EDIInterchange ei ON ei.EI_ECC_CommunicationPartyConfig = ecc.ECC_PK
LEFT JOIN EDIMessage em ON em.EM_EI = ei.EI_PK
    AND em.EM_SystemCreateTimeUtc >= DATEADD(DAY, -30, SYSUTCDATETIME())
GROUP BY ecp.ECP_Name, ecc.ECC_Endpoint
ORDER BY MessageCount_Last30Days DESC;
