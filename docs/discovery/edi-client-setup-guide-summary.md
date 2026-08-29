# Set up EDI Client Details — Official Guide Summary

Source: `02_Set up EDI Client Details.pdf` (WiseTech Global, v2.0, 13 April 2026), extracted to `C:\Users\SpencerNGUYEN\Downloads\EDI_2026\extract\02_Set up EDI Client Details.txt` (not tracked in this repo — original PDF/extract live outside the repo). This is the direct how-to for the task in progress: creating a new EDI Client. Companion to `docs/discovery/eadaptor-next-developer-guide-summary.md`.

## Path and basic creation

**Maintain → EDI Messaging → EDI Client Details → New.**

Note: *"The EDI Client Details Module is only accessible to eAdaptorNext users as of now"* — if it's still not visible after checking the `Maintain` menu, this may need a specific user-type/licensing flag, not just a generic menu permission grant.

### Fields on creation (mapped to the confirmed DB schema)

| UI field | DB column (confirmed) | Notes |
|---|---|---|
| Connection Type | `ECP_ApplicationCode` | Always `EAN` currently (matches empirical UAT data) |
| EDI Client Name | `ECP_Name` | Unique, descriptive — matches partner/integration purpose |
| Summary | `ECP_Summary` | Short description |
| Staff Proxy | likely `ECP_GS_SecurityProxy` | User account attributed to EDI messages/events from this client |
| Technical Contact | `ECP_OC_TechnicalContact` | Person/team responsible for maintenance |
| Enabled | `ECP_IsActive` | On by default |

Inbound and Outbound are each independently enable/disable-able within the same record (tabs), not separate records — matches the earlier empirical finding of one `ECP` per party with up to 2 `ECC` rows (one per direction).

## ⚠️ Auth availability — WiseCloud restriction, with an empirical caveat

The guide states: *"Basic authentication is only available for self-hosted customers. WiseCloud hosted customers do not have this option."* Taken at face value this would rule out Basic Auth entirely for this (WiseCloud-hosted) environment — but **UAT's real current config directly contradicts a blanket reading**: `H56_TRN_CW2SAGE`, `Kestrel`, `SAPI`, `VNPT`, `BravoTrans`, `Boomi` all use `BAU` (Basic Auth) on their **outbound** side today, confirmed via `EDICommunicationAuth.ECA_AuthorizationMode`. Reconciling this with the Developer's Guide's more precise statement (*"WiseCloud inbound connections now mandate certificate-based authentication"*), the accurate read is almost certainly: **Basic Auth is unavailable for INBOUND on WiseCloud, but remains available for OUTBOUND** — matching every real config already found. Don't take the blanket statement in this doc at face value for outbound; trust the empirical DB evidence.

## Setting up INBOUND

- **Active by default** — untick to disable if not needed yet (matches the earlier caution about not activating both directions immediately).
- **Branch and Department are mandatory** for inbound (cascade to all inbound EDI Message records). This likely explains why most existing `IN` rows in UAT show blank Branch/Department — those are inactive placeholder rows; the mandatory validation probably only enforces once you actually enable inbound.
- **Auth options for inbound**: OAuth (Client Certificate Grant only — the only inbound grant type supported) or Basic Auth (self-hosted only, per above).
  - **OAuth inbound setup** is a real multi-step process: generate a CSR + private key (external tool like OpenSSL, or CW's own CSR generator per section 2.3.1's outbound flow — inbound's CSR flow isn't fully detailed but implies a similar upload-CSR-then-generate-certificate flow), upload the CSR (`Certificate Request File` field), click `Generate Certificate`. CSR subject fields (`CN`, `O`, `OU`, `L`, `ST`, `C`, `emailAddress`) have **strict allowed-character rules** — no underscores or most symbols, or certificate generation fails. **A CSR can only be used once** — regenerate for any redo/renewal. Only **Entra ID** (formerly Azure AD) is supported as identity provider.
  - **Basic Auth inbound setup** (self-hosted only): unique username + click **"Generate Password"** (system-generated — the guide explicitly warns **it cannot be retrieved once saved**, so capture it immediately).

## Setting up OUTBOUND

- **Active by default**, same as inbound.
- Requires: a valid web service endpoint (`ECC_Endpoint`) + auth type.
- **Three OAuth grant types available for outbound** (inbound only supports the first):
  - **Client Certificate Grant (CCT)** — same CSR-based flow as inbound, but outbound's CSR generation is done directly in CW (`Generate CSR...` button → download `.pem` → get it signed by a **real, publicly-trusted CA** (self-signed not accepted) → `Set Certificate...` → `Verify`. **If you exit before completing, the CSR becomes invalid** — must restart from a fresh CSR.
  - **Client Credentials Grant (CCD)** — simpler: Authorization URL (token endpoint) + Client ID + Client Secret + optional Scope, then `Verify`.
  - **Resource Owner Credentials (ROC)** — username/password based; guide explicitly calls this **"discouraged," legacy/less-secure** — avoid for a new setup unless there's a specific reason.
- **Basic Auth outbound**: username + password, straightforward (and empirically the most common pattern in this environment already — matches `Sage`/`Kestrel`/`SAPI`/`VNPT`/`BravoTrans`/`Boomi`).
- **No Authentication**: outbound-only option, for trusted-network scenarios.

## The missing link, now confirmed: Organization → EDI Client routing

*"EDI Communication mode on Organization now can specify the EDI Client to use when EAM sends outbound eAdaptor messages."* **This directly confirms the earlier empirical finding**: `EDICommunicationsMode` (`EK_` prefix, `ParentTableCode='OH'`) is exactly this per-Organization routing layer, pointing at a specific EDI Client (`EK_ECC_CommunicationPartyConfig`) — see `docs/discovery/uat-edi-configuration-collector.sql` Step 2 and the BravoTran 4-organization routing finding in `docs/discovery/workflow-audit-checklist.md`. A new EDI Client alone won't route any real Organization's traffic to it — that Organization also needs an `EDICommunicationsMode` entry pointing at the new client (set up via the Organization's own EDI Communication Mode screen, not the EDI Client Details screen itself).

## Other useful facts

- **Certificate expiry notifications**: 30 days before expiry by default, daily until renewed (continues even past expiry if not renewed). Configurable at `EDI Messaging > EDI Client > Certificate Expiry`.
- **Audit tab**: each EDI Client record has its own **Audit tab showing all config changes** — a UI-level way to see change history without needing DB/CDC access (relevant to the earlier CDC-permission-denied dead end from the `401` investigation — for a *current* EDI Client, this UI tab may be the easier path next time).
- **User Security**: a dedicated Security Rights entry exists for EDI Client Details (separate from general menu access) — reinforces checking security/permissions specifically for this module if it's still not visible.

## Related files

- `docs/discovery/eadaptor-next-developer-guide-summary.md` — the broader Developer's Guide this how-to complements.
- `docs/discovery/edi-communication-mechanism-reference.md` — DB-level mechanism this UI configures.
- `docs/discovery/uat-edi-configuration-collector.sql` — the "New Integration Checklist" this now supersedes with confirmed real steps.
- `docs/backlog/eadaptor-inbound-auth-401.md` — where the `Maintain` vs `Registry` menu confusion was first identified.
