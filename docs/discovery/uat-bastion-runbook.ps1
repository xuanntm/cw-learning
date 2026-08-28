<#
.SYNOPSIS
  Run this ON the UAT/TRN VM (10.10.11.4) — not from your laptop. The SQL host
  does not resolve over public DNS (confirmed for the PROD host; UAT is assumed
  the same), so this only works from inside the network the VM sits on.

.DESCRIPTION
  Covers:
    Section 1 - re-verify the eAdaptor Next inbound Basic Auth credential (Track A prerequisite)
    Section 2 - DNS + TCP reachability check for the SQL Reporting DB host (Track B)
    Section 3 - sqlcmd connection test
    Section 4 - discover the real ProcessTask*-style table/column names
    Section 5 - draft template-usage traffic query (edit names from Section 4 before running)

  Nothing here is auto-executed end-to-end blind — Section 5's real query is commented
  out on purpose until Section 4 confirms real table/column names against your schema.

.NOTES
  - Requires `sqlcmd` installed on the VM (part of the "sqlcmd Utility" / SQL Server
    command line tools, or `mssql-cli`). If missing, install from the VM before running
    Section 3 onward, or substitute DBeaver/SSMS manually for those two sections.
  - You will be prompted for passwords interactively — nothing is hardcoded in this file.
  - SqlHost/SqlDatabase below are confirmed (2026-08-2x, three independent sources —
    see docs/discovery/workflow-traffic-analysis-guide.md Track B). SqlUser follows the
    confirmed per-person naming convention but still needs its real password from IT/DBA
    (last attempt got "Login failed for user", i.e. reachable but wrong/unissued password).
#>
param(
    [string]$EAdaptorHost = "H56TRNservices.wisegrid.net",
    [string]$EAdaptorUser = "HONEASHKG",

    [string]$SqlHost = "H56TRN.db.wisegrid.net",
    [int]$SqlPort = 1433,
    [string]$SqlDatabase = "OdysseyH56TRN",
    [string]$SqlUser = "EnterpriseDbUser_OdysseyH56TRN_H56.Spencer.Nguyen"
)

# ============================================================
# SECTION 1 - eAdaptor inbound auth check (re-verification)
# ============================================================
Write-Host "`n=== Section 1: eAdaptor inbound auth check ($EAdaptorHost) ===" -ForegroundColor Cyan
$eadaptorPwSecure = Read-Host "Enter eAdaptor inbound password for $EAdaptorUser" -AsSecureString
$eadaptorPwPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($eadaptorPwSecure))
$authToken = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$EAdaptorUser`:$eadaptorPwPlain"))

curl.exe --location --request POST "https://$EAdaptorHost/eAdaptorNext" `
  --header 'Accept: application/xml' `
  --header "Authorization: Basic $authToken" `
  --data '' -vvv

Write-Host "`nExpect 401 if the credential is still stale (see docs/backlog/eadaptor-inbound-auth-401.md), anything else if it's now working." -ForegroundColor Yellow

# ============================================================
# SECTION 2 - SQL Reporting DB reachability check
# ============================================================
Write-Host "`n=== Section 2: DNS + TCP reachability check for $SqlHost`:$SqlPort ===" -ForegroundColor Cyan
Resolve-DnsName -Name $SqlHost -ErrorAction SilentlyContinue
Test-NetConnection -ComputerName $SqlHost -Port $SqlPort -WarningAction SilentlyContinue |
    Select-Object ComputerName, RemoteAddress, RemotePort, TcpTestSucceeded

# ============================================================
# SECTION 3 - sqlcmd connection test
# ============================================================
Write-Host "`n=== Section 3: sqlcmd connection test ===" -ForegroundColor Cyan
$sqlPwSecure = Read-Host "Enter SQL login password for $SqlUser" -AsSecureString
$sqlPwPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sqlPwSecure))

# -C = trust server certificate (common requirement for internal CargoWise SQL hosts)
sqlcmd -S "$SqlHost,$SqlPort" -d $SqlDatabase -U $SqlUser -P $sqlPwPlain -C -Q "SELECT @@VERSION;"

# ============================================================
# SECTION 4 - discover ProcessTask*-style tables
# ============================================================
Write-Host "`n=== Section 4: discover ProcessTask*/WorkflowTemplate*-related tables ===" -ForegroundColor Cyan
$discoverQuery = @"
SELECT TABLE_SCHEMA, TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_NAME LIKE 'ProcessTask%'
   OR TABLE_NAME LIKE '%WorkflowTemplate%'
ORDER BY TABLE_NAME;
"@
sqlcmd -S "$SqlHost,$SqlPort" -d $SqlDatabase -U $SqlUser -P $sqlPwPlain -C -Q $discoverQuery

Write-Host "`nAlso worth running once you see real table names:" -ForegroundColor Yellow
Write-Host @"
SELECT COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = '<real table name from above>'
ORDER BY ORDINAL_POSITION;
"@ -ForegroundColor Yellow

# ============================================================
# SECTION 5 - draft template usage traffic query
# Table name confirmed 2026-08-28 via real schema discovery (query against
# INFORMATION_SCHEMA.TABLES on the PROD DB): it's `ProcessTasks` (plural),
# not `ProcessTask`. Column names (SourceTemplateID, ActualDateUtc, PK) are
# STILL GUESSES - confirm with INFORMATION_SCHEMA.COLUMNS on ProcessTasks
# and ProcessTaskTemplate before running this for real.
# ============================================================
Write-Host "`n=== Section 5: draft template-usage traffic query (CONFIRM COLUMN NAMES FIRST) ===" -ForegroundColor Cyan
$trafficQuery = @"
SELECT
    tpl.Name AS TemplateName,
    COUNT(*) AS FiredCount
FROM ProcessTasks pt                                            -- confirmed real table name (2026-08-28)
JOIN ProcessTaskTemplate tpl ON pt.SourceTemplateID = tpl.PK    -- CONFIRM real FK column name (still a guess)
WHERE pt.ActualDateUtc >= DATEADD(month, -1, GETUTCDATE())      -- or CompletedTimeUtc, whichever is populated
GROUP BY tpl.Name
ORDER BY FiredCount DESC;
"@
Write-Host $trafficQuery -ForegroundColor Yellow
Write-Host "Not auto-run. Once column names are confirmed via INFORMATION_SCHEMA.COLUMNS, uncomment the line below (or paste the corrected query) and re-run." -ForegroundColor Yellow
# sqlcmd -S "$SqlHost,$SqlPort" -d $SqlDatabase -U $SqlUser -P $sqlPwPlain -C -Q $trafficQuery
