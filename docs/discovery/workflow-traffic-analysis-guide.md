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

**DNS/connectivity status — still failing as of 2026-08-2x (this remains the live blocker):** direct tests from `vm-cwuat-001` (`10.10.11.4`), run in Git Bash, both fail at name resolution, not the port:
- `(echo > /dev/tcp/H56TRN.db.wisegrid.net/1433)` → `bash: H56TRN.db.wisegrid.net: Name or service not known`
- `Test-NetConnection -ComputerName H56TRN.db.wisegrid.net -Port 1433` → `WARNING: Name resolution ... failed`

So the VNet-level DNS gap documented on 2026-08-23 (both VMs use only Azure default DNS `168.63.129.16`, no route to whatever zone hosts `*.db.wisegrid.net`) is **still unresolved** on this VM — the "Blocked on IT" section below still applies as-is.

**Access/permissions confirmed independently (not the same thing as connectivity):** per `tmp/2026_08_28_db_build.log`, the login `EnterpriseDbUser_OdysseyH56TRN_H56.Spencer.Nguyen` has `CONNECT SQL` server-wide, `CONNECT` on `OdysseyH56TRN`, and membership in `cwRestrictedReaderRole` — so once the DNS/network path is actually open, this login should work. The old Windows/AD login `PROD\H56.Spencer.Nguyen` is being decommissioned in that same build run (revoked, renamed `_TO_DELETE`, dropped) — use the SQL login, not AD/Windows auth, once reachable.

**Open question:** an earlier "Login failed for user" result (2026-08-28) had suggested the network path was open — that's now contradicted by the DNS failures above. Need to confirm where that earlier result came from (which machine, which tool) before trusting it; it may have come from inside CW's app tier rather than a client machine, which wouldn't tell us anything about `vm-cwuat-001`'s own DNS.

**Login naming convention confirmed** (multiple examples in `tmp/work_history.log`): `EnterpriseDbUser_Odyssey<ENV>_H56.<FirstName>.<LastName>` — each person appears to get their own DB login (seen for John.Lonzame, Oliver.Buchanan, and now Spencer.Nguyen), not a shared account. Note casing is inconsistent across notes (`EnterpriseDBUser` vs `EnterpriseDbUser`) — SQL Server logins are case-insensitive under the default collation so this likely doesn't matter, but use exactly what CW/IT gives you rather than retyping from memory.

Once DNS/network is actually open:
- Database/catalog name: `OdysseyH56TRN` (confirmed, 3 sources above).
- Login: `EnterpriseDbUser_OdysseyH56TRN_H56.Spencer.Nguyen` — permissions already confirmed adequate (see above), so this should just work once reachable.
- Auth type: SQL Server Authentication (plain username/password) based on the login format — not Windows/Azure AD auth, despite the VM logins themselves being `azuread\...`.

**Steps (all in `docs/discovery/uat-bastion-runbook.ps1`, run from the VM):**
1. **Section 2** — confirm the SQL host resolves and port 1433 is reachable from the VM's network.
2. **Section 3** — `sqlcmd` connection test (`SELECT @@VERSION`) to confirm the login works at all.
3. **Section 4** — discover the real table names (`INFORMATION_SCHEMA.TABLES` search for `ProcessTask%` / `%WorkflowTemplate%`) and their columns — don't trust guessed names.
4. **Section 5** — draft traffic query (grouped count of task/trigger instances per template over the last month) — deliberately left commented out until Section 4 confirms real table/column names, to avoid running a query against wrong/guessed identifiers.

**Status:** host/database/login all confirmed — still blocked purely on DNS resolution from `vm-cwuat-001` (retested, still failing as of the latest check; see above). Same "Blocked on IT" options as 2026-08-23 apply. Section 1 (eAdaptor re-check) can be run immediately regardless.

## Once both tracks have data

Cross-reference: which templates show up as both high-job-usage (Track B) and high-trigger-firing (Track A)? Those are the "main flow" candidates — prioritize the audit checklist sections against those first, and treat the rest of the 55-56 templates as lower priority unless something else (like the empty+NFB risk already found) flags them independently of volume.

## Related files

- `docs/discovery/uat-bastion-runbook.ps1` — the runnable script for this document's CLI steps.
- `docs/workflow/Analyze-WorkflowTemplates.ps1` — the script used to produce the static config analysis (`docs/workflow/workflow-templates-analysis.md`, `docs/discovery/prod-vs-uat-gap-analysis.md`); traffic data from this guide should be layered on top of that, not replace it.
- `docs/discovery/workflow-audit-checklist.md` — where traffic findings should feed back into prioritization.
