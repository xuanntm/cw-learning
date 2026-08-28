# Workflow Traffic Analysis — Track A & Track B

Goal: find out which Workflow Templates / triggers actually see real usage over a period (e.g. 1 month), so the audit in `docs/discovery/workflow-audit-checklist.md` can focus on the main flows instead of treating all 55-56 templates as equal priority. Two independent tracks, depending on which "traffic" metric matters more — pursue both if unsure.

Runnable steps for the CLI parts are in `docs/discovery/uat-bastion-runbook.ps1` — **run that file on the UAT/TRN VM (`10.10.11.4`), not your laptop.** The SQL host (`H56TRN.db.wisegrid.net`) doesn't resolve over public DNS; it appears to resolve fine from inside the VNet as of 2026-08-28 (see Track B below) — run from the VM to be safe until that's fully confirmed.

## Track A — EDI/trigger firing volume (no DB needed)

Measures: how many times triggers actually fired / EDI messages actually sent, over a date range. This is a CW UI task, no CLI involved.

**Steps:**
1. Log into CW UAT.
2. Go to eAdaptor Next → Message Logs (or Health Check — per `docs_for_thanh/foundations/05_EDI_menu_note.txt`).
3. Filter the date range to the period you want (e.g. last 1 month).
4. If the grid supports grouping/sorting by Message Type or Interchange, use it. Otherwise export raw and pivot in Excel.
5. Export to Excel/CSV (most CW list grids support this).
6. Save the export somewhere in this repo (e.g. `docs/workflow/` alongside the other exports) so it can be cross-referenced against the Trigger-type breakdown already in `docs/workflow/workflow-templates-analysis.md` (the `IFC`/`FLD`/etc. `TriggerType` counts).

**Status:** not yet run — do this first, it's the lower-effort track.

## Track B — job/template usage volume (needs SQL Reporting DB)

Measures: how many jobs actually got each Workflow Template applied. No confirmed bulk CW UI screen for this — the only UI mechanism found so far is the per-job "Source Template" column on the Workflow & Tracking tab grid (per the `1PRO Workflow Templates Reference Guide.docx`), which doesn't scale to "all jobs, last month." SQL against the Reporting DB is the practical path.

**Real UAT SQL hostname — now confirmed three independent ways:**
1. 2026-08-23: found via CW's own Help > DB Administration > "Output SQL security build info" tool (see `docs/discovery/workflow-audit-checklist.md`).
2. 2026-08-2x: Hari (data team) confirmed directly that `h56trn.wisegrid.net`/`h56prd.wisegrid.net` are **deprecated** hostnames — the current ones are `H56TRN.db.wisegrid.net` / `H56PRD.db.wisegrid.net` (per `tmp/work_history.log`, ticket `DAT25T002-414`).
3. 2026-08-28: CW's own Help > About / System Info screen shows it directly — `DB Server Name: H56TRN.db.wisegrid.net`, `DB Database Name: OdysseyH56TRN` (this is the simplest way to get this in future — no need for the "Output SQL security build info" detour; check Help > About first).

Treat the hostname as settled. Neither earlier guess (`H56PRD.wisegrid.net`/`H56TRN.wisegrid.net` without `.db.`) is correct — those are the deprecated names.

**DNS/connectivity status — likely resolved as of 2026-08-28:** a connection attempt against `EnterpriseDbUser_OdysseyH56TRN_H56.Spencer.Nguyen` returned **"Login failed for user"** (SQL Server error 18456), not the earlier error 53/network-path-not-found. A "Login failed" response only happens after the client has already resolved the host, opened the TCP connection, and completed TDS handshake with SQL Server — so the VNet DNS gap documented below on 2026-08-23 appears to no longer be blocking. **Not 100% confirmed yet** — worth explicitly noting which tool (SSMS/DBeaver/sqlcmd) and which machine produced this error, to be sure it wasn't the CW app server (which sits inside the same VNet as the DB and may have always resolved it fine) rather than your own client machine.

**Resolved 2026-08-28:** connection confirmed working — you have admin + read + developer access via `EnterpriseDbUser_OdysseyH56TRN_H56.Spencer.Nguyen`. Cross-checked against `tmp/2026_08_28_db_build.log` (CW's SQL security build output): this login has `CONNECT SQL` server-wide, `CONNECT` on `OdysseyH56TRN`, and membership in `cwRestrictedReaderRole` — consistent with the read access described. Note: the old Windows/AD login `PROD\H56.Spencer.Nguyen` is being decommissioned in that same build run (revoked, renamed `_TO_DELETE`, dropped) — use the SQL login going forward, not AD/Windows auth.

**Login naming convention confirmed** (multiple examples in `tmp/work_history.log`): `EnterpriseDbUser_Odyssey<ENV>_H56.<FirstName>.<LastName>` — each person appears to get their own DB login (seen for John.Lonzame, Oliver.Buchanan, and now Spencer.Nguyen), not a shared account. Note casing is inconsistent across notes (`EnterpriseDBUser` vs `EnterpriseDbUser`) — SQL Server logins are case-insensitive under the default collation so this likely doesn't matter, but use exactly what CW/IT gives you rather than retyping from memory.

Once the password is confirmed:
- Database/catalog name: `OdysseyH56TRN` (confirmed, 3 sources above).
- Auth type: SQL Server Authentication (plain username/password) based on the login format — not Windows/Azure AD auth, despite the VM logins themselves being `azuread\...`.

**Steps (all in `docs/discovery/uat-bastion-runbook.ps1`, run from the VM):**
1. **Section 2** — confirm the SQL host resolves and port 1433 is reachable from the VM's network.
2. **Section 3** — `sqlcmd` connection test (`SELECT @@VERSION`) to confirm the login works at all.
3. **Section 4** — discover the real table names (`INFORMATION_SCHEMA.TABLES` search for `ProcessTask%` / `%WorkflowTemplate%`) and their columns — don't trust guessed names.
4. **Section 5** — draft traffic query (grouped count of task/trigger instances per template over the last month) — deliberately left commented out until Section 4 confirms real table/column names, to avoid running a query against wrong/guessed identifiers.

**Status:** host/database confirmed, network reachability likely resolved — blocked only on the real password for `EnterpriseDbUser_OdysseyH56TRN_H56.Spencer.Nguyen` (see `docs/discovery/workflow-audit-checklist.md` interview log). Once that's in hand, run Sections 2–4 of the runbook end to end. Section 1 (eAdaptor re-check) can be run immediately regardless.

## Once both tracks have data

Cross-reference: which templates show up as both high-job-usage (Track B) and high-trigger-firing (Track A)? Those are the "main flow" candidates — prioritize the audit checklist sections against those first, and treat the rest of the 55-56 templates as lower priority unless something else (like the empty+NFB risk already found) flags them independently of volume.

## Related files

- `docs/discovery/uat-bastion-runbook.ps1` — the runnable script for this document's CLI steps.
- `docs/workflow/Analyze-WorkflowTemplates.ps1` — the script used to produce the static config analysis (`docs/workflow/workflow-templates-analysis.md`, `docs/discovery/prod-vs-uat-gap-analysis.md`); traffic data from this guide should be layered on top of that, not replace it.
- `docs/discovery/workflow-audit-checklist.md` — where traffic findings should feed back into prioritization.
