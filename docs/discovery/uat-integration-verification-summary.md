# UAT Integration Verification — Data Summary for QA Planning

Environment: UAT (`H56TRN.db.test.wisegrid.net` / `OdysseyH56TRN`). Collected 2026-08-29 via `docs/discovery/uat-integration-verification.sql` (4 queries) to give the QA team a concrete, evidence-based starting point for planning UAT integration verification — what's actually configured, whether it mirrors PROD, and what has real recent traffic to test against.

Source data: `tmp/Integration_step1_202608291555.csv` through `tmp/Integration_step4_202608291557.csv` (gitignored, not tracked).

## Integrations configured in UAT (15 parties)

All active `OUT`-direction endpoints found. `IN`-direction rows are omitted here (they carry no outbound URL by design — inbound configs receive, they don't target a URL).

| Party | Endpoint | Auth Mode | Traffic (last 30d) | Notes |
|---|---|---|---|---|
| `H56_TRN_CW2BRAVO` | `bci-be-uat.benline.com/api/EadaptorNext/BravoTrans` | BAU | **0** | Mirrors PROD's BravoTrans. See "BravoTran risk" below. |
| `H56_TRN_CW2KES` | `bci-be-uat.benline.com/api/EadaptorNext/Kestrel` | BAU | **0** | Configured, no recent traffic |
| `H56_TRN_CW2SAGE` | `bci-be-uat.benline.com/api/EadaptorNext/Sage` | BAU | **19** | Only `eAdaptorNext` endpoint with real recent UAT traffic |
| `H56_TRN_CW2SAPI` | `bci-be-uat.benline.com/api/EadaptorNext/SAPI` | BAU | **0** | Configured, no recent traffic |
| `H56_TRN_CW2VNPT` | `bci-be-uat.benline.com/api/EadaptorNext/VNPT` | BAU | **0** | Configured, no recent traffic |
| `H56_TRN_CW2BOOMI2NS_AP` | `boomi-test.benline.com:9443/.../aptransactions` | BAU | 27 | NetSuite AP, via Boomi |
| `H56_TRN_CW2BOOMI2NS_AR` | `boomi-test.benline.com:9443/.../artransactions` | BAU | 9 | NetSuite AR, via Boomi. Only party with **both** IN and OUT active. |
| `H56_TRN_CW2SHPDOC` | `boomi-test.benline.com:9443/.../universaldocument` | BAU | 17 | SharePoint document sync, via Boomi |
| `H56_TRN_CW2SYNXUS` | `boomi-test.benline.com:9443/.../universalshipment` | BAU | 12 | Syngenta shipment, via Boomi |
| `H56_TRN_CW2SYNXUE` | `boomi-test.benline.com:9443/.../universalevent` | BAU | 1 | Syngenta event, via Boomi |
| `EAN_Eadaptor_NEXT` | `edi-neonexus.onrender.com/cw/outbound` | **NAU** | 60 | Highest volume, but endpoint looks like a personal dev/mock service (Render.com hosting) — confirm with team whether in-scope for QA before including |
| `Sharepoint Test` | SharePoint folder share link | OAU | 10 | Separate from `H56_TRN_CW2SHPDOC` — literal folder link, not an API |
| `Boomi` | `boomi-test.benline.com/ws/rest/cw-api-test/CW-TEST/` | BAU | 0 | Generic test endpoint |
| `H56_TRN_MIDDLE` | (blank — inbound-only) | — | 5 | IN-direction only |

## Cross-checked against PROD

All 5 of PROD's confirmed `eAdaptorNext` endpoints (`docs/discovery/edi-communication-mechanism-reference.md`) exist in UAT under matching names, with `-uat` in the hostname (`bci-be-uat.benline.com` vs. `bci-be.benline.com`) — clean environment separation, and all 5 are realistically in scope for QA testing.

## The BravoTran risk — now triangulated from two independent signals

- `docs/discovery/workflow-runtime-check.sql` (2026-08-29): `BravoTran` workflow templates show `ActualProcessInstanceCount = 0` in UAT — no job has ever matched them.
- This integration-level check (same date): the `BravoTrans` endpoint itself shows **0 messages in the last 30 days**.

Two different data sources (workflow engine vs. raw EDI traffic) agree: BravoTran integration is currently dormant in UAT. Still pending your team discussion on what "BravoTran" actually is and whether this matters for PROD — see `docs/discovery/workflow-audit-checklist.md` Section A1/B.

## UAT traffic volume — set QA expectations

~575 messages across all integrations in the last 30 days (vs. ~166K/30 days on PROD). **Most integrations will not have enough organic UAT traffic to verify passively** — QA will likely need to trigger test transactions manually for anything showing 0 in the table above, rather than waiting to observe real traffic.

## Suggested starting scope for QA's verification plan

1. **Ready to verify with existing traffic**: `Sage`, the Boomi-routed NetSuite AP/AR, SharePoint doc sync, Syngenta shipment — these have recent real messages to inspect and build test cases from.
2. **Needs manual/synthetic triggering**: `BravoTrans`, `Kestrel`, `SAPI`, `VNPT` — configured correctly, mirror PROD, but no recent traffic to observe. QA will need to actively generate a test transaction to verify these.
3. **Confirm scope before including**: `EAN_Eadaptor_NEXT` (looks like a personal dev/mock endpoint, not a real partner) and `Sharepoint Test` (a folder link, not a true API integration) — check with the team whether these belong in a QA verification plan at all.
4. **Auth mode `NAU` (no auth?) on `EAN_Eadaptor_NEXT`** — worth a second look regardless of scope decision above; an integration endpoint with no authentication is unusual.

## Caveats

- `ECC_Status = 'REQ'` and the auth mode codes (`OAU`/`BAU`/`NAU`) are inferred from context, not confirmed against a lookup table.
- This is a structural/volume snapshot, not a payload-level content check — doesn't confirm the actual data being exchanged is correct, only that the plumbing exists and (for some) is active.

## Related files

- `docs/discovery/uat-integration-verification.sql` — the 4 queries this summary is based on.
- `docs/discovery/edi-communication-mechanism-reference.md` — the underlying table mechanism (`EDICommunicationPartyConfig`/`EDICommunicationAuth`/`EDICommunicationParty`/`EDIMessage`/`EDIInterchange`), and PROD's equivalent endpoint list.
- `docs/discovery/workflow-runtime-check.sql`, `docs/discovery/workflow-audit-checklist.md` — the workflow-template-level BravoTran evidence this cross-confirms.
