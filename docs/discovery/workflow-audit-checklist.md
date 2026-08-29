# Workflow Templates — Audit Checklist

Purpose: verify (in live CW, not just the static XML exports) the open findings from `docs/workflow/workflow-templates-analysis.md` and `docs/discovery/prod-vs-uat-gap-analysis.md`, and give a repeatable procedure for auditing any workflow template going forward. Confirmed: you have **admin access to Workflow Templates** in CW, so every item below is self-serve unless marked otherwise.

Status legend: `[ ]` Not Started · `[/]` In Progress · `[x]` Completed · `[!]` Blocked / Need someone else

## Interview log

Answers gathered so far — re-ask if circumstances change (e.g. after checking Registry):

| Question | Answer (2026-08-23) |
|---|---|
| Is "BravoTran" a currently active customer/partner integration? | Not sure — needs checking (Section A1) |
| Is "MVN" a currently operating branch/company code? | **Confirmed active (2026-08-28, via PROD DB query).** `GC_Code = MVN` → "Marine Connections (Vietnam) Co., Ltd.", branch `MSG` (Ho Chi Minh), has live active job data (`JH_IsActive = 1`). See Section A2. |
| Do OwnerCodes `SIMLOGMNL` (Non-Prod) and `MARCONSGN` (Prod) represent the same entity? | **Lead found, not confirmed.** `MARCONSGN` plausibly abbreviates "Marine Connections" — the same MVN company just confirmed above. Not proven; ask the team to verify rather than assume. See Section A3. |
| Your CW access level | Admin access to Workflow Templates — you can execute this whole checklist directly |

---

## Section A — Resolve the three unknowns first

Everything downstream depends on these. Do this section before the rest.

- [/] **A1. What is "BravoTran"?**
  - **New evidence 2026-08-29 (PROD DB, `tmp/EDI_communication_eadaptor_202608291128.csv`):** a real, currently-configured outbound eAdaptor Next endpoint exists in PROD: `EDICommunicationPartyConfig.ECC_Endpoint = https://bci-be.benline.com/api/EadaptorNext/BravoTrans`, `Direction = OUT`, `Status = REQ` (code meaning not yet decoded). Confirms "BravoTrans" is real, active infrastructure — not a dormant/orphaned name. Still unconfirmed: whether it's currently *receiving* traffic (i.e. whether any live job actually matches the empty+`NFB` Universal templates in Section B below) — this config record existing doesn't by itself prove that.
  - Still worth doing in CW: Maintain > Master Data > Organizations, search `BravoTran`, to get the business-side record (org type, active status, linked branches) alongside this technical config record.
  - **Record here:** Confirmed real/active endpoint config in PROD (`ECC_Status = REQ`, meaning TBD). Organization-record lookup still pending.

- [x] **A2. What is "MVN"?**
  - **Confirmed 2026-08-28 via direct PROD DB query** (`GlbCompany` joined through `GlbBranch`): `GC_Code = MVN`, `GC_Name = "Marine Connections (Vietnam) Co., Ltd."`, branch `GB_Code = MSG` ("Ho Chi Minh"). Has active job data referencing it (`JH_IsActive = 1`), so this is a live, operating company — not dormant/deprecated.
  - **Record here:** Active. Country: Vietnam. Branch: Ho Chi Minh (`MSG`). Still worth confirming go-live date and whether it should be a priority to backfill into UAT (original stakeholder question) — that part is unconfirmed.

- [ ] **A3. Do `SIMLOGMNL` and `MARCONSGN` represent the same entity?**
  - These are the `OwnerCode` values from the two exports' headers — likely the login company code used when running the export, not necessarily the company the templates belong to.
  - **New lead (2026-08-28):** `MARCONSGN` plausibly abbreviates "**MAR**ine **CONS**...**GN**" — i.e. Marine Connections, the same MVN company confirmed in A2 above. This is a plausible naming match, not a proven identity — the codes were only spotted as visually similar while investigating an unrelated job number, not verified against any CW config screen.
  - Still need: does your CW login let you switch between both codes? If both are accessible from the same user login, they're almost certainly the same Enterprise instance viewed from different company contexts (normal). If only one is accessible to you, ask IT/admin to confirm both exports came from the same entity before trusting the Prod/Non-Prod diff as apples-to-apples.
  - **Record here:** Lead: `MARCONSGN` ≈ Marine Connections (MVN)? — unconfirmed, ask the team.

---

## Section B — Critical: verify the empty + NFB Universal templates

Applies to `BravoTran Shipment` (SHP), `BravoTran Customs` (BRK), `BravoTran Console` (CON) — confirmed empty (0 items) and `TriggerFallbackMethod=NFB` in **both** Non-Prod and Prod.

- [ ] **B1.** Open each of the 3 templates in Registry > Workflow Templates. Confirm directly in the UI (not just the XML) that Tasks/Milestones/Triggers tabs are genuinely empty and Trigger Fallback Method is still `NFB`.
- [ ] **B2.** Determine whether any live job actually matches these Universal templates. Practical trick from the CW reference guide: open a job of the relevant type (e.g. any Shipment), go to its Workflow & Tracking tab, add the **Template Name (Source Template)** column to the grid, and check whether any job shows a BravoTran template as its source. If BravoTran is a real org (from A1), filter/search jobs for that customer specifically.
- [ ] **B3.** If jobs ARE matching and getting nothing applied: escalate — this is jobs silently missing all workflow automation (including any EDI triggers) today.
- [ ] **B4.** If no jobs match (BravoTran turns out inactive/unused): downgrade this from "critical" to "cleanup candidate" — recommend deactivating the 3 templates or documenting them as intentionally dormant so a future audit doesn't re-flag them.
- [ ] **B5.** Record outcome in `docs/backlog/` following the pattern of `docs/backlog/eadaptor-inbound-auth-401.md` if it turns out to be a real gap needing a fix.

---

## Section C — Verify environment-only templates

- [ ] **C1.** `H56 SHP, SEA, DOM, global, system` (Prod-only, 99 items) — confirm it's actively used (check Source Template on a few real domestic sea shipments). If confirmed active, decide with your team whether to replicate it into Non-Prod for test coverage, and log that decision.
- [ ] **C2.** The 3 `MVN`-coded templates (Prod-only) — once A2 confirms MVN's status, decide the same replicate-or-ignore question.
- [ ] **C3.** The 3 Non-Prod-only templates (`BRK, global, system`; `H56, CON, SPH, local, system`; `H56 SHP, SPH, GOOASISIN, local, system`) — check whether these are intentional test scaffolding or templates that were meant to be promoted to Prod and never were.

---

## Section D — Verify the EXP/IMP/FIN category gap

`H56 SHP, global, system` has 22 Exception + 4 Finance + 14 Import items in Non-Prod that don't exist in Prod at all (and no other template in the whole Prod export has any EXP/IMP/FIN items either).

- [ ] **D1.** Open `H56 SHP, global, system` in both environments side by side (or export again if the files are stale) and confirm this split still holds.
- [ ] **D2.** Ask whoever last modified this template (check any audit/change-log CW exposes on the record, or ask the team) whether the EXP/IMP/FIN items are: (a) new functionality staged for promotion to Prod, or (b) deliberate Non-Prod-only test items.
- [ ] **D3.** If (a): this becomes a deployment backlog item — log it. If (b): document that decision so it's not re-flagged as a bug later.

---

## Section E — General template audit procedure (repeatable, for any template)

Use this for any template not already covered above, or for future audits:

- [ ] Record: Name, Process Type, Active flag, System vs Custom (`IsSystem`), Universal/Partial flags.
- [ ] Record all three Fallback Methods (Milestone/Task/Trigger) — flag any `NFB` for a closer look, since that's the setting that can cause "missing" behavior to go unnoticed.
- [ ] Count Tasks/Milestones/Triggers — flag anything at 0 items combined with `NFB` (see Section B pattern) as high priority.
- [ ] For templates with overlapping-looking criteria (e.g. multiple SHP templates with no visible SubType/Country differentiator), check the actual match criteria — Basic Registration tab conditions, linked Organization, or `ProcessJobHeaderCollection` in an export — to confirm they don't unintentionally double-apply.
- [ ] Cross-check Trigger items with `TriggerType=IFC` against `docs/integration-design/diagrams/eAdaptor_Inbound_Outbound_Mechanism.puml` to confirm which are genuine EDI outbound sends vs internal notifications.
- [ ] Log findings in `docs/discovery/` or `docs/backlog/` following existing file patterns in this repo.

---

## Stakeholder questions — for your PO

Business context, ownership, and priority calls that only someone with organizational visibility can answer.

- Is "BravoTran" a current customer/partner/carrier? Are any jobs today expected to route through it? (Section A1/B — the empty+NFB risk depends entirely on this.)
- Is "MVN" a currently operating branch/office? When did it go live, and should its Prod-only templates (SHP/TRN/WKI) be a priority to backfill into UAT?
- Do the two environments compared in `docs/discovery/prod-vs-uat-gap-analysis.md` (OwnerCode `SIMLOGMNL` vs `MARCONSGN`) represent the same legal entity, or different business units?
- Is there an existing integration/architecture doc set (owner map, governance rules) maintained elsewhere that this discovery work should align with, rather than rebuild? (`docs/discovery/integration-owner-map.md` and `docs/governance/` are still empty placeholders in this repo.)
- Who owns/approves changes to Workflow Templates, and is there a formal change-control or UAT→Prod promotion process for them?
- Priority call: should the eAdaptor inbound auth blocker (`docs/backlog/eadaptor-inbound-auth-401.md`) get resolved before continuing the workflow template audit, or can they run in parallel?
- Is there a business deadline or driver (e.g. a customer/Boomi go-live) that should reorder any of this work?

## Stakeholder questions — for team members / IT / CW admins

Technical specifics that need someone with CW config access or institutional memory.

- Does eAdaptor Next inbound Basic Auth for interchange `HONEASHKG` read from the interchange config's own password field, or from a separately linked CW user/login record? (Core blocker — see `docs/backlog/eadaptor-inbound-auth-401.md`.)
- Are there multiple inbound config records for this interchange (per Application Code / Message Type / Sub Type), and which one actually backs the `/eAdaptorNext` endpoint we've been testing against?
- ~~What's the correct UAT/Prod SQL Reporting DB hostname?~~ **Resolved.** `H56TRN.db.wisegrid.net` / `H56PRD.db.wisegrid.net`, confirmed 3 independent ways (CW's own "Output SQL security build info", Hari/data team, and CW's Help > About screen — see `docs/discovery/workflow-traffic-analysis-guide.md`). The old `h56trn.wisegrid.net`/`h56prd.wisegrid.net` (no `.db.`) are deprecated.
- Login `EnterpriseDbUser_OdysseyH56TRN_H56.Spencer.Nguyen` has the right permissions (`CONNECT SQL`, `CONNECT` on `OdysseyH56TRN`, member of `cwRestrictedReaderRole` — confirmed via `tmp/2026_08_28_db_build.log`), **but DNS for `H56TRN.db.wisegrid.net` fails identically from all 3 test servers as of 2026-08-29** (confirmed 3-for-3, different public IPs/subnets each — see `docs/discovery/workflow-traffic-analysis-guide.md`) — this is a VNet/DNS-zone-peering gap, not credentials, and not a per-server whitelist issue. **Ready to escalate to IT/network team** with the specific evidence rather than continuing to retest; Track B remains blocked until that's resolved.
- Where in CW UI can we actually see EDI message send/receive history (not just failures)? `Health Check > Failed EDI Interchange` turned out to only be an email-alert-recipient config, not a traffic log — need the real screen name/path.
- Who last modified `H56 SHP, global, system` (the largest workflow template, 144 items in UAT / 99 in Prod), and do they know why its 22 Exception + 4 Finance + 14 Import items exist only in UAT and not Prod — pending promotion, or deliberate test-only scaffolding? (See "Section D" above.)
- Does CW expose a change history/audit log for Workflow Template records we could check directly, instead of relying on memory?
- Is `H56 SHP, SEA, DOM, global, system` (Prod-only, 99 items) actively used today? Should it be replicated into UAT?
- Does the org already have a Power BI dashboard covering workflow/task volume or EDI message volume — would shortcut the traffic analysis in `docs/discovery/workflow-traffic-analysis-guide.md` entirely if it exists.
- When these two XML exports were pulled, which company/login was used for each? That alone could resolve the `OwnerCode` question above immediately.
