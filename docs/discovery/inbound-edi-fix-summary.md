# Inbound EDI (eAdaptor Next) — Fix Summary

Environment: UAT/TRN, EDI Client `Full Integration`. Consolidates the full troubleshooting path from "inbound isn't configured" to "a real API call succeeds" — three distinct problems were found and fixed along the way, each easy to misdiagnose as one of the others. Companion to `docs/discovery/inbound-edi-oauth-testing-setup.md` (setup/reference detail) and `docs/discovery/edi-communication-mechanism-reference.md` (DB mechanism).

## Goal

Get the inbound `eAdaptorNext` OAuth Client Certificate Grant flow working end-to-end for `Full Integration`, mirroring the outbound model integration already proven earlier this session (`docs/discovery/edi-trigger-flow-mechanism-reference.md`).

## What's different about inbound vs. outbound (confirmed, not assumed)

- **No ngrok needed** — inbound means *we* call *CW's* already-public endpoint (`https://H56TRNservices.wisegrid.net/eAdaptorNext`), the reverse of outbound where CW called our mock listener.
- **No Org-level routing** — confirmed via `docs/discovery/inbound-edi-config-discovery.sql`: joining every real `ECC_Direction='IN'` config against `EDICommunicationsMode` returned zero matches. Inbound identifies the sender purely through EDI Client auth + Branch/Department, not an Organization routing row.
- **WiseCloud inbound mandates certificate-based auth** — confirmed against real data: all 14 existing inbound configs use `ECA_AuthorizationMode='OAU'`, zero using Basic Auth.

## Step 1 — Certificate generation (confirmed working correctly)

- Generated a private key + CSR locally via OpenSSL (`tmp/EDI/full-integration-inbound.key`/`.csr`), respecting the CSR subject-field character restrictions from the official setup guide.
- Uploaded the CSR to `Full Integration`'s Inbound tab, clicked **Generate Certificate**.
- Downloaded the issued certificate (`tmp/EDI/DownloadCertificate.pem`) and **confirmed its public key modulus matches our private key's** (MD5 `d4b24fb2adbe1efe6ee9566c6ecbf089` on both) — proof CW signed our CSR rather than generating its own key pair, so we hold the correct matching private key.
- Checked `EDICommunicationAuth` metadata (never the credential columns themselves): the Entra ID app registration (`ECA_ClientID`, `ECA_AuthorizationEndpoint`) **already existed a day before** the certificate was generated — no separate manual Entra Portal step was needed.

## Step 2 — JWT signing failure: `"init failed: Error: not supported argument"`

First suspected a PEM format/line-ending issue (tried converting the key to PKCS#8 — turned out it was already PKCS#8, no effect). **Real root cause, found by checking the actual debug log**: the Postman environment variables `OAuthCertificatePem`/`OAuthPrivateKeyPem` had been set to the **file paths** (e.g. `C:\Users\...\DownloadCertificate.pem`) instead of the **file contents**. `jsrsasign` was trying to parse a Windows path string as PEM data.

**Fix**: opened each file directly and pasted the actual PEM text (`-----BEGIN...-----` through `-----END...-----`) into the Postman variables via the expanded multi-line editor. Login succeeded immediately after.

## Step 3 — Login succeeded, but API calls still returned `401`

A test call (`Native XML` `UNLOCO` lookup) to `https://H56TRNservices.wisegrid.net/eAdaptorNext` returned `401 Unauthorized` despite the OAuth login having worked. Inspecting the raw request showed `Authorization: Basic Og==` (base64 for `:`, i.e. empty username/password) — **the request wasn't using the bearer token at all.**

Checked the official WiseTech Postman collection file directly (`eAdaptor Next API.postman_collection.json`): confirmed **one single `auth` block at the collection level**, hardcoded to `type: basic` using `{{BasicAuthUserName}}`/`{{BasicAuthPassword}}` (both blank in the environment) — inherited by every request in the collection. Separately confirmed the `GetOAuthToken` request's post-response script correctly does `pm.environment.set("OAuthBearerToken", accessToken)`, so the token *was* being captured — it just wasn't wired into any request's Authorization.

**Fix**: edited the collection-level `auth` block from Basic (blank) to Bearer Token (`{{OAuthBearerToken}}`) — one change applies to every request in the collection, since they all inherit from it. Since editing the JSON file on disk doesn't live-update an already-imported Postman collection, the file needed **re-importing** into Postman (or the same change made manually in the Postman UI's collection-level Authorization tab).

## Result

✅ **API call succeeded.** Endpoint `https://{{EnterpriseIDXML}}{{ServerIDXML}}services.wisegrid.net/eAdaptorNext` resolving to `H56TRNservices.wisegrid.net` (confirmed formula: Enterprise=`H56`, Server=`TRN`), authenticated via the OAuth Client Certificate Grant flow, now returns real responses instead of `401`.

**One nuance still worth keeping in mind for actual message submission** (not just the query-style test used here): per the Developer's Guide, bare `/eAdaptorNext` (sync, no suffix) is specifically for Interchange Requeue requests — a real inbound message submission would use a format-specific path (e.g. `/eAdaptorNext/UniversalShipment`) or `/eAdaptorNext/Async` for a wrapped Universal Interchange.

## Related files

- `docs/discovery/inbound-edi-oauth-testing-setup.md` — file locations, environment variable mapping, JWT script detail.
- `docs/discovery/edi-communication-mechanism-reference.md` — the DB-level inbound mechanism (`ECA_`/`ECC_`), including the no-Org-routing finding and the certificate-generation confirmation.
- `docs/discovery/inbound-edi-config-discovery.sql`, `docs/discovery/inbound-certificate-generation-check.sql` — the diagnostic queries behind the findings above.
- `docs/discovery/eadaptor-next-developer-guide-summary.md` — the official OAuth flow and endpoint-path documentation this implements.
