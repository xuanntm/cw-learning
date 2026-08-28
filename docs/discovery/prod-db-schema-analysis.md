# PROD Database — Schema & Size Analysis (2026-08-28)

Environment: PROD, `H56PRD.db.wisegrid.net`, database `OdysseyH56PRD`. Data pulled via two read-only discovery queries run directly against PROD (see `docs/discovery/workflow-traffic-analysis-guide.md` for the SQL used and the access/connectivity story). Source exports: `tmp/Query_1_202608282207.csv` (all tables, row counts + size, sorted descending) and `tmp/Query_3_202608282215.csv` (`INFORMATION_SCHEMA.TABLES` search for `%Job%`).

Purpose: identify the "main" tables in the schema (by volume and by relevance to workflow-template usage) so Track B of the traffic analysis can be built against real table/column names instead of guesses.

## Top tables by row count and size

| Table | Rows | Total MB | Used MB | Notes |
|---|---|---|---|---|
| `StmALog` | 33,007,695 | 6,456.28 | 6,455.23 | System audit/activity log — largest table in the DB overall, not workflow-specific |
| `ProcessTasks` | 16,062,993 | 3,129.66 | 3,128.55 | **Workflow task instances** — every task actually created from a template, per job |
| `ProcessTaskNotification` | 11,896,245 | 1,150.47 | 1,137.27 | Notification/trigger firings tied to tasks |
| `StmActivityLog` | 4,782,651 | 653.11 | 651.92 | Another system activity log table |
| `RptDtJobCostingData` | 2,593,097 | 1,538.13 | 1,262.28 | Reporting/costing datamart table |
| `StmComplianceEvent` | 1,961,220 | 101.16 | 101.09 | Compliance event log |
| `StmNote` | 1,916,352 | 553.13 | 547.27 | Notes attached to records across the system |
| `AccTransactionLines` | 1,829,245 | 1,048.78 | 1,047.99 | Accounting transaction line items |
| `JobDocAddress` | 1,654,206 | 98.78 | 97.96 | Job document address records |
| `EDIMessage` | 1,539,351 | 4,533.31 | 4,451.89 | Raw EDI message traffic — directly relevant to Track A |
| `EDIInterchange` | 1,405,092 | 3,180.31 | 3,126.80 | EDI interchange records — directly relevant to Track A |
| `JobPackLines` | 1,387,704 | 171.97 | 170.74 | Job pack line items |
| `StmNumberSequence` | 1,000,001 | 13.55 | 12.81 | Number sequence generator table |
| `GenSpatialData` | 988,860 | 39.52 | 39.28 | Spatial/geo data |
| `LicenceUsageLog` | 901,245 | 91.78 | 91.05 | Licence usage tracking |
| `StmEntityScreeningLog` | 731,301 | 12,311.06 | 12,308.28 | Entity screening log — largest table by *size* (not rows), likely stores large blob/document data per row |
| `ProcessJobTriggerLink` | 704,197 | 94.84 | 94.77 | Join table linking jobs ↔ triggers |
| `JobCharge` | 598,535 | 524.41 | 522.38 | Job charge line items |
| `JobContainerPenalty` | 540,362 | 96.28 | 94.29 | Container penalty records |
| `JobRequiredDocument` | 525,506 | 108.84 | 108.13 | Required document tracking per job |
| `JobContainer` | 409,842 | 86.03 | 85.65 | Job container records |
| `AccTransactionHeader` | 360,375 | 211.91 | 209.85 | Accounting transaction headers |
| `JobConsolTransport` | 280,515 | 34.90 | 34.85 | Consol transport legs |
| `JobShipment` | 254,709 | 68.53 | 67.23 | Shipment-level job records |
| `JobConsol` | 80,864 | 56.03 | 55.23 | Consol header records |
| `JobHeader` | 103,614 | 39.53 | 38.30 | **Core Job master record** — one row per job; much smaller than its child tables, consistent with it being the master entity |
| `ProcessTaskTemplate` | 522 | 0.33 | 0.23 | **Template definitions** — small dimension table, matches the 55/56-template XML exports already analyzed in `docs/workflow/workflow-templates-analysis.md` |

*(Full ~1,400-table list is in `tmp/Query_1_202608282207.csv` if a table not listed here is needed — most of the remainder are 0-row or near-empty feature tables not currently in use.)*

## Workflow-relevant tables (from the `%Job%` schema search, `Query_3`)

Beyond the tables above, the search surfaced the full workflow/process schema:

- **Process engine core:** `ProcessTasks`, `ProcessTaskTemplate`, `ProcessTaskNotification`, `ProcessJobTriggerLink`, `ProcessTasksSecure`
- **Task automation (newer CW feature, all 0 rows in PROD currently):** `ProcessTaskAutomation`, `ProcessTaskAutomationConversation`, `ProcessTaskAutomationQuestion`, `ProcessTaskAutomationQuestionOption`, `ProcessTaskAutomationResultAction` — worth a stakeholder question: is task automation configured/rolled out at all, or fully unused so far?
- **Country-specific declaration/invoice tables:** dozens of `<CC>JobDeclaration` / `<CC>JobComInvoiceHeader` / `<CC>JobComInvoiceLine` tables (e.g. `USJobDeclaration`, `CNJobDeclaration`, `DEJobDeclaration`, etc.) — one set per country customs regime. Confirms the schema is heavily localized per country compliance requirements, separate from the generic `JobDeclaration` table.
- **CDC (Change Data Capture) is enabled** on a large number of Job/Process tables — visible as a parallel `cdc` schema with `dbo_<TableName>_CT` shadow tables (e.g. `cdc.dbo_JobHeader_CT`, `cdc.dbo_ProcessTasks_CT` is not in current list but similar pattern tables like `cdc.dbo_JobCharge_CT`, `cdc.dbo_JobContainer_CT` are). **Worth investigating as an alternative, lower-impact data source** for traffic/change analysis instead of querying the live OLTP tables directly — CDC capture tables are purpose-built for exactly this kind of "what changed, when" analysis and querying them has less contention risk on a live PROD system.

## Main-table conclusions for Track B (traffic analysis)

1. **`ProcessTasks`** (16.1M rows) is the table to count "how many times a template's tasks actually fired" — this corrects the earlier guess of `ProcessTask` (singular) in `uat-bastion-runbook.ps1` Section 5, now fixed.
2. **`ProcessTaskTemplate`** (522 rows) is the template dimension table to join against — note it has 522 rows in PROD vs. the 55/56 seen in the two XML exports, meaning those exports were scoped to a single company/branch context and PROD holds templates for many more.
3. **`ProcessTaskNotification`** (11.9M rows) is the best DB-level proxy for Track A (trigger-firing volume) if the CW UI screen for that turns out not to exist or not to scale.
4. **`JobHeader`** (104K rows) is the master Job record to join against if the analysis needs to be scoped by job type/branch/date rather than just counting tasks in isolation.

## Still needed before the real traffic query can run

```sql
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN ('ProcessTasks', 'ProcessTaskTemplate', 'ProcessTaskNotification', 'ProcessJobTriggerLink')
ORDER BY TABLE_NAME, ORDINAL_POSITION;
```
The FK/date column names used in the draft query (`SourceTemplateID`, `ActualDateUtc`, `PK`) are still guesses — confirm real names before running Section 5 of the runbook for real.

## Caveats

- This is PROD, not UAT — treat all further queries here as read-only (`SELECT` only, no writes/DDL); consider `WITH (NOLOCK)` or off-peak timing for anything touching the 16M-row `ProcessTasks` table directly.
- Row/size figures are a point-in-time snapshot (2026-08-28) — PROD is live and will have grown since.
- The 522-row `ProcessTaskTemplate` count spans (presumably) all companies/branches on this PROD instance, not just the single entity covered by the earlier 55/56-template XML exports — don't assume a 1:1 match without filtering by the same OwnerCode/company context used for those exports.

## Related files

- `docs/discovery/workflow-traffic-analysis-guide.md` — Track A/B traffic analysis plan this feeds into.
- `docs/discovery/uat-bastion-runbook.ps1` — runnable script, Section 5 updated with the corrected `ProcessTasks` table name.
- `docs/workflow/workflow-templates-analysis.md` / `docs/discovery/prod-vs-uat-gap-analysis.md` — the static XML-export analysis this DB data should be cross-referenced against.
- `tmp/Query_1_202608282207.csv`, `tmp/Query_3_202608282215.csv` — raw query outputs this analysis is based on (gitignored, not tracked).
