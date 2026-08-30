# Backlog: JobHeader replication stalled on UAT read-only replica

## Status
[x] Closed (2026-08-30) — NOT a replication issue. Root cause confirmed:
`JobHeader` is created when Billing information is first saved on a
shipment, not at shipment creation. See `docs/discovery/
jobheader-creation-mechanism.md` for the full write-up and evidence. Do
not submit this as an IT ticket.

## ⚠️ Correction (2026-08-30)

This ticket's conclusion assumed JobShipment and JobHeader are created
together, 1:1, in the same save transaction — so a JobShipment with no
matching JobHeader row could only mean broken replication. That assumption
was never actually verified; it was inherited from earlier findings about
the polymorphic *link* mechanism (JH_ParentID/JH_ParentTableCode), which say
nothing about *when* the JobHeader row is created relative to JobShipment.

Re-reading `docs_for_thanh/foundations/02_CargoWise Quick Concept.md` and
`04_core system objects.md`: **"Job" (JobHeader) is described as a distinct
branch-execution/billing layer under Shipment/Consol** — not necessarily the
same event as saving the Shipment (One-File) record. CargoWise also has
several Shipment lifecycle states below "full Job" (Quote, Booking,
Booking-only, CFS-registered, etc.) visible directly as columns on
`JobShipment` itself: `JS_ShipmentStatus`, `JS_Phase`, `JS_IsBooking`,
`JS_IsDirectBooking`, `JS_IsForwardRegistered`, `JS_IsCFSRegistered`,
`JS_IsShipping` — none of which were inspected before writing this ticket.

**New working theory**: `S00075831`/`S00075832` may simply not have been
promoted from Booking/Quote phase to a full Job yet — a business-logic gap
in test-case setup, not a replica sync failure. `docs/discovery/
jobshipment-phase-status-diagnostic.sql` tests this directly by comparing
these lifecycle columns against the known-working `S00075824`.

**Do not submit this ticket to IT** until that diagnostic comes back
consistent with an actual stall (i.e. the lifecycle flags match
`S00075824` and there's still no JobHeader row).

## Environment
- Environment: UAT/TRN (`H56TRN.db.test.wisegrid.net` / `OdysseyH56TRN`), read-only replica endpoint `au2wtreadonly411l1.wisegrid.net`
- Table affected: `JobHeader`

## Problem
`JobHeader` on this replica has not received any new rows since **2026-08-29 16:40:00 UTC** (`JH_JobNum = S00075826`), despite it now being **2026-08-30** — over a day of missing replication. New jobs created since then are invisible via `JobHeader` no matter how they're queried.

## Evidence

Three shipments created after the stall point, tested with 3 independent query methods each (job number match, polymorphic pointer match via `JH_ParentTableCode`/`JH_ParentID`, and `JH_ParentID`-only match) — all return zero rows in `JobHeader`:

| Job | Created (JobShipment) | Creation method | Visible in `JobHeader`? |
|---|---|---|---|
| `S00075824` | before the stall | Manual/scratch | ✅ Yes |
| `S00075826` | ~16:40 UTC 2026-08-29 | — | ✅ Yes (this is the last row that synced) |
| `S00075831` | 22:41 UTC 2026-08-29 | Search + copy + save | ❌ No |
| `S00075832` | after `S00075831` | Manual/scratch | ❌ No |

**`JobShipment` is confirmed still replicating normally** — both `S00075831` and `S00075832` are fully visible there, with correct `JS_SystemCreateTimeUtc` values well after the `JobHeader` stall point. This isolates the problem specifically to `JobHeader` (or possibly a small set of tables including it), not the replica as a whole.

## Ruled out
- **Query method** — three different approaches to find the missing `JobHeader` rows (job number, full polymorphic pointer, `ParentID`-only) all consistently return nothing.
- **Creation method** — both a copy-created shipment (`S00075831`) and a from-scratch manual one (`S00075832`) are equally missing; not related to how the record was created.
- **Declared FK relationship gap** — confirmed via `sys.foreign_keys` on `JobShipment` (both outbound and inbound) that `JobHeader` genuinely has no declared FK to/from `JobShipment` at all (expected — this link is a polymorphic pointer, not a real FK, per `docs/discovery/jobheader-table-reference.md`) — so this isn't a case of missing an alternate relationship to query through instead.

## Requested action
Confirm whether replication/sync for `JobHeader` (and any related tables) on this UAT read-only replica has stalled, and restart/resync as needed.

## Related files
- `docs/discovery/jobheader-relationship-map.sql` — the FK discovery queries used to rule out a missed relationship.
- `docs/discovery/test-shipment-verify.sql` — the verification pattern that first surfaced this.
- `docs/backlog/uat-db-dns-resolution-failure.md` — a prior, similarly-resolved replica/hostname issue on the same environment, for reference on how that escalation went.

## Date opened
2026-08-30
