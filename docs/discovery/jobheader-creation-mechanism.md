# JobHeader ("Job") Creation Mechanism — Confirmed

Environment: UAT/TRN (`H56TRN.db.test.wisegrid.net` / `OdysseyH56TRN`). Resolves the investigation opened in `docs/backlog/uat-jobheader-replication-stall.md` (now closed — see that file).

## Finding

**A `JobHeader` row is NOT created at the same time as the `JobShipment` row.** It's created later, the first time Billing information is saved on the shipment. Until that happens, a `JobShipment` can exist — fully valid, fully visible, with real org roles, sailing links, etc. — with **zero** corresponding `JobHeader` row, and therefore no job number (`JH_JobNum`) at all.

This matches the conceptual distinction in `docs_for_thanh/foundations/02_CargoWise Quick Concept.md` and `04_core system objects.md`: **"Job" is described as the branch-specific execution/billing layer, distinct from the Shipment (One-File) record** — this is that distinction showing up concretely in the schema, not just as a conceptual note.

## Evidence

Two independent, deliberately-triggered test cases, both on UAT:

| Job | `JS_PK` | `JobShipment` created | Billing edit made | `JobHeader` created | Same timestamp? |
|---|---|---|---|---|---|
| `S00075832` | `69A65D88-...` | 2026-08-30 07:23 UTC | 2026-08-30 08:24 UTC | `JH_SystemCreateTimeUtc = 2026-08-30 08:24:00` | ✅ exact match |
| `S00075831` | `5E06300A-...` | 2026-08-30 06:41 UTC | 2026-08-30 08:32 UTC | `JH_SystemCreateTimeUtc = 2026-08-30 08:32:00` | ✅ exact match |

Both jobs sat with a `JobShipment` row and no `JobHeader` for roughly an hour (`S00075832`) to nearly two hours (`S00075831`) — not because of any replication delay, but because nobody had touched Billing yet. The moment Billing was edited, `JobHeader` appeared immediately, at the same timestamp.

`StmALog` shows a `DEX` event firing right around the same moment (`S00075832`: `DEX` at `08:24:20`/`08:24:21`, ~20 seconds after the edit landed) — likely the event code associated with this specific action, though not confirmed as causal vs. coincidental.

## Practical implications

- **Don't rely on `JobHeader` to detect "does this shipment exist."** A shipment can be fully real and correctly configured (org roles, routing, etc. — all live on `JobShipment`/`cvw_JobShipmentOrgs`) with no `JobHeader` row and no job number yet.
- **Any report/query keyed on `JobHeader`/`JH_JobNum`** (which is most of them — see `docs/discovery/jobheader-table-reference.md`) will silently exclude shipments that haven't had Billing touched yet. This could under-count "new" shipments in volume/trend reports if there's a real-world lag between shipment creation and first billing action.
- **For EDI trigger testing specifically**: if a trigger condition or downstream process expects `JH_JobNum` or anything keyed off `JobHeader`, it won't be available until Billing has been saved at least once — worth doing that step early in any new test shipment, not as an afterthought.

## What's still unconfirmed

- Whether *any* Billing-tab save triggers this, or something more specific (e.g. a particular field, like assigning a billing branch/debtor). Both test cases here were general "update billing information" actions — not isolated to one field.
- Whether other actions (outside Billing) can also trigger `JobHeader` creation independently — not tested.
- ~~Whether `DEX` is the specific/reliable event code for this action, or coincidental.~~ **Resolved 2026-08-30**: `DEX` decodes to "Data Export" (`StmEvent.SE_Desc`, see `docs/discovery/milestone-event-reference-discovery.sql`) — an unrelated system-level event, not specific to Billing edits or `JobHeader` creation. The real event tied to this action is `JED` ("Billing Job Edit"), confirmed via the built-in `ProcessTemplateTrigger` row of the same name (see `docs/discovery/edi-trigger-flow-mechanism-reference.md`'s ruled-out `ProcessJobTriggerLink` dead end). The `DEX` correlation observed earlier was coincidental timing, not the causal event.

## Related files

- `docs/backlog/uat-jobheader-replication-stall.md` — the original (incorrect) replication-stall theory, now closed with a pointer here.
- `docs/discovery/jobshipment-phase-status-diagnostic.sql` — ruled out a `JobShipment`-side lifecycle-flag difference (all identical) before this was found.
- `docs/discovery/jobheader-post-billing-edit-check.sql` — the query that produced the confirming evidence above.
- `docs/discovery/stmalog-shipment-events-check.sql` — surfaced the `DEX` event correlation.
- `docs_for_thanh/foundations/02_CargoWise Quick Concept.md`, `04_core system objects.md` — the conceptual "Job ≠ Shipment" distinction that pointed toward this mechanism instead of a data/sync issue.
