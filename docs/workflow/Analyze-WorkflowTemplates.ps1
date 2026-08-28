<#
.SYNOPSIS
  Analyze one CargoWise ProcessTaskTemplate (Workflow Template) Native XML export,
  or diff two of them (e.g. Non-Prod vs Prod).

.DESCRIPTION
  This is the script used to produce docs/workflow/workflow-templates-analysis.md
  and docs/discovery/prod-vs-uat-gap-analysis.md. Re-run it against fresh exports
  to refresh those findings.

.PARAMETER Path
  Path to a ProcessTaskTemplate Native XML export.

.PARAMETER ComparePath
  Optional second export to diff against Path (name-matched comparison).

.EXAMPLE
  .\Analyze-WorkflowTemplates.ps1 -Path "ProcessTaskTemplate x 55_....xml"

.EXAMPLE
  .\Analyze-WorkflowTemplates.ps1 -Path "ProcessTaskTemplate x 55_....xml" -ComparePath "PROD_ProcessTaskTemplate x 56_....xml"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $false)]
    [string]$ComparePath
)

function Get-TemplateSummary {
    param([string]$XmlPath)

    [xml]$xml = Get-Content -Path $XmlPath -Raw
    $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $ns.AddNamespace("n", "http://www.cargowise.com/Schemas/Native/2011/11")

    $owner = $xml.SelectSingleNode("//n:Header/n:OwnerCode", $ns).InnerText
    $templates = $xml.SelectNodes("//n:ProcessTaskTemplate", $ns)

    $rows = foreach ($t in $templates) {
        $tasks = $t.SelectNodes(".//n:ProcessTasksCollection/n:ProcessTasks", $ns)
        $typeGroups = ($tasks | ForEach-Object { $_.Type } | Group-Object | Sort-Object Name)
        $typeSummary = ($typeGroups | ForEach-Object { "$($_.Name):$($_.Count)" }) -join ","

        [PSCustomObject]@{
            Name          = $t.Name.Trim()
            ProcessType   = $t.ProcessType
            IsActive      = $t.IsActive
            IsSystem      = $t.IsSystem
            IsUniversal   = $t.IsUniversal
            IsPartial     = $t.IsPartialTemplate
            MilestoneFB   = $t.MilestoneFallbackMethod
            TaskFB        = $t.TaskFallbackMethod
            TriggerFB     = $t.TriggerFallbackMethod
            SubType1      = $t.SubType1
            SubType2      = $t.SubType2
            TaskCount     = $tasks.Count
            TypeBreakdown = $typeSummary
        }
    }

    $allTasks = $xml.SelectNodes("//n:ProcessTasksCollection/n:ProcessTasks", $ns)
    $notifs = $xml.SelectNodes(
        "//n:ProcessTaskNotification_RegularTriggersCollection/n:ProcessTaskNotification_RegularTriggers | " +
        "//n:ProcessTaskNotification_UniversalTriggersCollection/n:ProcessTaskNotification_UniversalTriggers", $ns)

    return [PSCustomObject]@{
        Owner     = $owner
        Rows      = $rows
        AllTasks  = $allTasks
        Notifs    = $notifs
    }
}

function Show-SingleAnalysis {
    param($Summary, [string]$Label)

    Write-Host "`n########## $Label (OwnerCode: $($Summary.Owner)) ##########" -ForegroundColor Cyan

    Write-Host "`nTotal templates: $($Summary.Rows.Count)"
    Write-Host "IsActive=false: $(@($Summary.Rows | Where-Object { $_.IsActive -eq 'false' }).Count)"
    Write-Host "IsSystem=true (CW default): $(@($Summary.Rows | Where-Object { $_.IsSystem -eq 'true' }).Count)"
    Write-Host "IsSystem=false (custom): $(@($Summary.Rows | Where-Object { $_.IsSystem -eq 'false' }).Count)"
    Write-Host "IsUniversal=true: $(@($Summary.Rows | Where-Object { $_.IsUniversal -eq 'true' }).Count)"
    Write-Host "IsPartialTemplate=true: $(@($Summary.Rows | Where-Object { $_.IsPartial -eq 'true' }).Count)"

    Write-Host "`n--- Process Type distribution ---"
    $Summary.Rows | ForEach-Object { $_.ProcessType } | Group-Object | Sort-Object Count -Descending |
        Format-Table Name, Count -AutoSize

    Write-Host "--- Item type breakdown (all Tasks/Milestones/Triggers) ---"
    Write-Host "Total items: $($Summary.AllTasks.Count)"
    $Summary.AllTasks | ForEach-Object { $_.Type } | Group-Object | Sort-Object Count -Descending |
        Format-Table Name, Count -AutoSize

    Write-Host "--- Trigger notification TriggerType breakdown ---"
    Write-Host "Total notification rows: $($Summary.Notifs.Count)"
    $Summary.Notifs | ForEach-Object { $_.TriggerType } | Group-Object | Sort-Object Count -Descending |
        Format-Table Name, Count -AutoSize

    Write-Host "--- Universal templates (auto-apply broadly - check Trigger Fallback for NFB+0-items risk) ---"
    $Summary.Rows | Where-Object { $_.IsUniversal -eq 'true' } |
        Format-Table Name, ProcessType, TaskCount, TriggerFB -AutoSize

    Write-Host "--- Empty templates (0 items) ---"
    $Summary.Rows | Where-Object { $_.TaskCount -eq 0 } |
        Format-Table Name, ProcessType, IsSystem, IsUniversal, TriggerFB -AutoSize

    Write-Host "--- Top 10 heaviest templates ---"
    $Summary.Rows | Sort-Object TaskCount -Descending | Select-Object -First 10 |
        Format-Table Name, ProcessType, TaskCount -AutoSize
}

function Show-Diff {
    param($SummaryA, [string]$LabelA, $SummaryB, [string]$LabelB)

    Write-Host "`n########## DIFF: $LabelA  vs  $LabelB ##########" -ForegroundColor Cyan
    if ($SummaryA.Owner -ne $SummaryB.Owner) {
        Write-Host "WARNING: OwnerCode differs ($($SummaryA.Owner) vs $($SummaryB.Owner)) - confirm these exports are the same entity before trusting this diff." -ForegroundColor Yellow
    }

    $aByName = @{}
    foreach ($r in $SummaryA.Rows) { $aByName[$r.Name] = $r }
    $bByName = @{}
    foreach ($r in $SummaryB.Rows) { $bByName[$r.Name] = $r }

    $onlyInA = $SummaryA.Rows | Where-Object { -not $bByName.ContainsKey($_.Name) }
    $onlyInB = $SummaryB.Rows | Where-Object { -not $aByName.ContainsKey($_.Name) }
    $common = $SummaryA.Rows.Name | Where-Object { $bByName.ContainsKey($_) }

    Write-Host "`n--- Only in $LabelA ($($onlyInA.Count)) ---"
    $onlyInA | Sort-Object ProcessType, Name | Format-Table Name, ProcessType, TaskCount, TriggerFB -AutoSize

    Write-Host "--- Only in $LabelB ($($onlyInB.Count)) ---"
    $onlyInB | Sort-Object ProcessType, Name | Format-Table Name, ProcessType, TaskCount, TriggerFB -AutoSize

    Write-Host "--- Drift on common templates ($($common.Count) common; showing only where something differs) ---"
    $drift = foreach ($name in $common) {
        $a = $aByName[$name]; $b = $bByName[$name]
        $diffs = @()
        foreach ($field in @('IsActive', 'IsSystem', 'IsUniversal', 'IsPartial', 'MilestoneFB', 'TaskFB', 'TriggerFB', 'TaskCount', 'TypeBreakdown')) {
            if ($a.$field -ne $b.$field) {
                $diffs += "$field`: $LabelA=$($a.$field) | $LabelB=$($b.$field)"
            }
        }
        if ($diffs.Count -gt 0) {
            [PSCustomObject]@{ Name = $name; ProcessType = $a.ProcessType; Diffs = ($diffs -join " || ") }
        }
    }
    Write-Host "Templates with drift: $($drift.Count)"
    $drift | Sort-Object ProcessType, Name | Format-Table Name, Diffs -AutoSize -Wrap
}

# ---- main ----
$labelA = Split-Path -Leaf $Path
$summaryA = Get-TemplateSummary -XmlPath $Path
Show-SingleAnalysis -Summary $summaryA -Label $labelA

if ($ComparePath) {
    $labelB = Split-Path -Leaf $ComparePath
    $summaryB = Get-TemplateSummary -XmlPath $ComparePath
    Show-SingleAnalysis -Summary $summaryB -Label $labelB
    Show-Diff -SummaryA $summaryA -LabelA $labelA -SummaryB $summaryB -LabelB $labelB
}
