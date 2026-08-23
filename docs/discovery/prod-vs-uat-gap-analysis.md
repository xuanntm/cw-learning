# Prod vs Non-Prod — Workflow Template Gap Analysis

Compares two CargoWise Workflow Template exports:
- **Non-Prod**: `docs/workflow/ProcessTaskTemplate x 55_639230997705570000.xml` — 55 templates, OwnerCode `SIMLOGMNL`. Full standalone stats in `docs/workflow/workflow-templates-analysis.md`.
- **Prod**: `docs/workflow/PROD_ProcessTaskTemplate x 56_639230970020300000.xml` — 56 templates, OwnerCode `MARCONSGN`.

**Caveat before anything else:** the two exports have **different `OwnerCode` values** (`SIMLOGMNL` vs `MARCONSGN`). That could just be the login company used to run each export, or it could mean these were pulled from genuinely different company contexts within the Enterprise. Confirm which before treating this as a strict same-entity Prod/UAT diff — it changes how much weight the "only in one environment" findings below should carry.

## Critical — the empty-Universal-NFB risk exists identically in both environments

The high-risk pattern flagged in the standalone Non-Prod analysis (Universal template, 0 configured items, `TriggerFallbackMethod=NFB`) is **present unchanged in Prod**:

| Name | Process Type | Items (UAT / PROD) | Trigger Fallback |
|---|---|---|---|
| BravoTran Shipment | SHP | 0 / 0 | NFB (both) |
| BravoTran Customs | BRK | 0 / 0 | NFB (both) |
| BravoTran Console | CON | 0 / 0 | NFB (both) |

Since `NFB` means "never fall back to a less specific template" and both are empty in both environments, this is **not a UAT-only artifact — it's live in Prod today**. Any job actually matched by these Universal criteria in production gets zero Tasks/Milestones/Triggers, silently. This raises the priority of confirming what "BravoTran" identifies and whether any live Prod jobs match it — see recommendations.

(`BravoTran Organization` / `BravoTran Staff` are also empty in both, but `AFB` fallback makes them safe — not a concern.)

## Templates present in only one environment

**Only in Non-Prod (3):**

| Name | Process Type | Items |
|---|---|---|
| BRK, global, system | BRK | 4 |
| H56, CON, SPH, local, system | CON | 2 |
| H56 SHP, SPH, GOOASISIN, local, system | SHP | 16 |

**Only in Prod (4):**

| Name | Process Type | Items |
|---|---|---|
| H56 SHP, MVN, local, system | SHP | 2 |
| **H56 SHP, SEA, DOM, global, system** | SHP | **99** |
| H56, TRN, MVN, global, system | TRN | 3 |
| H56, WKI, MVN, global, system | WKI | 4 |

Two distinct patterns here, worth treating separately:

1. **`H56 SHP, SEA, DOM, global, system` (99 items) exists only in Prod.** This is a substantial, actively-used template (Domestic Sea Shipment) with no Non-Prod counterpart at all — meaning changes to domestic sea shipment workflow can't currently be tested in Non-Prod before they hit Prod. This is the single most important item in this list.
2. **The three `MVN`-coded templates exist only in Prod** (SHP, TRN, WKI). `MVN` looks like a branch/company code that's been set up in Prod but not yet replicated to Non-Prod — an environment-topology gap rather than a content gap. Worth confirming whether `MVN` is a real, currently-operating branch; if so, it currently has zero test coverage in Non-Prod.
3. The three Non-Prod-only templates (`BRK` plain, `CON ... SPH local`, `SHP ... SPH GOOASISIN local`) are small (2-16 items) and read like either legacy/test artifacts left in Non-Prod, or work-in-progress not yet promoted to Prod. Lower priority than #1/#2.

## Content drift on templates that exist in both (52 common names, 11 with differences)

All differences found were in item **counts/type breakdown only** — no drift was found in `IsActive`, `IsSystem`, `IsUniversal`, `IsPartial`, or any of the three Fallback Method fields across the 52 shared templates. Fallback-method posture is consistent between environments; only the configured content volume differs.

| Template | UAT items | PROD items | What differs |
|---|---|---|---|
| **H56 SHP, global, system** | 144 | 99 | UAT has 22 Exception + 4 Finance + 14 Import items (40 total) that **do not exist in Prod at all** |
| H56, RNV, global, system | 16 (1 MIL + 15 TRG) | 8 (0 MIL + 8 TRG) | UAT has a Milestone item and nearly double the Triggers |
| H56, CNT, global, system | 25 (12 MIL) | 37 (24 MIL) | Prod has double the Milestones |
| H56, CON, CST, global, system | 21 (8 TRG) | 24 (11 TRG) | Prod has more Triggers |
| H56, CON, EXP, global, system | 18 (8 TRG) | 21 (11 TRG) | Prod has more Triggers |
| H56 BRK, global, system | 22 (20 TRG) | 25 (23 TRG) | Prod has more Triggers |
| H56, SHP, CONCARMNN / CONDURMN / CONMIDMNL (3 templates) | 18 each (9 MIL + 9 TRG) | 23 each (12 MIL + 11 TRG) | Prod consistently has 5 more items on all three customer-specific SHP templates |
| H56, PNV, global, system | 8 TRG | 5 TRG | UAT has more Triggers |
| H56, RRC, global, system | 2 TRG | 4 TRG | Prod has more Triggers |

**The one that matters most:** `H56 SHP, global, system` — the single largest and most heavily-used template in the whole config (dominant in both environments) — is missing its entire complement of Exception (22), Finance (4), and Import (14) items in Prod. This isn't a small drift; it's a whole category of workflow behavior (40 items) that exists in Non-Prod and not in Prod. Combined with the environment-wide item-type totals below, this looks systemic rather than isolated to one template:

| Item Type | UAT total | PROD total |
|---|---|---|
| TRG | 361 | 434 |
| MIL | 138 | 170 |
| EXP | 22 | **0** |
| IMP | 14 | **0** |
| FIN | 4 | **0** |
| UDF | 1 | 4 |

**Every single Exception/Import/Finance-type item in the export lives in Non-Prod, and none exist in Prod.** Given Prod otherwise has *more* Triggers and Milestones than Non-Prod (434 vs 361, 170 vs 138), this isn't "Prod is behind" in general — it specifically never received these three item types. That points at one of two explanations: (a) these are newer workflow features being trialed in Non-Prod that haven't been promoted yet, or (b) they were deliberately added only to Non-Prod for testing and were never meant for Prod. Worth confirming which with whoever owns this template before assuming it's a pending deployment.

## Recommendations

1. **Highest priority — same as the standalone Non-Prod finding, now confirmed live in Prod:** confirm what "BravoTran" refers to and whether it currently matches any real Prod jobs. If it does, those jobs are getting zero workflow automation today.
2. Confirm whether `H56 SHP, SEA, DOM, global, system` (Prod-only, 99 items) should be backfilled into Non-Prod so domestic sea shipment changes can be tested before they reach production.
3. Confirm whether `MVN` is a live branch — if so, replicate its three Prod-only templates into Non-Prod for test coverage.
4. Get a definitive answer on the EXP/IMP/FIN (40-item) gap on `H56 SHP, global, system`: pending promotion to Prod, or Non-Prod-only test scaffolding that should stay put. This determines whether it's a deployment backlog item or a non-issue.
5. Confirm the `OwnerCode` discrepancy (`SIMLOGMNL` vs `MARCONSGN`) doesn't invalidate any of the above — re-pull both exports from the same login company if there's any doubt.

## Caveats

Same as the standalone analysis: this is a structural diff (names, flags, item counts/types) — it does not resolve linked records (organization scoping, message templates, `ProcessJobHeaderCollection`) or check live job data. Findings phrased as "confirm"/"worth checking" are leads for a human to verify in CW UI, not confirmed conclusions.
