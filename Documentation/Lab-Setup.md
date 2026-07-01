# Lab Setup

## Recommended Lab Shape

| System | Role |
| --- | --- |
| LABMGMT01 | Domain-joined management workstation |
| DC2016A | Windows Server 2016 domain controller |
| DC2016B | Windows Server 2016 domain controller |
| DC2022A | Windows Server 2022 domain controller |
| DC2022B | Windows Server 2022 domain controller |

## Install RSAT on Windows 11

Run PowerShell as Administrator:

```powershell
Get-WindowsCapability -Online |
    Where-Object Name -like "Rsat.ActiveDirectory*" |
    Add-WindowsCapability -Online
```

Optional broader RSAT install:

```powershell
$Capabilities = @(
    "Rsat.ActiveDirectory*",
    "Rsat.GroupPolicy*",
    "Rsat.Dns*",
    "Rsat.DHCP*",
    "Rsat.FileServices*",
    "Rsat.FailoverCluster.Management*",
    "Rsat.ServerManager*"
)

foreach ($Capability in $Capabilities) {
    Get-WindowsCapability -Online |
        Where-Object Name -like $Capability |
        Add-WindowsCapability -Online
}
```

## Install PowerShell 7

PowerShell 7 is optional for this project. Windows PowerShell 5.1 remains the baseline.

```powershell
winget install --id Microsoft.PowerShell --source winget
```

