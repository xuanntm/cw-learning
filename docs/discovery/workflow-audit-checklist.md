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
  - **New evidence 2026-08-29 (UAT DB, `docs/discovery/workflow-runtime-check.sql` Step 3, `tmp/UAT_step3_202608291546.csv`):** the BravoTran footprint is larger than previously catalogued — **13 templates** reference "BravoTran" in their name, not 5: the 5 generic ones already known, plus **7 branch/company-scoped variants** (`H56, ACA, BRK, BravoTran, system`, `H56, BCA, SHP/SAR/PNV/ORG/CON/BRK, BravoTran, system`). None of the 13 have a value in `ProcessTaskTemplate.P0_OH_Client` (the FK to `OrgHeader`) — rules out "BravoTran is a specific customer Org referenced directly on the template," though it doesn't rule out BravoTran being an Org scoped some other way, or not an Org at all. Combined with the confirmed live PROD endpoint (`bci-be.benline.com/api/EadaptorNext/BravoTrans`), the working theory remains: BravoTran is most likely an external system/integration partner name, not a CW Organization.
  - **New evidence 2026-08-29 (UAT DB, `docs/discovery/uat-edi-configuration-collector.sql` Steps 2 & 4, `tmp/EDI/EDI_step2_202608291621.csv` and `EDI_step4_202608291622.csv`):**
    - **Correction to the "fully dormant" read from earlier today:** the 30-day traffic check showed 0 messages for `BravoTran`/`Kestrel`/`SAPI`, but the 90-day window shows real traffic: **15 messages** (BravoTran), **14** (Kestrel), **2** (SAPI) in the 31–90 day range — these went quiet in the last 30 days, they were not "never used." Only `VNPT` is genuinely zero across both windows.
    - **`EDICommunicationsMode` (the legacy transport table) turned out to be an actively-used per-Organization EDI routing layer**, not dormant/unused — every row is scoped via `ParentTableCode='OH'` + `ParentID` (the polymorphic pointer pattern, 5th confirmed real-world instance). **BravoTran-specific routing rules exist for 4 distinct real Organizations**, names confirmed via `OrgHeader`:

      | Org Code | Name |
      |---|---|
      | `BENLINCDN` | BEN LINE AGENCIES (CANADA) LTD. |
      | `BENLINYVR` | BEN LINE AGENCIES (NORTH AMERICA) LIMITED |
      | `PACOCECDN` | PAC OCEAN LOGISTICS LTD. |
      | `PACOCEUSA` | PAC OCEAN LOGISTICS INC. |

      All 4 are North American entities (Canada/USA) — strong pattern suggesting **BravoTran is a North America–specific integration partner/system** (paired with Ben Line's Canada/North America operations and their partner Pac Ocean Logistics), not a dormant/orphaned template. This is a materially different picture than "possibly unused" — it now reads as a real, regionally-scoped integration that recently went quiet, worth asking the team specifically about North American operations/BravoTran rather than a generic "what is this" question.
  - **Status:** taking this to the team for discussion (2026-08-29) — this file has the full evidence base for that conversation, including the NA-region customer pattern above. Record their answer here once available.

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

Applies to `BravoTran Shipment` (SHP), `BravoTran Customs` (BRK), `BravoTran Console` (CON) — confirmed empty (0 items) and `TriggerFallbackMethod=NFB` in **both** Non-Prod and Prod (static XML analysis).

**New evidence 2026-08-29 (live UAT DB query, `docs/discovery/workflow-runtime-check.sql` Step 2, results in `tmp/UAT_step2_202608291538.csv`):**
- **Two corrections to the template list itself:** a 5th BravoTran template exists — `BravoTran Automatic Invoice Posting` (PNV, also `NFB` + `IsUniversal=1`) — not previously catalogued in `workflow-templates-analysis.md`/`prod-vs-uat-gap-analysis.md`. Meanwhile `BravoTran Console` does **not** appear in UAT's active-template list at all — needs checking (inactive? renamed? UAT-specific absence?).
- **B2 answered for UAT specifically:** all 5 BravoTran templates show `ActualProcessInstanceCount = 0` — zero jobs have ever matched any of them in UAT. Per B4 below, that would downgrade UAT's instance of this risk to "cleanup candidate."
- **This does NOT answer B2 for PROD**, which is the actually load-bearing environment — `docs/discovery/edi-communication-mechanism-reference.md` already confirmed a real, configured PROD outbound endpoint (`https://bci-be.benline.com/api/EadaptorNext/BravoTrans`), so PROD traffic patterns could differ substantially from UAT's. **Run `workflow-runtime-check.sql` Step 2 against PROD before treating B2–B4 as resolved.**

- [ ] **B1.** Open each of the (now 5, not 3) templates in Registry > Workflow Templates. Confirm directly in the UI (not just the XML/DB) that Tasks/Milestones/Triggers tabs are genuinely empty and Trigger Fallback Method is still `NFB` for the 3 `NFB` ones.
- [/] **B2.** Determine whether any live job actually matches these Universal templates. **UAT: confirmed no (0 for all 5) via direct DB query, 2026-08-29.** **PROD: still needed** — this is the environment that actually matters given the confirmed live endpoint config.
- [ ] **B3.** If jobs ARE matching (check PROD) and getting nothing applied: escalate — this is jobs silently missing all workflow automation (including any EDI triggers) today.
- [ ] **B4.** If PROD also shows no jobs matching: downgrade this from "critical" to "cleanup candidate" — recommend deactivating the templates or documenting them as intentionally dormant so a future audit doesn't re-flag them.
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
- ~~Login `EnterpriseDbUser_OdysseyH56TRN_H56.Spencer.Nguyen` has the right permissions... DNS for `H56TRN.db.wisegrid.net` fails identically from all 3 test servers...~~ **Resolved 2026-08-29.** CW's team confirmed the correct hostname is `H56TRN.db.test.wisegrid.net` (the `.wisegrid.net` version used until now was missing a `.test.` segment) — not a VNet/DNS-zone-peering gap as first theorized. Retested successfully from server1 (DNS/TCP/login all OK, same SQL Server build as PROD) — see `docs/backlog/uat-db-dns-resolution-failure.md`. **Track B is now unblocked.**
- Where in CW UI can we actually see EDI message send/receive history (not just failures)? `Health Check > Failed EDI Interchange` turned out to only be an email-alert-recipient config, not a traffic log — need the real screen name/path.
- Who last modified `H56 SHP, global, system` (the largest workflow template, 144 items in UAT / 99 in Prod), and do they know why its 22 Exception + 4 Finance + 14 Import items exist only in UAT and not Prod — pending promotion, or deliberate test-only scaffolding? (See "Section D" above.)
- Does CW expose a change history/audit log for Workflow Template records we could check directly, instead of relying on memory?
- Is `H56 SHP, SEA, DOM, global, system` (Prod-only, 99 items) actively used today? Should it be replicated into UAT?
- Does the org already have a Power BI dashboard covering workflow/task volume or EDI message volume — would shortcut the traffic analysis in `docs/discovery/workflow-traffic-analysis-guide.md` entirely if it exists.
- When these two XML exports were pulled, which company/login was used for each? That alone could resolve the `OwnerCode` question above immediately.
