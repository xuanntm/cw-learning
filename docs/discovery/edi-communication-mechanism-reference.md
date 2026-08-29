# EDI Communication & Messaging — Table Reference

Environment: PROD (`H56PRD.db.wisegrid.net` / `OdysseyH56PRD`) unless noted. Consolidates the `EDIMessage`/`EDIInterchange`/`EDICommunication*` table family discovered while chasing `docs/backlog/eadaptor-inbound-auth-401.md` — written up as a standing reference since these tables will back any future EDI traffic/reliability reporting, not just the auth investigation.

## ⚠️ This whole document describes the MODERN implementation only — a separate legacy one exists too

Confirmed 2026-08-29 (`docs/backlog/eadaptor-inbound-auth-401.md`): CargoWise has **two separate eAdaptor endpoints/implementations** on the same environment:

| Endpoint | Implementation | Config mechanism |
|---|---|---|
| `.../eAdaptorNext` | Modern ("Next") | Everything in this document — `EDICommunicationParty`/`EDICommunicationPartyConfig`/`EDICommunicationAuth`, per-client named parties (Boomi, Kestrel, Sage, SAPI, VNPT, BravoTrans, etc.) |
| `.../eadaptor` (no "Next") | Legacy (old) | A **different** mechanism, not yet mapped — traditional interchange-style codes (e.g. `HONEASHKG`) live here, not in any table below |

**Before assuming a given interchange/party is represented in the tables below, confirm which endpoint it actually uses** — searching exhaustively through `EDICommunicationAuth`/`EDICommunicationPartyConfig`/`GlbExternalPassword`/`EDIInterchange` for a legacy interchange code will correctly find nothing, because it isn't there. This document does not yet cover the legacy implementation's actual storage mechanism — that's open territory if it's ever needed.

Source data: `tmp/EDI_structure_202608291114.csv` (columns), `tmp/EDI_constraints_202608291119.csv` (real FKs), `tmp/EDI_last_30_days_202608291120.csv` (status breakdown), `tmp/EDI_communication_v2_202608291126.csv` (EDICommunication* family columns), `tmp/EDI_communication_eadaptor_202608291128.csv` (real PROD endpoint config sample) — all gitignored, not tracked.

## The table family

| Table | Prefix | Role |
|---|---|---|
| `EDIInterchange` | `EI_` | Transport-level envelope/session — one interchange can carry multiple messages |
| `EDIMessage` | `EM_` | Individual EDI message — child of `EDIInterchange` via `EM_EI` |
| `EDICommunicationPartyConfig` | `ECC_` | **One row per configured endpoint** — the URL, direction, and links to auth + party |
| `EDICommunicationAuth` | `ECA_` | **The real credential record** — Basic Auth, OAuth2, or certificate/mTLS, one mechanism per row |
| `EDICommunicationParty` | `ECP_` | The trading-partner record an endpoint config belongs to |
| `EDICommunicationsMode` | `EK_` | Separate, older FTP/SFTP-style transport config — own login/password fields, not linked to `ECA` |
| `GlbExternalPassword` | `GP_` | General external-credential vault, referenced from `EI_GP`/`EM_GP` — purpose relative to `ECA` still unconfirmed (see Open questions) |

## Message → Interchange → Endpoint config chain

```
EDIMessage (EM_)
  EM_EI            -----> EDIInterchange.EI_PK        (parent envelope)
  EM_LinkTable +
  EM_LinkUniqueID  -----> polymorphic pointer to the source business record
                          (same pattern as JobHeader.JH_ParentTableCode/JH_ParentID —
                          see docs/discovery/jobheader-table-reference.md)
  EM_EM_RequestMessage -> EDIMessage.EM_PK             (self-link: response -> its request)
  EM_ECC_CommunicationPartyConfig -> EDICommunicationPartyConfig.ECC_PK

EDIInterchange (EI_)
  EI_GB            -----> GlbBranch.GB_PK
  EI_GP            -----> GlbExternalPassword.GP_PK    (purpose vs. ECA unconfirmed)
  EI_ECC_CommunicationPartyConfig -> EDICommunicationPartyConfig.ECC_PK

EDICommunicationPartyConfig (ECC) -- one row per configured endpoint
  ECC_Endpoint      -- the actual URL, e.g. https://.../api/EadaptorNext/<Name>
  ECC_Direction     -- IN / OUT
  ECC_Status        -- code, not yet decoded (sample data showed 'REQ')
  ECC_ECA_Auth  ---> EDICommunicationAuth.ECA_PK        (the credential)
  ECC_ECP_Party ---> EDICommunicationParty.ECP_PK       (the trading partner)
  ECC_GB_Branch, ECC_GE_Department -- standard scoping
```

## `EDICommunicationAuth` — the credential record

One row supports exactly one of three auth mechanisms, selected by `ECA_AuthorizationMode` (code, not yet decoded):

| Mechanism | Columns |
|---|---|
| Basic Auth | `ECA_Username`, `ECA_Password` |
| OAuth2 | `ECA_ClientID`, `ECA_ClientSecret`, `ECA_Scopes`, `ECA_AuthorizationEndpoint`, `ECA_FlowCode` |
| Certificate / mTLS | `ECA_Certificate`, `ECA_EncodedPrivateKey`, plus renewal tracking (`ECA_RenewalEncodedPrivateKey`, `ECA_RenewalOperationId`) |

**This resolves the structural question behind `docs/backlog/eadaptor-inbound-auth-401.md`:** `/eAdaptorNext`'s Basic Auth reads `ECA_Username`/`ECA_Password`, reached via `EDICommunicationPartyConfig.ECC_ECA_Auth` — not `GlbExternalPassword`, and not a separate CW user/login record. Confirmed structurally in PROD; the specific `HONEASHKG` (UAT) record itself still needs checking once UAT is reachable.

**⚠️ Never query, log, or record actual values of `ECA_Password`, `ECA_ClientSecret`, `ECA_Certificate`, or `ECA_EncodedPrivateKey`** — structure and relationships only, consistent with this repo's credential-redaction convention.

## Confirmed real PROD endpoints (2026-08-29 sample, structure only — no credential values)

```sql
SELECT ECC_PK, ECC_Endpoint, ECC_Direction, ECC_Status, ECC_ECA_Auth, ECC_ECP_Party
FROM EDICommunicationPartyConfig
WHERE ECC_Endpoint LIKE '%eAdaptorNext%';
```

| Endpoint | Direction | Status |
|---|---|---|
| `.../api/EadaptorNext/BravoTrans` | OUT | REQ |
| `.../api/EadaptorNext/SAPI` | OUT | REQ |
| `.../api/EadaptorNext/Sage` | OUT | REQ |
| `.../api/EadaptorNext/Kestrel` | OUT | REQ |
| `.../api/EadaptorNext/VNPT` | OUT | REQ |

**Cross-reference:** `BravoTrans` here is the same name flagged as an open unknown in `docs/discovery/workflow-audit-checklist.md` Section A1 (the empty + `NFB` Universal workflow-template risk). This confirms it's a real, currently-configured outbound endpoint — not a dormant/test artifact — raising the priority of confirming whether live jobs actually match those templates (Section B of that checklist).

## `EDIMessage` / `EDIInterchange` status codes (observed, not from a lookup table — treat as inferred)

Last-30-days sample (`tmp/EDI_last_30_days_202608291120.csv`), ~166K messages total, direction codes `RCV` (inbound) / `TRX` (outbound) / `INT` (internal, rare):

| Status (inferred) | Count | Direction |
|---|---|---|
| Parsed (`PRS`) | 93,557 | RCV |
| Sent (`SNT`) | 41,735 | TRX |
| Captured (`CAP`) | 18,923 | TRX |
| Warning (`WAR`) | 9,475 | RCV |
| Decoded (`DCD`) | 944 | RCV |
| Received (`RCV`) | 607 | RCV |
| Rejected (`REJ`) | 4 total | both |

Rejection rate is negligible (~0.002%) in this window — no explicit "Failed"/"Error" status appeared, so failures may roll up under `WAR` or are genuinely rare.

## Open questions

1. What is `GlbExternalPassword` (`EI_GP`/`EM_GP`) actually used for, if not `/eAdaptorNext` Basic Auth? Candidates: the separate legacy `EDICommunicationsMode` (`EK_`) FTP/SFTP transport (though that table has its own `EK_LoginName`/`EK_Password` and doesn't reference `GP` directly either), or some other message-signing/mailbox context. Unconfirmed — would need `EDICommunicationsMode` FK discovery or a live example to trace.
2. What do `ECC_Status = 'REQ'` and the `EM_Status`/`EI_Status` codes actually decode to? No lookup table found yet — may be a hardcoded CW application enum rather than a DB reference table.
3. Is `BravoTrans` currently receiving real traffic, or configured-but-unused? (Feeds directly into `workflow-audit-checklist.md` Section B.)
4. Does `EDICommunicationParty.ECP_ApplicationCode` or `ECP_Name` hold partner codes like `HONEASHKG`, for looking up a specific interchange's config end-to-end? Not yet queried.

## Related files

- `docs/backlog/eadaptor-inbound-auth-401.md` — the specific 401 investigation this mechanism discovery resolves structurally.
- `docs/discovery/workflow-audit-checklist.md` — Section A1/B, informed by the `BravoTrans` endpoint finding above.
- `docs/discovery/jobheader-table-reference.md`, `docs/discovery/custom-fields-mechanism-reference.md` — the polymorphic `ParentID`/`ParentTableCode` pointer pattern also seen here on `EDIMessage.EM_LinkTable`/`EM_LinkUniqueID` and `EDICommunicationsMode.EK_ParentID`/`EK_ParentTableCode`.
- `docs/integration-design/boomi-integration-options.md` — architecture-level integration patterns this table family sits underneath.
