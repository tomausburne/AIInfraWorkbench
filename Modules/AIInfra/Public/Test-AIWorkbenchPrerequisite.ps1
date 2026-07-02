function Test-AIWorkbenchPrerequisite {
    [CmdletBinding()]
    param()

    function New-AIPrerequisiteResult {
        param(
            [Parameter(Mandatory)]
            [string] $Category,

            [Parameter(Mandatory)]
            [string] $CheckName,

            [Parameter(Mandatory)]
            [ValidateSet('Pass','Warning','Fail')]
            [string] $Status,

            [Parameter(Mandatory)]
            [string] $Summary,

            [Parameter()]
            [string] $Details,

            [Parameter()]
            [bool] $Blocking = $false
        )

        [pscustomobject]@{
            Category  = $Category
            CheckName = $CheckName
            Status    = $Status
            Blocking  = $Blocking
            Summary   = $Summary
            Details   = $Details
        }
    }

    try {
        $PowerShellVersion = $PSVersionTable.PSVersion.ToString()

        if ($PSVersionTable.PSVersion.Major -ge 5) {
            New-AIPrerequisiteResult `
                -Category 'PowerShell' `
                -CheckName 'PowerShell version' `
                -Status 'Pass' `
                -Summary "PowerShell version $PowerShellVersion detected." `
                -Details 'The Workbench is currently designed for Windows PowerShell 5.1 compatibility.'
        }
        else {
            New-AIPrerequisiteResult `
                -Category 'PowerShell' `
                -CheckName 'PowerShell version' `
                -Status 'Fail' `
                -Blocking $true `
                -Summary "PowerShell version $PowerShellVersion detected." `
                -Details 'PowerShell 5.1 or later is required.'
        }

        $ExecutionPolicies = Get-ExecutionPolicy -List
        $EffectivePolicy = Get-ExecutionPolicy

        if ($EffectivePolicy -eq 'Restricted') {
            New-AIPrerequisiteResult `
                -Category 'PowerShell' `
                -CheckName 'Execution policy' `
                -Status 'Warning' `
                -Summary "Effective execution policy is $EffectivePolicy." `
                -Details (($ExecutionPolicies | Out-String).Trim())
        }
        else {
            New-AIPrerequisiteResult `
                -Category 'PowerShell' `
                -CheckName 'Execution policy' `
                -Status 'Pass' `
                -Summary "Effective execution policy is $EffectivePolicy." `
                -Details (($ExecutionPolicies | Out-String).Trim())
        }

        $ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem

        if ($ComputerSystem.PartOfDomain) {
            New-AIPrerequisiteResult `
                -Category 'Computer' `
                -CheckName 'Domain joined' `
                -Status 'Pass' `
                -Summary "Computer is joined to domain $($ComputerSystem.Domain)." `
                -Details "Computer name: $env:COMPUTERNAME"
        }
        else {
            New-AIPrerequisiteResult `
                -Category 'Computer' `
                -CheckName 'Domain joined' `
                -Status 'Fail' `
                -Blocking $true `
                -Summary 'Computer is not domain joined.' `
                -Details 'Most Active Directory Workbench commands require a domain-joined management workstation.'
        }

        $ActiveDirectoryModule = Get-Module -ListAvailable ActiveDirectory | Select-Object -First 1

        if ($ActiveDirectoryModule) {
            New-AIPrerequisiteResult `
                -Category 'RSAT' `
                -CheckName 'ActiveDirectory PowerShell module' `
                -Status 'Pass' `
                -Summary 'ActiveDirectory module is available.' `
                -Details "Module path: $($ActiveDirectoryModule.Path)"
        }
        else {
            New-AIPrerequisiteResult `
                -Category 'RSAT' `
                -CheckName 'ActiveDirectory PowerShell module' `
                -Status 'Fail' `
                -Blocking $true `
                -Summary 'ActiveDirectory module was not found.' `
                -Details 'Install RSAT Active Directory tools before using AD Workbench commands.'
        }

        try {
            Import-Module ActiveDirectory -ErrorAction Stop
            $Domain = Get-ADDomain -ErrorAction Stop

            New-AIPrerequisiteResult `
                -Category 'Active Directory' `
                -CheckName 'Current domain query' `
                -Status 'Pass' `
                -Summary "Successfully queried current domain $($Domain.DNSRoot)." `
                -Details "NetBIOS name: $($Domain.NetBIOSName); Domain mode: $($Domain.DomainMode)"
        }
        catch {
            New-AIPrerequisiteResult `
                -Category 'Active Directory' `
                -CheckName 'Current domain query' `
                -Status 'Fail' `
                -Blocking $true `
                -Summary 'Failed to query the current Active Directory domain.' `
                -Details $_.Exception.Message
        }

        $GitCommand = Get-Command git -ErrorAction SilentlyContinue

        if ($GitCommand) {
            $GitVersion = git --version

            New-AIPrerequisiteResult `
                -Category 'Git' `
                -CheckName 'Git availability' `
                -Status 'Pass' `
                -Summary $GitVersion `
                -Details "Path: $($GitCommand.Source)"
        }
        else {
            New-AIPrerequisiteResult `
                -Category 'Git' `
                -CheckName 'Git availability' `
                -Status 'Warning' `
                -Summary 'Git was not found in PATH.' `
                -Details 'Git is recommended for source control but not required to run the Workbench commands.'
        }

        $ProjectRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent

        if (Test-Path $ProjectRoot) {
            New-AIPrerequisiteResult `
                -Category 'Workbench' `
                -CheckName 'Project root' `
                -Status 'Pass' `
                -Summary "Project root found: $ProjectRoot" `
                -Details 'The module was able to determine the Workbench root path.'
        }
        else {
            New-AIPrerequisiteResult `
                -Category 'Workbench' `
                -CheckName 'Project root' `
                -Status 'Fail' `
                -Blocking $true `
                -Summary 'Project root could not be found.' `
                -Details "Calculated path: $ProjectRoot"
        }

        $ReportFolder = Join-Path $ProjectRoot 'Reports'

        if (Test-Path $ReportFolder) {
            New-AIPrerequisiteResult `
                -Category 'Workbench' `
                -CheckName 'Reports folder' `
                -Status 'Pass' `
                -Summary "Reports folder exists: $ReportFolder" `
                -Details 'Reports can be written to the expected location.'
        }
        else {
            try {
                New-Item -Path $ReportFolder -ItemType Directory -Force | Out-Null

                New-AIPrerequisiteResult `
                    -Category 'Workbench' `
                    -CheckName 'Reports folder' `
                    -Status 'Pass' `
                    -Summary "Reports folder created: $ReportFolder" `
                    -Details 'Reports folder did not exist and was created.'
            }
            catch {
                New-AIPrerequisiteResult `
                    -Category 'Workbench' `
                    -CheckName 'Reports folder' `
                    -Status 'Fail' `
                    -Blocking $true `
                    -Summary 'Reports folder does not exist and could not be created.' `
                    -Details $_.Exception.Message
            }
        }

        $ModuleManifest = Join-Path $ProjectRoot 'Modules\AIInfra\AIInfra.psd1'

        if (Test-Path $ModuleManifest) {
            New-AIPrerequisiteResult `
                -Category 'Workbench' `
                -CheckName 'Module manifest' `
                -Status 'Pass' `
                -Summary 'AIInfra module manifest was found.' `
                -Details $ModuleManifest
        }
        else {
            New-AIPrerequisiteResult `
                -Category 'Workbench' `
                -CheckName 'Module manifest' `
                -Status 'Fail' `
                -Blocking $true `
                -Summary 'AIInfra module manifest was not found.' `
                -Details $ModuleManifest
        }
    }
    catch {
        Write-Error "Failed to test Workbench prerequisites. $($_.Exception.Message)"
    }
}