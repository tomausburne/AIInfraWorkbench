<#
.SYNOPSIS
Generates an HTML report for Active Directory domain controller replication health.

.DESCRIPTION
Queries all domain controllers in the current Active Directory domain and collects
replication partner metadata for each server. The report shows which domain
controllers and replication links are healthy, warning, or failing.

Failing links include the consecutive replication failure count, time since the
last successful replication, last replication attempt, last success, result code,
and result message when available. The report also shows current replication
delta times, calculated from the last successful replication timestamp.

Optionally, the generated HTML report can be emailed by using -SendEmail. The
SMTP settings are defined as parameters with generic defaults so they can be
customized in the script or supplied at runtime.

.PARAMETER OutputPath
Path where the HTML replication report will be written. If not specified, the
report is created in the current directory with a timestamped file name.

.PARAMETER WarnDeltaHours
Marks otherwise healthy replication links as Warning when the current replication
delta is greater than this number of hours. The default is 24.

.PARAMETER OpenReport
Opens the generated HTML report after it is created.

.PARAMETER SendEmail
Emails the generated HTML report. The report is sent as the HTML body and is also
attached to the email.

.PARAMETER SmtpServer
SMTP server used to send the report when -SendEmail is specified.

.PARAMETER SmtpPort
SMTP server port used to send the report when -SendEmail is specified. The
default is 25.

.PARAMETER UseSsl
Uses SSL/TLS for the SMTP connection when -SendEmail is specified.

.PARAMETER MailFrom
Sender address for the email report.

.PARAMETER MailTo
Recipient address for the email report. The default is ad.admin@bcbssc.com.

.PARAMETER MailSubject
Base subject line for the email report. The domain name and timestamp are
appended automatically.

.EXAMPLE
.\Get-ADReplicationHtmlReport.ps1 -OutputPath C:\Temp\AD-Repl-Report.html

Creates the Active Directory replication HTML report at C:\Temp\AD-Repl-Report.html.

.EXAMPLE
.\Get-ADReplicationHtmlReport.ps1 -OutputPath C:\Temp\AD-Repl-Report.html -OpenReport

Creates the report and opens it after generation.

.EXAMPLE
.\Get-ADReplicationHtmlReport.ps1 -OutputPath C:\Temp\AD-Repl-Report.html -SendEmail

Creates the report and emails it using the SMTP settings defined in the script
parameters.

.EXAMPLE
.\Get-ADReplicationHtmlReport.ps1 -OutputPath C:\Temp\AD-Repl-Report.html -SendEmail -SmtpServer smtp.yourdomain.com -SmtpPort 587 -UseSsl -MailFrom ad-replication-report@yourdomain.com

Creates the report and emails it using SMTP settings supplied at runtime.

.NOTES

READONLY GUARANTEE
This script is designed and validated as a strictly read-only reporting tool.

The script performs the following actions only:
- Queries Active Directory domain and domain controller metadata using read-only cmdlets:
  - Get-ADDomain
  - Get-ADDomainController
  - Get-ADReplicationPartnerMetadata
- Processes collected data in memory for reporting purposes
- Writes a formatted HTML report to the local file system
- Optionally sends the generated report via SMTP email
- Optionally opens the generated report locally

The script DOES NOT:
- Modify any Active Directory objects
- Initiate or force replication between domain controllers
- Change domain controller configuration or topology
- Write to Active Directory, registry, or system configuration
- Execute remote commands or alter system state

All operations against Active Directory are read-only and non-intrusive.

CAB APPROVAL STATEMENT
Change Classification: Standard / Low Risk (Read-Only Monitoring Script)

This script has been reviewed and confirmed to:
- Perform read-only queries against Active Directory
- Have no impact on domain controller operations or replication behavior
- Introduce no configuration, schema, or data modifications
- Operate within the permissions of a standard domain account with read access

Risk Assessment:
- Risk Level: Low
- Service Impact: None
- Backout Plan: Not required (no changes made)

Approval Justification:
This script is safe for execution in production environments as it does not alter
any system or directory state. It is intended solely for monitoring, reporting,
and operational visibility of Active Directory replication health.

AUTHOR
    Tom Ausburne

CREATED
    2026-06-23

VERSION
    1.0.1

LASTMODIFIED
    2026-06-25

REQUIREMENTS
    - PowerShell Version:  5.1
    - Required Modules:   ActiveDirectory
    - Requires ADWS on Windows Server 2008 R2+, Uses SOAP over TCP 9389. All Get-AD* cmdlets use TCP 9389
    - Permissions Required: Domain account with permission to query Active Directory replication metadata

CHANGELOG
    1.0.0 - Initial creation
    1.0.1 - Added documentation requirements for Port 9389 and a test to see if that port is usuable

Requires the ActiveDirectory PowerShell module. Run from a domain controller or a
domain-joined system with RSAT Active Directory tools installed.
#>
[CmdletBinding()]
param(
    [string]$OutputPath = (Join-Path $PWD ("AD-Replication-Report-{0}.html" -f (Get-Date -Format "yyyyMMdd-HHmmss"))),
    [int]$WarnDeltaHours = 24,
    [switch]$OpenReport,

    [switch]$SendEmail,
    [string]$SmtpServer = "smtp.yourdomain.com",
    [int]$SmtpPort = 25,
    [switch]$UseSsl,
    [string]$MailFrom = "ad-replication-report@yourdomain.com",
    [string]$MailTo = "admin@yourdomain.com",
    [string]$MailSubject = "Active Directory Replication Report"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Format-TimeSpan {
    param([AllowNull()][object]$TimeSpan)

    if ($null -eq $TimeSpan) {
        return "Never / Unknown"
    }

    $span = [TimeSpan]$TimeSpan

    if ($span.TotalDays -ge 1) {
        return "{0}d {1}h {2}m" -f [int]$span.TotalDays, $span.Hours, $span.Minutes
    }

    return "{0}h {1}m" -f [int]$span.TotalHours, $span.Minutes
}

function Encode-Html {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return "" }
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Get-ObjectProperty {
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Name,

        [object]$Default = $null
    )

    $property = $InputObject.PSObject.Properties | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if ($null -eq $property) {
        return $Default
    }

    return $property.Value
}

try {
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch {
    throw "The ActiveDirectory PowerShell module is required. Install RSAT Active Directory tools or run this on a domain controller. Details: $($_.Exception.Message)"
}

$now = Get-Date
$domain = Get-ADDomain
$domainControllers = Get-ADDomainController -Filter * | Sort-Object HostName

if (-not $domainControllers) {
    throw "No domain controllers were found in domain '$($domain.DNSRoot)'."
}

$rawMetadata = foreach ($dc in $domainControllers) {
    try {
        if (-not (Test-NetConnection $dc.HostName -Port 9389 -InformationLevel Quiet)) {
        throw "ADWS (TCP 9389) not reachable"
    }
        Get-ADReplicationPartnerMetadata -Target $dc.HostName -Scope Server -ErrorAction Stop |
            Select-Object *,
                @{Name = "ReportServer"; Expression = { $dc.HostName }},
                @{Name = "CollectionError"; Expression = { $null }}
    }
    catch {
        [pscustomobject]@{
            ReportServer                    = $dc.HostName
            Server                          = $dc.HostName
            Partner                         = $null
            Partition                       = $null
            PartnerType                     = $null
            IntersiteTransport              = $null
            LastReplicationAttempt          = $null
            LastReplicationSuccess          = $null
            LastReplicationResult           = $null
            LastReplicationResultMessage    = $null
            ConsecutiveReplicationFailures  = 1
            CollectionError                 = $_.Exception.Message
        }
    }
}

$detailRows = foreach ($item in $rawMetadata) {
    $lastSuccess = Get-ObjectProperty -InputObject $item -Name "LastReplicationSuccess"
    $delta = if ($lastSuccess) { $now - $lastSuccess } else { $null }
    $failuresValue = Get-ObjectProperty -InputObject $item -Name "ConsecutiveReplicationFailures" -Default 0
    $failures = if ($null -ne $failuresValue) { [int]$failuresValue } else { 0 }
    $resultValue = Get-ObjectProperty -InputObject $item -Name "LastReplicationResult"
    $resultCode = if ($null -ne $resultValue) { [int]$resultValue } else { $null }
    $collectionError = Get-ObjectProperty -InputObject $item -Name "CollectionError"
    $resultMessage = Get-ObjectProperty -InputObject $item -Name "LastReplicationResultMessage"

    if ([string]::IsNullOrWhiteSpace([string]$resultMessage) -and $null -ne $resultCode) {
        $resultMessage = if ($resultCode -eq 0) { "The operation completed successfully." } else { "Non-zero replication result code: $resultCode" }
    }

    $isFailure = ($null -ne $collectionError) -or ($failures -gt 0) -or ($null -ne $resultCode -and $resultCode -ne 0)
    $isWarning = -not $isFailure -and $delta -and $delta.TotalHours -gt $WarnDeltaHours

    [pscustomobject]@{
        Server                         = Get-ObjectProperty -InputObject $item -Name "ReportServer"
        Partner                        = Get-ObjectProperty -InputObject $item -Name "Partner"
        Partition                      = Get-ObjectProperty -InputObject $item -Name "Partition"
        PartnerType                    = Get-ObjectProperty -InputObject $item -Name "PartnerType"
        Transport                      = Get-ObjectProperty -InputObject $item -Name "IntersiteTransport"
        Status                         = if ($isFailure) { "Failing" } elseif ($isWarning) { "Warning" } else { "Healthy" }
        ConsecutiveFailures            = $failures
        LastReplicationSuccess         = $lastSuccess
        TimeSinceLastSuccess           = $delta
        LastReplicationAttempt         = Get-ObjectProperty -InputObject $item -Name "LastReplicationAttempt"
        LastReplicationResult          = $resultCode
        LastReplicationResultMessage   = if ($collectionError) { $collectionError } else { $resultMessage }
    }
}

$summaryRows = foreach ($dc in $domainControllers) {
    $rows = @($detailRows | Where-Object { $_.Server -eq $dc.HostName })
    $failingRows = @($rows | Where-Object { $_.Status -eq "Failing" })
    $warningRows = @($rows | Where-Object { $_.Status -eq "Warning" })
    $oldestDelta = @($rows | Where-Object { $_.TimeSinceLastSuccess } | Sort-Object TimeSinceLastSuccess -Descending | Select-Object -First 1)
    $lastSuccess = @($rows | Where-Object { $_.LastReplicationSuccess } | Sort-Object LastReplicationSuccess -Descending | Select-Object -First 1)

    [pscustomobject]@{
        DomainController        = $dc.HostName
        Site                    = $dc.Site
        Status                  = if ($failingRows.Count -gt 0) { "Failing" } elseif ($warningRows.Count -gt 0) { "Warning" } else { "Healthy" }
        ReplicationPartners     = $rows.Count
        FailingLinks            = $failingRows.Count
        TotalConsecutiveFails   = ($rows | Measure-Object ConsecutiveFailures -Sum).Sum
        MaxConsecutiveFails     = ($rows | Measure-Object ConsecutiveFailures -Maximum).Maximum
        LongestCurrentDelta     = if ($oldestDelta) { $oldestDelta[0].TimeSinceLastSuccess } else { $null }
        MostRecentSuccess       = if ($lastSuccess) { $lastSuccess[0].LastReplicationSuccess } else { $null }
    }
}

$healthyCount = @($summaryRows | Where-Object Status -eq "Healthy").Count
$warningCount = @($summaryRows | Where-Object Status -eq "Warning").Count
$failingCount = @($summaryRows | Where-Object Status -eq "Failing").Count

$css = @"
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
th { background: #eaf0f6; font-weight: 700; position: sticky; top: 0; }
tr.failrow { background: #fff1f0; }
tr.warnrow { background: #fff8e6; }
.small { font-size: 12px; color: #52606d; }
</style>
"@

$summaryHtmlRows = foreach ($row in $summaryRows) {
    $class = $row.Status.ToLowerInvariant()
    @"
<tr class="$($class -replace 'warning','warnrow' -replace 'failing','failrow')">
  <td>$(Encode-Html $row.DomainController)</td>
  <td>$(Encode-Html $row.Site)</td>
  <td class="$class">$(Encode-Html $row.Status)</td>
  <td>$($row.ReplicationPartners)</td>
  <td>$($row.FailingLinks)</td>
  <td>$($row.TotalConsecutiveFails)</td>
  <td>$($row.MaxConsecutiveFails)</td>
  <td>$(Format-TimeSpan $row.LongestCurrentDelta)</td>
  <td>$(Encode-Html $row.MostRecentSuccess)</td>
</tr>
"@
}

$detailHtmlRows = foreach ($row in ($detailRows | Sort-Object Server, Status, Partition, Partner)) {
    $rowClass = if ($row.Status -eq "Failing") { "failrow" } elseif ($row.Status -eq "Warning") { "warnrow" } else { "" }
    $statusClass = $row.Status.ToLowerInvariant()
    @"
<tr class="$rowClass">
  <td>$(Encode-Html $row.Server)</td>
  <td>$(Encode-Html $row.Partner)</td>
  <td>$(Encode-Html $row.Partition)</td>
  <td class="$statusClass">$(Encode-Html $row.Status)</td>
  <td>$($row.ConsecutiveFailures)</td>
  <td>$(Format-TimeSpan $row.TimeSinceLastSuccess)</td>
  <td>$(Encode-Html $row.LastReplicationSuccess)</td>
  <td>$(Encode-Html $row.LastReplicationAttempt)</td>
  <td>$(Encode-Html $row.LastReplicationResult)</td>
  <td>$(Encode-Html $row.LastReplicationResultMessage)</td>
</tr>
"@
}

$html = @"
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>Active Directory Replication Report - $($domain.DNSRoot)</title>
$css
</head>
<body>
<h1>Active Directory Replication Report</h1>
<div class="meta">
Domain: <strong>$(Encode-Html $domain.DNSRoot)</strong><br>
Generated: <strong>$(Encode-Html $now)</strong><br>
Warning threshold: healthy links with a current replication delta over <strong>$WarnDeltaHours hours</strong> are marked Warning.
</div>

<div class="cards">
  <div class="card"><div>Total DCs</div><div class="number">$($domainControllers.Count)</div></div>
  <div class="card"><div>Healthy</div><div class="number healthy">$healthyCount</div></div>
  <div class="card"><div>Warning</div><div class="number warning">$warningCount</div></div>
  <div class="card"><div>Failing</div><div class="number failing">$failingCount</div></div>
</div>

<h2>Domain Controller Summary</h2>
<table>
<thead>
<tr>
  <th>Domain Controller</th>
  <th>Site</th>
  <th>Status</th>
  <th>Partners</th>
  <th>Failing Links</th>
  <th>Total Consecutive Fails</th>
  <th>Max Consecutive Fails</th>
  <th>Longest Current Delta</th>
  <th>Most Recent Success</th>
</tr>
</thead>
<tbody>
$($summaryHtmlRows -join "`n")
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
$($detailHtmlRows -join "`n")
</tbody>
</table>

<div class="small">
Status is Failing when collection fails, LastReplicationResult is non-zero, or ConsecutiveReplicationFailures is greater than zero.
Current Delta is calculated as the time elapsed since LastReplicationSuccess.
</div>
</body>
</html>
"@

$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory -and -not (Test-Path $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$html | Out-File -FilePath $OutputPath -Encoding utf8

Write-Host "Replication report written to: $OutputPath"

if ($SendEmail) {
    $mailParams = @{
        From        = $MailFrom
        To          = $MailTo
        Subject     = "$MailSubject - $($domain.DNSRoot) - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        Body        = $html
        BodyAsHtml  = $true
        SmtpServer  = $SmtpServer
        Port        = $SmtpPort
        Attachments = $OutputPath
    }

    if ($UseSsl) {
        $mailParams.UseSsl = $true
    }

    Send-MailMessage @mailParams
    Write-Host "Replication report emailed to: $MailTo"
}

if ($OpenReport) {
    Invoke-Item $OutputPath
}
