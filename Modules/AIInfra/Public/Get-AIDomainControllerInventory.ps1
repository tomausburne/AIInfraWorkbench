function Get-AIDomainControllerInventory {
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

        $ForestParams = @{}
        if ($PSBoundParameters.ContainsKey('Server')) { $ForestParams['Server'] = $Server }
        if ($PSBoundParameters.ContainsKey('Credential')) { $ForestParams['Credential'] = $Credential }

        $Forest = Get-ADForest @ForestParams -ErrorAction Stop

        foreach ($DomainName in $Forest.Domains) {
            $DomainParams = @{
                Server = $DomainName
            }

            if ($PSBoundParameters.ContainsKey('Credential')) {
                $DomainParams['Credential'] = $Credential
            }

            $Domain = Get-ADDomain @DomainParams -ErrorAction Stop
            $DomainControllers = Get-ADDomainController -Filter * @DomainParams -ErrorAction Stop

            foreach ($DomainController in $DomainControllers) {
                $FsmoRoles = @()

                if ($DomainController.HostName -ieq $Forest.SchemaMaster) {
                    $FsmoRoles += 'SchemaMaster'
                }

                if ($DomainController.HostName -ieq $Forest.DomainNamingMaster) {
                    $FsmoRoles += 'DomainNamingMaster'
                }

                if ($DomainController.HostName -ieq $Domain.PDCEmulator) {
                    $FsmoRoles += 'PDCEmulator'
                }

                if ($DomainController.HostName -ieq $Domain.RIDMaster) {
                    $FsmoRoles += 'RIDMaster'
                }

                if ($DomainController.HostName -ieq $Domain.InfrastructureMaster) {
                    $FsmoRoles += 'InfrastructureMaster'
                }

                [pscustomobject]@{
                    Domain                 = $DomainName
                    HostName               = $DomainController.HostName
                    Name                   = $DomainController.Name
                    Site                   = $DomainController.Site
                    IPv4Address            = $DomainController.IPv4Address
                    OperatingSystem        = $DomainController.OperatingSystem
                    OperatingSystemVersion = $DomainController.OperatingSystemVersion
                    IsWindowsServer2016    = ($DomainController.OperatingSystem -like '*2016*')
                    IsWindowsServer2022    = ($DomainController.OperatingSystem -like '*2022*')
                    IsGlobalCatalog        = $DomainController.IsGlobalCatalog
                    IsReadOnly             = $DomainController.IsReadOnly
                    FSMORoles              = ($FsmoRoles -join ', ')
                }
            }
        }
    }
    catch {
        Write-Error "Failed to collect domain controller inventory. $($_.Exception.Message)"
    }
}