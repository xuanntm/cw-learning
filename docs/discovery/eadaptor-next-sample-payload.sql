-- ============================================================
-- Pull a real EDI message body to use as a Postman test template
-- ============================================================
-- Purpose: samples/xml/ has been an empty placeholder all session - rather
-- than guess CargoWise's Universal XML schema, pull one real historical
-- message from a KNOWN-WORKING integration (H56_TRN_CW2SAGE - confirmed
-- 19 real messages/30 days, docs/discovery/uat-integration-verification-
-- summary.md) and use that as the template for Postman testing.
--
-- ⚠️ REDACT BEFORE SAVING TO samples/xml/ - this is real integration
-- traffic and may contain real customer/job/address data. Replace any
-- organization names, addresses, job numbers, references, etc. with
-- obviously-fake placeholders before committing, per this repo's
-- credential/PII redaction convention (CLAUDE.md, docs/integration-design/
-- README.md).

SELECT TOP 5
    em.EM_PK,
    em.EM_MessageType,
    em.EM_MessageSubType,
    em.EM_Status,
    em.EM_SystemCreateTimeUtc,
    em.EM_MessageText,   -- redact before saving anywhere tracked
    em.EM_MessageNText   -- redact before saving anywhere tracked
FROM EDIMessage em
JOIN EDIInterchange ei ON ei.EI_PK = em.EM_EI
JOIN EDICommunicationPartyConfig ecc ON ecc.ECC_PK = ei.EI_ECC_CommunicationPartyConfig
JOIN EDICommunicationParty ecp ON ecp.ECP_PK = ecc.ECC_ECP_Party
WHERE ecp.ECP_Name = 'H56_TRN_CW2SAGE'
  AND em.EM_ReceiveTransmit = 'TRX'
  AND (em.EM_MessageText IS NOT NULL OR em.EM_MessageNText IS NOT NULL)
ORDER BY em.EM_SystemCreateTimeUtc DESC;

-- Pick whichever result has the most "typical" shape (not the shortest/
-- longest outlier), copy EM_MessageText (or EM_MessageNText if that's the
-- populated one) out, redact it, then save as samples/xml/eadaptor-next-
-- sample-payload.xml for the Postman collection to reference.
