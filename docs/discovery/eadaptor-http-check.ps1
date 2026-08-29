<#
.SYNOPSIS
  Test eAdaptor Next INBOUND connectivity + auth from this server. Mirrors
  db-connectivity-check.ps1's approach (reachability first, then the real
  test, with a hard timeout) but for the HTTPS eAdaptor Next service instead
  of the SQL Reporting DB.

.DESCRIPTION
  Section 1 - DNS + TCP:443 reachability to the eAdaptor Next host
  Section 2 - HTTP POST test with Basic Auth (empty body - matches the
              reproduction steps already in docs/backlog/eadaptor-inbound-
              auth-401.md). Expect 401 if the known credential issue is
              still unresolved; anything else means real progress.
  Section 3 - reminder to verify via DB afterward (query EDIMessage/
              EDIInterchange for a row matching this test's timestamp)

.NOTES
  - -EAdaptorHost defaults to the UAT host confirmed in
    docs/backlog/eadaptor-inbound-auth-401.md (H56TRNservices.wisegrid.net).
    The PROD equivalent hostname has NOT been confirmed in this repo - do
    not guess it (the SQL DB host had a hidden ".test." gotcha that took a
    support ticket to resolve; the eAdaptor service host could have a
    similar naming surprise). Confirm with the team/CW's own Help > About
    screen before testing against PROD.
  - -EAdaptorUser defaults to the interchange username already confirmed
    correct in the backlog file. Password is NOT defaulted - you must
    supply it, and it is never written to this file.
  - This only tests INBOUND (posting a message INTO CW). Outbound cannot be
    triggered from here - it requires a real business event in the CW UI.
    Verify outbound via the DB queries in
    docs/discovery/uat-integration-verification.sql instead.
  - Script version is printed in the Section 1 banner, same convention as
    docs/discovery/db-connectivity-check.ps1, so results can be traced to
    the revision that produced them.

.VERSIONHISTORY
  1.0 - initial reachability (DNS/TCP) + inbound auth test, confirmed
        working for DNS/TCP against UAT from server1 on 2026-08-29
        (resolves via Cloudflare CDN - au-1-t.eadaptor.wisegrid.net.cdn.
        cloudflare.net - unlike the SQL DB host's direct private IP, so
        the eAdaptor Next service is public-facing/CDN-fronted while the
        Reporting DB is VNet-only)
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'EAdaptorPassword',
    Justification = 'Same deliberate convenience trade-off as db-connectivity-check.ps1 - intended for use on a personal, non-shared server. Pass at invocation, never hardcode.')]
param(
    [string]$EAdaptorHost = "H56TRNservices.wisegrid.net",
    [int]$EAdaptorPort = 443,
    [string]$EAdaptorPath = "/eAdaptorNext",
    [string]$EAdaptorUser = "HONEASHKG",
    [string]$EAdaptorPassword = "",  # required - pass at invocation, never hardcode here
    [int]$TimeoutSec = 20
)

$ScriptVersion = "1.0"
$ProgressPreference = 'SilentlyContinue'

Write-Host "`n=== eAdaptor Next HTTP check (script version: $ScriptVersion) ===" -ForegroundColor Magenta

Write-Host "`n=== Section 1: reachability check for $EAdaptorHost`:$EAdaptorPort ===" -ForegroundColor Cyan
$dns = Resolve-DnsName -Name $EAdaptorHost -ErrorAction SilentlyContinue
$dnsOk = $null -ne $dns
Write-Host "DNS resolution: $(if ($dnsOk) {'OK'} else {'FAILED'})" -ForegroundColor $(if ($dnsOk) {'Green'} else {'Red'})
if ($dnsOk) { $dns | Select-Object Name, IPAddress | Format-Table }

$tcp = Test-NetConnection -ComputerName $EAdaptorHost -Port $EAdaptorPort -WarningAction SilentlyContinue
Write-Host "TCP $EAdaptorPort reachable: $($tcp.TcpTestSucceeded)" -ForegroundColor $(if ($tcp.TcpTestSucceeded) {'Green'} else {'Red'})

if (-not ($dnsOk -and $tcp.TcpTestSucceeded)) {
    Write-Host "`nStopping - fix reachability before testing auth. If DNS fails, this may be the same class of issue as the SQL DB host (confirm the real hostname with the team rather than assuming)." -ForegroundColor Yellow
    return
}

Write-Host "`n=== Section 2: inbound auth test ===" -ForegroundColor Cyan
if ($EAdaptorPassword -eq "") {
    Write-Host "No -EAdaptorPassword supplied - skipping auth test. Reachability above is still valid on its own." -ForegroundColor Yellow
    return
}

$authToken = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$EAdaptorUser`:$EAdaptorPassword"))
$uri = "https://$EAdaptorHost$EAdaptorPath"
$testStartUtc = (Get-Date).ToUniversalTime()

try {
    $response = Invoke-WebRequest -Uri $uri -Method POST `
        -Headers @{ Accept = "application/xml"; Authorization = "Basic $authToken" } `
        -Body "" -TimeoutSec $TimeoutSec -ErrorAction Stop
    Write-Host "Status: $($response.StatusCode) $($response.StatusDescription)" -ForegroundColor Green
    Write-Host $response.Content
} catch {
    $resp = $_.Exception.Response
    if ($resp) {
        Write-Host "Status: $([int]$resp.StatusCode) $($resp.StatusDescription)" -ForegroundColor $(if ([int]$resp.StatusCode -eq 401) {'Yellow'} else {'Red'})
        if ([int]$resp.StatusCode -eq 401) {
            Write-Host "401 matches the known unresolved issue in docs/backlog/eadaptor-inbound-auth-401.md - not a new problem, update that file's status if this changes." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Request failed before a response was received: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n=== Section 3: verify via DB ===" -ForegroundColor Cyan
Write-Host "Test sent at (UTC): $($testStartUtc.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Yellow
Write-Host @"
Run this against the same environment's DB to see whether the attempt was logged
(even a rejected/401 attempt may or may not create a row, depending on how early
CW's auth check runs - this itself is useful information):

SELECT TOP 20 EM_PK, EM_ApplicationCode, EM_MessageType, EM_Status, EM_ReceiveTransmit, EM_SystemCreateTimeUtc
FROM EDIMessage
WHERE EM_SystemCreateTimeUtc >= '$($testStartUtc.AddMinutes(-2).ToString("yyyy-MM-dd HH:mm:ss"))'
ORDER BY EM_SystemCreateTimeUtc DESC;
"@ -ForegroundColor Yellow
