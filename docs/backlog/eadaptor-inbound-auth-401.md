# Backlog: eAdaptor Next inbound auth returns 401 after password reset

## Status
[x] Resolved (2026-08-29) — root cause found: wrong endpoint was being tested

## ✅ Root cause (2026-08-29)

**`HONEASHKG` belongs to the OLD/legacy eAdaptor implementation, not eAdaptor Next.** Two separate endpoints exist:

| Endpoint | Implementation | Config mechanism |
|---|---|---|
| `https://H56TRNservices.wisegrid.net/eAdaptorNext` | Modern ("Next") | Per-client `EDICommunicationParty`/`EDICommunicationPartyConfig`/`EDICommunicationAuth` — see `docs/discovery/edi-communication-mechanism-reference.md`. Named partners: Boomi, Kestrel, Sage, SAPI, VNPT, BravoTrans, etc. |
| `https://h56trnservices.wisegrid.net/eadaptor` | Legacy (old) | Different mechanism (exact table still unconfirmed — likely `GlbExternalPassword` or a legacy interchange-code scheme). Traditional interchange-style codes like `HONEASHKG`. |

**`HONEASHKG` authenticates successfully against the legacy `/eadaptor` endpoint.** That fully explains everything found this session: `HONEASHKG` was never in `EDICommunicationAuth`/`EDICommunicationPartyConfig`/`EDICommunicationParty` (checked exhaustively — full inventory, CDC change history attempted) because it was never part of that system at all. The password reset done via "Registry → EDI Messaging → eAdaptor Next → Inbound" was editing a **new-implementation** record unrelated to `HONEASHKG`'s actual (legacy) credential store — which is why the reset never changed the `401` result against `/eAdaptorNext`: that was always testing the wrong system for this interchange.

**Confirmed via `eadaptor-http-check.ps1 -EAdaptorPath "/eadaptor"` (2026-08-29):** `POST /eadaptor` with the `HONEASHKG` credential returns **`400 Bad Request`, not `401 Unauthorized`.** `400` means the request passed authentication and failed only on content (an intentionally empty test body, which the legacy endpoint validates — unlike `/eAdaptorNext`, which rejected the same empty body at the auth stage before even reaching content validation). This is direct, positive confirmation that the credential is valid and the legacy endpoint accepts it — the ticket's original symptom is fully explained and resolved, not just theorized.

**Everything below this point is the investigation trail that led here — kept for reference, not because the mystery is still open.**

## Environment
- Environment: UAT/TRN (H56TRN)
- Interchange / inbound username: `HONEASHKG`
- **Legacy endpoint (confirmed working with `HONEASHKG`):** `https://h56trnservices.wisegrid.net/eadaptor`
- Modern endpoint under test throughout this investigation (wrong one for this interchange): `https://H56TRNservices.wisegrid.net/eAdaptorNext`
- Tested from: local dev sandbox (non-whitelisted IP), CW VM `10.10.11.4` (whitelisted), and server1 (private, `20.247.185.174`) via `docs/discovery/eadaptor-http-check.ps1` (2026-08-29) — **3 independent sources, identical `401` against `/eAdaptorNext`**

## Problem (as originally reported — explained above)
`POST /eAdaptorNext` with Basic Auth returns `401 Unauthorized`, both before and after resetting the password on the eAdaptor Next inbound config screen (Registry → EDI Messaging → eAdaptor Next → Inbound). Username is unchanged; the password reset was confirmed saved in the CW UI. **Explained**: the reset was correctly saved, just on a record unrelated to `HONEASHKG` (see Root cause above).

## Ruled out so far
- **Network / IP whitelist** — request reaches the app cleanly from both a non-whitelisted IP and the whitelisted VM; identical `401` from both, and `GET` on the host root returns `200` with real app content. Not a network-level block. **Reinforced 2026-08-29:** a 3rd independent server (private, different public IP, reached via Cloudflare CDN — `au-1-t.eadaptor.wisegrid.net.cdn.cloudflare.net`) reproduces the exact same `401`. Three different source IPs, three identical results — this is very unlikely to be network/whitelist-related at this point.
- **Wrong endpoint path** — the bare host root explicitly returns `405 Method Not Allowed` (`Allow: GET`), confirming it's just a landing page, not the inbound submission endpoint. `/eAdaptorNext` is the correct path — it's the one that runs an auth check at all.
- **Wrong username** — decoded directly from the Basic Auth header configured in CW; confirmed `HONEASHKG`, unchanged after the reset.
- **Malformed request** — an initial `411 Length Required` (missing `Content-Length` on an empty POST) was resolved by sending an explicit empty body; the `401` shown above is from a well-formed request that reached the real auth check.
- **Propagation delay** — retested a few minutes after the reset with the same result.

## ⚠️ Correction (2026-08-29): the "resolved mechanism" below does NOT hold for HONEASHKG — retracted

Ran the full unconditioned `ECC`/`ECA`/`ECP` inventory against **UAT directly** (`tmp/EDI_communiction_Config_202608291648.csv`, 15 parties, 29 rows). Two things disprove the theory below:

1. **`HONEASHKG` does not appear anywhere in this table** — not as `ECA_Username`, not as `ECP_Name`. It is not one of the 15 configured parties.
2. **Every single `IN`-direction row across all 15 parties has a blank `ECA_Username`** — not a HONEASHKG-specific gap. Every populated username (`cwtestapi@...`, `cargowiseboomitest@...`, `kestrel_user`, `bravotrans_user`, etc.) belongs to an `OUT`-direction row. This is a structural pattern: **`ECA_Username`/`ECA_Password` on this table authenticates CW *to* the third party for outbound sends — it does not appear to be where per-partner inbound credentials (third party authenticating *into* CW) are stored.**

So the mechanism described below is real and correct for outbound auth, but it is very likely **not** what `/eAdaptorNext`'s inbound Basic Auth check actually reads. Reviving the earlier `GlbExternalPassword` lead (`EI_GP`/`EM_GP`), which was set aside prematurely — next queries to run (identifying columns only, never the password value itself):

```sql
SELECT GP_PK, GP_UserID, GP_MailBoxID, GP_Name, GP_PasswordType, GP_PasswordStatus, GP_SystemLastEditTimeUtc, GP_SystemLastEditUser
FROM GlbExternalPassword
WHERE GP_UserID = 'HONEASHKG' OR GP_Name LIKE '%HONEASHKG%' OR GP_MailBoxID LIKE '%HONEASHKG%';

SELECT TOP 20 EI_PK, EI_ApplicationCode, EI_InterchangeType, EI_From, EI_To, EI_GP, EI_ECC_CommunicationPartyConfig, EI_SystemCreateTimeUtc
FROM EDIInterchange
WHERE EI_From = 'HONEASHKG' OR EI_To = 'HONEASHKG'
ORDER BY EI_SystemCreateTimeUtc DESC;
```

## Mechanism confirmed for OUTBOUND auth (2026-08-29, from PROD DB schema discovery) — kept for reference, does not answer question 1

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

Confirmed real and correctly structured — but per the correction above, this appears to be the **outbound** auth mechanism (CW → third party), not inbound (third party → CW). Do not treat this as the answer to "what does `/eAdaptorNext` check" without further evidence.

**Do not query or record actual values of `ECA_Password`, `ECA_ClientSecret`, `ECA_Certificate`, `ECA_EncodedPrivateKey`, `GP_CurrentPassword`, or `GP_NextPassword`** in any tracked file — structure/identifying columns only.

## Formerly "still unknown" — now answered

1. ~~Does `/eAdaptorNext`'s Basic Auth actually read from `GlbExternalPassword`, a per-interchange-code table not yet found, or a separately linked CW user/login record?~~ **Answered**: it doesn't matter for `HONEASHKG` — that interchange isn't on `/eAdaptorNext` at all, it's on the legacy `/eadaptor` endpoint. Which exact table backs the *legacy* endpoint's auth is still technically unconfirmed, but no longer blocking — the credential works.
2. ~~Are there multiple inbound config records for this interchange, and is `/eAdaptorNext` bound to a different record than the one that was edited?~~ **Answered**: yes, in effect — `/eAdaptorNext` isn't bound to `HONEASHKG` at all; the record that was edited belongs to a different implementation entirely.
3. Propagation delay — moot, not a real factor once the endpoint mismatch is understood.

## DB investigation trail (kept for reference — no longer blocking)

This all happened before the endpoint mismatch was discovered. Preserved because the mechanism findings themselves (outbound auth structure, CDC tracking, permission boundaries) remain accurate and reusable for other EDI work, even though they didn't apply to this specific ticket.

Checked whether the rejected `401` attempt left any trace in `EDIMessage` (query in `docs/discovery/eadaptor-http-check.ps1` Section 3, run against UAT for the exact test window) — **zero rows returned.** Consistent with the root cause: `/eAdaptorNext` rejects `HONEASHKG` before message ingestion because that interchange isn't configured there at all.

**Live config tables**: ran the full unconditioned `ECC`/`ECA`/`ECP` inventory, plus targeted searches on `GlbExternalPassword` and `EDIInterchange` — `HONEASHKG` does not appear in any of them. Now explained: none of these tables need to contain it, since it belongs to the legacy implementation.

**CDC audit trail** (`docs/discovery/audit-log-discovery.sql`): confirmed `EDICommunicationAuth`, `EDICommunicationPartyConfig`, and `GlbExternalPassword` are all CDC-tracked. `SELECT` on the `cdc` schema was denied for the current UAT login (`cwRestrictedReaderRole`) — expected/correct access control, not pursued further since it's no longer needed.

## Follow-up (optional, separate from this ticket): migrating `HONEASHKG` to eAdaptor Next

Not a bug fix — a possible future task if there's a reason to move this interchange onto the modern implementation. Per the "New Integration Checklist" in `docs/discovery/uat-edi-configuration-collector.sql`, that would mean creating fresh `EDICommunicationParty`/`EDICommunicationAuth`/`EDICommunicationPartyConfig` records for `HONEASHKG` (the way `H56_TRN_CW2SAGE`, `H56_TRN_CW2KES`, etc. are set up), rather than trying to "fix" anything on the legacy side. Worth raising with the team only if there's an actual reason to retire the legacy `/eadaptor` endpoint.

## Requested action
None — resolved. If `HONEASHKG` needs to move to the new implementation, that's a separate, forward-looking task (see Follow-up above), not a continuation of this ticket.

## Reproduction (historical — reproduces the now-explained `401` against the wrong endpoint)
```
curl --location --request POST 'https://H56TRNservices.wisegrid.net/eAdaptorNext' \
  --header 'Accept: application/xml' \
  --header 'Authorization: Basic <base64 of username:password>' \
  --data '' -vvv
```
Expect `401 Unauthorized` with `www-authenticate: Basic` — expected/correct now, since `HONEASHKG` isn't configured on this endpoint. **For the working legacy endpoint, use `https://h56trnservices.wisegrid.net/eadaptor` instead** (same header pattern, correct path for this interchange).

Raw request/response captures (including live tokens/cookies) are kept locally and are **not** committed — `tmp/work_history.log` and `tmp/2026_08_23_eadaptor_checking.log`. Share those directly with the team rather than via this file.

## Date opened
2026-08-23

## Date resolved
2026-08-29
