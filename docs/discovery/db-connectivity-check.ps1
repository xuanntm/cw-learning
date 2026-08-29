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
  Section 1 - PROD: DNS resolution + TCP port check + real sqlcmd login (baseline —
              this already works from at least one known server, so a failure here on
              a *different* server tells you it's server/network-specific, not a PROD
              DB issue)
  Section 2 - UAT: same three checks against H56TRN.db.wisegrid.net
  Section 3 - summary table to eyeball pass/fail at a glance, and to copy into
              docs/discovery/workflow-traffic-analysis-guide.md afterward

.NOTES
  - Requires `sqlcmd` on the server. If missing, DNS/port sections still work — skip
    the login test or substitute DBeaver/SSMS.
  - You'll be prompted for both passwords interactively — nothing hardcoded.
  - Record which physical/named server you ran this from each time (hostname, or a
    label you choose) — that's the whole point of running it 3 times.
#>
param(
    [string]$ServerLabel = $env:COMPUTERNAME,

    [string]$ProdSqlHost = "H56PRD.db.wisegrid.net",
    [int]$ProdSqlPort = 1433,
    [string]$ProdSqlDatabase = "OdysseyH56PRD",
    [string]$ProdSqlUser = "",

    [string]$UatSqlHost = "H56TRN.db.wisegrid.net",
    [int]$UatSqlPort = 1433,
    [string]$UatSqlDatabase = "OdysseyH56TRN",
    [string]$UatSqlUser = "EnterpriseDbUser_OdysseyH56TRN_H56.Spencer.Nguyen"
)

$results = @()

Write-Host "`n=== Running from server: $ServerLabel ===" -ForegroundColor Magenta

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
    $prodPwSecure = Read-Host "Enter SQL login password for PROD user '$ProdSqlUser'" -AsSecureString
    $prodPwPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($prodPwSecure))
    $prodLoginResult = sqlcmd -S "$ProdSqlHost,$ProdSqlPort" -d $ProdSqlDatabase -U $ProdSqlUser -P $prodPwPlain -C -Q "SELECT @@VERSION;" 2>&1
    Write-Host $prodLoginResult
    $prodLoginOk = if ($LASTEXITCODE -eq 0) { "OK" } else { "FAILED" }
} else {
    Write-Host "No -ProdSqlUser given - skipping login test, DNS/TCP results above still valid." -ForegroundColor Yellow
}

$results += [PSCustomObject]@{ Server=$ServerLabel; Env="PROD"; DNS=$(if($prodDnsOk){"OK"}else{"FAIL"}); TCP=$prodTcp.TcpTestSucceeded; Login=$prodLoginOk }

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
    $uatPwSecure = Read-Host "Enter SQL login password for UAT user '$UatSqlUser'" -AsSecureString
    $uatPwPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($uatPwSecure))
    $uatLoginResult = sqlcmd -S "$UatSqlHost,$UatSqlPort" -d $UatSqlDatabase -U $UatSqlUser -P $uatPwPlain -C -Q "SELECT @@VERSION;" 2>&1
    Write-Host $uatLoginResult
    $uatLoginOk = if ($LASTEXITCODE -eq 0) { "OK" } else { "FAILED" }
} else {
    Write-Host "Skipping login test - DNS or TCP failed above, login would just time out." -ForegroundColor Yellow
}

$results += [PSCustomObject]@{ Server=$ServerLabel; Env="UAT"; DNS=$(if($uatDnsOk){"OK"}else{"FAIL"}); TCP=$uatTcp.TcpTestSucceeded; Login=$uatLoginOk }

# ============================================================
# SECTION 3 - summary
# ============================================================
Write-Host "`n=== Section 3: Summary (server: $ServerLabel, public IP: $publicIp, private IP: $privateIp) ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize

Write-Host "`nCopy this row into docs/discovery/workflow-traffic-analysis-guide.md's server-comparison table:" -ForegroundColor Yellow
Write-Host "| $ServerLabel | $publicIp | $(if($prodDnsOk){'OK'}else{'FAIL'}) | $(if($uatDnsOk){'OK'}else{'FAIL'}) | $($uatTcp.TcpTestSucceeded) | $uatLoginOk |"
