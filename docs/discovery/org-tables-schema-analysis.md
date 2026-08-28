# Org Tables — Schema Analysis (2026-08-28)

Environment: PROD (`H56PRD.db.wisegrid.net` / `OdysseyH56PRD`). Analysis of the four tables behind this report query:

```sql
SELECT
    OH_Code, OH_FullName, OB_IsDebtor, GC_Code, OH_IsSalesLead, OM_CMIndustryVertical
FROM OrgHeader
LEFT JOIN OrgMiscServ ON OM_PK = OH_PK
LEFT JOIN OrgCompanyData ON OB_OH = OH_PK
LEFT JOIN GlbCompany ON OB_GC = GC_PK
WHERE OH_IsControllingCustomer = '1'
ORDER BY OH_Code;
```

Source data: `tmp/Query_table_and_columns_202608282250.csv` (`INFORMATION_SCHEMA.COLUMNS` for all 4 tables) and `tmp/Query_table_base_202608282251.csv` (`INFORMATION_SCHEMA.TABLES` type check) — both gitignored, not tracked in the repo.

## Query purpose

Lists "Controlling Customer" organizations (`OH_IsControllingCustomer = '1'`) with debtor status, sales-lead flag, and CRM industry vertical — a customer/debtor summary report.

## Table type check

All four are plain **`BASE TABLE`**, not views — the column list below is the real physical schema, not a computed/aliased one.

## Table roles and column counts

| Table | Prefix | Columns | Role |
|---|---|---|---|
| `OrgHeader` | `OH_` | 88 | Org master record. ~50 boolean `OH_Is*` role flags (`IsConsignee`, `IsForwarder`, `IsBroker`, `IsShippingLine`, etc.) describing what type of org this is, plus 32 generic `OH_IsUserFlag1..32` custom flags |
| `OrgCompanyData` | `OB_` (name doesn't match prefix) | 119 | Per-**(Org, Company)** AR/AP settings. Dominated by Accounts Receivable (`AR*`: credit limit, credit hold, payment terms, statement style) and Accounts Payable (`AP*`) fields. Has explicit FKs `OB_OH` → `OrgHeader.OH_PK` and `OB_GC` → `GlbCompany.GC_PK` |
| `GlbCompany` | `GC_` | 36 | Legal-entity/operating-company master — registration numbers, GST/WHT registration, address, local currency, country |
| `OrgMiscServ` | `OM_` | 249 | Large catch-all Org extension table, sub-organized by module-area prefix within the column names: `IM`=Import, `EX`=Export, `FW`=Forwarder/agent, `CR`=Carrier, `SV`=Services, `CM`=Client Management/CRM (sales), `CI`=Competitor Intelligence, `Whs`=Warehouse |

## Key finding: per-company fan-out risk in the original query

`OrgCompanyData` is genuinely a **per-org-per-company** table (both `OB_OH` and `OB_GC` are FK columns on it), not a per-org table. The original query's `LEFT JOIN OrgCompanyData ON OB_OH = OH_PK` has no company filter — so if a controlling customer has AR/AP settings set up under more than one operating company (`GlbCompany`), the query returns **one row per company for that org**, not one row per org. If a report needs exactly one row per org, add `AND OB_GC = '<specific company GUID>'` (or otherwise pick a deterministic company) to the join condition.

## Fields worth considering alongside the ones already selected

Since `OB_IsDebtor` sits in a table full of credit-review fields, and `OM_CMIndustryVertical` sits in a table full of CRM fields, these near neighbors may be relevant depending on what the report is actually for:

- Debtor/credit angle: `OB_AROnCreditHold`, `OB_ARCreditApproved`, `OB_ARCreditLimit`, `OB_ARCreditRating`
- CRM/sales angle: `OM_CMSalesCategory`, `OM_CMTotalClientRevenue`, `OM_CMEstimatedProfit`

## Full column lists

Not reproduced in full here (`OrgMiscServ` alone has 249 columns) — see `tmp/Query_table_and_columns_202608282250.csv` for the complete `TABLE_NAME, COLUMN_NAME, DATA_TYPE, ORDINAL_POSITION` listing across all four tables, re-run the discovery query in `docs/discovery/uat-bastion-runbook.ps1`-style if that file is no longer available.

## Related files

- `docs/discovery/prod-db-schema-analysis.md` — broader PROD schema/size analysis this org-table deep-dive builds on.
- `docs/discovery/workflow-traffic-analysis-guide.md` — the traffic-analysis work this DB access was originally set up for.
