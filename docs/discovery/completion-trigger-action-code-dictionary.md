# Completion Trigger Action — Code Dictionary

Growing reference for the short codes used on a Workflow Trigger's **Completion Trigger Action** block (`Action` / `Purpose` / `Recipient` / `Recipient Organisation` / `Alternate Recipient`), built up empirically as codes are observed in the CW UI. The backing DB table for this whole block is still not located (see `docs/discovery/edi-trigger-flow-mechanism-reference.md` Stage 6) — until it is, this dictionary is UI-observation-only, not DB-confirmed.

**Purpose of this doc**: avoid re-guessing what a code means every time it comes up (a repeated failure mode this session — e.g. wrongly assuming `ProcessTemplateTrigger` was the Triggers-tab table). Each entry should be filled in only once actually confirmed, not guessed.

## ⚠️ Naming collision — `EAN` means two different things in two different fields

**Confirmed 2026-08-30**: `EAN` shows up in two completely unrelated CW fields with different meanings, and it's easy to conflate them mid-troubleshooting:

1. **`EAN` as Connection Type** — on `EDI Client Details` (`Maintain > EDI Messaging > EDI Client Details`), `Connection Type = EAN` is the fixed system code meaning **"eAdaptor Next"** (as opposed to the legacy connection type). This is a system-level classification of the EDI Client itself.
2. **`EAN` as Purpose Code** — on the working "EDI" trigger's Completion Trigger Action `Purpose` field (see table below), `EAN` is a **user-customized Purpose Code value**, unrelated in meaning to "eAdaptor Next" — it just happens to share the same 3 letters. This one matches against `EK_MessagePurpose` on an Org's `EDICommunicationsMode` routing row, same mechanism as `FTI` on the custom trigger.

**Don't assume a shared code value across different fields means a shared meaning** — confirm which field/table each `EAN` belongs to before drawing conclusions. This is the same discipline as the `ProcessTasks` vs `ProcessTemplateTrigger` naming trap earlier in the session, just at the value level instead of the table-name level.

## System vs. Custom — status: unconfirmed

**Open question, not yet answered**: are these dropdown values a fixed, WiseTech-shipped code set (not modifiable by us), or a per-instance reference/lookup table that could have custom values added (e.g. via a Registry maintenance screen)? Not yet checked. Once the real backing table for Completion Trigger Action is found (Stage 6), check whether it has its own DB-level lookup table (a `Ref...` table is CW's usual pattern for this) or whether the values are hardcoded in application code. Until then, treat every code below as **status: unconfirmed** for editability.

## Action

| Code | Meaning | System/Custom | Evidence |
|---|---|---|---|
| `XUS` | Universal Shipment message — fires once on the triggering event | Unconfirmed | Seen on both the working "EDI" trigger and the custom "Full Integration Testing" trigger; matches the Developer's Guide's `XUS` description (`docs/discovery/edi-organization-routing-and-trigger-guide.md`) |
| `XUE` | Universal Event message — fires repeatedly as milestone dates become available | Unconfirmed | Referenced in the Developer's Guide and the real Syngenta reference doc; not directly observed on either trigger checked so far |

## Purpose

| Code | Meaning | System/Custom | Evidence |
|---|---|---|---|
| `EAN` | Purpose code used by the working "EDI" trigger | Unconfirmed | Observed 2026-08-30. Meaning of the code itself not yet decoded (possibly an abbreviation tied to the specific working integration/partner). **⚠️ Not the same thing as `Connection Type = EAN` ("eAdaptor Next") on EDI Client Details — see collision note above** |
| `FTI` | Purpose code used by the custom "Full Integration Testing" trigger | Unconfirmed | Observed 2026-08-30. **Correctly matches** the Purpose Code configured on `FULTESVIC`'s `EDICommunicationsMode` routing row (`docs/discovery/edi-full-configuration-finder.sql` result) — this part of the config is confirmed consistent, not a mismatch |

## Recipient

| Code | Meaning | System/Custom | Evidence |
|---|---|---|---|
| `CNE` | Consignee (role-based recipient — resolves to whichever Org is the job's Consignee) | Unconfirmed | Used on the custom "Full Integration Testing" trigger. `FULTESVIC` is confirmed as Consignee on `S00075824` via `cvw_JobShipmentOrgs`, so this *should* resolve correctly on this test job |
| `OTH` | "Other" | Unconfirmed | Used on the working "EDI" trigger. **⚠️ Confirmed 2026-08-30: selecting this value in the UI on the custom trigger throws a validation error and blocks saving.** The working trigger already has it saved — likely either (a) set via a path that bypasses this UI validation (import, API, or an older CW version), or (b) requires a companion field (e.g. `Recipient Organisation` populated) that wasn't set when testing. Not yet resolved — see Open Gap below. |

## Open gap (2026-08-30)

**`OTH` cannot currently be selected/saved via the standard trigger-edit UI** — it throws an error. This means the "just copy the working trigger's exact Recipient value" approach isn't directly reproducible right now. Two directions to try next:
1. Check whether `Recipient Organisation` needs to be populated *before* `OTH` becomes a valid, savable combination (i.e. `OTH` might mean "explicit org below," and CW validates that a value is present there).
2. Capture the exact validation error text — it may name the missing/invalid field directly rather than requiring more guessing.

## Related files

- `docs/discovery/edi-trigger-flow-mechanism-reference.md` — Stage 6, the broader "Completion Trigger Action not located" gap this dictionary supports.
- `docs/discovery/edi-organization-routing-and-trigger-guide.md` — "Current test case status" table, kept in sync with this dictionary's findings.
- `docs/discovery/test-shipment-verify.sql` — the `cvw_JobShipmentOrgs` query confirming `FULTESVIC`'s Consignee/Consignor roles.
