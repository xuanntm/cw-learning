<#
.SYNOPSIS
  Run this on EACH of your 3 servers, in turn, to systematically test SQL Reporting DB
  connectivity: PROD first (known-working baseline), then UAT (the target still blocked
  on DNS as of the last check). Same script, same order, on every server — differences
  in the results between servers are the diagnostic signal.

.DESCRIPTION
  Section 0 - report this server's outbound public IP (for correlating against whatever
              IP(s) are actually whitelisted — the working theory this run is testing is
              "only some servers' egress IPs are whitelisted")
  Section 1 - PROD: DNS resolution + TCP port check + real SQL login (baseline —
              this already works from at least one known server, so a failure here on
              a *different* server tells you it's server/network-specific, not a PROD
              DB issue)
  Section 2 - UAT: same three checks against H56TRN.db.wisegrid.net
  Section 3 - summary table to eyeball pass/fail at a glance, and to copy into
              docs/discovery/workflow-traffic-analysis-guide.md afterward

.NOTES
  - NO EXTERNAL TOOL REQUIRED — the login test uses System.Data.SqlClient, which
    ships as part of .NET Framework on every Windows machine. Nothing to install,
    no admin rights needed. (Previous versions shelled out to sqlcmd.exe; dropped
    in 1.4 both because it requires a separate install and because it hit an
    unresolved TLS/negotiation-level hang on server1 that this ADO.NET path may
    not share, being a different driver stack entirely.)
  - You'll be prompted for both passwords interactively by default. To skip the
    prompts (e.g. on your own non-shared server), pass -ProdSqlPassword / -UatSqlPassword
    directly. NEVER hardcode a real password inside this file (it's tracked in git) -
    always pass it at the command line when you invoke the script.
  - Record which physical/named server you ran this from each time (hostname, or a
    label you choose) — that's the whole point of running it 3 times.
  - Script version is printed in the summary and the copy-paste row, so results in
    docs/discovery/workflow-traffic-analysis-guide.md can be traced to the script
    revision that produced them — this matters more than usual here, since 1.0-1.3
    results (sqlcmd-based) and 1.4+ results (ADO.NET-based) can differ for reasons
    that have nothing to do with the actual network path.
  - The login step has a HARD cancellation timeout (default 30s, see $LoginTimeoutSec)
    via a CancellationToken on the async connection open — it will always return
    within that window regardless of what the connection is stuck on.

.VERSIONHISTORY
  1.0 - initial PROD-then-UAT connectivity script
  1.1 - added -l 20 sqlcmd login timeout (was hanging indefinitely on TLS/negotiation
        mismatch, confirmed 2026-08-29 on server1)
  1.2 - -l 20 alone still hung past 20s on server1 (that flag doesn't cover a
        lower-level TLS/socket hang) — replaced with a hard external process-kill
        timeout (Start-Process + Stop-Process) that always returns within
        $LoginTimeoutSec regardless of what sqlcmd itself is stuck on
  1.3 - added optional -ProdSqlPassword / -UatSqlPassword params to skip the
        interactive Read-Host prompt when running repeatedly on your own server
  1.4 - dropped the sqlcmd.exe dependency entirely (no permission to install
        software on server1) — login test now uses System.Data.SqlClient
        (built into .NET Framework, zero install) with an async CancellationToken
        for the hard timeout instead of process-kill
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'ProdSqlPassword',
    Justification = 'Deliberate convenience param for a personal, non-shared server (user request 2026-08-29) - a SecureString param cannot be populated from a plain command-line arg, which is the whole point of skipping the Read-Host prompt. Default remains the interactive SecureString prompt.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'UatSqlPassword',
    Justification = 'Same as ProdSqlPassword above.')]
param(
    [string]$ServerLabel = $env:COMPUTERNAME,
    [int]$LoginTimeoutSec = 30,

    [string]$ProdSqlHost = "H56PRD.db.wisegrid.net",
    [int]$ProdSqlPort = 1433,
    [string]$ProdSqlDatabase = "OdysseyH56PRD",
    [string]$ProdSqlUser = "",
    [string]$ProdSqlPassword = "",  # optional - skips the Read-Host prompt if set. Pass at invocation, never hardcode here.

    [string]$UatSqlHost = "H56TRN.db.wisegrid.net",
    [int]$UatSqlPort = 1433,
    [string]$UatSqlDatabase = "OdysseyH56TRN",
    [string]$UatSqlUser = "EnterpriseDbUser_OdysseyH56TRN_H56.Spencer.Nguyen",
    [string]$UatSqlPassword = ""    # optional - skips the Read-Host prompt if set. Pass at invocation, never hardcode here.
)

$ScriptVersion = "1.4"
$ProgressPreference = 'SilentlyContinue'  # suppress PS progress-bar UI (was leaving stale render artifacts in copied transcripts)

Add-Type -AssemblyName "System.Data" -ErrorAction SilentlyContinue

$results = @()

function Invoke-SqlConnectionTest {
    param(
        [string]$SqlHost, [int]$SqlPort, [string]$SqlDatabase, [string]$SqlUser,
        [System.Security.SecureString]$SqlPassword,
        [int]$TimeoutSec
    )
    # System.Data.SqlClient ships with .NET Framework - no install, no admin rights
    # needed. This is also a genuinely different driver/TLS stack than sqlcmd.exe's
    # ODBC path, so a result here that differs from earlier sqlcmd results is itself
    # informative (isolates whether a problem is sqlcmd-specific or deeper).
    $plainPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SqlPassword))
    $connString = "Server=$SqlHost,$SqlPort;Database=$SqlDatabase;User Id=$SqlUser;Password=$plainPassword;Encrypt=True;TrustServerCertificate=True;"
    $conn = New-Object System.Data.SqlClient.SqlConnection($connString)
    $cts = New-Object System.Threading.CancellationTokenSource
    $cts.CancelAfter([TimeSpan]::FromSeconds($TimeoutSec))
    try {
        $conn.OpenAsync($cts.Token).GetAwaiter().GetResult()
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "SELECT @@VERSION;"
        $version = $cmd.ExecuteScalar()
        return [PSCustomObject]@{ Status = "OK"; Output = $version }
    } catch [System.OperationCanceledException] {
        return [PSCustomObject]@{ Status = "TIMEOUT (cancelled after ${TimeoutSec}s)"; Output = "" }
    } catch {
        return [PSCustomObject]@{ Status = "FAILED"; Output = $_.Exception.Message }
    } finally {
        $conn.Close()
        $cts.Dispose()
    }
}

Write-Host "`n=== Running from server: $ServerLabel (script version: $ScriptVersion) ===" -ForegroundColor Magenta

# ============================================================
# SECTION 0 - outbound public IP (for whitelist correlation)
# ============================================================
Write-Host "`n=== Section 0: outbound public IP ===" -ForegroundColor Cyan
try {
    $publicIp = (Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -TimeoutSec 10).ip
    Write-Host "Outbound public IP: $publicIp" -ForegroundColor Yellow
} catch {
    Write-Host "Could not determine public IP (no outbound internet from this server?) - $($_.Exception.Message)" -ForegroundColor Red
    $publicIp = "UNKNOWN"
}
# If this is an Azure VM, its private IP is also worth recording for the ticket to IT:
try {
    $privateIp = (Invoke-RestMethod -Headers @{Metadata="true"} -Uri "http://169.254.169.254/metadata/instance/network?api-version=2021-02-01" -TimeoutSec 5).interface[0].ipv4.ipAddress[0].privateIpAddress
    Write-Host "Azure private IP: $privateIp" -ForegroundColor Yellow
} catch {
    $privateIp = "N/A (not Azure IMDS-reachable, or not an Azure VM)"
}

# ============================================================
# SECTION 1 - PROD baseline (known-working)
# ============================================================
Write-Host "`n=== Section 1: PROD - $ProdSqlHost`:$ProdSqlPort ===" -ForegroundColor Cyan

$prodDns = Resolve-DnsName -Name $ProdSqlHost -ErrorAction SilentlyContinue
$prodDnsOk = $null -ne $prodDns
Write-Host "DNS resolution: $(if ($prodDnsOk) {'OK'} else {'FAILED'})" -ForegroundColor $(if ($prodDnsOk) {'Green'} else {'Red'})
if ($prodDnsOk) { $prodDns | Select-Object Name, IPAddress | Format-Table }

$prodTcp = Test-NetConnection -ComputerName $ProdSqlHost -Port $ProdSqlPort -WarningAction SilentlyContinue
Write-Host "TCP $ProdSqlPort reachable: $($prodTcp.TcpTestSucceeded)" -ForegroundColor $(if ($prodTcp.TcpTestSucceeded) {'Green'} else {'Red'})

$prodLoginOk = "SKIPPED"
if ($ProdSqlUser -ne "") {
    if ($ProdSqlPassword -ne "") {
        $prodPwSecure = ConvertTo-SecureString $ProdSqlPassword -AsPlainText -Force
    } else {
        $prodPwSecure = Read-Host "Enter SQL login password for PROD user '$ProdSqlUser'" -AsSecureString
    }
    Write-Host "Testing SQL connection (cancels at ${LoginTimeoutSec}s if it hangs)..." -ForegroundColor DarkGray
    $prodResult = Invoke-SqlConnectionTest -SqlHost $ProdSqlHost -SqlPort $ProdSqlPort -SqlDatabase $ProdSqlDatabase -SqlUser $ProdSqlUser -SqlPassword $prodPwSecure -TimeoutSec $LoginTimeoutSec
    Write-Host $prodResult.Output
    $prodLoginOk = $prodResult.Status
} else {
    Write-Host "No -ProdSqlUser given - skipping login test, DNS/TCP results above still valid." -ForegroundColor Yellow
}

$results += [PSCustomObject]@{ ScriptVersion=$ScriptVersion; Server=$ServerLabel; Env="PROD"; DNS=$(if($prodDnsOk){"OK"}else{"FAIL"}); TCP=$prodTcp.TcpTestSucceeded; Login=$prodLoginOk }

# ============================================================
# SECTION 2 - UAT target
# ============================================================
Write-Host "`n=== Section 2: UAT - $UatSqlHost`:$UatSqlPort ===" -ForegroundColor Cyan

$uatDns = Resolve-DnsName -Name $UatSqlHost -ErrorAction SilentlyContinue
$uatDnsOk = $null -ne $uatDns
Write-Host "DNS resolution: $(if ($uatDnsOk) {'OK'} else {'FAILED'})" -ForegroundColor $(if ($uatDnsOk) {'Green'} else {'Red'})
if ($uatDnsOk) { $uatDns | Select-Object Name, IPAddress | Format-Table }

$uatTcp = Test-NetConnection -ComputerName $UatSqlHost -Port $UatSqlPort -WarningAction SilentlyContinue
Write-Host "TCP $UatSqlPort reachable: $($uatTcp.TcpTestSucceeded)" -ForegroundColor $(if ($uatTcp.TcpTestSucceeded) {'Green'} else {'Red'})

$uatLoginOk = "SKIPPED (DNS/TCP failed)"
if ($uatDnsOk -and $uatTcp.TcpTestSucceeded) {
    if ($UatSqlPassword -ne "") {
        $uatPwSecure = ConvertTo-SecureString $UatSqlPassword -AsPlainText -Force
    } else {
        $uatPwSecure = Read-Host "Enter SQL login password for UAT user '$UatSqlUser'" -AsSecureString
    }
    Write-Host "Testing SQL connection (cancels at ${LoginTimeoutSec}s if it hangs)..." -ForegroundColor DarkGray
    $uatResult = Invoke-SqlConnectionTest -SqlHost $UatSqlHost -SqlPort $UatSqlPort -SqlDatabase $UatSqlDatabase -SqlUser $UatSqlUser -SqlPassword $uatPwSecure -TimeoutSec $LoginTimeoutSec
    Write-Host $uatResult.Output
    $uatLoginOk = $uatResult.Status
} else {
    Write-Host "Skipping login test - DNS or TCP failed above, login would just time out." -ForegroundColor Yellow
}

$results += [PSCustomObject]@{ ScriptVersion=$ScriptVersion; Server=$ServerLabel; Env="UAT"; DNS=$(if($uatDnsOk){"OK"}else{"FAIL"}); TCP=$uatTcp.TcpTestSucceeded; Login=$uatLoginOk }

# ============================================================
# SECTION 3 - summary
# ============================================================
Write-Host "`n=== Section 3: Summary (server: $ServerLabel, script version: $ScriptVersion, public IP: $publicIp, private IP: $privateIp) ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize

Write-Host "`nCopy this row into docs/discovery/workflow-traffic-analysis-guide.md's server-comparison table:" -ForegroundColor Yellow
Write-Host "| $ServerLabel | $ScriptVersion | $publicIp | $(if($prodDnsOk){'OK'}else{'FAIL'}) | $(if($uatDnsOk){'OK'}else{'FAIL'}) | $($uatTcp.TcpTestSucceeded) | $uatLoginOk |"
