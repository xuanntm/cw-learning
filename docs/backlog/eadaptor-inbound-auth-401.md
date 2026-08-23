# Backlog: eAdaptor Next inbound auth returns 401 after password reset

## Status
[!] Blocked / Need IT Support

## Environment
- Environment: UAT/TRN (H56TRN)
- Interchange / inbound username: `HONEASHKG`
- Inbound endpoint under test: `https://H56TRNservices.wisegrid.net/eAdaptorNext`
- Tested from: local dev sandbox (non-whitelisted IP) and CW VM `10.10.11.4` (whitelisted)

## Problem
`POST /eAdaptorNext` with Basic Auth returns `401 Unauthorized`, both before and after resetting the password on the eAdaptor Next inbound config screen (Registry → EDI Messaging → eAdaptor Next → Inbound). Username is unchanged; the password reset was confirmed saved in the CW UI.

## Ruled out so far
- **Network / IP whitelist** — request reaches the app cleanly from both a non-whitelisted IP and the whitelisted VM; identical `401` from both, and `GET` on the host root returns `200` with real app content. Not a network-level block.
- **Wrong endpoint path** — the bare host root explicitly returns `405 Method Not Allowed` (`Allow: GET`), confirming it's just a landing page, not the inbound submission endpoint. `/eAdaptorNext` is the correct path — it's the one that runs an auth check at all.
- **Wrong username** — decoded directly from the Basic Auth header configured in CW; confirmed `HONEASHKG`, unchanged after the reset.
- **Malformed request** — an initial `411 Length Required` (missing `Content-Length` on an empty POST) was resolved by sending an explicit empty body; the `401` shown above is from a well-formed request that reached the real auth check.
- **Propagation delay** — retested a few minutes after the reset with the same result.

## Still unknown — needs team input
1. Does `/eAdaptorNext`'s Basic Auth actually read from this interchange config's password field, or from a separately linked CW user/login record (Registry → User Security)? If the latter, the reset done so far wouldn't take effect here.
2. Are there multiple inbound config records for this interchange (per Application Code / Message Type / Sub Type — see `docs_for_thanh/foundations/05_EDI_menu_note.txt`), and is `/eAdaptorNext` bound to a different record than the one that was edited?
3. Any known caching/propagation delay for credential changes on this service host longer than a few minutes?

## Requested action
Confirm which config object the `/eAdaptorNext` Basic Auth check actually authenticates against, and help verify/reset the credential at the correct source.

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
