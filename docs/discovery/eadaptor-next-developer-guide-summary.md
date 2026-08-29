# eAdaptor Next Developer's Guide — Summary

Source: `tmp/01_eAdaptor_Next_Developer_Guide.pdf` (WiseTech Global, v1.4, 30 March 2026) — read 2026-08-29, gitignored/not tracked (per the guide's own Terms of Use: internal development use only, not for redistribution). This doc extracts the parts directly relevant to the work already done in this repo — not a full reproduction.

## The single most important correction

**Real EDI Client configuration lives at `Maintain → EDI Messaging → EDI Client Details`** — the `Maintain` menu, not `Registry`. The `Registry → EDI Messaging → eAdaptor → Inbound → eAdaptor Service URL` field (where a password reset was performed in `docs/backlog/eadaptor-inbound-auth-401.md`'s original troubleshooting) is **explicitly documented as reference-only**: *"It does not affect eAdaptor functionality but serves as a convenient point of reference."* This explains the whole 401 investigation at a deeper level than "wrong endpoint" — the screen itself was never going to change real behavior, regardless of which endpoint was involved.

**"EDI Client"** is the UI's own name for the modern implementation's config module — matches `EDICommunicationParty`/`EDICommunicationPartyConfig`/`EDICommunicationAuth` (`docs/discovery/edi-communication-mechanism-reference.md`).

## Endpoint URL formula (confirmed, not guessed)

```
Base:  https://{Enterprise Code}{Server Code}services.wisegrid.net/
Sync:  https://{Enterprise Code}{Server Code}services.wisegrid.net/eAdaptorNext
Async: https://{Enterprise Code}{Server Code}services.wisegrid.net/eAdaptorNext/Async
```

Matches the confirmed real hostnames: `H56TRNservices.wisegrid.net` (Enterprise=`H56`, Server=`TRN`), so the **PROD equivalent is `H56PRDservices.wisegrid.net`** — following the same formula as the confirmed UAT one, though still worth a live confirmation before relying on it (per the earlier caution about the SQL DB host's hidden `.test.` naming gotcha — this formula-based prediction is much better-grounded than that guess was, but "confirmed by an official doc" and "verified live" are still two different things).

Format-specific sync endpoints (append to the base `/eAdaptorNext` sync URL):
`/Native`, `/UniversalActivity`, `/UniversalActivityRequest`, `/UniversalDocumentRequest`, `/UniversalEvent`, `/UniversalShipment`, `/UniversalShipmentRequest`, `/UniversalTransaction`, `/UniversalTransactionBatch`, `/UniversalTransactionBatchRequest`, `/UniversalInterchangeRequeueRequest`.

`/eAdaptorNext/Async` is Universal Interchange only (wraps multiple messages, processed in order); `/eAdaptorNext` (sync) is used for Interchange Requeue requests specifically.

Minimum TLS version: **1.2** (WiseCloud-hosted).

## Message formats

- **Universal XML** — cross-module, standardized. Types: `XUA` (Universal Activity — PAVE/Customer Service Tickets/Projects/Work Items), `XUE` (Universal Event — business events/milestones, uses `ContextCollection` for flexible matching), `XUS` (Universal Shipment — freight movements/consols/declarations/bookings), `XUT` (Universal Transaction — invoices/credit notes/payments/journals), `XUB` (Universal Transaction Batch). Matches the `XU*` codes already empirically confirmed in `docs/discovery/uat-edi-configuration-collector.sql` Step 4's message-type profiling.
- **Universal Request types** (query-only, no create/update): `XAR`, `XDR`, `XSR`, `XBR`.
- **Native XML** — module-specific, generated directly from CW's own DB schema, no business-layer pass-through. Used for master data/reference file publishing.

## Sync vs. Async

- **Sync**: immediate processing, no queue, response returned in the same call. Creates 2 `EDI Message` module entries (inbound request + outbound response).
- **Async**: queued (`EDI Interchange` module), processed by background service tasks — `UMI` (Universal Shipment/Event Messaging Inbound) and `NMI` (Native Messaging Inbound). Better for batch/high-volume/ordered processing.

## Authentication — a real constraint for any NEW inbound EDI Client

**"WiseCloud inbound connections now mandate certificate-based authentication."** Basic Auth remains available generally, but if this environment is WiseCloud-hosted (it appears to be, given the Cloudflare-fronted `wisegrid.net` setup already confirmed), **a new inbound EDI Client likely cannot use Basic Auth** — it needs the certificate fields already seen on `EDICommunicationAuth` (`ECA_Certificate`, `ECA_EncodedPrivateKey`). Outbound connections support Basic, OAuth2, or (for some) no-auth-with-other-safeguards — matches the `BAU`/`OAU`/`NAU` modes already observed empirically in UAT's real config. **This directly affects the "create a new EDI client profile" plan from earlier** — if the new integration needs an inbound direction, budget for certificate setup, not just a username/password.

OAuth 2.0 flow (for outbound, or inbound if self-hosted): environment variables `OAuthClientID`, `OAuthTenantID`, `OAuthCertificatePem`, `OAuthPrivateKeyPem` → call `GetOAuthToken` request → populates `OAuthBearerToken` → used as Bearer token on subsequent requests.

## Official Postman collection exists — better than a hand-built one

WiseTech provides **official Postman collection + environment files via WiseTech Academy** (not this guide itself — a separate download), covering: `Native XMLs`, `Universal Interchange` (with/without acknowledgement), `Universal Interchange Requeue Request`, `GetOAuthToken`. **Recommend downloading and using these instead of (or alongside) the hand-built `samples/postman/eadaptor-next-*.json` created earlier this session** — the official ones will have the real, WiseTech-maintained request shapes and pre-built OAuth flow, which is more authoritative than anything built from inference here.

## Error codes (confirmed, matches everything empirically observed this session)

| Code | Meaning |
|---|---|
| 401 | Not authenticated / credential not recognized |
| 403 | Authenticated but not permitted |
| 400 | Malformed request (matches the `/eadaptor` legacy-endpoint result once auth passed) |
| 404 | Wrong URL |
| 500/502/503 | Server-side |

## Message traceability features

- Sync: request ↔ response linked via "View" button, either direction.
- Async: message ↔ its `EDI Interchange` linked directly.
- Acknowledgement: can be requested on async messages, linked back to the initiating request. Testable via a Postman mock endpoint even without a working outbound connection.
- External Reference Number: an arbitrary ID set on the request, persists into the response/EDI Message record, filterable in the `EDI Message` module — useful for correlating CW-side records with an external system's own IDs.

## Migration notes (eAdaptor → eAdaptor Next)

- Inbound: must move to OAuth (or certificate) if WiseCloud-hosted; self-hosted can keep Basic Auth but credentials move into the EDI Client module.
- Outbound: message processor must support REST/HTTP+XML instead of SOAP.
- A **Bulk Update** feature can migrate existing legacy EDI communication modes into EDI Client entries — relevant if there's ever a reason to migrate `HONEASHKG` off the legacy `/eadaptor` endpoint (see the "Follow-up" note in `docs/backlog/eadaptor-inbound-auth-401.md`).

## What this guide does NOT cover

Explicitly out of scope per its own Terms of Use / Disclaimer: actual application/interface development, code samples, library recommendations. It assumes an existing team with web service development, XML/XSD/REST, and Postman experience — WiseTech does not provide implementation support beyond this guide and directs self-implementers lacking that expertise to their integration partners.

## Related files

- `docs/backlog/eadaptor-inbound-auth-401.md` — the investigation this guide provided the final missing pieces for.
- `docs/discovery/edi-communication-mechanism-reference.md` — DB-level mechanism for the modern ("EDI Client") implementation.
- `samples/postman/eadaptor-next-collection.json`, `samples/postman/eadaptor-next-environment.json` — hand-built starting point; supersede with the official WiseTech Academy collection when available.
