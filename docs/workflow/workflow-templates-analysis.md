# Workflow Templates Export — Analysis

Source: `ProcessTaskTemplate x 55_639230997705570000.xml` (CargoWise Native XML export, OwnerCode `SIMLOGMNL`, 55 `ProcessTaskTemplate` records, 540 individual Task/Milestone/Trigger items, 404 trigger notification actions). Read alongside `docs/discovery/workflow-templates-technical-guide.md` for what each field means.

## Top finding — 3 templates can silently suppress all workflow for jobs they match

Three templates are **Universal** (auto-apply broadly, not tied to a specific job's fields) **and have zero Tasks/Milestones/Triggers configured**, **and** set `TriggerFallbackMethod = NFB` ("never fall back to a less specific template"):

| Name | Process Type | Items | Trigger Fallback |
|---|---|---|---|
| BravoTran Shipment | SHP | 0 | NFB |
| BravoTran Customs | BRK | 0 | NFB |
| BravoTran Console | CON | 0 | NFB |

Per the fallback semantics (see technical guide): NFB means "even if this template has nothing configured, do not fall back to a less specific template." Combined with 0 items, **any job matched by these Universal criteria gets no Tasks, Milestones, or Triggers applied at all** — including whatever EDI outbound triggers would normally fire from a less-specific SHP/BRK/CON template. This is either (a) a deliberate design decision to fully exclude a segment of jobs from all workflow automation, or (b) a template that was scaffolded (Universal + NFB set deliberately) but never actually populated, silently breaking workflow for whatever "BravoTran" jobs match it.

**This needs a human check in CW UI, not just this static export**: confirm what "BravoTran" identifies (customer/carrier/partner code), whether any live jobs actually match these Universal criteria, and whether the empty/NFB combination is intentional.

Two other Universal templates are also empty but safe — `TriggerFallbackMethod = AFB` means they still fall back even though empty, so no suppression risk:

| Name | Process Type | Items | Trigger Fallback |
|---|---|---|---|
| BravoTran Organization | ORG | 0 | AFB |
| BravoTran Staff | SAR | 0 | AFB |

`BravoTran Automatic Invoice Posting` (PNV) is Universal + `NFB` but has 1 item configured, so it's not in the same "silently does nothing" category — worth a quick look to confirm that 1 item is actually sufficient, but lower priority than the three above.

## Overview stats

| Metric | Value |
|---|---|
| Total templates | 55 |
| Active | 55 / 55 (100%) |
| System-provided (`IsSystem=true`) | 19 |
| Custom/admin-built (`IsSystem=false`) | 36 |
| Universal templates | 8 |
| Partial templates | 1 |
| Templates with 0 Tasks/Milestones/Triggers | 18 (33%) |
| Total Task/Milestone/Trigger items | 540 |
| Total trigger notification actions | 404 |

## Process Type distribution

| Process Type | Templates |
|---|---|
| SHP (Shipment) | 13 |
| QBK (Quoted Booking) | 11 |
| CON (Consol) | 5 |
| BRK (Declaration Job) | 3 |
| SAR, WKI, TRN, PNV | 2 each |
| ORD, ORG, POD, CNT, RNV, CST, PPT, LTC, WKP, WIN, LTL, PRC, RPT, WOU, RRC | 1 each |

## Item type breakdown (all 540 items)

| Type | Count | Likely meaning |
|---|---|---|
| TRG | 361 | Trigger |
| MIL | 138 | Milestone |
| EXP | 22 | Exception |
| IMP | 14 | Import-related task |
| FIN | 4 | Finance-related task |
| UDF | 1 | User-defined |

Triggers (TRG) dominate — 67% of all configured items are triggers, consistent with this being an integration-heavy config rather than a manual-task-tracking one.

## Trigger notification types (404 notification actions)

| TriggerType | Count | Share |
|---|---|---|
| IFC | 145 | 36% |
| FLD | 119 | 29% |
| XUE | 43 | 11% |
| NTF | 25 | 6% |
| XUS | 25 | 6% |
| XUT | 13 | 3% |
| XUB | 8 | 2% |
| GHG, ECM | 6 each | — |
| XUD, XML, XUA, GAR | 2-3 each | — |
| ATP, TMP, EXL | 1-2 each | — |

`IFC` ("Interface") is the largest single category — this is the trigger family most likely tied to system-to-system/EDI communication, which is directly relevant to the eAdaptor discovery work elsewhere in this repo. **Caveat:** a manual sample of 10 IFC entries showed mixed content — some reference what look like custom-field-driven email/interface actions, one is a plain "Job Deactivation" notification, others reference only a GUID with no readable purpose inline (the actual message template is a separate linked record not resolved in this pass). Don't assume all 145 are outbound EDI sends without checking a few directly in CW — treat this as "where to look first," not a confirmed count.

## Workload concentration on SHP

`H56 SHP, global, system` alone carries **144 of the 540 total items (27%)** — by far the heaviest template in the export (next largest is `H56 SQT, global, system` at 50). Several customer/org-specific SHP templates (`CONCARMNN`, `CONDURMN`, `CONMIDMNL`, `MAELOGZRH`, `AIR EXP FEA`, `KESTRE_NP`, etc.) layer 18-20 items each **on top of** that base template — all use `AFB` (Always Falls Back) for Milestone/Trigger, so they're designed to stack additively rather than override. This is coherent as a design (one broad baseline + per-customer additions), but it also means:
- The single `H56 SHP, global, system` template is a concentration risk — a mistake there affects every shipment.
- These per-customer SHP template names (`CONCARMNN`, `MAELOGZRH`, etc.) have **no visible differentiator at the SubType/LoadPortCountry/DischargePortCountry level** — their actual match criteria (almost certainly an organization/customer link) lives deeper in the XML (`ProcessJobHeaderCollection`) than this pass resolved. If two of these ever have overlapping actual match criteria, they'd both apply (stacking via AFB) rather than one replacing the other — worth confirming in CW UI which organization each is actually scoped to.

## Empty templates (0 items) — full list

Most of these are low-risk system defaults for QBK sub-types that were never customized (`TriggerFallbackMethod=EFB`, so they safely fall back and aren't "dead" — they're just unused placeholders). Two are worth a second look:

| Name | System? | Trigger FB | Risk |
|---|---|---|---|
| BravoTran Shipment / Customs / Console | No | **NFB** | **High — see top finding** |
| BravoTran Organization / Staff | No | AFB | Low — falls back safely |
| BravoTran Automatic Invoice Posting | No | NFB | Medium — has 1 item, not fully empty |
| H56, WKI, TCL, 1WA, global, system | No (custom) | EFB | Low, but likely an abandoned custom template — candidate for cleanup |
| 10× QBK system templates (SQT/BWQ/QBN/FCL combinations) | Yes | EFB | Low — standard CW scaffolding, safe to ignore unless you specifically need those booking sub-types customized |

## Recommended next steps

1. In CW UI, open the three `BravoTran` + `NFB` + empty templates (Shipment, Customs, Console) and confirm whether they're intentionally suppressing workflow, or a leftover misconfiguration. This is the one finding worth escalating before anything else.
2. Confirm what "BravoTran" actually refers to (partner code/customer) so the scope of the empty-NFB risk is understood — check `docs/discovery/integration-owner-map.md` (currently empty) and fill it in as part of this.
3. Spot-check 3-5 `IFC` trigger entries directly in CW to confirm how many are genuinely EDI outbound sends vs. internal notifications, then fold that into the "Outbound Trigger Matrix" deliverable referenced in the roadmap.
4. Trace the actual match criteria (organization link) for the per-customer SHP templates (`CONCARMNN`, `MAELOGZRH`, etc.) to rule out overlapping scope.

## Caveats on this analysis

This was produced by parsing the XML structurally (element counts, flags, fallback methods) — it did not resolve every linked reference (e.g., `ProcessJobHeaderCollection`, `MessageDeliveryContextSelector`, organization PKs), and did not evaluate live job data, so "0 items" and fallback flags are the only things confirmed with certainty; anything above framed as "likely" or "worth checking" is a lead, not a verified conclusion.
