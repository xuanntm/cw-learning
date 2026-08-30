# Document Upload → EDI Send — Full Mechanism Reference

Consolidates everything confirmed this session about the pipeline from "a document/event happens on a job" through to "an EDI message actually sends." Built while debugging why a new test trigger ("Full Integration Testing" / EDI Client "Full Integration") wasn't firing. Confirmed facts are marked ✅; **unresolved gaps are marked ⚠️ — these are the places most likely to hide a missed config or special condition.**

## The pipeline, stage by stage

```
1. Document uploaded (StorageMain)
        │
        │  ⚠️ reconciliation mechanism NOT confirmed
        ▼
2. Required Document marked received (JobRequiredDocument.EQ_DateReceived)
        │
        │  relationship assumed from real reference example, not directly observed firing
        ▼
3. Milestone/Event registers (StmALog, SL_SE_NKEvent = code, SL_FireWorkflow = 1)
        │
        │  ✅ confirmed mechanism
        ▼
4. Template trigger definition matches (ProcessTasks, P9_Type='TRG', on the template)
        │  - event code match: P9_SE_NKMilestoneEvent
        │  - condition match: P9_TriggerCondition formula (⚠️ text not readable via SQL)
        ▼
5. Job-instance trigger fires (ProcessTasks, SAME table, P9_FH_ProcessHeader now populated)
        │
        │  ⚠️ "Completion Trigger Action" (Action/Purpose/Recipient) table NOT YET LOCATED
        ▼
6. Organization → EDI Client routing resolved (EDICommunicationsMode: Module+Purpose+Org)
        │
        │  ✅ confirmed mechanism
        ▼
7. EDI Client config resolved (EDICommunicationParty/PartyConfig/Auth)
        │
        │  ✅ confirmed mechanism
        ▼
8. Message created and sent (EDIInterchange/EDIMessage, via the EAM service task)
```

## Quick reference — table for each stage

| Stage | Table(s) | Key columns | Status |
|---|---|---|---|
| 1. Document Upload | `StorageMain` | Document Type classification | ✅ mapped, but confirmed to NOT cascade to Stage 2/3 by itself |
| 2. Required Document Reconciliation | `JobRequiredDocument` (`EQ_`) | `EQ_DocType`, `EQ_DateReceived`, `EQ_ParentID`+`EQ_ParentTableCode` | ⚠️ reconciliation mechanism (what actually stamps `EQ_DateReceived`) not found |
| 3. Milestone/Event Registration | `StmALog` (`SL_`) | `SL_SE_NKEvent`, `SL_FireWorkflow`, `SL_EventTimeUtc`, `SL_Table`+`SL_Parent` | ✅ confirmed |
| Event code dictionary (used by both Stage 3 and 4) | `StmEvent` (`SE_`) | `SE_Code`, `SE_Desc`, plus milestone-type flags | ✅ confirmed 2026-08-30 — see `docs/discovery/milestone-event-reference-discovery.sql` |
| 4. Template Trigger Definition | `ProcessTasks` (`P9_`, `P9_Type='TRG'`, `P9_FH_ProcessHeader` blank) | `P9_SE_NKMilestoneEvent`, `P9_TriggerCondition` (type code only, formula unreadable), `P9_ParentID`+`P9_ParentTableCode='P0'` → `ProcessTaskTemplate` | ✅ mechanism confirmed; ⚠️ condition formula text not readable via SQL |
| 5. Job-Instance Trigger Firing | `ProcessTasks` (same table, `P9_FH_ProcessHeader` populated) | same as above, plus the job link | ⚠️ stayed blank even after a confirmed real send on `S00075834` — semantics not fully understood |
| 6. Completion Trigger Action | **not located** | Action/Purpose/Recipient/Recipient Org/Alternate Recipient — only observed via UI so far | ⚠️ not found; see `docs/discovery/completion-trigger-action-code-dictionary.md` |
| Ruled out for Stage 5/6 | `ProcessJobTriggerLink` (`P9L_`) + `ProcessTemplateTrigger` (`P9T_`) | `P9L_TriggerFiredCountdown`, `P9L_ParentTableCode`+`P9L_ParentId` | ❌ dead end — only 3 fixed built-in system triggers, unrelated to custom triggers |
| 7. Org → EDI Client Routing | `EDICommunicationsMode` (`EK_`) | `EK_Module`, `EK_CommsDirection`, `EK_CommunicationsTransport`, `EK_MessagePurpose`, `EK_Destination` (Recipient ID), `EK_ParentTableCode='OH'`+`EK_ParentID`, `EK_ECC_CommunicationPartyConfig` | ✅ confirmed |
| Job → Org role resolution (feeds Stage 6's Recipient role) | `cvw_JobShipmentOrgs` (view) | `ControllingCustomer_Code`, `JS_E2_OA_OH_NKConsignor`/`NKConsignee`, keyed by `JS_PK` | ✅ confirmed |
| 8. EDI Client Configuration | `EDICommunicationParty` (`ECP_`) + `EDICommunicationPartyConfig` (`ECC_`) + `EDICommunicationAuth` (`ECA_`) | client name, endpoint, auth mode | ✅ confirmed |
| 9. Actual Send | `EDIInterchange` (`EI_`) + `EDIMessage` (`EM_`) | `EI_Status`/`EM_Status`, `EM_EI` (FK to interchange), `EM_LinkTable`+`EM_LinkUniqueID` (polymorphic pointer straight to the source job), `EM_MessageType` | ✅ confirmed, verified end-to-end via exact `EI_PK` ↔ `Eadaptor-Trackingid` match |

## Stage 1 — Document Upload

**Table**: `StorageMain` (`Enterprise.DocumentScanning.Business.StorageMain`), confirmed via field-inspector on `ShipmentForm > eDocs > Document Storage`.

This is pure file attachment — a document with a Document Type classification. **Confirmed empirically: uploading here does not, by itself, create a `StmALog` milestone event or populate anything on `JobRequiredDocument`.** Two BKC-type uploads to the test job produced zero rows in either downstream table.

## Stage 2 — Required Document Reconciliation ⚠️

**Table**: `JobRequiredDocument` (`EQ_` prefix) — `EQ_DocType`, `EQ_DateReceived`, `EQ_ParentID`+`EQ_ParentTableCode` (polymorphic pointer — parent value/code not yet empirically confirmed; tested against both the `JobShipment` and `JobHeader` PKs for the test job and got zero matches against either).

The real reference document's trigger condition explicitly checks this collection:
```
DocsAndCartage.RequiredDocuments.Find("{EQ_DocType}"=="BKC").EQ_DateReceived != ""
```

**⚠️ Open gap**: the test job has **zero** `JobRequiredDocument` rows at all — no `BKC` requirement, no others. Two unresolved questions:
1. Are these rows meant to be auto-created by the workflow/job template based on job type/route (and something is missing that would normally generate them), or are they always manually added per job?
2. Once a requirement row exists, what UI action actually reconciles an uploaded `StorageMain` document against it to stamp `EQ_DateReceived`? Not yet identified — likely a "Document Tracking" or similar screen, not the plain eDocs attachment list.

**This is the most likely single point of failure for a document-upload-driven trigger** — if there's no requirement row, there's nothing to reconcile, and stage 3 never happens no matter how many files get uploaded.

## Stage 3 — Milestone/Event Registration ✅

**Table**: `StmALog` (`SL_` prefix) — confirmed via field-inspector as the backing table for `ShipmentForm > Workflow > Events` (`StmALogCollectionWithMaster`).

Key columns: `SL_SE_NKEvent` (the event code, e.g. `BKC`, `EDT`), `SL_FireWorkflow` (bit — whether this event should trigger workflow evaluation), `SL_EventTimeUtc`, `SL_Table`+`SL_Parent` (which job/record this event belongs to).

**Confirmed empirically**: a `BKC`-coded event did not appear here system-wide in the 24 hours after the test uploads — consistent with Stage 2 never completing.

## Stage 4 — Template Trigger Definition Match ✅ (mechanism), ⚠️ (condition content)

**Table**: `ProcessTasks` (`P9_` prefix), **not** the similarly-named `ProcessTemplateTrigger` — confirmed via field-inspector on `ProcessTaskTemplateForm > Triggers` (`Table/Field Name: ProcessTasks.P9_Description`). Querying `ProcessTemplateTrigger` for a real, freshly-created trigger returns nothing.

- **`P9_Type = 'TRG'`** identifies a trigger-type row (vs. Task/Milestone types on the same table).
- **Template link**: `P9_ParentID` + `P9_ParentTableCode = 'P0'` → `ProcessTaskTemplate.P0_PK`. (`P9_ParentTemplateID`, a real column that looks like it should be this link, is confirmed unused/blank — don't use it.)
- **Event match**: `P9_SE_NKMilestoneEvent` (or `TaskCompletionEvent`/`ExceptionEvent` for other trigger styles).
- **Condition**: `P9_TriggerCondition` holds a short type code (`UDF` = User-Defined Formula, seen on most real triggers) — **the actual expression text is not visible via a plain `SELECT`** on the columns discovered so far, likely stored in a `varbinary` column. This means **two triggers can look byte-for-byte identical across every readable column and still behave completely differently** — confirmed directly: the test trigger and a known-working trigger ("EDI") matched on every visible column, yet only one fires.
- `P9_TriggerField`/`P9_LineTriggerType` — optional additional field-level conditions, often blank even on working triggers.

**⚠️ Practical implication for your review**: since the condition formula itself can't be read from the DB, **the CW UI's own Trigger Condition editor is the only reliable way to inspect/compare the actual rule logic** — don't trust a DB-level column match as proof two triggers behave the same.

## Stage 5 — Job-Instance Trigger Firing

When Stage 4's condition genuinely matches on a real job, `ProcessTasks` gets a **second row** — same table, but now in "instance mode": `P9_FH_ProcessHeader` populated (linking to a `ProcessHeader` row, which itself links back to the template via `FH_P0_Template`). This is the same table serving two roles depending on whether `P9_FH_ProcessHeader` is populated (job instance) or blank (template definition) — see `docs/discovery/edi-trigger-fire-diagnostic.sql` Step 2 for the check query.

**No new instance row appearing = the condition never matched on that job** (the most likely explanation for "nothing happened" if Stage 3's event did fire but Stage 5 still shows nothing).

## Stage 6 — "Completion Trigger Action" ⚠️ NOT YET LOCATED

The real reference document describes this as a distinct configuration block, separate from the Trigger Condition itself:

| Action | Purpose | Recipient | Recipient Organisation | Alternate Recipient |
|---|---|---|---|---|
| `XUS`/`XUE` (message type) | matches the Purpose Code on the Org's EDI Communications record | type | which Org | fallback |

**This table has not been found in the DB yet.** The FK discovery query already queued (`docs/discovery/trigger-config-compare.sql` Step 2, searching for FKs referencing `ProcessTasks.P9_PK`) is the next step to locate it — **this is possibly where your test config differs from the working one**, since Stage 4's condition columns already matched exactly.

**⚠️ Dead end ruled out (2026-08-30)**: `ShipmentForm > Workflow > Triggers > Countdown` looked like a promising lead — it's a live, per-job trigger-firing UI with a real backing table (`ProcessJobTriggerLink`, `P9L_` prefix, linking a job via the standard `P9L_ParentTableCode`/`P9L_ParentId` pointer to `ProcessTemplateTrigger`, `P9T_` prefix). Confirmed via field-inspector and direct query (`docs/discovery/workflow-trigger-live-state-discovery.sql`). **But `ProcessTemplateTrigger` turned out to be a small, fixed set of 3 built-in system triggers** (`Job Open`/`JOP`, `Billing Job Edit`/`JED`, `Add`/`ADD`), company/branch-unscoped, applying to every job in the system — not a user-configurable per-integration mechanism. A search for any row matching the custom "Full Integration Testing" trigger (by description or by creator) returned **zero rows**. The Countdown value the user watched change after a Billing edit was this built-in `Billing Job Edit` system trigger reacting to its own `JED` event — coincidental timing, unrelated to the custom EDT/BKC trigger. `ProcessJobTriggerLink`/`ProcessTemplateTrigger` can be ruled out as the "Completion Trigger Action" mechanism — the custom trigger only exists in `ProcessTasks`, which this table structurally cannot reference.

**Field values compared directly in the UI (2026-08-30)** — see `docs/discovery/completion-trigger-action-code-dictionary.md` for the growing code reference:

| Field | Working "EDI" trigger | Custom "Full Integration Testing" trigger |
|---|---|---|
| Action | `XUS` | `XUS` (same) |
| Purpose | `EAN` | `FTI` — **confirmed correctly matching** the Purpose Code already configured on `FULTESVIC`'s `EDICommunicationsMode` routing row, so this is not the mismatch |
| Recipient | `OTH` ("Other") | `CNE` ("Consignee") — `FULTESVIC` is confirmed as Consignee on `S00075824` via `cvw_JobShipmentOrgs`, so this *should* resolve correctly on this test job |

**⚠️ New blocker found**: selecting `OTH` on the custom trigger (to try matching the working config exactly) **throws a validation error and blocks saving** — not yet reproducible via the standard UI. The working trigger already has `OTH` saved, likely set via a path that bypasses this validation, or requiring a companion field (e.g. `Recipient Organisation`) that hasn't been populated when testing. This is now the most concrete open lead — see the code dictionary doc's "Open gap" section for next steps.

## ✅ Success confirmed (2026-08-30) — end-to-end send on `S00075834`

Real message delivery confirmed via three independent, cross-matching sources:
1. `tmp/2026_08_30_first_successful_message.log` — full `UniversalInterchange`/`UniversalShipment` XML received by the ngrok mock listener, `Eadaptor-Ediclientname: Full Integration`, `ActionPurpose` `FTI`, `RecipientID` `FULTESVIC`.
2. DB-side: `EDIMessage`/`EDIInterchange` rows exist for this exact send (`docs/discovery/full-integration-success-confirmation.sql` Step 2), `EI_Status`/`EM_Status = SNT`.
3. **Exact match**: `EI_PK = FE4FBF2C-DACD-4E4D-87CC-AA3D21C73737` is byte-for-byte identical to the `Eadaptor-Trackingid` header captured in the mock listener log — proof this is the same record on both sides, not just a nearby-in-time coincidence.

**Event codes decoded (2026-08-30)**, resolving the `EDT`/`DEX` confusion — see `docs/discovery/milestone-event-reference-discovery.sql`, real dictionary is `StmEvent` (`SE_Code`/`SE_Desc`):

| Code | Meaning |
|---|---|
| `EDT` | Edited a record — generic, fires on **any** edit to the record, not billing-specific |
| `DEX` | Data Export — a distinct, unrelated system-level event |
| `BKC` | Booking Confirmed (the trigger's original event code before being changed to `EDT`) |
| `JED` | Billing Job Edit (confirmed as the event behind `docs/discovery/jobheader-creation-mechanism.md`) |
| `JOP` | Job Open |

This explains why editing Billing finally produced a send: it wasn't Billing specifically that mattered — the trigger's condition was changed to listen for `EDT` ("any edit"), an almost-always-true condition, so any edit at all would satisfy it. `DEX` is unrelated — most likely the EAM/eAdaptor service's own "data exported" confirmation log entry, a side effect of a successful send rather than something a trigger listens for. `ProcessTasks.P9_FH_ProcessHeader` remaining blank on all three trigger rows for `S00075834` despite a confirmed real send (see Step 5 result in `full-integration-success-confirmation.sql`) is still unexplained — either that column doesn't mean "has fired" the way earlier assumed, or the actual firing/send record lives somewhere not yet found. Not blocking further work, since the practical goal (a working model integration, proven end-to-end) is achieved regardless.

## Stage 7 — Organization → EDI Client Routing ✅

**Table**: `EDICommunicationsMode` (`EK_` prefix). UI: `Organization → Details → Config → EDI Communications`. Fields: `EK_Module`, `EK_CommsDirection` (`TRX`), `EK_CommunicationsTransport` (`EDP`), `EK_MessagePurpose`, linked via `EK_ParentTableCode='OH'`+`EK_ParentID`→`OrgHeader.OH_PK`, and `EK_ECC_CommunicationPartyConfig` → the actual EDI Client.

This is presumably how Stage 6's "Purpose" + "Recipient Organisation" resolve to an actual EDI Client — but the exact join between Stage 6's (still-unlocated) action table and this routing table hasn't been directly observed, only inferred from the reference document's description.

## Stage 8 — EDI Client Configuration ✅

`EDICommunicationParty` (`ECP_`) + `EDICommunicationPartyConfig` (`ECC_`) + `EDICommunicationAuth` (`ECA_`). UI: `Maintain → EDI Messaging → EDI Client Details`. Fully mapped — see `docs/discovery/edi-communication-mechanism-reference.md` and `docs/discovery/edi-client-setup-guide-summary.md`.

**Note**: there are **two separate implementations** — this modern one (`/eAdaptorNext`) and a legacy `/eadaptor` mechanism with a different, still-unmapped credential store. See `docs/backlog/eadaptor-inbound-auth-401.md`.

## Stage 9 — Actual Send

`EDIInterchange` (`EI_`) + `EDIMessage` (`EM_`), processed by the **EAM** (eAdaptor Outbound Messages) service task — queues, transmits, retries, logs. See `docs/discovery/edi-communication-mechanism-reference.md`.

## Summary — where to focus your review

Given everything above, in priority order:

1. **Stage 2 (Required Document reconciliation)** — if your trigger depends on a document-type event like `BKC`, confirm whether the job actually needs a `JobRequiredDocument` row first, and how to reconcile an upload against it. This alone could fully explain "nothing happens" regardless of trigger config.
2. **Stage 4's condition formula content** — since DB comparison shows identical columns between working/non-working triggers, **open both in the CW UI's condition editor side by side** — the actual logic difference can only be seen there.
3. **Stage 6 (Completion Trigger Action)** — run `trigger-config-compare.sql` Step 2 to find this table; compare your trigger's action config against the working one's once found.
4. **Confirm which event you're actually testing** — the test trigger's event code has changed from `BKC` to `EDT` at some point; make sure whatever action you perform on the test job actually corresponds to the event currently configured.

## Related files

- `docs/discovery/edi-organization-routing-and-trigger-guide.md` — the Org/EDI Client/naming-convention reference this builds on.
- `docs/discovery/edi-trigger-fire-diagnostic.sql` — the 3-stage diagnostic (event/instance/message) referenced above.
- `docs/discovery/trigger-config-compare.sql` — the trigger comparison and pending Completion Trigger Action FK search.
- `docs/discovery/job-required-document-check.sql` — the Stage 2 check.
- `docs/discovery/edi-communication-mechanism-reference.md`, `docs/discovery/edi-client-setup-guide-summary.md` — Stages 7-9 detail.
