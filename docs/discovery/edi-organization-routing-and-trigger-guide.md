# Organization EDI Routing + Workflow Trigger Wiring — Confirmed Pattern

Source: an internal setup guide for a real, already-working production eAdaptor Next integration (extracted from `C:\Users\SpencerNGUYEN\Downloads\EDI_2026\SampleIntegrationDocument\`, not tracked in this repo — the source is classified "Internal — Project Reference" and contains stakeholder names/business details out of scope for this technical reference). This doc extracts only the **technical mechanism** — UI paths, field mappings, trigger syntax — confirmed against a real working example, completing the gap flagged in `docs/discovery/edi-client-setup-guide-summary.md` and the Stage 3 discussion in chat.

## Organization → EDI Client routing (confirmed navigation)

**Organization (Master Data) → Organization → [pick the Org] → Details → Config → EDI Communications.**

Add a new EDI Communications record with:

| Field | Example value | Maps to (DB, confirmed earlier) |
|---|---|---|
| Module | e.g. `SHP`, `CNT` | `EK_Module` |
| Communication Direction | `TRX` (Transmit) | `EK_CommsDirection` |
| Communication Transport | `EDP` (eAdaptor Interface) | `EK_CommunicationsTransport` |
| Purpose Code | short partner code | `EK_MessagePurpose` |
| EDI Client | the EDI Client's name | resolves to `EK_ECC_CommunicationPartyConfig` |
| Recipient ID | free-text trading-partner identifier (embedded in the outbound message envelope) | `EK_Destination` — confirmed via field-inspector 2026-08-30 (`DestinationTextBox` control, plain `ZString`, no lookup/validation). Any consistent value works for a test integration, e.g. the test Org code |

This confirms the `EDICommunicationsMode` mechanism already mapped from the earlier BravoTran routing investigation — this is the real UI screen that writes those rows.

## EDI Client naming convention (confirmed real standard)

```
H56_{ENV}_{MODULE}_{PARTNER}
```
e.g. `H56_PRD_SHP_CNT_SYNGENTA` — `H56` (instance prefix, matches the confirmed hostname formula), `PRD`/`TRN` (environment), module code(s), then the integration partner/purpose name. **"One EDI Client per integration"** is the stated rule. Worth knowing our own test client ("Full Integration") doesn't follow this convention — fine for a test/model integration, but real ones should.

## Workflow trigger wiring — the confirmed, safe pattern

The real example does **not** use a dedicated/partial template — it adds scoped trigger rows to the **global** template (e.g. `H56, SHP, global, system`), with tight filtering so only in-scope jobs are affected:

- **Trigger Condition** is a CW expression referencing object/field paths, e.g.:
  ```
  "<ControllingCustomer.OH_Code>"=="<TEST_ORG_CODE>" && ("<Consignor.OH_Code>"=="<TEST_ORG_CODE>" || "<Consignee.OH_Code>"=="<TEST_ORG_CODE>")
  ```
  Combined with an **Event Code** (e.g. a document-type upload event) and, for container-level triggers, additional consol/direction filters (`Consol.JK_ConsolMode`, `JobDirection`, `JobContainer.JC_IsShipperOwned`) and a document-tracking condition (a specific required-document type having been received).
- The **Completion Trigger Action** is what actually dispatches: `Action` (message type, e.g. `XUS`/`XUE`), `Purpose` (matches the Purpose Code on the Org's EDI Communications record), `Recipient` type, `Recipient Organisation`, `Alternate Recipient`.

**Recommended safe approach for the test EDI Client ("Full Integration")**: add a new trigger row to the appropriate global template, filtered tightly to a dedicated test Organization's code (mirroring the pattern above) — don't touch or repurpose any existing real customer-scoped trigger row. This confirms the "use a dedicated test Org, add a new scoped row" recommendation from the Stage 3 chat discussion is the actual real-world pattern, not a guess.

## ⚠️ Correction (2026-08-30): the Triggers tab is backed by `ProcessTasks`, NOT `ProcessTemplateTrigger`

Confirmed directly via the CW field-inspector (`Ctrl+right-click` on the Triggers tab's Description field, `ProcessTaskTemplateForm > Details > Triggers`): **`Table/Field Name: ProcessTasks.P9_Description`.** `ProcessTemplateTrigger` (despite its name matching exactly what you'd expect) is a red herring for this purpose — querying it for a newly-created trigger returns nothing, because the real data lives in `ProcessTasks`.

Confirmed real chain, tested end-to-end against a real created trigger:

- **`P9_Type = 'TRG'`** identifies a Trigger-type row (vs. Task/Milestone types on the same table) — matches the `TRG`/`MIL`/`TSK` item-type terminology from the earliest workflow-template analysis this session.
- **Template link**: `P9_ParentID` + `P9_ParentTableCode = 'P0'` (`P0` = `ProcessTaskTemplate`'s own prefix) — **another confirmed instance of the polymorphic pointer pattern** (see the `cw-jobheader-subtype-link-pattern` memory). `P9_ParentTemplateID` is a real column but was confirmed blank/unused — don't use it.
- **`P9_FH_ProcessHeader` is blank** on a template-definition row (correct — no job instance exists yet; this column is only populated once a real job actually fires the trigger, per the earlier-confirmed job-instance chain `ProcessTaskTemplate <- ProcessHeader <- ProcessTasks`).
- **The firing event** is in `P9_SE_NKMilestoneEvent` (or `P9_SE_NKTaskCompletionEvent`/`P9_SE_NKExceptionEvent` for other trigger styles) — e.g. `BKC` (Booking Confirmation document upload), matching the real reference example exactly.
- **`P9_TriggerCondition`** holds a short type code (e.g. `UDF` = User-Defined Formula), not the literal expression text — the actual condition formula is likely stored in a `varbinary` column, not plainly readable via a simple `SELECT`.
- **`P9_TriggerField`** may be blank if the condition relies purely on the milestone/event association rather than an additional field-level check — not necessarily a problem.

## ⚠️ Correction (2026-08-30): Controlling Customer/Consignor/Consignee are NOT columns on `JobShipment`

Confirmed via full column discovery: `JobShipment` has no `ControllingCustomer`/`Consignor`/`Consignee` columns — only fixed roles (`JS_OH_HandledOnBehalfOfForwarder`, `JS_OH_TranshipAgent`, `JS_OH_DeliveryAgent`, `JS_OH_ExportBroker`, `JS_OH_ImportBroker`, `JS_OH_Creditor`). These specific roles are resolved through a **dedicated CW-maintained view: `cvw_JobShipmentOrgs`**, keyed by `JS_PK`, with columns `ControllingCustomer_Code`/`FullName`/`PK`, `ControllingAgent_Code`/`FullName`/`PK`, `JS_E2_OA_OH_NKConsignor`/`ConsignorFullName`, `JS_E2_OA_OH_NKConsignee`/`ConsigneeFullName`, plus Booking Party and Notify Party 1-3. **Use this view, not manual `OA_`/`OH_` joins, whenever a job's org-role assignments need checking** — see `docs/discovery/test-shipment-verify.sql` for the full pattern.

## Other confirmed facts

- **"EAM"** = **eAdaptor Outbound Messages** service task — processes/queues/transmits/retries/logs outbound EDI messages, maintains order, supports parallel processing for throughput. Failures trigger an automated email notification.
- **Malformed/invalid XML** → `HTTP 400 Bad Request`, logged in the EDI Message Processing Log (Notes) and service task log files — not treated as a successful delivery.
- **Universal Shipment (XUS)** fires once on a triggering document upload event; **Universal Event (XUE)** fires repeatedly afterward as milestone dates become available — matches the Developer's Guide's `XUS`/`XUE` description exactly.

## ⚠️ Still-unresolved tension on Basic Auth availability

Both this source document and `docs/discovery/edi-client-setup-guide-summary.md` state **"Basic Authentication (self-hosted endpoints only)"** — yet this environment's real UAT config demonstrably uses `BAU` (Basic Auth) on multiple active outbound `EDI Client`s (Sage, Kestrel, SAPI, VNPT, BravoTrans, Boomi), in an environment that otherwise looks WiseCloud-hosted (Cloudflare-fronted `wisegrid.net`). Two official-ish sources agreeing doesn't resolve this — worth asking whoever administers this CW instance directly whether it's genuinely self-hosted, a hybrid arrangement, or whether the "self-hosted only" restriction is specifically outbound-exempt in practice (matching the Developer's Guide's more precise "WiseCloud **inbound** mandates certificate" phrasing). Don't take either doc's blanket statement at face value over the empirical DB evidence.

## Current test case status (2026-08-30, updated) — "Full Integration" end-to-end

| Piece | Value | Status |
|---|---|---|
| Test Organization | `FULTESVIC` / "FULL TESTING VIETNAM COMPANY" | ✅ Created, active, valid |
| EDI Client | "Full Integration" | ✅ Outbound active, `BAU`, endpoint = ngrok tunnel |
| Org → EDI Client routing | `EDICommunicationsMode`: Module `SHP`, `TRX`/`EDP`, Purpose `FTI` → "Full Integration" | ✅ Confirmed via `edi-full-configuration-finder.sql` |
| Workflow trigger | `ProcessTasks` row, `P9_Type='TRG'`, Description "Full Integration Testing", `P9_SE_NKMilestoneEvent='BKC'`/`'EDT'` (changed during testing), linked to global `H56, SHP, global, system` template via `P9_ParentID`+`P9_ParentTableCode='P0'` | ✅ Confirmed saved correctly; condition columns match the working "EDI" trigger byte-for-byte except event code |
| Completion Trigger Action | Action `XUS`, Purpose `FTI`, Recipient `CNE` | ✅ Purpose confirmed matching routing config; Recipient role (`CNE`=Consignee) should resolve correctly on this job — but actual send still unconfirmed. See `docs/discovery/completion-trigger-action-code-dictionary.md` |
| ⚠️ Open blocker | Working trigger uses Recipient `OTH` ("Other") instead of `CNE` — selecting `OTH` on the custom trigger throws a save-blocking validation error | Not yet reproducible; likely needs a companion field (e.g. `Recipient Organisation`) populated first |
| Test jobs | `S00075824` (original), `S00075831`, `S00075832` (both created 2026-08-30) | ✅ All three now have real `JobHeader`/job numbers — see `docs/discovery/jobheader-creation-mechanism.md` (JobHeader is created on first Billing edit, not at shipment creation — this was misdiagnosed as a replication stall for most of the day, now closed) |
| Org roles | `FULTESVIC` confirmed as **Consignor and Consignee** on `S00075824` via `cvw_JobShipmentOrgs`; `ControllingCustomer_Code` still blank | Not yet re-checked on `S00075831`/`S00075832` |
| Ruled out (dead end) | `ProcessJobTriggerLink`/`ProcessTemplateTrigger` (the `ShipmentForm > Workflow > Triggers > Countdown` UI) | ❌ Confirmed unrelated — only 3 fixed, built-in system triggers exist there (`Job Open`, `Billing Job Edit`, `Add`); the custom trigger doesn't and can't appear in this table at all |
| Mock receiver | `ngrok-mock-listener.ps1` v1.4 + `ngrok http 8080 --host-header=rewrite` | ✅ Confirmed reachable and working, Basic Auth validation enabled |

**Next action**: resolve the `OTH` save-validation error (try populating `Recipient Organisation` first), or alternatively just test with `CNE` as-is since it should theoretically resolve correctly — then upload a `BKC`/`EDT`-type document or trigger the matching event on one of the now-billable test jobs and watch the three verification layers (ngrok inspector, mock listener console, `edi-client-verify.sql` Step 2).

## Related files

- `docs/discovery/edi-client-setup-guide-summary.md` — the EDI Client creation guide this completes.
- `docs/discovery/edi-client-verify.sql` — verification queries for the EDI Client config.
- `docs/discovery/edi-full-configuration-finder.sql` — full Org→EDI Client routing chain, plus the `ProcessTasks`/`ProcessTemplateTrigger` correction and FK discovery for the "Completion Trigger Action" table (not yet found).
- `docs/discovery/test-shipment-verify.sql` — job verification pattern, including the `cvw_JobShipmentOrgs` discovery.
- `docs/discovery/ngrok-integration-testing-guide.md`, `docs/discovery/ngrok-mock-listener.ps1` — the mock receiver this test case sends to.
- `docs/discovery/workflow-audit-checklist.md` — the BravoTran `EDICommunicationsMode` routing finding this confirms the UI mechanism for.
- `docs/discovery/completion-trigger-action-code-dictionary.md` — the growing Action/Purpose/Recipient code reference, including the `OTH` save-error blocker.
- `docs/discovery/jobheader-creation-mechanism.md` — why `S00075831`/`S00075832` had no job number for most of the day (Billing-edit-triggered, not a replication issue).
- `docs/discovery/edi-trigger-flow-mechanism-reference.md` — the full 9-stage pipeline doc, including the `ProcessTemplateTrigger` dead end ruled out today.
