# Backlog: eAdaptor Next inbound auth returns 401 after password reset

## Status
[!] Blocked / Need IT Support

## Environment
- Environment: UAT/TRN (H56TRN)
- Interchange / inbound username: `HONEASHKG`
- Inbound endpoint under test: `https://H56TRNservices.wisegrid.net/eAdaptorNext`
- Tested from: local dev sandbox (non-whitelisted IP), CW VM `10.10.11.4` (whitelisted), and server1 (private, `20.247.185.174`) via `docs/discovery/eadaptor-http-check.ps1` (2026-08-29) — **3 independent sources, identical `401`**

## Problem
`POST /eAdaptorNext` with Basic Auth returns `401 Unauthorized`, both before and after resetting the password on the eAdaptor Next inbound config screen (Registry → EDI Messaging → eAdaptor Next → Inbound). Username is unchanged; the password reset was confirmed saved in the CW UI.

## Ruled out so far
- **Network / IP whitelist** — request reaches the app cleanly from both a non-whitelisted IP and the whitelisted VM; identical `401` from both, and `GET` on the host root returns `200` with real app content. Not a network-level block. **Reinforced 2026-08-29:** a 3rd independent server (private, different public IP, reached via Cloudflare CDN — `au-1-t.eadaptor.wisegrid.net.cdn.cloudflare.net`) reproduces the exact same `401`. Three different source IPs, three identical results — this is very unlikely to be network/whitelist-related at this point.
- **Wrong endpoint path** — the bare host root explicitly returns `405 Method Not Allowed` (`Allow: GET`), confirming it's just a landing page, not the inbound submission endpoint. `/eAdaptorNext` is the correct path — it's the one that runs an auth check at all.
- **Wrong username** — decoded directly from the Basic Auth header configured in CW; confirmed `HONEASHKG`, unchanged after the reset.
- **Malformed request** — an initial `411 Length Required` (missing `Content-Length` on an empty POST) was resolved by sending an explicit empty body; the `401` shown above is from a well-formed request that reached the real auth check.
- **Propagation delay** — retested a few minutes after the reset with the same result.

## Resolved mechanism (2026-08-29, from PROD DB schema discovery) — structural answer to question 1

Full chain confirmed via `EDIInterchange`/`EDIMessage` FK discovery (`tmp/EDI_constraints_202608291119.csv`) plus direct column discovery of the `EDICommunication*` table family (`tmp/EDI_communication_v2_202608291126.csv`):

```
EDICommunicationPartyConfig (ECC)  -- one row per configured endpoint
  ECC_Endpoint          -- the actual URL (e.g. https://.../api/EadaptorNext/<Name>)
  ECC_Direction         -- IN / OUT
  ECC_ECA_Auth   ------> EDICommunicationAuth (ECA)  -- the real credential record
                            ECA_AuthorizationMode
                            ECA_Username / ECA_Password        <- Basic Auth
                            ECA_ClientID / ECA_ClientSecret     <- OAuth2
                            ECA_Certificate / ECA_EncodedPrivateKey <- cert/mTLS
  ECC_ECP_Party  ------> EDICommunicationParty (ECP)  -- the trading-partner record
```

**So `/eAdaptorNext`'s Basic Auth reads `EDICommunicationAuth.ECA_Username`/`ECA_Password`, reached via `EDICommunicationPartyConfig.ECC_ECA_Auth` — not `GlbExternalPassword`** (that earlier theory, based on `EI_GP`/`EM_GP`, turned out to point somewhere else — possibly the separate legacy `EDICommunicationsMode`/`EK_` transport table, unconfirmed).

**Caveat — this is a PROD schema discovery, not a UAT/HONEASHKG-specific confirmation.** `HONEASHKG` is a UAT-only interchange; the PROD query correctly found no match for it. The table structure/mechanism is the same app, so it should transfer, but the actual root cause (which `ECC`/`ECA` record `HONEASHKG` resolves to, and whether the password reset touched a different record than the live auth check reads) still needs verifying directly against UAT once reachable, or by asking the team to check it server-side.

**Do not query or record actual values of `ECA_Password`, `ECA_ClientSecret`, `ECA_Certificate`, or `ECA_EncodedPrivateKey`** in any tracked file — structure/relationships only.

## Still unknown — needs team input
1. ~~Does `/eAdaptorNext`'s Basic Auth actually read from this interchange config's password field, or from a separately linked CW user/login record?~~ **Resolved structurally above** — reads `EDICommunicationAuth.ECA_Username`/`ECA_Password` via `ECC_ECA_Auth`. Still needs live verification against the actual `HONEASHKG` record in UAT.
2. Are there multiple inbound config records for this interchange (per Application Code / Message Type / Sub Type — see `docs_for_thanh/foundations/05_EDI_menu_note.txt`), and is `/eAdaptorNext` bound to a different record than the one that was edited?
3. Any known caching/propagation delay for credential changes on this service host longer than a few minutes?

## DB-side diagnosis exhausted (2026-08-29)

Checked whether the rejected `401` attempt left any trace in `EDIMessage` (query in `docs/discovery/eadaptor-http-check.ps1` Section 3, run against UAT for the exact test window) — **zero rows returned.** The auth check rejects before any message row is created, i.e. it happens at the authentication/gateway layer, ahead of message ingestion. There is no further self-service DB angle left to check — the mechanism (`ECC`→`ECA`), credential structure, and reachability (now 3 independent source servers, all identical `401`) are all confirmed; what remains needs either server-side auth/middleware logs or direct team confirmation of which `ECC`/`ECA` record `HONEASHKG` actually resolves to.

## Requested action
Confirm which config object the `/eAdaptorNext` Basic Auth check actually authenticates against, and help verify/reset the credential at the correct source. **This now needs the team/IT directly — no further progress is possible from this side without server-side visibility.**

## Reproduction
```
curl --location --request POST 'https://H56TRNservices.wisegrid.net/eAdaptorNext' \
  --header 'Accept: application/xml' \
  --header 'Authorization: Basic <base64 of username:password>' \
  --data '' -vvv
```
Expect `401 Unauthorized` with `www-authenticate: Basic` if still failing.

Raw request/response captures (including live tokens/cookies) are kept locally and are **not** committed — `tmp/work_history.log` and `tmp/2026_08_23_eadaptor_checking.log`. Share those directly with the team rather than via this file.

## Date opened
2026-08-23
