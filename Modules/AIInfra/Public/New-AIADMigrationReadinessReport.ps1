function New-AIADMigrationReadinessReport {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $OutputPath,

        [Parameter()]
        [int]
        $WarnDeltaHours = 24,

        [Parameter()]
        [string]
        $DnsServer,

        [Parameter()]
        [switch]
        $SkipDnsChecks,

        [Parameter()]
        [switch]
        $SkipReplicationPortCheck,

        [Parameter()]
        [switch]
        $OpenReport
    )

    function ConvertTo-AIHtmlEncodedText {
        param([AllowNull()][object] $Value)

        if ($null -eq $Value) {
            return ''
        }

        return [System.Net.WebUtility]::HtmlEncode([string]$Value)
    }

    try {
        $ReadinessParams = @{
            WarnDeltaHours = $WarnDeltaHours
        }

        if (-not [string]::IsNullOrWhiteSpace($DnsServer)) {
            $ReadinessParams['DnsServer'] = $DnsServer
        }

        if ($SkipDnsChecks) {
            $ReadinessParams['SkipDnsChecks'] = $true
        }

        if ($SkipReplicationPortCheck) {
            $ReadinessParams['SkipReplicationPortCheck'] = $true
        }

        $Rows = @(Test-AIADMigrationReadiness @ReadinessParams)

        if ([string]::IsNullOrWhiteSpace($OutputPath)) {
            $ProjectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
            $ReportFolder = Join-Path $ProjectRoot 'Reports'

            if (-not (Test-Path $ReportFolder)) {
                New-Item -Path $ReportFolder -ItemType Directory -Force | Out-Null
            }

            $Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $OutputPath = Join-Path $ReportFolder "ADMigrationReadiness-$Timestamp.html"
        }

        $OutputDirectory = Split-Path -Parent $OutputPath
        if ($OutputDirectory -and -not (Test-Path $OutputDirectory)) {
            New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
        }

        $OverallReadiness = ($Rows | Select-Object -First 1).OverallReadiness
        $Generated = Get-Date

        $PassCount = @($Rows | Where-Object { $_.Status -eq 'Pass' }).Count
        $WarningCount = @($Rows | Where-Object { $_.Status -eq 'Warning' }).Count
        $FailCount = @($Rows | Where-Object { $_.Status -eq 'Fail' }).Count
        $BlockingCount = @($Rows | Where-Object { $_.Blocking -eq $true }).Count

        $OverallClass = 'ready'
        if ($OverallReadiness -eq 'Warning') {
            $OverallClass = 'warning'
        }
        elseif ($OverallReadiness -eq 'Blocked') {
            $OverallClass = 'blocked'
        }

        $Css = @'
<style>
body { font-family: Segoe UI, Arial, sans-serif; color: #1f2933; margin: 24px; background: #f6f8fb; }
h1, h2 { margin-bottom: 8px; }
.meta { color: #52606d; margin-bottom: 20px; }
.banner { background: white; border: 1px solid #d9e2ec; border-left-width: 10px; border-radius: 6px; padding: 18px; margin: 18px 0 24px; }
.banner.ready { border-left-color: #0b7a3b; }
.banner.warning { border-left-color: #9a6700; }
.banner.blocked { border-left-color: #b42318; }
.banner .status { font-size: 34px; font-weight: 800; margin-top: 4px; }
.ready-text { color: #0b7a3b; }
.warning-text { color: #9a6700; }
.blocked-text { color: #b42318; }
.cards { display: grid; grid-template-columns: repeat(4, minmax(150px, 1fr)); gap: 12px; margin: 18px 0 24px; }
.card { background: white; border: 1px solid #d9e2ec; border-radius: 6px; padding: 14px; }
.card .number { font-size: 30px; font-weight: 700; margin-top: 6px; }
.pass { color: #0b7a3b; font-weight: 700; }
.warning { color: #9a6700; font-weight: 700; }
.fail { color: #b42318; font-weight: 700; }
table { border-collapse: collapse; width: 100%; background: white; margin-bottom: 28px; border: 1px solid #d9e2ec; }
th, td { padding: 8px 10px; border-bottom: 1px solid #e4e7eb; text-align: left; vertical-align: top; font-size: 13px; }
th { background: #eaf0f6; font-weight: 700; }
tr.failrow { background: #fff1f0; }
tr.warnrow { background: #fff8e6; }
.small { font-size: 12px; color: #52606d; }
</style>
'@

        $DetailRows = foreach ($Row in ($Rows | Sort-Object Category, CheckName)) {
            $StatusClass = $Row.Status.ToLowerInvariant()
            $RowClass = ''

            if ($Row.Status -eq 'Fail') {
                $RowClass = 'failrow'
            }
            elseif ($Row.Status -eq 'Warning') {
                $RowClass = 'warnrow'
            }

@"
<tr class="$RowClass">
  <td>$(ConvertTo-AIHtmlEncodedText $Row.Category)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Row.CheckName)</td>
  <td class="$StatusClass">$(ConvertTo-AIHtmlEncodedText $Row.Status)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Row.Blocking)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Row.Summary)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Row.Details)</td>
</tr>
"@
        }

        $Html = @"
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>AD Migration Readiness Report</title>
$Css
</head>
<body>
<h1>Active Directory Migration Readiness Report</h1>
<div class="meta">
Generated: <strong>$(ConvertTo-AIHtmlEncodedText $Generated)</strong><br>
Warning threshold: replication links with current replication delta over <strong>$WarnDeltaHours hour(s)</strong> are marked Warning.
</div>

<div class="banner $OverallClass">
  <div>Overall Migration Readiness</div>
  <div class="status $OverallClass-text">$(ConvertTo-AIHtmlEncodedText $OverallReadiness)</div>
</div>

<div class="cards">
  <div class="card"><div>Passed Checks</div><div class="number pass">$PassCount</div></div>
  <div class="card"><div>Warnings</div><div class="number warning">$WarningCount</div></div>
  <div class="card"><div>Failures</div><div class="number fail">$FailCount</div></div>
  <div class="card"><div>Blocking Failures</div><div class="number fail">$BlockingCount</div></div>
</div>

<h2>Readiness Checks</h2>
<table>
<thead>
<tr>
  <th>Category</th>
  <th>Check</th>
  <th>Status</th>
  <th>Blocking</th>
  <th>Summary</th>
  <th>Details</th>
</tr>
</thead>
<tbody>
$($DetailRows -join "`n")
</tbody>
</table>

<div class="small">
This report is read-only. It combines domain controller inventory, FSMO role placement, AD replication health, and client-side AD DNS resolution checks.
</div>
</body>
</html>
"@

        $Html | Out-File -FilePath $OutputPath -Encoding UTF8

        if ($OpenReport) {
            Invoke-Item $OutputPath
        }

        Get-Item -Path $OutputPath
    }
    catch {
        Write-Error "Failed to create AD migration readiness report. $($_.Exception.Message)"
    }
}