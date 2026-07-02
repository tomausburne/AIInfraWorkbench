function New-AIADDnsResolutionReport {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $OutputPath,

        [Parameter()]
        [string]
        $DnsServer,

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
        $TestParams = @{}
        if (-not [string]::IsNullOrWhiteSpace($DnsServer)) {
            $TestParams['DnsServer'] = $DnsServer
        }

        $Rows = @(Test-AIADDnsResolution @TestParams)

        if ([string]::IsNullOrWhiteSpace($OutputPath)) {
            $ProjectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
            $ReportFolder = Join-Path $ProjectRoot 'Reports'

            if (-not (Test-Path $ReportFolder)) {
                New-Item -Path $ReportFolder -ItemType Directory -Force | Out-Null
            }

            $Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $OutputPath = Join-Path $ReportFolder "ADDnsResolution-$Timestamp.html"
        }

        $OutputDirectory = Split-Path -Parent $OutputPath
        if ($OutputDirectory -and -not (Test-Path $OutputDirectory)) {
            New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
        }

        $PassCount = @($Rows | Where-Object { $_.Status -eq 'Pass' }).Count
        $WarningCount = @($Rows | Where-Object { $_.Status -eq 'Warning' }).Count
        $FailCount = @($Rows | Where-Object { $_.Status -eq 'Fail' }).Count
        $Generated = Get-Date

        $Css = @'
<style>
body { font-family: Segoe UI, Arial, sans-serif; color: #1f2933; margin: 24px; background: #f6f8fb; }
h1, h2 { margin-bottom: 8px; }
.meta { color: #52606d; margin-bottom: 20px; }
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

        $DetailRows = foreach ($Row in ($Rows | Sort-Object Status, RecordType, QueryName)) {
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
  <td>$(ConvertTo-AIHtmlEncodedText $Row.QueryName)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Row.RecordType)</td>
  <td class="$StatusClass">$(ConvertTo-AIHtmlEncodedText $Row.Status)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Row.ResultCount)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Row.Results)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Row.ExpectedTarget)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Row.Description)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Row.Error)</td>
</tr>
"@
        }

        $DnsServerText = if ([string]::IsNullOrWhiteSpace($DnsServer)) { 'System default resolver' } else { $DnsServer }

        $Html = @"
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Active Directory DNS Resolution Report</title>
$Css
</head>
<body>
<h1>Active Directory DNS Resolution Report</h1>
<div class="meta">
Generated: <strong>$(ConvertTo-AIHtmlEncodedText $Generated)</strong><br>
DNS resolver: <strong>$(ConvertTo-AIHtmlEncodedText $DnsServerText)</strong><br>
Scope: Client-side validation only. This report does not inspect or modify DNS server configuration.
</div>

<div class="cards">
  <div class="card"><div>Total Checks</div><div class="number">$($Rows.Count)</div></div>
  <div class="card"><div>Pass</div><div class="number pass">$PassCount</div></div>
  <div class="card"><div>Warning</div><div class="number warning">$WarningCount</div></div>
  <div class="card"><div>Fail</div><div class="number fail">$FailCount</div></div>
</div>

<h2>DNS Resolution Checks</h2>
<table>
<thead>
<tr>
  <th>Query Name</th>
  <th>Type</th>
  <th>Status</th>
  <th>Result Count</th>
  <th>Results</th>
  <th>Expected Target</th>
  <th>Description</th>
  <th>Error</th>
</tr>
</thead>
<tbody>
$($DetailRows -join "`n")
</tbody>
</table>

<div class="small">
This report validates whether Active Directory DNS records resolve from the machine running the Workbench.
It is suitable for environments using Infoblox or another non-Microsoft DNS platform where DNS server configuration access is not available.
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
        Write-Error "Failed to create AD DNS resolution report. $($_.Exception.Message)"
    }
}