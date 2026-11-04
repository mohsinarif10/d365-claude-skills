<#
.SYNOPSIS
    Exports the complete audit history for one Dataverse table to JSONL. READ-ONLY.

.DESCRIPTION
    Written to preserve audit evidence before a deletion job removes it.
    Pages through the audit table via the Web API and writes one JSON object
    per line, including the changedata payload (the old/new values).
    A manifest with record count, filter and SHA-256 is written alongside.

    Nothing is modified.

.EXAMPLE
    .\Export-DataverseAuditTable.ps1 -Url https://contoso.crm.dynamics.com -Table account
    .\Export-DataverseAuditTable.ps1 -Url https://contoso.crm.dynamics.com -Table contact -Before 2025-01-01
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Url,

    [Parameter(Mandatory)]
    [string]$Table,

    # Optional: only export records created before this date (yyyy-MM-dd)
    [string]$Before,

    [string]$OutputDir,

    [int]$PageSize = 5000
)

$ErrorActionPreference = 'Stop'
$url = $Url.TrimEnd('/')
$orgHost = ([uri]$url).Host.Split('.')[0]

if (-not $OutputDir) { $OutputDir = Join-Path (Get-Location).Path 'audit-exports' }
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }

function Get-Headers {
    param([int]$Page = $PageSize)
    $tok = az account get-access-token --resource $url --query accessToken -o tsv
    if (-not $tok) { throw "No token for $url. Run: az login --tenant <tenant> --allow-no-subscriptions" }
    @{
        Authorization = "Bearer $tok"
        Accept        = 'application/json'
        Prefer        = "odata.include-annotations=`"*`",odata.maxpagesize=$Page"
    }
}

$stamp   = Get-Date
$outFile = Join-Path $OutputDir ("audit-{0}-{1}-{2}.jsonl" -f $orgHost, $Table, $stamp.ToString('yyyyMMdd-HHmm'))

$select = 'auditid,createdon,operation,action,attributemask,changedata,transactionid,objecttypecode,_objectid_value,_userid_value,_callinguserid_value,timetoliveinseconds'
$filter = "objecttypecode eq '$Table'"
if ($Before) { $filter += " and createdon lt ${Before}T00:00:00Z" }

$next   = "$url/api/data/v9.2/audits?`$select=$select&`$filter=$([uri]::EscapeDataString($filter))"
$h      = Get-Headers
$total  = 0
$page   = 0
$sw     = [System.Diagnostics.Stopwatch]::StartNew()

Write-Host "Table       : $Table" -ForegroundColor Cyan
Write-Host "Environment : $url"
if ($Before) { Write-Host "Filter      : created before $Before" }
Write-Host "Output      : $outFile"
Write-Host ''

$writer = [System.IO.StreamWriter]::new($outFile, $false, [System.Text.UTF8Encoding]::new($false))
try {
    while ($next) {
        $page++
        if ($page % 10 -eq 0) { $h = Get-Headers }   # refresh token on long runs

        $resp = Invoke-RestMethod -Uri $next -Headers $h -TimeoutSec 600
        foreach ($rec in $resp.value) {
            $writer.WriteLine(($rec | ConvertTo-Json -Depth 4 -Compress))
            $total++
        }
        $next = $resp.'@odata.nextLink'

        if ($page % 5 -eq 0 -or -not $next) {
            Write-Host ("  page {0,4}  rows {1,10:N0}  elapsed {2}" -f $page, $total, $sw.Elapsed.ToString('mm\:ss'))
        }
    }
}
finally {
    $writer.Close()
}

$sw.Stop()
$sizeMB = (Get-Item $outFile).Length / 1MB

Write-Host ''
Write-Host 'Export complete' -ForegroundColor Green
'{0,-22} {1}'      -f 'Table',       $Table
'{0,-22} {1:N0}'   -f 'Records',     $total
'{0,-22} {1:N1} MB' -f 'File size',  $sizeMB
'{0,-22} {1}'      -f 'Duration',    $sw.Elapsed.ToString('hh\:mm\:ss')
'{0,-22} {1}'      -f 'File',        $outFile

# integrity marker so the export can be shown to be complete and unaltered
$hash = (Get-FileHash $outFile -Algorithm SHA256).Hash
$manifest = [PSCustomObject]@{
    Table       = $Table
    Url         = $url
    ExportedAt  = $stamp.ToString('o')
    FilterUsed  = $filter
    RecordCount = $total
    FileName    = Split-Path -Leaf $outFile
    FileSizeMB  = [math]::Round($sizeMB, 2)
    SHA256      = $hash
}
$manifestFile = [System.IO.Path]::ChangeExtension($outFile, 'manifest.json')
$manifest | ConvertTo-Json | Out-File $manifestFile -Encoding utf8
'{0,-22} {1}' -f 'SHA256', $hash
'{0,-22} {1}' -f 'Manifest', $manifestFile
