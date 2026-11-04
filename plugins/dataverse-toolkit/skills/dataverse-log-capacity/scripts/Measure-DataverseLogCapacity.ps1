<#
.SYNOPSIS
    Captures a Dataverse audit/log capacity snapshot. READ-ONLY.

.DESCRIPTION
    Run before a cleanup, then again at T+0, T+24h and T+72h.
    Writes a timestamped JSON snapshot and prints a summary table.
    Compare two snapshots with -CompareWith.

    Nothing is modified. Every call is a read:
      - organizations            (audit settings)
      - RetrieveTotalRecordCount (row counts)
      - GetAuditStorageDetails   (audit storage per table)
      - audit aggregate counts   (row totals)

.EXAMPLE
    .\Measure-DataverseLogCapacity.ps1 -Url https://contoso.crm.dynamics.com
    .\Measure-DataverseLogCapacity.ps1 -Url https://contoso.crm.dynamics.com -CompareWith .\snapshots\logcap-contoso-20260101-0900.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Url,

    [string]$OutputDir,

    [string]$CompareWith
)

$ErrorActionPreference = 'Stop'
$url = $Url.TrimEnd('/')
$orgHost = ([uri]$url).Host.Split('.')[0]

if (-not $OutputDir) { $OutputDir = Join-Path (Get-Location).Path 'snapshots' }

function Get-Headers {
    $tok = az account get-access-token --resource $url --query accessToken -o tsv
    if (-not $tok) { throw "Could not get a token for $url. Run: az login --tenant <tenant> --allow-no-subscriptions" }
    @{
        Authorization  = "Bearer $tok"
        Accept         = 'application/json'
        'Content-Type' = 'application/json; charset=utf-8'
    }
}

Write-Host "Environment : $url" -ForegroundColor Cyan
$h = Get-Headers

# --- 1. audit settings -------------------------------------------------------
Write-Host 'Reading organisation settings...' -ForegroundColor DarkGray
$sel = 'name,isauditenabled,isuseraccessauditenabled,auditretentionperiodv2,plugintracelogsetting'
$org = (Invoke-RestMethod -Uri "$url/api/data/v9.2/organizations?`$select=$sel" -Headers $h).value[0]

# --- 2. row counts -----------------------------------------------------------
Write-Host 'Reading row counts...' -ForegroundColor DarkGray
$rc = Invoke-RestMethod -Headers $h -TimeoutSec 300 `
    -Uri "$url/api/data/v9.2/RetrieveTotalRecordCount(EntityNames=['asyncoperation','plugintracelog','workflowlog'])"
$counts = @{}
for ($i = 0; $i -lt $rc.EntityRecordCountCollection.Keys.Count; $i++) {
    $counts[$rc.EntityRecordCountCollection.Keys[$i]] = $rc.EntityRecordCountCollection.Values[$i]
}

# --- 3. audit row total ------------------------------------------------------
Write-Host 'Counting audit rows...' -ForegroundColor DarkGray
$fx = "<fetch aggregate='true'><entity name='audit'><attribute name='auditid' aggregate='count' alias='c'/></entity></fetch>"
$auditRows = try {
    [long](Invoke-RestMethod -Headers $h -TimeoutSec 900 `
        -Uri "$url/api/data/v9.2/audits?fetchXml=$([uri]::EscapeDataString($fx))").value[0].c
} catch { -1 }   # aggregate limit (50,000) or timeout on very large tables

# --- 4. audit date range -----------------------------------------------------
$oldest = try {
    (Invoke-RestMethod -Headers $h -TimeoutSec 300 `
        -Uri "$url/api/data/v9.2/audits?`$select=createdon&`$orderby=createdon asc&`$top=1").value[0].createdon
} catch { $null }

# --- 5. audit storage per table (async - poll until Completed) ---------------
Write-Host 'Requesting audit storage details (may take a few minutes)...' -ForegroundColor DarkGray
$detail = $null
for ($i = 1; $i -le 60; $i++) {
    $h = Get-Headers   # refresh token on long runs
    $r = Invoke-RestMethod -Uri "$url/api/data/v9.2/GetAuditStorageDetails" -Method Post -Headers $h -Body '{}' -TimeoutSec 300
    if ($r.Result.Status -notin @('Pending','InProgress')) { $detail = $r.Result; break }
    Write-Host "  $($r.Result.Status) ... attempt $i" -ForegroundColor DarkGray
    Start-Sleep -Seconds 30
}
if (-not $detail) { throw 'GetAuditStorageDetails did not complete in time.' }

$tables = for ($i = 0; $i -lt $detail.AuditStorageDetails.Count; $i++) {
    [PSCustomObject]@{
        Table = $detail.AuditStorageDetails.Keys[$i]
        Otc   = [int]$detail.AuditStorageDetails.Values[$i].ObjectTypeCode
        Bytes = [double]$detail.AuditStorageDetails.Values[$i].SizeInBytes
    }
}
$totalBytes = ($tables | Measure-Object Bytes -Sum).Sum

# --- snapshot ----------------------------------------------------------------
$stamp = Get-Date
$snapshot = [PSCustomObject]@{
    TakenAt                = $stamp.ToString('o')
    Url                    = $url
    AuditStorageBytes      = $totalBytes
    AuditStorageGB         = [math]::Round($totalBytes / 1GB, 3)
    AuditRows              = $auditRows
    OldestAuditRecord      = $oldest
    TablesWithAuditData    = $tables.Count
    IsAuditEnabled         = $org.isauditenabled
    IsUserAccessAudit      = $org.isuseraccessauditenabled
    AuditRetentionDays     = $org.auditretentionperiodv2
    PluginTraceLogSetting  = $org.plugintracelogsetting
    AsyncOperationRows     = $counts['asyncoperation']
    PluginTraceLogRows     = $counts['plugintracelog']
    WorkflowLogRows        = $counts['workflowlog']
    Tables                 = $tables
}

if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }
$file = Join-Path $OutputDir ("logcap-{0}-{1}.json" -f $orgHost, $stamp.ToString('yyyyMMdd-HHmm'))
$snapshot | ConvertTo-Json -Depth 6 | Out-File $file -Encoding utf8

# --- output ------------------------------------------------------------------
Write-Host ''
Write-Host "==== $orgHost snapshot  $($stamp.ToString('yyyy-MM-dd HH:mm')) ====" -ForegroundColor Cyan
'{0,-26} {1,16}' -f 'Audit storage (GB)',   $snapshot.AuditStorageGB
'{0,-26} {1,16:N0}' -f 'Audit rows',          $snapshot.AuditRows
'{0,-26} {1,16}' -f 'Oldest audit record',  $(if ($oldest) { $oldest.Substring(0,10) } else { 'n/a' })
'{0,-26} {1,16}' -f 'Tables with audit data', $snapshot.TablesWithAuditData
'{0,-26} {1,16}' -f 'Retention (days)',     $(if ($null -eq $org.auditretentionperiodv2) { 'null = Forever' } else { $org.auditretentionperiodv2 })
'{0,-26} {1,16}' -f 'Plug-in trace setting', $org.plugintracelogsetting
'{0,-26} {1,16:N0}' -f 'asyncoperation rows', $snapshot.AsyncOperationRows
'{0,-26} {1,16:N0}' -f 'plugintracelog rows', $snapshot.PluginTraceLogRows
'{0,-26} {1,16:N0}' -f 'workflowlog rows',    $snapshot.WorkflowLogRows
Write-Host ''
Write-Host 'Top 10 tables by audit storage' -ForegroundColor Cyan
'{0,-32} {1,10} {2,8}' -f 'Table','GB','Share'
$tables | Sort-Object Bytes -Descending | Select-Object -First 10 | ForEach-Object {
    '{0,-32} {1,10:N2} {2,7:N2}%' -f $_.Table, ($_.Bytes / 1GB), ($_.Bytes / $totalBytes * 100)
}
Write-Host ''
Write-Host "Saved: $file" -ForegroundColor Green

# --- comparison --------------------------------------------------------------
if ($CompareWith) {
    if (-not (Test-Path $CompareWith)) { throw "Baseline not found: $CompareWith" }
    $base = Get-Content $CompareWith -Raw | ConvertFrom-Json
    $freedGB   = $base.AuditStorageGB - $snapshot.AuditStorageGB
    $freedRows = $base.AuditRows - $snapshot.AuditRows

    Write-Host ''
    Write-Host '==== BEFORE / AFTER ====' -ForegroundColor Yellow
    '{0,-22} {1,14} {2,14} {3,14}' -f 'Measure','Before','After','Reclaimed'
    '{0,-22} {1,14} {2,14} {3,14}' -f ('-'*22),('-'*14),('-'*14),('-'*14)
    '{0,-22} {1,14:N2} {2,14:N2} {3,14:N2}' -f 'Audit storage (GB)', $base.AuditStorageGB, $snapshot.AuditStorageGB, $freedGB
    '{0,-22} {1,14:N0} {2,14:N0} {3,14:N0}' -f 'Audit rows', $base.AuditRows, $snapshot.AuditRows, $freedRows
    if ($base.AuditStorageGB -gt 0) {
        '{0,-22} {1,14} {2,14} {3,13:N1}%' -f 'Share reclaimed','','', ($freedGB / $base.AuditStorageGB * 100)
    }
    Write-Host ''
    Write-Host 'Baseline taken: ' -NoNewline; Write-Host $base.TakenAt -ForegroundColor DarkGray
    Write-Host 'NOTE: capacity figures can lag up to 72 hours after a delete job completes.' -ForegroundColor Yellow
}
