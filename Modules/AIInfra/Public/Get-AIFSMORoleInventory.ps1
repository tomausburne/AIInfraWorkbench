function Get-AIFSMORoleInventory {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Server,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    try {
        Import-Module ActiveDirectory -ErrorAction Stop

        $CommandParams = @{}
        if ($PSBoundParameters.ContainsKey('Server')) { $CommandParams['Server'] = $Server }
        if ($PSBoundParameters.ContainsKey('Credential')) { $CommandParams['Credential'] = $Credential }

        $Forest = Get-ADForest @CommandParams -ErrorAction Stop

        $DcInventory = Get-AIDomainControllerInventory @CommandParams

        function Find-RoleHolder {
            param(
                [string] $HostName
            )

            $DcInventory |
                Where-Object { $_.HostName -ieq $HostName } |
                Select-Object -First 1
        }

        $ForestRoles = @(
            [pscustomobject]@{
                Scope = 'Forest'
                Domain = $Forest.RootDomain
                Role = 'SchemaMaster'
                RoleHolder = $Forest.SchemaMaster
            },
            [pscustomobject]@{
                Scope = 'Forest'
                Domain = $Forest.RootDomain
                Role = 'DomainNamingMaster'
                RoleHolder = $Forest.DomainNamingMaster
            }
        )

        foreach ($ForestRole in $ForestRoles) {
            $Holder = Find-RoleHolder -HostName $ForestRole.RoleHolder

            [pscustomobject]@{
                Scope = $ForestRole.Scope
                Domain = $ForestRole.Domain
                Role = $ForestRole.Role
                RoleHolder = $ForestRole.RoleHolder
                Site = $Holder.Site
                IPv4Address = $Holder.IPv4Address
                OperatingSystem = $Holder.OperatingSystem
                IsWindowsServer2016 = $Holder.IsWindowsServer2016
                IsWindowsServer2022 = $Holder.IsWindowsServer2022
            }
        }

        foreach ($DomainName in $Forest.Domains) {
            $DomainParams = @{
                Server = $DomainName
            }

            if ($PSBoundParameters.ContainsKey('Credential')) {
                $DomainParams['Credential'] = $Credential
            }

            $Domain = Get-ADDomain @DomainParams -ErrorAction Stop

            $DomainRoles = @(
                [pscustomobject]@{
                    Scope = 'Domain'
                    Domain = $DomainName
                    Role = 'PDCEmulator'
                    RoleHolder = $Domain.PDCEmulator
                },
                [pscustomobject]@{
                    Scope = 'Domain'
                    Domain = $DomainName
                    Role = 'RIDMaster'
                    RoleHolder = $Domain.RIDMaster
                },
                [pscustomobject]@{
                    Scope = 'Domain'
                    Domain = $DomainName
                    Role = 'InfrastructureMaster'
                    RoleHolder = $Domain.InfrastructureMaster
                }
            )

            foreach ($DomainRole in $DomainRoles) {
                $Holder = Find-RoleHolder -HostName $DomainRole.RoleHolder

                [pscustomobject]@{
                    Scope = $DomainRole.Scope
                    Domain = $DomainRole.Domain
                    Role = $DomainRole.Role
                    RoleHolder = $DomainRole.RoleHolder
                    Site = $Holder.Site
                    IPv4Address = $Holder.IPv4Address
                    OperatingSystem = $Holder.OperatingSystem
                    IsWindowsServer2016 = $Holder.IsWindowsServer2016
                    IsWindowsServer2022 = $Holder.IsWindowsServer2022
                }
            }
        }
    }
    catch {
        Write-Error "Failed to collect FSMO role inventory. $($_.Exception.Message)"
    }
}