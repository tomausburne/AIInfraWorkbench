function Get-AIForestSummary {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Server,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential
    )

    begin {
        $CommandParameters = @{}

        if ($PSBoundParameters.ContainsKey('Server')) {
            $CommandParameters['Server'] = $Server
        }

        if ($PSBoundParameters.ContainsKey('Credential')) {
            $CommandParameters['Credential'] = $Credential
        }
    }

    process {
        try {
            Import-Module ActiveDirectory -ErrorAction Stop

            $Forest = Get-ADForest @CommandParameters -ErrorAction Stop
            $DomainSummaries = @()
            $DomainControllers = @()
            $Trusts = @()

            foreach ($DomainName in $Forest.Domains) {
                $DomainParameters = @{}

                if ($PSBoundParameters.ContainsKey('Credential')) {
                    $DomainParameters['Credential'] = $Credential
                }

                $DomainParameters['Server'] = $DomainName

                try {
                    $Domain = Get-ADDomain @DomainParameters -ErrorAction Stop
                    $DomainSummaries += [pscustomobject]@{
                        Name = $Domain.DNSRoot
                        NetBIOSName = $Domain.NetBIOSName
                        DomainMode = $Domain.DomainMode
                        PDCEmulator = $Domain.PDCEmulator
                        RIDMaster = $Domain.RIDMaster
                        InfrastructureMaster = $Domain.InfrastructureMaster
                    }
                }
                catch {
                    Write-Warning "Failed to query domain '$DomainName'. $($_.Exception.Message)"
                }

                try {
                    $Dcs = Get-ADDomainController -Filter * @DomainParameters -ErrorAction Stop

                    foreach ($Dc in $Dcs) {
                        $DomainControllers += [pscustomobject]@{
                            Domain = $DomainName
                            HostName = $Dc.HostName
                            Site = $Dc.Site
                            IPv4Address = $Dc.IPv4Address
                            OperatingSystem = $Dc.OperatingSystem
                            IsGlobalCatalog = $Dc.IsGlobalCatalog
                            IsReadOnly = $Dc.IsReadOnly
                        }
                    }
                }
                catch {
                    Write-Warning "Failed to query domain controllers for '$DomainName'. $($_.Exception.Message)"
                }
            }

            try {
                $TrustParameters = @{}

                if ($PSBoundParameters.ContainsKey('Server')) {
                    $TrustParameters['Server'] = $Server
                }

                if ($PSBoundParameters.ContainsKey('Credential')) {
                    $TrustParameters['Credential'] = $Credential
                }

                $Trusts = Get-ADTrust -Filter * @TrustParameters -ErrorAction Stop |
                    Select-Object Name, Direction, TrustType, TrustAttributes, ForestTransitive
            }
            catch {
                Write-Warning "Failed to query forest trusts. $($_.Exception.Message)"
            }

            [pscustomobject]@{
                CollectedAt = Get-Date
                ForestName = $Forest.Name
                RootDomain = $Forest.RootDomain
                ForestMode = $Forest.ForestMode
                SchemaMaster = $Forest.SchemaMaster
                DomainNamingMaster = $Forest.DomainNamingMaster
                Domains = $DomainSummaries
                Sites = $Forest.Sites
                GlobalCatalogs = $Forest.GlobalCatalogs
                DomainControllers = $DomainControllers
                Trusts = $Trusts
            }
        }
        catch {
            Write-Error "Failed to collect AD forest summary. $($_.Exception.Message)"
        }
    }
}

