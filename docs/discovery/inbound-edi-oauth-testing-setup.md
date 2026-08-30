# Inbound EDI — OAuth Certificate Testing Setup (Postman)

Environment: UAT/TRN. Reference for testing the inbound `eAdaptorNext` OAuth Client Certificate Grant flow on the `Full Integration` EDI Client, via the Postman collection's pre-request script (JWT Bearer / RFC 7523 flow, `jsrsasign`-based).

## Local file locations

All in `tmp/EDI/` (gitignored — never move these into a tracked location or paste their contents into a tracked file):

| File | Contents | Origin |
|---|---|---|
| `full-integration-inbound.key` | Private key (PKCS#8, `-----BEGIN PRIVATE KEY-----`) | Generated locally via OpenSSL (`openssl genrsa`) |
| `full-integration-inbound.csr` | The CSR built from that key | Generated locally via OpenSSL (`openssl req -new`), uploaded to CW's Inbound EDI Client "Certificate Request File" field |
| `DownloadCertificate.pem` | The issued certificate | Exported from CW after clicking "Generate Certificate" — confirmed 2026-08-30 to have the **same public key modulus** as `full-integration-inbound.key` (MD5 `d4b24fb2adbe1efe6ee9566c6ecbf089` on both), proving CW signed our CSR rather than generating its own key pair. Issued by `wisetechglobal eAdaptor ca1 g1`, valid `2026-08-30` → `2027-08-30` |
| `full-integration-inbound-pkcs8.key` | Redundant PKCS#8 re-export of the same key | Created while ruling out a PKCS#1-vs-PKCS#8 format theory for a `jsrsasign` error — turned out unnecessary, the original key was already PKCS#8, but kept for reference |

## Postman environment variables

| Variable | Value | Source |
|---|---|---|
| `OAuthClientID` | `61eb7b29-3a21-4845-962d-ec66d86330ba` | `EDICommunicationAuth.ECA_ClientID`, confirmed via DB (safe — Client ID is a public OAuth identifier, not a secret) |
| `OAuthTenantID` | `1b20b87e-cebd-43cc-97bd-bdd41a2f5cf1` | Extracted from `ECA_AuthorizationEndpoint` (`https://login.microsoftonline.com/{tenant}/v2.0`) |
| `OAuthCertificatePem` | contents of `tmp/EDI/DownloadCertificate.pem` | paste as full multi-line PEM into Postman's **expanded** variable editor, not the compact table cell |
| `OAuthPrivateKeyPem` | contents of `tmp/EDI/full-integration-inbound.key` | same — full multi-line PEM, expanded editor |
| `OAuthAccessTokenURL` | auto-set by the pre-request script (`https://login.microsoftonline.com/{OAuthTenantID}/oauth2/v2.0/token`) | derived, don't set manually |
| `OAuthJWTToken` | auto-set by the pre-request script | derived, don't set manually |

**Entra app registration** (`OAuthClientID`/`OAuthTenantID` above) already existed prior to this session's certificate generation (`ECA_SystemCreateTimeUtc = 2026-08-29 13:11`, a day before `Generate Certificate` was clicked on 2026-08-30) — no separate manual Entra Portal step was needed; "Generate Certificate" only added the certificate/key material to this existing registration. See `docs/discovery/edi-communication-mechanism-reference.md`'s "Inbound certificate generation, confirmed end-to-end" section.

## Pre-request script — what it does

Runs entirely client-side in Postman (`jsrsasign` + `crypto-js`), no external calls until the final token request:
1. Computes `x5t` (certificate thumbprint) as base64url-encoded SHA-1 of `OAuthCertificatePem`'s DER bytes.
2. Builds a JWT: header `{alg: RS256, typ: JWT, x5t}`, payload `{iss, sub, aud, iat, exp}` (`iss`/`sub` = Client ID, `aud` = the token URL, `exp` = now + 3600s). No `jti` claim in this version.
3. Signs it with `OAuthPrivateKeyPem` via `KJUR.jws.JWS.sign('RS256', ...)`, stores the result as `OAuthJWTToken`.
4. The actual HTTP request (not shown here) then POSTs to `OAuthAccessTokenURL` using `client_assertion = OAuthJWTToken`, `client_assertion_type = urn:ietf:params:oauth:client-assertion-type:jwt-bearer`, `grant_type = client_credentials`, per RFC 7523.

## Known issue and fix

**`JWT creation failed: init failed:Error: not supported argument`** — `jsrsasign`'s `KEYUTIL.getKey()` (called inside `JWS.sign`) fails to parse a PEM string that's lost its real line breaks, which happens easily when pasting a multi-line PEM into Postman's compact environment-variable table cell instead of the expanded editor. **Not a key-format problem** — confirmed the key was already PKCS#8 (the correct format), converting to PKCS#8 again made no difference.

Two mitigations:
1. Paste via Postman's **expanded** variable editor (click to expand the Current Value cell), not the inline row.
2. Defensive fix regardless of paste method — normalize escaped newlines before use:
   ```js
   const privateKeyPem = pm.environment.get('OAuthPrivateKeyPem').replace(/\\n/g, '\n');
   const pemCert = pm.environment.get('OAuthCertificatePem').replace(/\\n/g, '\n');
   ```

## Related files

- `docs/discovery/edi-communication-mechanism-reference.md` — the broader inbound EDI mechanism (`ECA_`/`ECC_` tables, confirmed no Org-level routing for inbound, the Entra app-registration timing finding).
- `docs/discovery/inbound-edi-config-discovery.sql` — confirmed all real inbound configs use OAuth (`ECA_AuthorizationMode='OAU'`), none use Basic Auth.
- `docs/discovery/inbound-certificate-generation-check.sql` — the DB queries that surfaced `ECA_ClientID`/`ECA_AuthorizationEndpoint`/`ECA_OperationId`.
- `docs/discovery/eadaptor-next-developer-guide-summary.md` — the official OAuth flow description (`OAuthClientID`, `OAuthTenantID`, `OAuthCertificatePem`, `OAuthPrivateKeyPem` → `GetOAuthToken` → `OAuthBearerToken`) this Postman script implements.
