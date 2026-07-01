#requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()]
    [switch]
    $All
)

$Capabilities = if ($All) {
    @('RSAT*')
}
else {
    @(
        'Rsat.ActiveDirectory*',
        'Rsat.GroupPolicy*',
        'Rsat.Dns*',
        'Rsat.DHCP*',
        'Rsat.FileServices*',
        'Rsat.FailoverCluster.Management*',
        'Rsat.ServerManager*'
    )
}

foreach ($Capability in $Capabilities) {
    Get-WindowsCapability -Online |
        Where-Object Name -like $Capability |
        Add-WindowsCapability -Online
}

Get-WindowsCapability -Online |
    Where-Object {
        $_.Name -like 'RSAT*' -and
        $_.State -eq 'Installed'
    } |
    Sort-Object Name

