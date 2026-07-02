# AI Infrastructure Engineer Workbench

AI Infrastructure Engineer Workbench is a PowerShell-based toolkit for Active Directory infrastructure discovery, health validation, migration readiness checks, and HTML reporting.

The initial focus is Windows Server 2016 to Windows Server 2022 domain controller migration readiness.

## Current Capabilities

### Inventory

* `Get-AIForestSummary`
* `Get-AIDomainControllerInventory`
* `Get-AIFSMORoleInventory`

### Health and Validation

* `Get-AIADReplicationHealth`
* `Test-AIADDnsResolution`
* `Test-AIADMigrationReadiness`
* `Test-AIWorkbenchPrerequisite`

### Reports

* `New-AIForestSummaryReport`
* `New-AIDomainControllerMigrationReport`
* `New-AIADReplicationHealthReport`
* `New-AIADDnsResolutionReport`
* `New-AIADMigrationReadinessReport`
* `New-AIWorkbenchPrerequisiteReport`
* `New-AIWorkbenchSummaryReport`

### Standalone Scripts

* `Scripts\Standalone\Get-ADReplicationHtmlReport.ps1`

## Design Goals

* Windows PowerShell 5.1 compatible
* Read-only by default
* Safe for lab validation before production use
* Suitable for domain-joined management workstations
* Designed around Active Directory migration and operations
* Report output saved locally as HTML
* Source-controlled with Git

## Requirements

* Windows PowerShell 5.1 or later
* Domain-joined management workstation
* RSAT Active Directory tools
* ActiveDirectory PowerShell module
* Network access to domain controllers
* ADWS access to domain controllers over TCP 9389
* Git recommended for development and version control

## Getting Started

Open Windows PowerShell 5.1 from the Workbench root folder:

```powershell
Set-Location C:\AIInfraWorkbench
Import-Module .\Modules\AIInfra\AIInfra.psd1 -Force
```

Verify available commands:

```powershell
Get-Command -Module AIInfra
```

Run prerequisite checks:

```powershell
Test-AIWorkbenchPrerequisite |
    Format-Table Category,CheckName,Status,Blocking,Summary -AutoSize
```

Generate a prerequisite report:

```powershell
New-AIWorkbenchPrerequisiteReport -OpenReport
```

Generate the main Workbench summary report:

```powershell
New-AIWorkbenchSummaryReport -OpenReport
```

## Common Commands

### Forest Summary

```powershell
Get-AIForestSummary
New-AIForestSummaryReport -OpenReport
```

### Domain Controller Inventory

```powershell
Get-AIDomainControllerInventory |
    Format-Table Domain,HostName,Site,IPv4Address,OperatingSystem,IsGlobalCatalog,FSMORoles -AutoSize
```

### FSMO Role Inventory

```powershell
Get-AIFSMORoleInventory |
    Format-Table Scope,Domain,Role,RoleHolder,OperatingSystem,IPv4Address -AutoSize
```

### AD Replication Health

```powershell
Get-AIADReplicationHealth |
    Format-Table DomainController,Partner,Partition,Status,ConsecutiveFailures,LastReplicationSuccess -AutoSize
```

Generate the replication report:

```powershell
New-AIADReplicationHealthReport -OpenReport
```

### AD DNS Resolution Validation

This performs client-side DNS validation only. It does not inspect or modify DNS server configuration.

```powershell
Test-AIADDnsResolution |
    Format-Table RecordType,QueryName,Status,ResultCount -AutoSize
```

Generate the DNS resolution report:

```powershell
New-AIADDnsResolutionReport -OpenReport
```

### AD Migration Readiness

```powershell
Test-AIADMigrationReadiness |
    Format-Table OverallReadiness,Category,CheckName,Status,Blocking,Summary -AutoSize
```

Generate the migration readiness report:

```powershell
New-AIADMigrationReadinessReport -OpenReport
```

## One-Command Summary

The main summary report combines:

* Forest summary
* Domain controller inventory
* FSMO role placement
* AD replication health
* AD DNS resolution validation
* AD migration readiness

```powershell
New-AIWorkbenchSummaryReport -OpenReport
```

## Standalone AD Replication Report

A standalone replication report script is included for administrators who do not want to import the full Workbench module.

```powershell
.\Scripts\Standalone\Get-ADReplicationHtmlReport.ps1 `
    -OutputPath C:\AIInfraWorkbench\Reports\AD-Replication-Report.html `
    -OpenReport
```

## Read-Only Guarantee

The current Workbench functions are designed for discovery, validation, and reporting.

They do not:

* Modify Active Directory objects
* Move FSMO roles
* Promote or demote domain controllers
* Modify DNS records
* Modify Group Policy
* Force replication
* Change server configuration

## Version History

### v0.3.1

* Added Workbench prerequisite HTML report

### v0.3.0

* Added Workbench prerequisite check

### v0.2.0

* Added one-command Workbench summary report

### v0.1.0

* Initial AD migration readiness workbench
* Forest summary
* Domain controller inventory
* FSMO role inventory
* AD replication health
* AD DNS resolution validation
* Migration readiness checks
