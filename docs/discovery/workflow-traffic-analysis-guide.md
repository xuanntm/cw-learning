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

### Strategic pivot — use PROD, not UAT, for the actual traffic measurement

You now have confirmed working access to **PROD** (`H56PRD.db.wisegrid.net`, credential from `tmp/work_history.log`) while UAT/TRN is still DNS-blocked. This is arguably better for Track B anyway: the whole point is measuring **real** usage, and UAT/TRN traffic is synthetic test activity that wouldn't answer "which templates do real jobs actually hit." Recommend running the traffic query against PROD directly rather than waiting on the UAT DNS fix — treat UAT connectivity as a separate, lower-priority thread.

**Schema discovery already run against PROD (2026-08-28)** — largest tables by row count (`tmp/Query_1_202608282207.csv`) and a `Job%`-pattern table search (`tmp/Query_3_202608282215.csv`). Key findings:

| Table | Rows | Relevance |
|---|---|---|
| `ProcessTasks` | 16.1M | Workflow task **instances** — the real table name (plural), correcting the earlier guess of `ProcessTask` in the runbook's Section 5 draft |
| `ProcessTaskNotification` | 11.9M | Notification/trigger firings tied to tasks — DB-level equivalent of Track A's "how many times did a trigger fire" |
| `ProcessJobTriggerLink` | 704K | Join table linking jobs ↔ triggers |
| `ProcessTaskTemplate` | 522 | Template *definitions* (small dimension table — matches the 55/56-template XML exports already analyzed) |
| `EDIMessage` / `EDIInterchange` | 1.5M / 1.4M | Raw EDI message traffic — also feeds Track A |
| `JobHeader` | 104K | Core Job master record |

`uat-bastion-runbook.ps1` Section 5 updated with the corrected table name (`ProcessTasks`). Column names (`SourceTemplateID`, `ActualDateUtc`, `PK`) are still guesses — next step is:
```sql
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN ('ProcessTasks', 'ProcessTaskTemplate', 'ProcessTaskNotification', 'ProcessJobTriggerLink')
ORDER BY TABLE_NAME, ORDINAL_POSITION;
```
Once those are confirmed, finalize and run the Section 5 traffic query against PROD.

**Caution:** this is PROD — keep everything `SELECT`-only, no writes/DDL. The schema queries above (`INFORMATION_SCHEMA`) are cheap/safe; if querying `ProcessTasks` itself (16M rows) add a date filter and consider `WITH (NOLOCK)` or off-peak timing to avoid load on a live system.

## Multi-server UAT connectivity retest (2026-08-29+)

You now have 3 servers to test from — working theory is that IP whitelisting is per-server (only some egress IPs are allowed), not a blanket VNet-wide DNS gap. Run `docs/discovery/db-connectivity-check.ps1` identically on each server (it tests PROD first as a known-working baseline, then UAT) and record each run's result row here:

| Server | Script Ver | Public IP | Private IP | PROD DNS | PROD Login | UAT DNS | UAT TCP | UAT Login |
|---|---|---|---|---|---|---|---|---|
| server1 | 1.4/1.5 | `20.247.185.174` (matches `docs/config/uat-environment-overview.md`'s recorded "Virtual Environment IP") | `10.14.8.29` | OK (CNAME chain to `au2wpreadonly440l1.wisegrid.net` / `203.62.211.152`) | **OK** — `Microsoft SQL Server 2022 (RTM-CU25-GDR/KB5101347), Enterprise Edition, Windows Server 2019` | **FAIL** | **False** | SKIPPED |
| server2 | 1.5 | `4.194.70.13` | `10.10.11.4` | OK | **OK** (same version as above) | **FAIL** | **False** | SKIPPED |
| server3 | 1.5 | `52.230.84.213` | `10.10.11.7` | OK | **OK** (same version as above) | **FAIL** | **False** | SKIPPED |

**Resolved (2026-08-29): the `sqlcmd` hang was tool-specific, not network.** On server1, `sqlcmd` (legacy ODBC-based) hung indefinitely against PROD even with a login timeout set, while DBeaver connected instantly on the same machine/network path. `db-connectivity-check.ps1` v1.4 replaced `sqlcmd` entirely with `System.Data.SqlClient` (built into .NET Framework, no install/admin rights needed) — it connected to PROD immediately on all 3 servers, confirming the hang was specific to the old ODBC/SChannel TLS stack, not a real connectivity problem.

**CONCLUSION (2026-08-29) — confirmed 3-for-3, UAT DNS failure is a zone/peering gap, not a whitelist or credential issue.** All 3 test servers (3 different public IPs, 3 different private subnets — ruling out any shared NAT-gateway confound) show the identical pattern: PROD (`H56PRD.db.wisegrid.net`) resolves via a CNAME to a differently-named zone (`au2wpreadonly440l1.wisegrid.net`) and logs in successfully; UAT (`H56TRN.db.wisegrid.net`) fails at the **DNS resolution step itself**, before any TCP/whitelist check would even apply. This rules out per-server IP whitelisting (which would block the TCP connect, not DNS resolution) and confirms the original VNet-wide DNS gap theory from 2026-08-23: UAT's DNS record likely lives in a private zone not linked/peered to any of these 3 servers' VNets.

**Action: escalate to IT/network team** with this exact evidence — request confirmation of the DNS zone/VNet peering configuration for the UAT SQL host, framed as a zone-linking gap rather than a generic "UAT doesn't work" or whitelist request. The hostname itself does not need re-verification — already confirmed 3 independent ways (see above), and a clean 3-for-3 identical-failure pattern across independently-tested servers is inconsistent with a wrong/stale hostname.

If any server shows UAT DNS `OK`, that's the one to standardize on for Track B going forward — and its public IP is what confirms the whitelist theory (compare against whatever IP(s) IT has on file as whitelisted, if that list is available). If all 3 show UAT DNS `FAIL` identically, that points back to the earlier VNet-wide DNS gap theory instead (Azure default DNS `168.63.129.16` with no route to the `*.db.wisegrid.net` zone) rather than a per-server whitelist issue — worth ruling PROD's own DNS success in/out as a control either way, since PROD resolves fine from wherever it's already been tested from.

## Once both tracks have data

Cross-reference: which templates show up as both high-job-usage (Track B) and high-trigger-firing (Track A)? Those are the "main flow" candidates — prioritize the audit checklist sections against those first, and treat the rest of the 55-56 templates as lower priority unless something else (like the empty+NFB risk already found) flags them independently of volume.

## Related files

- `docs/discovery/uat-bastion-runbook.ps1` — the runnable script for this document's CLI steps.
- `docs/workflow/Analyze-WorkflowTemplates.ps1` — the script used to produce the static config analysis (`docs/workflow/workflow-templates-analysis.md`, `docs/discovery/prod-vs-uat-gap-analysis.md`); traffic data from this guide should be layered on top of that, not replace it.
- `docs/discovery/workflow-audit-checklist.md` — where traffic findings should feed back into prioritization.
