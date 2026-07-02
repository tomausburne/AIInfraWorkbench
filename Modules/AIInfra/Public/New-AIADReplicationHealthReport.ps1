function New-AIADReplicationHealthReport {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $OutputPath,

        [Parameter()]
        [int]
        $WarnDeltaHours = 24,

        [Parameter()]
        [switch]
        $OpenReport
    )

    function Format-AITimeSpan {
        param([AllowNull()][object] $TimeSpan)

        if ($null -eq $TimeSpan) {
            return 'Never / Unknown'
        }

        $Span = [TimeSpan]$TimeSpan

        if ($Span.TotalDays -ge 1) {
            return '{0}d {1}h {2}m' -f [int]$Span.TotalDays, $Span.Hours, $Span.Minutes
        }

        return '{0}h {1}m' -f [int]$Span.TotalHours, $Span.Minutes
    }

    function ConvertTo-AIHtmlEncodedText {
        param([AllowNull()][object] $Value)

        if ($null -eq $Value) {
            return ''
        }

        return [System.Net.WebUtility]::HtmlEncode([string]$Value)
    }

    try {
        $Rows = @(Get-AIADReplicationHealth -WarnDeltaHours $WarnDeltaHours)

        if ([string]::IsNullOrWhiteSpace($OutputPath)) {
            $ProjectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
            $ReportFolder = Join-Path $ProjectRoot 'Reports'

            if (-not (Test-Path $ReportFolder)) {
                New-Item -Path $ReportFolder -ItemType Directory -Force | Out-Null
            }

            $Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $OutputPath = Join-Path $ReportFolder "ADReplicationHealth-$Timestamp.html"
        }

        $OutputDirectory = Split-Path -Parent $OutputPath
        if ($OutputDirectory -and -not (Test-Path $OutputDirectory)) {
            New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
        }

        $SummaryRows = foreach ($Group in ($Rows | Group-Object DomainController)) {
            $DcRows = @($Group.Group)
            $FailingRows = @($DcRows | Where-Object { $_.Status -eq 'Failing' })
            $WarningRows = @($DcRows | Where-Object { $_.Status -eq 'Warning' })
            $OldestDelta = @($DcRows | Where-Object { $_.TimeSinceLastSuccess } | Sort-Object TimeSinceLastSuccess -Descending | Select-Object -First 1)
            $LastSuccess = @($DcRows | Where-Object { $_.LastReplicationSuccess } | Sort-Object LastReplicationSuccess -Descending | Select-Object -First 1)

            $Status = 'Healthy'
            if ($FailingRows.Count -gt 0) {
                $Status = 'Failing'
            }
            elseif ($WarningRows.Count -gt 0) {
                $Status = 'Warning'
            }

            [pscustomobject]@{
                DomainController      = $Group.Name
                Domain                = ($DcRows | Select-Object -First 1).Domain
                Site                  = ($DcRows | Select-Object -First 1).Site
                OperatingSystem       = ($DcRows | Select-Object -First 1).OperatingSystem
                Status                = $Status
                ReplicationPartners   = $DcRows.Count
                FailingLinks          = $FailingRows.Count
                WarningLinks          = $WarningRows.Count
                TotalConsecutiveFails = ($DcRows | Measure-Object ConsecutiveFailures -Sum).Sum
                MaxConsecutiveFails   = ($DcRows | Measure-Object ConsecutiveFailures -Maximum).Maximum
                LongestCurrentDelta   = if ($OldestDelta) { $OldestDelta[0].TimeSinceLastSuccess } else { $null }
                MostRecentSuccess     = if ($LastSuccess) { $LastSuccess[0].LastReplicationSuccess } else { $null }
            }
        }

        $HealthyCount = @($SummaryRows | Where-Object { $_.Status -eq 'Healthy' }).Count
        $WarningCount = @($SummaryRows | Where-Object { $_.Status -eq 'Warning' }).Count
        $FailingCount = @($SummaryRows | Where-Object { $_.Status -eq 'Failing' }).Count
        $TotalDcCount = @($SummaryRows).Count
        $Generated = Get-Date

        $Css = @'
<style>
body { font-family: Segoe UI, Arial, sans-serif; color: #1f2933; margin: 24px; background: #f6f8fb; }
h1, h2 { margin-bottom: 8px; }
.meta { color: #52606d; margin-bottom: 20px; }
.cards { display: grid; grid-template-columns: repeat(4, minmax(150px, 1fr)); gap: 12px; margin: 18px 0 24px; }
.card { background: white; border: 1px solid #d9e2ec; border-radius: 6px; padding: 14px; }
.card .number { font-size: 30px; font-weight: 700; margin-top: 6px; }
.healthy { color: #0b7a3b; font-weight: 700; }
.warning { color: #9a6700; font-weight: 700; }
.failing { color: #b42318; font-weight: 700; }
table { border-collapse: collapse; width: 100%; background: white; margin-bottom: 28px; border: 1px solid #d9e2ec; }
th, td { padding: 8px 10px; border-bottom: 1px solid #e4e7eb; text-align: left; vertical-align: top; font-size: 13px; }
th { background: #eaf0f6; font-weight: 700; }
tr.failrow { background: #fff1f0; }
tr.warnrow { background: #fff8e6; }
.small { font-size: 12px; color: #52606d; }
</style>
'@

        $SummaryHtmlRows = foreach ($Row in $SummaryRows) {
            $StatusClass = $Row.Status.ToLowerInvariant()
            $RowClass = ''
            if ($Row.Status -eq 'Failing') { $RowClass = 'failrow' }
            elseif ($Row.Status -eq 'Warning') { $RowClass = 'warnrow' }

@"
<tr class="$RowClass">
  <td>$(ConvertTo-AIHtmlEncodedText $Row.DomainController)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Row.Domain)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Row.Site)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Row.OperatingSystem)</td>
  <td class="$StatusClass">$(ConvertTo-AIHtmlEncodedText $Row.Status)</td>
  <td>$($Row.ReplicationPartners)</td>
  <td>$($Row.FailingLinks)</td>
  <td>$($Row.WarningLinks)</td>
  <td>$($Row.TotalConsecutiveFails)</td>
  <td>$($Row.MaxConsecutiveFails)</td>
  <td>$(Format-AITimeSpan $Row.LongestCurrentDelta)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Row.MostRecentSuccess)</td>
</tr>
"@
        }

        $DetailHtmlRows = foreach ($Row in ($Rows | Sort-Object DomainController, Status, Partition, Partner)) {
            $StatusClass = $Row.Status.ToLowerInvariant()
            $RowClass = ''
            if ($Row.Status -eq 'Failing') { $RowClass = 'failrow' }
            elseif ($Row.Status -eq 'Warning') { $RowClass = 'warnrow' }

@"
<tr class="$RowClass">
  <td>$(ConvertTo-AIHtmlEncodedText $Row.DomainController)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Row.Partner)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Row.Partition)</td>
  <td class="$StatusClass">$(ConvertTo-AIHtmlEncodedText $Row.Status)</td>
  <td>$($Row.ConsecutiveFailures)</td>
  <td>$(Format-AITimeSpan $Row.TimeSinceLastSuccess)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Row.LastReplicationSuccess)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Row.LastReplicationAttempt)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Row.LastReplicationResult)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Row.LastReplicationResultMessage)</td>
</tr>
"@
        }

        $Html = @"
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Active Directory Replication Health Report</title>
$Css
</head>
<body>
<h1>Active Directory Replication Health Report</h1>
<div class="meta">
Generated: <strong>$(ConvertTo-AIHtmlEncodedText $Generated)</strong><br>
Warning threshold: healthy links with a current replication delta over <strong>$WarnDeltaHours hours</strong> are marked Warning.
</div>

<div class="cards">
  <div class="card"><div>Total DCs</div><div class="number">$TotalDcCount</div></div>
  <div class="card"><div>Healthy</div><div class="number healthy">$HealthyCount</div></div>
  <div class="card"><div>Warning</div><div class="number warning">$WarningCount</div></div>
  <div class="card"><div>Failing</div><div class="number failing">$FailingCount</div></div>
</div>

<h2>Domain Controller Summary</h2>
<table>
<thead>
<tr>
  <th>Domain Controller</th>
  <th>Domain</th>
  <th>Site</th>
  <th>Operating System</th>
  <th>Status</th>
  <th>Partners</th>
  <th>Failing Links</th>
  <th>Warning Links</th>
  <th>Total Consecutive Fails</th>
  <th>Max Consecutive Fails</th>
  <th>Longest Current Delta</th>
  <th>Most Recent Success</th>
</tr>
</thead>
<tbody>
$($SummaryHtmlRows -join "`n")
</tbody>
</table>

<h2>Replication Partner Detail</h2>
<table>
<thead>
<tr>
  <th>Server</th>
  <th>Partner</th>
  <th>Partition</th>
  <th>Status</th>
  <th>Consecutive Fails</th>
  <th>Current Delta</th>
  <th>Last Success</th>
  <th>Last Attempt</th>
  <th>Result</th>
  <th>Result Message</th>
</tr>
</thead>
<tbody>
$($DetailHtmlRows -join "`n")
</tbody>
</table>

<div class="small">
Status is Failing when collection fails, LastReplicationResult is non-zero, or ConsecutiveReplicationFailures is greater than zero.
Current Delta is calculated as the time elapsed since LastReplicationSuccess.
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
        Write-Error "Failed to create AD replication health report. $($_.Exception.Message)"
    }
}