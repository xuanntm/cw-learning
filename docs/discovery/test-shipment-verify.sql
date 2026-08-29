-- ============================================================
-- Test Shipment Verification — reusable for any job number
-- ============================================================
-- Purpose: verify a test job's basic info and org-role assignment
-- (Controlling Customer/Consignor/Consignee) before relying on it to fire
-- a workflow trigger. Built for S00075824 but reusable for any job.
--
-- IMPORTANT: JH_JobNum is only unique PER COMPANY, not globally (confirmed
-- via a real unique index NR_UX__JH_JobNum_JH_GC - see the cw-job-number-
-- not-globally-unique memory / docs/discovery/glbbranch-table-reference.md
-- point 5). If Step 1 returns more than one row, you have jobs with the
-- same number in different companies - use CompanyCode to disambiguate
-- before trusting anything downstream.

-- ============================================================
-- STEP 1 — job existence + company/branch/department context (safe, run now)
-- ============================================================
SELECT
    JH_JobNum,
    GC_Code AS CompanyCode,
    GC_Name AS CompanyName,
    GB_Code AS BranchCode,
    GB_BranchName AS BranchName,
    GE_Code AS DeptCode,
    JH_A_JOP AS OpenDate,
    JH_ParentTableCode,
    JH_ParentID,
    JH_PK
FROM JobHeader
LEFT JOIN GlbBranch ON GB_PK = JH_GB
LEFT JOIN GlbCompany ON GC_PK = GB_GC
LEFT JOIN GlbDepartment ON GE_PK = JH_GE
WHERE JH_JobNum = 'S00075824';

-- If more than one row: note the CompanyCode of the one you actually
-- created (should match wherever you're testing - UAT), and use its
-- JH_ParentID for Step 3 below.

-- ============================================================
-- STEP 2 — discover JobShipment's real columns (not yet confirmed this
-- session - needed to find the Controlling Customer/Consignor/Consignee
-- columns without guessing a name)
-- ============================================================
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'JobShipment'
ORDER BY ORDINAL_POSITION;


-- ============================================================
-- STEP 3 — CORRECTION: JobShipment's real columns (confirmed
-- tmp/JobShipment_202608292358.csv) have NO ControllingCustomer/Consignor/
-- Consignee column at all - only fixed roles (Forwarder/TranshipAgent/
-- DeliveryAgent/ExportBroker/ImportBroker/Creditor). These org roles are
-- very likely stored in a separate address/role collection table instead
-- of fixed FK columns. Search the whole schema for it rather than guess
-- a table name:
-- ============================================================
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE COLUMN_NAME LIKE '%ControllingCustomer%'
   OR COLUMN_NAME LIKE '%Consignor%'
   OR COLUMN_NAME LIKE '%Consignee%'
ORDER BY TABLE_NAME, COLUMN_NAME;

-- ============================================================
-- STEP 4 — Step 3 result (tmp/query_3_202608300001.csv): best candidate is
-- an existing CW-maintained view, cvw_JobShipmentOrgs, which already has
-- ControllingCustomer_Code/FullName/PK plus Consignor/Consignee natural
-- keys and PKs in one place - better than manually reconstructing the
-- role logic across the OA_/OH_ tables ourselves. Discover its full
-- column list first to find the join key (not shown in the filtered
-- search above):
-- ============================================================
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'cvw_JobShipmentOrgs'
ORDER BY ORDINAL_POSITION;

-- ============================================================
-- STEP 5 — real query, confirmed columns (tmp/cvw_JobShipmentOrgs_202608300003.csv).
-- JS_PK is the join key, matching JH_ParentID from Step 1.
-- ============================================================
SELECT
    ControllingCustomer_Code,
    ControllingCustomer_FullName,
    JS_E2_OA_OH_NKConsignor AS ConsignorCode,
    JS_E2_OA_OH_ConsignorFullName AS ConsignorFullName,
    JS_E2_OA_OH_NKConsignee AS ConsigneeCode,
    JS_E2_OA_OH_ConsigneeFullName AS ConsigneeFullName,
    ControllingAgent_Code,
    ControllingAgent_FullName
FROM cvw_JobShipmentOrgs
WHERE JS_PK = 'ED00D373-610F-44D8-B441-7FB15623174C';  -- JH_ParentID for S00075824, from Step 1

-- Checklist: at least one of ControllingCustomer_Code/ConsignorCode/
-- ConsigneeCode should show 'FULTESVIC', matching whichever role your
-- workflow trigger condition checks.
