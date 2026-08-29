# Backlog: UAT SQL Reporting DB (H56TRN.db.wisegrid.net) — DNS resolution fails from all tested VNets

## Status
[x] Resolved (2026-08-29) — confirmed working on server1 with corrected hostname `H56TRN.db.test.wisegrid.net`. Retest on server2/server3 recommended for full closure but root cause is confirmed (see Resolution section below).

## Environment
- **UAT target:** `H56TRN.db.wisegrid.net`, port 1433, database `OdysseyH56TRN`
- **Login:** `EnterpriseDbUser_OdysseyH56TRN_H56.Spencer.Nguyen` — permissions already confirmed adequate (`CONNECT SQL`, `CONNECT` on `OdysseyH56TRN`, member of `cwRestrictedReaderRole`), not a permissions issue
- **PROD baseline (working, for comparison):** `H56PRD.db.wisegrid.net`, port 1433, database `OdysseyH56PRD` — resolves via CNAME to `au2wpreadonly440l1.wisegrid.net` (`203.62.211.152`)
- **Hostname correctness:** `H56TRN.db.wisegrid.net` independently confirmed 3 separate ways (CW's own "Output SQL security build info" tool, the data team, and CW's Help > About / System Info screen) — ruled out as a typo/stale-name issue

## Problem
DNS resolution for the UAT SQL Reporting DB host `H56TRN.db.wisegrid.net` fails from every server tested (3 for 3), while the equivalent PROD host `H56PRD.db.wisegrid.net` resolves and connects successfully from the same servers.

## Evidence — tested from 3 independent servers (2026-08-29, `docs/discovery/db-connectivity-check.ps1` v1.4/1.5)

| Server | Public IP | Private IP | PROD DNS + Login | UAT DNS |
|---|---|---|---|---|
| Server 1 | `20.247.185.174` | `10.14.8.29` | OK — connected, `SQL Server 2022 RTM-CU25-GDR` | **FAILED (DNS resolution)** |
| Server 2 | `4.194.70.13` | `10.10.11.4` | OK — connected | **FAILED (DNS resolution)** |
| Server 3 | `52.230.84.213` | `10.10.11.7` | OK — connected | **FAILED (DNS resolution)** |

All 3 servers have distinct public IPs and private subnets, ruling out a shared NAT gateway as the variable. In every case `H56TRN.db.wisegrid.net` fails to resolve at all (`Resolve-DnsName` returns no result) — the failure happens before a TCP connection to port 1433 is even attempted, and before any IP whitelist check would apply.

## Ruled out so far
- **Wrong/stale hostname** — confirmed correct 3 independent ways (see Environment above); a clean 3-for-3 identical failure across independently-tested servers is inconsistent with a naming issue.
- **Credentials/permissions** — the UAT SQL login's permissions were already separately confirmed adequate via `tmp/2026_08_28_db_build.log`.
- **Per-server IP whitelisting** — would block the TCP connect stage after a successful DNS lookup, not DNS resolution itself. All 3 servers fail at the DNS step, before whitelisting would even apply.

## ⚠️ Correction (2026-08-29): CW's team says the correct hostname is `H56TRN.db.test.wisegrid.net`, not `H56TRN.db.wisegrid.net`

The "DNS zone/VNet-peering gap" theory below was the best explanation available from the evidence gathered — but CW's team's response points at a simpler cause: **the hostname itself was wrong** (missing a `.test.` segment). This would fully explain the clean 3-for-3 identical DNS resolution failure across every server tested, since a genuinely nonexistent hostname fails identically everywhere regardless of network path.

This does **not** fully overturn the earlier "hostname confirmed 3 independent ways" finding — that confirmation (CW's own tooling, the data team, CW's Help > About screen) may have been correct for the environment's *display name*/connection string shown in-app, while the actual DNS-resolvable record needs the additional `.test.` segment. Worth asking CW's team directly why the in-app tooling didn't surface this, so the same gap doesn't repeat for future environment lookups.

`docs/discovery/db-connectivity-check.ps1` updated to v1.6 with the corrected default `-UatSqlHost` value.

## ✅ Resolution confirmed (2026-08-29)

Retested from server1 (`db-connectivity-check.ps1` v1.6): full success end to end.

- DNS resolution: OK — `H56TRN.db.test.wisegrid.net` → CNAME → `au2wtreadonly411l1.wisegrid.net` (`203.62.211.146`)
- TCP 1433: reachable
- SQL login: OK — `Microsoft SQL Server 2022 (RTM-CU25-GDR/KB5101347), Enterprise Edition, Windows Server 2019` (same build as PROD)

Nice confirming detail: the resolved hostname `au2wtreadonly411l1.wisegrid.net` mirrors PROD's `au2wpreadonly440l1.wisegrid.net` naming pattern exactly (`p` = PROD, `t` = TRN/UAT) — confirms this is UAT's own dedicated read-only Reporting DB replica, set up the same way as PROD's. Root cause was **purely the missing `.test.` segment in the hostname** — not a VNet/DNS-peering gap as first theorized from the evidence available at the time.

**Remaining:** retest server2 (`10.10.11.4`) and server3 (`10.10.11.7`) with v1.6 to confirm the fix holds everywhere, for full closure symmetry with the original 3-for-3 failure evidence. Not expected to reveal anything new (a hostname fix should work identically everywhere), but worth the 2 minutes to close this out cleanly.

## Working theory (superseded — kept for reference)
`H56TRN.db.wisegrid.net`'s DNS record likely lives in a private DNS zone not linked/peered to any of the 3 servers' VNets, while `H56PRD.db.wisegrid.net` resolves via a differently-routable path/zone (the CNAME chain to `au2wpreadonly440l1.wisegrid.net`). Needs confirmation from whoever manages DNS zone/VNet peering for these hosts. **Superseded by the correction above** — plausible the real answer is simpler (wrong hostname), but keeping this in case retesting the corrected hostname still shows a failure and this theory becomes relevant again.

## Requested action
Confirm the DNS zone configuration / VNet peering for the UAT SQL Reporting DB host, and link/whitelist it the same way `H56PRD.db.wisegrid.net` is currently configured.

## Ticket tracking
- **Ticket number:** _(fill in once submitted/assigned)_
- **Submitted:** 2026-08-29
- **Related ticket:** `DAT25T002-414` (confirmed current vs. deprecated hostname naming for both UAT and PROD SQL hosts)
- **Point of contact:** Hari (data team) — previously helped confirm hostnames

## Updates log
_(add a dated entry each time the ticket owner responds, so this file stays the single source of truth for follow-up)_

- 2026-08-29 — Ticket description drafted and submitted. Awaiting response.
- 2026-08-29 — CW's team responded: correct hostname is `H56TRN.db.test.wisegrid.net`, not `H56TRN.db.wisegrid.net`. Script updated to v1.6 with the corrected default.
- 2026-08-29 — Retested on server1: DNS, TCP, and login all succeed against the corrected hostname. Root cause confirmed (wrong hostname, not a network/DNS-zone issue). Marking resolved; server2/server3 retest still recommended for completeness.

## Related files
- `docs/discovery/workflow-traffic-analysis-guide.md` — full investigation history, including the 3-server test methodology and results this ticket is based on.
- `docs/discovery/db-connectivity-check.ps1` — the reusable script used to gather this evidence.
- `docs/discovery/workflow-audit-checklist.md` — where this blocker was tracked as an open stakeholder question before escalation.
