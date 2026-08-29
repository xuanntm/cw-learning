# CW ↔ Boomi Integration Options — Comparison

Diagram source: `docs/integration-design/diagrams/CW_Boomi_Integration_Patterns.puml` (6 patterns, one `@startuml` block each — export individually to `docs/integration-design/exports/` via the VS Code PlantUML extension, e.g. right-click → "Export Current Diagram").

This is general architecture reference material (not tied to a specific confirmed integration in this environment) — written to fill the gap identified in `CW Technical Discovery Roadmap.md` Week 3 Day 11 ("Middleware Design" / "Integration Option Comparison" deliverable), since no Boomi-specific discovery has happened here yet. Treat trade-offs as a starting framework to validate once you have real Boomi access, not confirmed findings.

## The 6 ways

| # | Pattern | What Boomi does | Transport |
|---|---|---|---|
| A | Direct point-to-point (no Boomi) | Nothing — not used | CW eAdaptor Next HTTP ↔ Client, directly |
| B | Pass-through relay | Protocol/transport bridging only, no logic | eAdaptor Next HTTP → Boomi → Client (any protocol) |
| C | Transformation / mapping layer | Field mapping + format conversion (XML↔JSON/EDI/flat file) | eAdaptor Next HTTP → Boomi → Client |
| D | Orchestration hub | Business rules, multi-system fan-out, retries, monitoring | eAdaptor Next HTTP → Boomi → N downstream systems |
| E | File / poll-based exchange | Picks up files on a schedule, processes, delivers | CW writes to SFTP/AS2 → Boomi polls → Client |
| F | Direct DB read | Reads CW's Reporting DB directly — bypasses eAdaptor entirely | Scheduled SQL query → Client/BI tool |

## Trade-offs

### A — Direct point-to-point (no Boomi)

| | |
|---|---|
| **Pros** | Fewest moving parts; no middleware cost/licensing; lowest latency; nothing extra to monitor or fail |
| **Cons** | Client must consume CW's native XML dialect as-is — every new client re-implements mapping/parsing; no central place to add retries, transformation, or fan-out later; CW-side changes can break clients directly |
| **When it fits** | A single, technically capable client willing to consume CW's schema natively, and no plan to add more integrations later |

### B — Pass-through relay

| | |
|---|---|
| **Pros** | Cheap to build; decouples transport/protocol (e.g. CW only speaks HTTPS, client only accepts SFTP) without touching payload logic; easy to reason about and debug (payload identical on both sides) |
| **Cons** | Doesn't solve schema mismatch — client still needs to understand CW's XML; provides false sense of "integration" when the hard part (mapping) is untouched |
| **When it fits** | Protocol mismatch is the *only* problem — client is fine with CW's schema, just can't reach the same endpoint type CW exposes |

### C — Transformation / mapping layer

| | |
|---|---|
| **Pros** | CW and client schemas stay fully independent — client gets its preferred format; centralizes mapping logic in one auditable place instead of duplicated per-client code; most reusable across multiple clients if mappings are parameterized |
| **Cons** | Mapping logic itself becomes a maintenance burden — every CW field change or new client format needs a Boomi process update; adds a real point of failure and a hop of latency; requires someone who understands both CW's schema and the client's |
| **When it fits** | The common case for external client integrations — this is likely the default pattern for most CW↔Boomi setups in practice |

### D — Orchestration hub

| | |
|---|---|
| **Pros** | One CW event can drive many downstream effects (client notification + ERP sync + WMS update) from a single trigger; centralized retry policy and monitoring instead of ad-hoc per-integration handling; business rules live outside CW (easier to change without a CW config/deployment) |
| **Cons** | Highest complexity and cost — becomes a second system of record for process *state*, which itself needs governance; a Boomi outage or bug can now affect multiple downstream systems at once (blast radius); harder to trace an issue back to root cause across more hops; risk of business logic silently drifting out of sync with what CW's own Workflow Templates assume happens (worth cross-checking against `docs/discovery/workflow-audit-checklist.md` if this pattern is ever adopted, so CW-side triggers and Boomi-side orchestration don't duplicate or contradict each other) |
| **When it fits** | Multiple downstream systems genuinely need to react to the same CW event, and centralized retry/monitoring is worth the added architectural weight |

### E — File / poll-based exchange

| | |
|---|---|
| **Pros** | Fully decoupled — CW and Boomi never need to be online simultaneously; simple, well-understood pattern for legacy EDI partners who only support SFTP/AS2; naturally batches, which suits high-volume low-urgency data |
| **Cons** | Not real-time — latency bounded by poll interval, not event time; file-drop location becomes a shared piece of infrastructure needing its own access control; failure detection is weaker (a missed/malformed file is quieter than a rejected HTTP call) unless explicitly monitored |
| **When it fits** | Legacy client/carrier systems that only speak file-based EDI, or genuinely batch-oriented data (e.g. nightly reconciliation) where real-time delivery isn't needed |

### F — Direct database read

| | |
|---|---|
| **Pros** | Zero eAdaptor development — any tool that speaks SQL can consume it immediately; no schema/XML mapping needed for read-heavy/reporting use cases; this is exactly the pattern already proven working in this session (`docs/discovery/jobheader-table-reference.md`'s tuned export query) |
| **Cons** | **Not a transactional integration** — no business-event trigger (only "what does the table look like right now"), no schema validation, no message log/retry/audit trail that eAdaptor provides; couples the client tightly to CW's internal physical schema (which can change between CW versions without notice, unlike the stable eAdaptor XML contract); read-only by necessity — this pattern must never be used to write back into CW |
| **When it fits** | Reporting/BI/analytics use cases only — exactly what this repo's PROD DB discovery work has been used for so far. Wrong choice for anything that needs to react to individual business events or write data back |

## Cross-cutting comparison

| Concern | A Direct | B Pass-through | C Transform | D Orchestration | E File/Poll | F Direct DB |
|---|---|---|---|---|---|---|
| Build effort | Lowest | Low | Medium | Highest | Low–Medium | Lowest |
| Latency | Lowest | Low | Low–Medium | Medium | Poll-interval bound | N/A (pull) |
| Schema decoupling | None | None | Full | Full | Full (format-dependent) | None (tight) |
| Multi-system fan-out | No | No | No (1:1) | Yes | No (1:1) | N/A |
| Retry/monitoring built in | No (CW's own eAdaptor logs only) | No | Depends on build | Yes, by design | Depends on build | No |
| Suitable for real-time events | Yes | Yes | Yes | Yes | No | No |
| Suitable for writes back to CW | Via eAdaptor inbound | Via eAdaptor inbound | Via eAdaptor inbound | Via eAdaptor inbound | Via eAdaptor inbound (batched) | **Never** |

## Open questions to validate once Boomi access exists

1. Which of these patterns is actually in use today for the client(s) `docs/discovery/integration-owner-map.md` should eventually document?
2. Is the current eAdaptor inbound 401 blocker (`docs/backlog/eadaptor-inbound-auth-401.md`) sitting in front of a Pattern C or D setup, or something simpler?
3. For any Pattern D (orchestration) found in practice: does its business logic overlap with any CW Workflow Template trigger already documented in `docs/discovery/workflow-audit-checklist.md`? Overlapping logic in two places is a drift risk.

## Related files

- `docs/integration-design/diagrams/CW_Boomi_Integration_Patterns.puml` — the 6 diagrams this doc explains.
- `docs/integration-design/diagrams/eAdaptor_Inbound_Outbound_Mechanism.puml` — detail view of the eAdaptor Next inbound/outbound flow that Patterns A–E all sit on top of.
- `docs/backlog/eadaptor-inbound-auth-401.md` — real inbound auth blocker, relevant once a specific pattern is confirmed in use.
- `docs/discovery/workflow-audit-checklist.md` — CW-side workflow trigger findings, relevant to Pattern D's overlap risk.
- `docs/discovery/jobheader-table-reference.md` — the working example of Pattern F already in use in this repo, for reporting purposes only.
