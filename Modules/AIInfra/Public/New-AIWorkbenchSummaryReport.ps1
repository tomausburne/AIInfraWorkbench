function New-AIWorkbenchSummaryReport {
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
        if ([string]::IsNullOrWhiteSpace($OutputPath)) {
            $ProjectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
            $ReportFolder = Join-Path $ProjectRoot 'Reports'

            if (-not (Test-Path $ReportFolder)) {
                New-Item -Path $ReportFolder -ItemType Directory -Force | Out-Null
            }

            $Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
            $OutputPath = Join-Path $ReportFolder "AIWorkbenchSummary-$Timestamp.html"
        }

        $OutputDirectory = Split-Path -Parent $OutputPath
        if ($OutputDirectory -and -not (Test-Path $OutputDirectory)) {
            New-Item -Path $OutputDirectory -ItemType Directory -Force | Out-Null
        }

        $Generated = Get-Date

        $ForestSummary = Get-AIForestSummary
        $DcInventory = @(Get-AIDomainControllerInventory)
        $FsmoRoles = @(Get-AIFSMORoleInventory)

        $ReplicationParams = @{
            WarnDeltaHours = $WarnDeltaHours
        }

        if ($SkipReplicationPortCheck) {
            $ReplicationParams['SkipPortCheck'] = $true
        }

        $ReplicationHealth = @(Get-AIADReplicationHealth @ReplicationParams)

        $DnsResults = @()
        if (-not $SkipDnsChecks) {
            $DnsParams = @{}

            if (-not [string]::IsNullOrWhiteSpace($DnsServer)) {
                $DnsParams['DnsServer'] = $DnsServer
            }

            $DnsResults = @(Test-AIADDnsResolution @DnsParams)
        }

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

        $Readiness = @(Test-AIADMigrationReadiness @ReadinessParams)
        $OverallReadiness = ($Readiness | Select-Object -First 1).OverallReadiness

        $Dc2016 = @($DcInventory | Where-Object { $_.IsWindowsServer2016 })
        $Dc2022 = @($DcInventory | Where-Object { $_.IsWindowsServer2022 })
        $FsmoOn2016 = @($FsmoRoles | Where-Object { $_.IsWindowsServer2016 })
        $FsmoOn2022 = @($FsmoRoles | Where-Object { $_.IsWindowsServer2022 })
        $ReplicationFailing = @($ReplicationHealth | Where-Object { $_.Status -eq 'Failing' })
        $ReplicationWarning = @($ReplicationHealth | Where-Object { $_.Status -eq 'Warning' })
        $DnsFailing = @($DnsResults | Where-Object { $_.Status -eq 'Fail' })
        $DnsWarning = @($DnsResults | Where-Object { $_.Status -eq 'Warning' })

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

        $DcRows = foreach ($Dc in ($DcInventory | Sort-Object HostName)) {
            $RowClass = ''
            if ($Dc.IsWindowsServer2016) {
                $RowClass = 'warnrow'
            }

@"
<tr class="$RowClass">
  <td>$(ConvertTo-AIHtmlEncodedText $Dc.Domain)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Dc.HostName)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Dc.Site)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Dc.IPv4Address)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Dc.OperatingSystem)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Dc.IsGlobalCatalog)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Dc.FSMORoles)</td>
</tr>
"@
        }

        $FsmoRows = foreach ($Role in ($FsmoRoles | Sort-Object Scope, Domain, Role)) {
            $RowClass = ''
            if ($Role.IsWindowsServer2016) {
                $RowClass = 'warnrow'
            }

@"
<tr class="$RowClass">
  <td>$(ConvertTo-AIHtmlEncodedText $Role.Scope)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Role.Domain)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Role.Role)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Role.RoleHolder)</td>
  <td>$(ConvertTo-AIHtmlEncodedText $Role.OperatingSystem)</td>
</tr>
"@
        }

        $ReadinessRows = foreach ($Row in ($Readiness | Sort-Object Category, CheckName)) {
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
</tr>
"@
        }

        $DnsSectionText = if ($SkipDnsChecks) {
            'DNS checks skipped'
        }
        else {
            "$($DnsResults.Count) total, $($DnsFailing.Count) failing, $($DnsWarning.Count) warning"
        }

        $Html = @"
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>AI Infrastructure Workbench Summary</title>
$Css
</head>
<body>
<h1>AI Infrastructure Workbench Summary</h1>
<div class="meta">
Generated: <strong>$(ConvertTo-AIHtmlEncodedText $Generated)</strong><br>
Forest: <strong>$(ConvertTo-AIHtmlEncodedText $ForestSummary.ForestName)</strong><br>
Forest Mode: <strong>$(ConvertTo-AIHtmlEncodedText $ForestSummary.ForestMode)</strong><br>
Root Domain: <strong>$(ConvertTo-AIHtmlEncodedText $ForestSummary.RootDomain)</strong>
</div>

<div class="banner $OverallClass">
  <div>Overall AD Migration Readiness</div>
  <div class="status $OverallClass-text">$(ConvertTo-AIHtmlEncodedText $OverallReadiness)</div>
</div>

<div class="cards">
  <div class="card"><div>Total DCs</div><div class="number">$($DcInventory.Count)</div></div>
  <div class="card"><div>Server 2016 DCs</div><div class="number warning">$($Dc2016.Count)</div></div>
  <div class="card"><div>Server 2022 DCs</div><div class="number pass">$($Dc2022.Count)</div></div>
  <div class="card"><div>FSMO on 2016</div><div class="number warning">$($FsmoOn2016.Count)</div></div>
</div>

<div class="cards">
  <div class="card"><div>FSMO on 2022</div><div class="number pass">$($FsmoOn2022.Count)</div></div>
  <div class="card"><div>Replication Failures</div><div class="number fail">$($ReplicationFailing.Count)</div></div>
  <div class="card"><div>Replication Warnings</div><div class="number warning">$($ReplicationWarning.Count)</div></div>
  <div class="card"><div>DNS Resolution</div><div class="number">$(ConvertTo-AIHtmlEncodedText $DnsSectionText)</div></div>
</div>

<h2>Domain Controllers</h2>
<table>
<thead>
<tr>
  <th>Domain</th>
  <th>Host Name</th>
  <th>Site</th>
  <th>IPv4 Address</th>
  <th>Operating System</th>
  <th>Global Catalog</th>
  <th>FSMO Roles</th>
</tr>
</thead>
<tbody>
$($DcRows -join "`n")
</tbody>
</table>

<h2>FSMO Roles</h2>
<table>
<thead>
<tr>
  <th>Scope</th>
  <th>Domain</th>
  <th>Role</th>
  <th>Role Holder</th>
  <th>Operating System</th>
</tr>
</thead>
<tbody>
$($FsmoRows -join "`n")
</tbody>
</table>

<h2>Migration Readiness Checks</h2>
<table>
<thead>
<tr>
  <th>Category</th>
  <th>Check</th>
  <th>Status</th>
  <th>Blocking</th>
  <th>Summary</th>
</tr>
</thead>
<tbody>
$($ReadinessRows -join "`n")
</tbody>
</table>

<div class="small">
This report is read-only. It summarizes forest inventory, domain controller inventory, FSMO placement, AD replication health, AD DNS resolution, and migration readiness.
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
        Write-Error "Failed to create AI Workbench summary report. $($_.Exception.Message)"
    }
}