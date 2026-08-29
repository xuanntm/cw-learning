<#
.SYNOPSIS
  Local mock HTTP receiver for eAdaptor Next outbound testing via ngrok.
  Logs every incoming request (method, path, headers, body) so you can
  confirm exactly what CW sent, then responds 200 OK.

.DESCRIPTION
  Run this FIRST, then start ngrok in a separate window with the Host
  header rewrite flag (see NOTES - required, no admin rights needed):
      ngrok http <port> --host-header=rewrite
  Then set the EDI Client's outbound Endpoint to the ngrok URL.

.NOTES
  - NO ADMINISTRATOR RIGHTS NEEDED in this version. Binds localhost-only
    (http://localhost:<port>/), which does not require the URL ACL
    reservation that a wildcard (http://+:<port>/) binding needs.
  - The catch: ngrok forwards requests with the public tunnel hostname as
    the Host header by default, which would still get rejected by a
    localhost-only binding (confirmed 2026-08-29 testing
    https://harbor-finer-movie.ngrok-free.dev - got 400 Bad Request from
    Microsoft-HTTPAPI/2.0 before this script's code ever saw the request).
    Fix belongs on the ngrok side instead of the Windows side:
      ngrok http <port> --host-header=rewrite
    This tells ngrok to rewrite the Host header to match the local target
    (localhost:<port>) before forwarding - no Windows permission needed at
    all. If that exact flag has changed in your ngrok version, run
    `ngrok http --help` and look for the host-header option.
  - Also verify via ngrok's own web inspector at http://127.0.0.1:4040
    while the tunnel is running - shows every request/response and lets
    you replay one without needing CW to resend it.
  - Ctrl+C to stop. The listener is explicitly closed in a finally block
    so the port is released cleanly.
  - This is a TEST-ONLY receiver - no auth, no TLS of its own (ngrok
    provides the HTTPS front end). Don't leave it running longer than the
    test, and don't route real customer data through it.

.VERSIONHISTORY
  1.0 - initial version, localhost-only prefix
  1.1 - switched to wildcard prefix (http://+:<port>/) to fix the Host
        header mismatch - required Administrator rights (or a one-time
        elevated netsh urlacl reservation)
  1.2 - reverted to localhost-only prefix (no admin rights available on
        this server) - fixed the same Host header mismatch on the ngrok
        side instead, via `--host-header=rewrite`, which needs zero
        Windows permissions
#>
param(
    [int]$Port = 8080
)

$ScriptVersion = "1.2"

Write-Host "`n=== ngrok mock listener (script version: $ScriptVersion) ===" -ForegroundColor Magenta
Write-Host "Remember to start ngrok with: ngrok http $Port --host-header=rewrite" -ForegroundColor Yellow

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")

try {
    $listener.Start()
    Write-Host "Listening on http://localhost:$Port/ - point ngrok at this port with --host-header=rewrite." -ForegroundColor Green
    Write-Host "Press Ctrl+C to stop.`n" -ForegroundColor Gray

    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $reader = New-Object System.IO.StreamReader($request.InputStream, $request.ContentEncoding)
        $body = $reader.ReadToEnd()
        $reader.Close()

        Write-Host "=== Incoming request $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" -ForegroundColor Cyan
        Write-Host "Method: $($request.HttpMethod)   Path: $($request.Url.PathAndQuery)"
        Write-Host "Host header: $($request.Headers['Host'])"
        Write-Host "Remote: $($request.RemoteEndPoint)"
        Write-Host "Headers:"
        foreach ($key in $request.Headers.AllKeys) {
            Write-Host "  ${key}: $($request.Headers[$key])"
        }
        Write-Host "Body ($($body.Length) chars):"
        Write-Host $body
        Write-Host ""

        $response = $context.Response
        $response.StatusCode = 200
        $response.ContentType = "text/plain"
        $responseBytes = [System.Text.Encoding]::UTF8.GetBytes("OK")
        $response.ContentLength64 = $responseBytes.Length
        $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
        $response.OutputStream.Close()
    }
} finally {
    if ($listener.IsListening) { $listener.Stop() }
    $listener.Close()
    Write-Host "`nListener stopped, port $Port released." -ForegroundColor Gray
}
