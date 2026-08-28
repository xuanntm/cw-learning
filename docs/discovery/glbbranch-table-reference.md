# GlbBranch — Table Reference

Environment: PROD (`H56PRD.db.wisegrid.net` / `OdysseyH56PRD`). Written up as a standing reference since this table will back many future reports — every operational, financial, and workflow table in the schema seems to carry at least one branch reference.

Source data: `tmp/Query_GlobalBranch_202608282333.csv` (own columns) and `tmp/Query_GlobalBranch_ER_202608282341.csv` (real FK constraints, both directions) — both gitignored, not tracked in the repo.

## What it is

`GlbBranch` is the **branch/office master table** — one row per operating branch (physical office/location) within a company. Confirmed real FK constraints exist for this table (not just naming-convention inference like most other relationships mapped so far in this repo).

- **PK:** `GB_PK` (`uniqueidentifier`)
- **Natural key:** `GB_Code` (`char`)
- **Display name:** `GB_BranchName` (`nvarchar`)

## Own columns (27 total)

| Column | Type | Notes |
|---|---|---|
| `GB_PK` | uniqueidentifier | Primary key |
| `GB_IsValid`, `GB_IsActive` | bit | Standard validity/active flags |
| `GB_Code` | char | Natural key / short code shown in UI |
| `GB_BranchName` | nvarchar | Full branch name |
| `GB_Address1`, `GB_Address2`, `GB_City`, `GB_State`, `GB_PostCode` | nvarchar/varchar | Address fields (also see `GB_OA_AddressProxy` below — a fuller address record exists elsewhere) |
| `GB_Phone`, `GB_Fax`, `GB_InternalExtension`, `GB_Email`, `GB_WebAddress` | varchar/nvarchar | Contact details |
| `GB_RL_NKHomePort` | varchar | Natural-key reference to the branch's home port |
| `GB_LocalDocLanguage` | varchar | Document language default |
| `GB_OH_OrgProxy` | uniqueidentifier | **FK → `OrgHeader.OH_PK`** — every branch has a shadow Org record |
| `GB_GC` | uniqueidentifier | **FK → `GlbCompany.GC_PK`** — the operating company this branch belongs to |
| `GB_AccountingGroupCode` | varchar | Accounting group classification |
| `GB_OA_AddressProxy` | uniqueidentifier | **FK → `OrgAddress.OA_PK`** — the branch's structured address record |
| `GB_RN_NKCountryCode` | varchar | Country |
| `GB_AddressMap`, `GB_GeoLocation` | varchar/geography | Mapping/geo data |
| `GB_ValidationStatus` | char | Address validation status |
| `GB_AutoVersion` | smallint | Optimistic concurrency version |
| `GB_SystemCreateTimeUtc`, `GB_SystemCreateUser`, `GB_SystemLastEditTimeUtc`, `GB_SystemLastEditUser` | smalldatetime/varchar | Standard audit columns |

## Outbound relationships (what GlbBranch depends on)

Only 3 — `GlbBranch` is a leaf-ish dimension table, not itself dependent on much:

| Column | References |
|---|---|
| `GB_OH_OrgProxy` | `OrgHeader.OH_PK` |
| `GB_GC` | `GlbCompany.GC_PK` |
| `GB_OA_AddressProxy` | `OrgAddress.OA_PK` |

So a branch's full Org-style detail (if ever needed) and its full structured address are both one join away via these proxies.

## Inbound relationships (what references GlbBranch) — 113 total

Every row below is `<Table>.<Column> → GlbBranch.GB_PK`. Grouped by functional domain for usability.

### Job / Shipment operations
`JobHeader` (`JH_GB`, `JH_GB_TaxBranch`), `JobCharge` (`JR_GB`, `JR_GB_InternalBranch`, `JR_GB_CostTaxBranch`, `JR_GB_SellTaxBranch`), `JobCartage` (`JJ_GB`), `JobMawb` (`JM_GB`), `JobDeclaration` (`JE_GB`), `JobConsolCost` (`E6_GB_CostTaxBranch`), `JobComInvoiceHeader` (`JZ_GB`), `CarrierShipmentHeader` (`CSH_GB_Branch`), `CusTempStorageJobHeader` (`SJH_GB`), `PkgHandlingUnit` (`KPU_GB_Branch`), `DtbBooking` (`KM_GB_Branch`), `DtbConsignment` (`LTC_GB_Branch`), `DtbConsignmentRunSheet` (`KG_GB_Branch`)

### Customs / Compliance
`CusMiscRequestHeader` (`CMR_GB`), `CusISFHeader` (`BF_GB`, `BF_GB_Origin`), `CusInBondHeader` (`BH_GB`), `CusReconDeclaration` (`CRD_GB_Branch`), `CusReconEntry` (`CRE_GB_Branch`), `CusMAWB` (`CM_GB`), `CusSeaManTranHead` (`BT_GB`), `CusSCAOceanBill` (`CB_GB`), `CusExitHeader` (`CXH_GB_Branch`), `CusUSLVClearance` (`ULH_GB`), `CusCAeMHMaster` (`BP_GB_Branch`), `AsycudaManifestHeader` (`AMA_GB`), `JPAFRHeader` (`JPH_GB_Branch`), `RefRfiConfig` (`RFC_GB_Branch`), `RfiRequest` (`RIQ_GB_Branch`), `AccComplianceReport` (`ACR_GB_Branch`), `AccComplianceSequence` (`XD_GB_BranchOwner`), `AccTransactionComplianceReportQueue` (`ACQ_GB_Branch`)

### Accounting / Finance
`AccApportionmentTemplateLines` (`Y0_GB`), `AccPayableOrderLine` (`APL_GB`), `AccGLAggregate` (`AA_GB`), `AccGLBudget` (`AU_GB`), `AccBankAccount` (`AB_GB`), `AccTaxTransaction` (`ATT_GB`), `AccTransactionHeader` (`AH_GB`, `AH_GB_TaxBranch`), `AccTransactionLines` (`AL_GB`, `AL_GB_TaxBranch`), `AccGeneralLedgerData` (`GLD_GB_Branch`, `GLD_GB_TaxBranch`), `AccPaymentBatch` (`APB_GB`), `AccPaymentApproval` (`AV_GB`), `AccChequeBook` (`AK_GB`), `AccChargeTaxOverride` (`AO_GB`), `AccChargeBranchOverride` (`YA_GB_SpecificBranch`), `AccDraftInvoiceHeader` (`AIH_GB_Branch`), `AccQueryClaim` (`AY_GB`), `AccAssetCategory` (`ACY_GB_Branch`), `AccAssetHeader` (`AAH_GB_Branch`), `AccAssetTransactionHeader` (`ASH_GB_Branch`), `AccAssetTransactionLine` (`ASL_GB_Branch`), `AccAllowedBranchDepartmentCombo` (`AAB_GB_Branch`), `OrgARTerms` (`PY_GB_Branch`)

### Workflow / Process engine (directly relevant to the ongoing workflow-template audit)
`ProcessTasks` (`P9_GB_TriggerBranch`), `ProcessTaskTemplate` (`P0_GB`), `ProcessTemplateTrigger` (`P9T_GB_TriggerBranch`), `ProcessTemplateReleaseGateRuleMapping` (`RGM_GB_AgingBranch`), `ProcessHeader` (`FH_GB_Branch`, `FH_GB_EffectiveBranch`), `ProductionRuleSet` (`PRS_GB_Branch`), `BMBoard` (`MB_GB_AgingBranch`), `BMComponent` (`FC_GB_AgingBranch`), `BMNCNSchedule` (`BNC_GB_Branch`), `BPMConfigurationTmpl` (`VCT_GB_Branch`), `WorkItem` (`WKI_GB_AssignedBranch`), `WorkRequest` (`WKR_GB_Branch`), `GenApprovalRequest` (`XP_GB_RequestingBranch`, `XP_GB_JobBranch`), `TagRule` (`TGR_GB_Branch`), `TimeActionSchedule` (`TAS_GB_Branch`)

**Note:** `ProcessTaskTemplate.P0_GB` confirms Workflow Templates are themselves branch-scoped — worth cross-referencing against `docs/workflow/workflow-templates-analysis.md` if branch scope ever needs to be added to that analysis.

### EDI (relevant to Track A of the traffic analysis)
`EDIInterchange` (`EI_GB`), `EDIMessage` (`EM_GB`), `EDICommunicationPartyConfig` (`ECC_GB_Branch`)

### HR / Staff
`GlbStaff` (`GS_GB_HomeBranch`, `GS_GB_LastLogonBranch`), `GlbStaffCostCentre` (`GSK_GB_Branch`), `GlbTeam` (`GST_GB_Branch`), `GlbEmployingBranchDepartment` (`GHB_GB_Branch`), `GlbBeneficiaryBranchDepartment` (`GBB_GB_Branch`), `GlbEmploymentLocation` (`GEL_GB_SourceBranch`), `HROnBoarding` (`HOB_GB_HomeBranch`), `HRHiringRequest` (`HRR_GB_BeneficiaryBranch`), `HrlPolicy` (`LLP_GB_Branch`)

### Master data / Security / System
`GlbSecurity` (`GU_GB`), `GlbExternalPassword` (`GP_GB`), `GlbBranchDefaultPort` (`GBP_GB_Branch`), `GlbBranchExtraPorts` (`GY_GB`), `StmLink` (`STL_GB_LogonBranch`), `StmScheduleTask` (`S5_GB`), `StmPrintJob` (`SP_GB`), `StmDocumentDelivery` (`SDL_GB`), `MailDBItemTemplate` (`MIT_GB_Branch`), `OrgCompanyData` (`OB_GB_ControllingBranch`), `OrgCollectionNote` (`PN_GB_Branch`), `OrgContact` (`OC_GB_DefaultBranch`), `OrgDocument` (`OD_GB_FilterBranch`), `OrgAirlineBranchAccount` (`OAA_GB_Branch`), `OrgAirlineMAWBStockManagement` (`OHM_GB_Branch`), `OrgCBANumberFormat` (`CNF_GB_Branch`), `OrgCBANumberRange` (`CBR_GB_Branch`), `OrgMiscServ` (`OM_GB_WhsDefaultWarehouse`), `ExportAWBHeader` (`EH_GB_UserBranch`), `WhsWarehouse` (`WW_GB_RelatedCompanyBranch`), `GteGate` (`GTE_GB_Branch`)

## Practical guidance for report writers

1. **Many tables have more than one branch column for different roles** — don't blindly join on the first `_GB` column you find. Common patterns:
   - Operational branch vs. **tax branch** (`JH_GB` vs `JH_GB_TaxBranch`; same pattern on `AccTransactionHeader`, `AccTransactionLines`, `AccGeneralLedgerData`, `JobCharge`)
   - `JobCharge` alone has 4 separate branch roles (`JR_GB`, `JR_GB_InternalBranch`, `JR_GB_CostTaxBranch`, `JR_GB_SellTaxBranch`) — pick the one matching what the report is actually measuring (operational branch vs. cost/tax attribution).
   - Requesting branch vs. job branch (`GenApprovalRequest`), home branch vs. last-logon branch (`GlbStaff`), branch vs. effective branch (`ProcessHeader`).
2. **`GB_Code`/`GB_BranchName` are the display fields** — join `GlbBranch` in and select these rather than exposing raw `GB_PK` GUIDs in any report output.
3. **`GB_GC` → `GlbCompany`** if a report needs to roll branches up to their parent company (see `docs/discovery/org-tables-schema-analysis.md` for `GlbCompany`'s own columns).
4. **This FK list only proves the relationship exists at the schema level** — it says nothing about how populated/nullable each column is in practice. Before relying on a specific branch-role column in a report, spot-check it isn't mostly NULL for the record population you care about.
5. **`JH_JobNum` is not globally unique — confirmed 2026-08-29.** This is one shared CW instance across multiple country entities, and job numbers are only unique *per company*, not across the whole database. Confirmed empirically: `JH_JobNum = 'S00081401'` matched two completely unrelated `JobHeader` rows under two different companies (`MVN` Marine Connections Vietnam, `BKR` Ben Line Agencies Korea). **Any report or lookup filtering on `JH_JobNum` alone must also filter by company/branch** (e.g. `GC_Code` via the `GlbBranch`/`GlbCompany` join above) to avoid silently returning/matching the wrong company's job.
6. **`JobHeader.JH_PK` does NOT equal `JobShipment.JS_PK` — confirmed 2026-08-29.** Unlike `OrgHeader`/`OrgMiscServ` (which do share a PK), `JobHeader` links to its Shipment/Consol/Order/etc. subtype via a generic polymorphic pointer instead: `JH_ParentTableCode` + `JH_ParentID` (e.g. `JH_ParentTableCode = 'JS'`, `JH_ParentID = <JobShipment.JS_PK>`). This also explains why no FK constraint was found referencing `JobHeader.JH_PK` — a polymorphic pointer can't be declared as one. See `docs/discovery/custom-fields-mechanism-reference.md` for the full correction and worked example — any query joining `JobHeader` to a Job subtype table must use `JH_ParentID`/`JH_ParentTableCode`, not a shared-PK assumption.

## Related files

- `docs/discovery/org-tables-schema-analysis.md` — `OrgHeader`/`OrgCompanyData`/`GlbCompany`/`OrgMiscServ` schema analysis (two of `GlbBranch`'s own outbound FKs land in these tables).
- `docs/discovery/prod-db-schema-analysis.md` — broader PROD schema/size analysis.
- `docs/workflow/workflow-templates-analysis.md` — Workflow Template analysis; cross-reference if branch-scoping of templates (`ProcessTaskTemplate.P0_GB`) becomes relevant.
