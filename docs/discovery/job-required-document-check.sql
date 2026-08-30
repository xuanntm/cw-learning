-- ============================================================
-- JobRequiredDocument check — does S00075824 have a BKC requirement,
-- and is it marked received?
-- ============================================================
-- Confirmed table/columns (tmp/doc_structure_202608300052.csv):
-- JobRequiredDocument.EQ_DocType, JobRequiredDocument.EQ_DateReceived.
-- Join key not yet confirmed - discover full columns first.

-- ============================================================
-- STEP 1 — discover full JobRequiredDocument columns (find the job/
-- shipment link column - not yet confirmed)
-- ============================================================
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'JobRequiredDocument'
ORDER BY ORDINAL_POSITION;

-- ============================================================
-- STEP 2 — real query. Confirmed: EQ_ParentID + EQ_ParentTableCode is
-- another instance of the polymorphic pointer pattern. Using the known
-- JS_PK for S00075824 to check the match AND confirm the real
-- ParentTableCode value empirically (rather than guessing 'JS'/'JH').
-- ============================================================
SELECT
    EQ_DocType,
    EQ_DocCategory,
    EQ_ParentTableCode,
    EQ_ParentID,
    EQ_DateReceived,
    EQ_DateRequired,
    EQ_SystemCreateTimeUtc,
    EQ_SystemLastEditTimeUtc
FROM JobRequiredDocument
WHERE EQ_ParentID = 'ED00D373-610F-44D8-B441-7FB15623174C'  -- JS_PK for S00075824
ORDER BY EQ_DocType;

-- Checklist: does a row with EQ_DocType = 'BKC' exist at all? If not, the
-- requirement itself needs to be added before any upload can satisfy it.
-- If it exists, is EQ_DateReceived populated (non-null)? If null, the
-- uploaded document was attached but never matched/reconciled against
-- this specific requirement.
