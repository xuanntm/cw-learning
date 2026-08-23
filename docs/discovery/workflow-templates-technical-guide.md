# Workflow Templates — Technical Quick Reference

Condensed from `docs/1PRO Workflow Templates Reference Guide.docx` for use while reviewing the current CW config against intended design. Full detail (including the complete Condition 1/2 matrix) is in the source docx.

## What it is
Workflow Templates standardize the Tasks, Milestones, and Triggers that would otherwise have to be set up manually on every job/record. An admin builds a template once; CW then auto-attaches it to matching jobs based on criteria (Process Type + conditions). This is also the layer that drives **Milestone/Trigger-based EDI outbound events** — so a "missing outbound message" bug is often a template-matching problem, not an eAdaptor problem.

## Where it lives
Registry (or wherever Workflow is exposed) → Workflow Templates. Each record's Details tab exposes these sub-tabs, which only appear once a **Process Type** is selected:

| Tab | Purpose |
|---|---|
| Template Selection Criteria | Name, Description, Process Type, Active flag, Partial/Universal template flags |
| Tasks | Manual work units with start/complete times (1PRO004) |
| Milestones | Tracking/tracing checkpoints visible to CW users and clients (1PRO005) |
| Triggers | Actions fired on an event or field change — **this is what fires eAdaptor outbound sends** (1PRO007) |
| Screen Layout | Per-Process-Type field/section layout changes (1PRO014) |
| Custom Fields | Adds custom fields for certain Process Types (1PRO015) |

## How CW picks which template applies
CW matches templates using **Process Type** + **Transport Mode** + **Direction**, then narrows further with **Condition 1** and **Condition 2** (both are Process-Type-specific — e.g. for Shipment, Condition 1 includes IMP/EXP/DOM/ORL/DSD/CDL/CPL/PUC/DLC/BRK/ACA/2LG-4LG; Condition 2 includes container/consol-type flags like LCL/FCL/BBK/BLK/etc.). More than one template can match and stack on the same job — see Fallback Method below for how that stacking is controlled. Full condition-to-field mapping is in the source docx Appendix §3.2/3.3 — don't hand-transcribe it, the matrix is dense and process-type-specific.

## Fallback Method — the most common source of "unexpected template" bugs

Set independently per Tasks / Milestones / Triggers on each template:

| Option | Behavior |
|---|---|
| **AFB** — Always falls back | Less specific templates are *always* also applied alongside this one. |
| **EFB** — Falls back if empty *(default)* | Less specific templates only apply if this template defines nothing for that item type. |
| **NFB** — Never falls back | Less specific templates are ignored entirely, even if this template has nothing configured — use to guarantee *only* the intended items apply. |

**Gotcha worth knowing before auditing:** if a template's conditions aren't met, CW keeps falling back to less specific templates. If conditions later *do* get met (e.g. a field changes mid-job), the better-matched template is added — but templates already applied are **not automatically removed**. A job can end up carrying items from multiple templates simultaneously. This is the #1 thing to check when a job's Tasks/Milestones/Triggers don't match what you'd expect from the template you think is "the" template for that job.

## Process Types relevant to Forwarding/EDI work

Full type list is in the docx (60+ types spanning Warehouse, Customs, AR/AP, HR, etc). The ones most relevant to shipment/EDI flow review:

| Code | Description | Module |
|---|---|---|
| SHP | Shipment | Operate > Forwarding > Shipments |
| CON | Consol | Operate > Forwarding > Forwarding > Consolidations |
| CNT | Container | Operate > Forwarding > Forwarding > Containers |
| BRK | Declaration Job | Operate > Customs > Customs Declaration |
| ORD | Forwarding Order | Operate > Forwarding > Order Manager > Orders |
| TBM | Transport Booking | Operate > Transport > Transport Booking > Bookings |
| BOL | Bill of Lading | Operate > Liner & Agency > Bills of Lading |
| ORG | Organization | Maintain > Master Data > Organizations |

## Gap-review checklist

Use this against the live CW config to compare "what's built" vs "what's intended":

- [ ] For each Process Type in scope (start with SHP/CON), list every Active template and its Condition 1/2 criteria — check for overlapping conditions that could cause unintended multi-template stacking.
- [ ] Confirm Fallback Method on the Triggers tab of each template — an unexpected **AFB** where **NFB** was intended is the most likely cause of a duplicate/extra outbound EDI trigger; an unexpected **EFB**/**AFB** where a trigger silently isn't firing is the likely cause of a *missing* one.
- [ ] For any job showing unexpected Tasks/Milestones/Triggers, check whether multiple templates are stacked on it (per the fallback gotcha above) rather than assuming the wrong single template matched.
- [ ] Cross-check Milestones tab items against `docs/integration-design/diagrams/eAdaptor_Inbound_Outbound_Mechanism.puml` — every Milestone intended to fire an outbound message needs a corresponding Trigger, they're configured separately.
- [ ] Note any template with **Partial Template** or **Universal Template** ticked — these have different matching behavior (1PRO047 / 1PRO044 in the source doc) and are easy to overlook during a gap review.
- [ ] Record findings back into `docs/discovery/integration-owner-map.md` or a new `docs/backlog/` entry per the pattern in `docs/backlog/eadaptor-inbound-auth-401.md`.

## Source
`docs/1PRO Workflow Templates Reference Guide.docx` — CargoWise reference guide. WiseTech Academy links referenced inside: *Workflow Manager – Administration* course, *How-To Determine and Troubleshoot which Workflow Template will be applied*, *Workflow Template inheritance of Tasks, Milestones and Triggers*.
