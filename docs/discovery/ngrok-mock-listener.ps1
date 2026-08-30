<#
.SYNOPSIS
  Local mock HTTP receiver for eAdaptor Next outbound testing via ngrok.
  Logs every incoming request (method, path, headers, body) so you can
  confirm exactly what CW sent, then responds 200 OK - or, if
  -ExpectedUsername is supplied, validates the request's Basic Auth
  credentials and responds 401 on a mismatch, same as a real endpoint would.

.DESCRIPTION
  Run this FIRST, then start ngrok in a separate window with the Host
  header rewrite flag (see NOTES - required, no admin rights needed):
      ngrok http <port> --host-header=rewrite
  Then set the EDI Client's outbound Endpoint to the ngrok URL, using
  Basic Authentication with the same username/password passed here via
  -ExpectedUsername/-ExpectedPassword.

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
  - Ctrl+C to stop - works reliably even while waiting for the NEXT request.
    HttpListener.GetContext() is a blocking synchronous call that PowerShell
    cannot interrupt with Ctrl+C once inside it (confirmed 2026-08-29 - the
    listener locked up after the first request, unable to stop). Fixed by
    polling GetContextAsync() in short timeouts instead of blocking
    indefinitely, checking for a manual Ctrl+C keypress between polls
    ([Console]::TreatControlCAsInput). The listener is explicitly closed in
    a finally block so the port is released cleanly either way.
  - This is a TEST-ONLY receiver - TLS is provided by ngrok's HTTPS front
    end, not this script. Don't leave it running longer than the test, and
    don't route real customer data through it. If -ExpectedUsername is
    set, this is your own test credential (the one generated via the EDI
    Client's "Generate Password" button) - not a production secret, but
    still don't hardcode it into this file; pass it at invocation.
  - Without -ExpectedUsername, auth validation is skipped entirely (backward
    compatible with earlier versions) - the listener just logs whatever
    Authorization header it received and always returns 200 OK.

.VERSIONHISTORY
  1.0 - initial version, localhost-only prefix
  1.1 - switched to wildcard prefix (http://+:<port>/) to fix the Host
        header mismatch - required Administrator rights (or a one-time
        elevated netsh urlacl reservation)
  1.2 - reverted to localhost-only prefix (no admin rights available on
        this server) - fixed the same Host header mismatch on the ngrok
        side instead, via `--host-header=rewrite`, which needs zero
        Windows permissions
  1.3 - added optional Basic Auth validation (-ExpectedUsername/
        -ExpectedPassword) - decodes the request's Authorization header
        and responds 401 with WWW-Authenticate on a mismatch, same as a
        real endpoint, so you can confirm CW is actually sending the
        credentials configured on the EDI Client, not just that traffic
        arrives
  1.4 - fixed Ctrl+C not working after the first request - replaced the
        blocking GetContext() call with a polled GetContextAsync() loop
        (250ms timeout) that checks for a manual Ctrl+C keypress between
        polls, since PowerShell cannot interrupt a blocking synchronous
        .NET call with its normal Ctrl+C handling
  1.5 - fixed a crash on the first real 401 response: $response.Headers.
        Add("WWW-Authenticate", ...) throws ("must be modified using the
        appropriate property or method") - .NET's HttpListenerResponse
        requires the indexer/Set form for this header, not Add. Confirmed
        2026-08-30 - the exception was unhandled, killing the whole
        listener (and releasing the port) right after the first request
        that failed auth, instead of just returning a clean 401. Fixed by
        using $response.Headers["WWW-Authenticate"] = ... instead.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'ExpectedPassword',
    Justification = 'This is a local test-only receiver validating a test credential (generated via the EDI Client "Generate Password" button), not a production secret. Pass at invocation, never hardcode.')]
param(
    [int]$Port = 8080,
    [string]$ExpectedUsername = "",
    [string]$ExpectedPassword = ""
)

$ScriptVersion = "1.5"

Write-Host "`n=== ngrok mock listener (script version: $ScriptVersion) ===" -ForegroundColor Magenta
Write-Host "Remember to start ngrok with: ngrok http $Port --host-header=rewrite" -ForegroundColor Yellow
if ($ExpectedUsername -ne "") {
    Write-Host "Basic Auth validation ENABLED - expecting username '$ExpectedUsername'." -ForegroundColor Yellow
} else {
    Write-Host "Basic Auth validation DISABLED (no -ExpectedUsername given) - all requests accepted and logged as-is." -ForegroundColor Gray
}

function Test-BasicAuthHeader {
    param([string]$AuthHeader, [string]$ExpectedUsername, [string]$ExpectedPassword)
    if ([string]::IsNullOrEmpty($AuthHeader) -or -not $AuthHeader.StartsWith("Basic ", [StringComparison]::OrdinalIgnoreCase)) {
        return $false
    }
    try {
        $encoded = $AuthHeader.Substring(6).Trim()
        $decoded = [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))
        $sepIndex = $decoded.IndexOf(':')
        if ($sepIndex -lt 0) { return $false }
        $user = $decoded.Substring(0, $sepIndex)
        $pass = $decoded.Substring($sepIndex + 1)
        return ($user -eq $ExpectedUsername -and $pass -eq $ExpectedPassword)
    } catch {
        return $false
    }
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")

[Console]::TreatControlCAsInput = $true

try {
    $listener.Start()
    Write-Host "Listening on http://localhost:$Port/ - point ngrok at this port with --host-header=rewrite." -ForegroundColor Green
    Write-Host "Press Ctrl+C to stop.`n" -ForegroundColor Gray

    $stopRequested = $false
    while (-not $stopRequested -and $listener.IsListening) {
        $contextTask = $listener.GetContextAsync()
        while (-not $contextTask.Wait(250)) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if ($key.Key -eq [ConsoleKey]::C -and ($key.Modifiers -band [ConsoleModifiers]::Control)) {
                    $stopRequested = $true
                    break
                }
            }
        }
        if ($stopRequested) { break }

        $context = $contextTask.GetAwaiter().GetResult()
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

        $response = $context.Response
        if ($ExpectedUsername -ne "") {
            $authOk = Test-BasicAuthHeader -AuthHeader $request.Headers["Authorization"] -ExpectedUsername $ExpectedUsername -ExpectedPassword $ExpectedPassword
            Write-Host "Auth check: $(if ($authOk) {'VALID'} else {'INVALID/MISSING'})" -ForegroundColor $(if ($authOk) {'Green'} else {'Red'})
            Write-Host ""
            if ($authOk) {
                $response.StatusCode = 200
                $responseBytes = [System.Text.Encoding]::UTF8.GetBytes("OK")
            } else {
                $response.StatusCode = 401
                $response.Headers["WWW-Authenticate"] = 'Basic realm="eAdaptorNext Mock Receiver"'
                $responseBytes = [System.Text.Encoding]::UTF8.GetBytes("Unauthorized")
            }
        } else {
            Write-Host ""
            $response.StatusCode = 200
            $responseBytes = [System.Text.Encoding]::UTF8.GetBytes("OK")
        }
        $response.ContentType = "text/plain"
        $response.ContentLength64 = $responseBytes.Length
        $response.OutputStream.Write($responseBytes, 0, $responseBytes.Length)
        $response.OutputStream.Close()
    }
} finally {
    [Console]::TreatControlCAsInput = $false
    if ($listener.IsListening) { $listener.Stop() }
    $listener.Close()
    Write-Host "`nListener stopped, port $Port released." -ForegroundColor Gray
}
