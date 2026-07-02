function New-AIDomainControllerMigrationReport {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $OutputPath
    )

    $DcInventory = Get-AIDomainControllerInventory
    $FsmoRoles = Get-AIFSMORoleInventory

    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $ProjectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
        $ReportFolder = Join-Path $ProjectRoot 'Reports'

        if (-not (Test-Path $ReportFolder)) {
            New-Item -Path $ReportFolder -ItemType Directory -Force | Out-Null
        }

        $Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        $OutputPath = Join-Path $ReportFolder "DomainControllerMigration-$Timestamp.html"
    }

    $Style = @'
<style>
body { font-family: Segoe UI, Arial, sans-serif; margin: 32px; color: #1f2933; }
h1 { font-size: 24px; }
h2 { margin-top: 28px; font-size: 18px; }
table { border-collapse: collapse; width: 100%; margin-top: 12px; }
th, td { border: 1px solid #d0d7de; padding: 8px; text-align: left; }
th { background: #f6f8fa; }
.warning { color: #9a3412; font-weight: 600; }
.good { color: #166534; font-weight: 600; }
</style>
'@

    $Summary = [pscustomobject]@{
        GeneratedAt = Get-Date
        TotalDomainControllers = @($DcInventory).Count
        WindowsServer2016 = @($DcInventory | Where-Object { $_.IsWindowsServer2016 }).Count
        WindowsServer2022 = @($DcInventory | Where-Object { $_.IsWindowsServer2022 }).Count
        FSMORolesOn2016 = @($FsmoRoles | Where-Object { $_.IsWindowsServer2016 }).Count
        FSMORolesOn2022 = @($FsmoRoles | Where-Object { $_.IsWindowsServer2022 }).Count
    }

    $SummaryHtml = $Summary | ConvertTo-Html -Fragment
    $DcHtml = $DcInventory |
        Select-Object Domain, HostName, Site, IPv4Address, OperatingSystem, IsGlobalCatalog, IsReadOnly, FSMORoles |
        ConvertTo-Html -Fragment

    $FsmoHtml = $FsmoRoles |
        Select-Object Scope, Domain, Role, RoleHolder, OperatingSystem, IPv4Address |
        ConvertTo-Html -Fragment

    $Html = @"
<html>
<head>
<title>Domain Controller Migration Report</title>
$Style
</head>
<body>
<h1>Domain Controller Migration Report</h1>
<h2>Summary</h2>
$SummaryHtml
<h2>Domain Controllers</h2>
$DcHtml
<h2>FSMO Roles</h2>
$FsmoHtml
</body>
</html>
"@

    $Html | Out-File -FilePath $OutputPath -Encoding UTF8
    Get-Item -Path $OutputPath
}