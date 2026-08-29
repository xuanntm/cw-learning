# ngrok Setup for eAdaptor Next Outbound Testing — Confirmed Working (2026-08-29)

Purpose: a public HTTPS endpoint to receive and inspect real outbound messages CW sends from a new EDI Client (`docs/discovery/edi-client-setup-guide-summary.md`), without standing up real hosted infrastructure. Run on a **private, non-shared server** — server1 in this repo's terminology (see `docs/discovery/workflow-traffic-analysis-guide.md`'s server-comparison table) — since the tunnel is public the moment it's up.

## 1. Install ngrok

```powershell
winget install ngrok.ngrok
```

**Known issue**: winget's `Ngrok.Ngrok` package was stuck at v3.3.1, while ngrok's free-tier policy requires **v3.20.0+** (`ERR_NGROK_121` on tunnel start otherwise). Checked directly — winget's catalog only offers `3.3.1`/`3.3.0`/`3.2.2`, none sufficient; **pinning a version via `winget install --version` does not help**, since none of the cataloged versions are new enough.

**Fix**: `ngrok update` (built-in self-update), or if that doesn't fully resolve it, download the current build directly from `https://ngrok.com/download` and replace the winget-installed `ngrok.exe`.

## 2. Auth token

```powershell
ngrok config add-authtoken <your-token>
```

**⚠️ Treat your auth token as a real secret** — it ties to your personal ngrok account/quota. Get it from your ngrok dashboard (Settings → Auth Tokens), and if one is ever pasted into a chat, terminal log, or anywhere outside your local config, rotate/regenerate it immediately rather than assume it's fine.

## 3. Start the local mock listener

Use `docs/discovery/ngrok-mock-listener.ps1` (currently v1.2) — logs every incoming request (method, path, headers, body) and responds `200 OK`.

```powershell
.\ngrok-mock-listener.ps1
# or a different port:
.\ngrok-mock-listener.ps1 -Port 9090
```

No administrator rights required — it binds `http://localhost:<port>/`, not a wildcard prefix.

## 4. Start the tunnel — the Host header fix

```powershell
ngrok http 8080 --host-header=rewrite
```

**Why `--host-header=rewrite` is required, not optional**: ngrok forwards each request with the *public tunnel hostname* as the `Host` header by default. A `localhost`-only listener binding rejects that mismatch with a `400 Bad Request` from the Windows HTTP.sys layer — **before the PowerShell script's code ever runs**, so nothing appears in its console output even though the tunnel itself is working. Confirmed via a live test against `https://harbor-finer-movie.ngrok-free.dev`, which returned `400` with `Server: Microsoft-HTTPAPI/2.0` (proof the tunnel reached the listener) and `Ngrok-Agent-Ips: <server1's public IP>` (proof it was genuinely this tunnel).

Two ways to fix this mismatch existed; **the admin-required one was tried first and failed** (no administrator rights on this server), so the working fix is entirely on the ngrok side:

| Approach | Requires admin? | Used? |
|---|---|---|
| Bind listener to wildcard prefix (`http://+:8080/`) + elevate or reserve URL ACL | Yes | ❌ Failed — `Access is denied` (`$listener.Start()`), no admin rights available |
| `ngrok http <port> --host-header=rewrite` (rewrites Host before forwarding) | No | ✅ **This is what worked** |

## 5. Verify

Three layers, cheapest first:

1. **ngrok's local web inspector** — `http://127.0.0.1:4040` while the tunnel is running. Shows every request/response, replayable without needing CW to resend.
2. **The listener's own console output** — full headers/body of each request.
3. **Cross-check in CW's DB** — the `EDIMessage`/`EDIInterchange` query pattern from `docs/discovery/eadaptor-http-check.ps1` Section 3, to confirm CW itself logged the send.

## 6. Next step

Set this ngrok URL as the **Endpoint** on the Outbound tab of the EDI Client from `docs/discovery/edi-client-setup-guide-summary.md`, then trigger a real send (once the Organization-level `EDICommunicationsMode` routing + workflow trigger wiring is in place — still a separate follow-up task, not yet done) to complete the model-integration test end-to-end.

## Related files

- `docs/discovery/ngrok-mock-listener.ps1` — the listener script (v1.2, no admin required).
- `docs/discovery/edi-client-setup-guide-summary.md` — the EDI Client this endpoint feeds into.
- `docs/discovery/eadaptor-http-check.ps1` — DB verification query pattern reused in step 5.
- `docs/discovery/eadaptor-next-developer-guide-summary.md` — mentions Postman Mock Servers as a no-tunnel alternative, if ngrok's per-session friction becomes a problem.
