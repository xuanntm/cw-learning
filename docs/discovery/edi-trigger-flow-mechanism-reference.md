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
