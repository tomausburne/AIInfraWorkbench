function Test-AIADDnsResolution {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]
        $Server,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [string]
        $DnsServer
    )

    function Invoke-AIDnsQuery {
        param(
            [Parameter(Mandatory)]
            [string] $QueryName,

            [Parameter(Mandatory)]
            [string] $Type,

            [Parameter()]
            [string] $ExpectedTarget,

            [Parameter()]
            [string] $Description
        )

        $ResolveParams = @{
            Name        = $QueryName
            Type        = $Type
            ErrorAction = 'Stop'
        }

        if (-not [string]::IsNullOrWhiteSpace($DnsServer)) {
            $ResolveParams['Server'] = $DnsServer
        }

        try {
            $Results = @(Resolve-DnsName @ResolveParams)

            $Values = foreach ($Result in $Results) {
                if ($Type -eq 'SRV') {
                    $Result.NameTarget
                }
                elseif ($Result.IPAddress) {
                    $Result.IPAddress
                }
                elseif ($Result.NameHost) {
                    $Result.NameHost
                }
                else {
                    $Result.Name
                }
            }

            $Values = @($Values | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Sort-Object -Unique)

            $Status = 'Pass'
            $Message = "Resolved $($Values.Count) result(s)."

            if (-not [string]::IsNullOrWhiteSpace($ExpectedTarget)) {
                $Matched = $false

                foreach ($Value in $Values) {
                    if ([string]$Value -ieq $ExpectedTarget) {
                        $Matched = $true
                    }
                }

                if (-not $Matched) {
                    $Status = 'Warning'
                    $Message = "Resolved, but expected target was not found."
                }
            }

            [pscustomobject]@{
                QueryName      = $QueryName
                RecordType     = $Type
                Status         = $Status
                ResultCount    = $Values.Count
                Results        = ($Values -join '; ')
                ExpectedTarget = $ExpectedTarget
                Description    = $Description
                Error          = $null
            }
        }
        catch {
            [pscustomobject]@{
                QueryName      = $QueryName
                RecordType     = $Type
                Status         = 'Fail'
                ResultCount    = 0
                Results        = ''
                ExpectedTarget = $ExpectedTarget
                Description    = $Description
                Error          = $_.Exception.Message
            }
        }
    }

    try {
        Import-Module ActiveDirectory -ErrorAction Stop

        $ForestParams = @{}
        if ($PSBoundParameters.ContainsKey('Server')) { $ForestParams['Server'] = $Server }
        if ($PSBoundParameters.ContainsKey('Credential')) { $ForestParams['Credential'] = $Credential }

        $Forest = Get-ADForest @ForestParams -ErrorAction Stop
        $DcInventory = @(Get-AIDomainControllerInventory @ForestParams)

        foreach ($DomainName in $Forest.Domains) {
            Invoke-AIDnsQuery `
                -QueryName "_ldap._tcp.dc._msdcs.$DomainName" `
                -Type 'SRV' `
                -Description "Domain controller LDAP SRV records for $DomainName"

            Invoke-AIDnsQuery `
                -QueryName "_ldap._tcp.$DomainName" `
                -Type 'SRV' `
                -Description "LDAP SRV records for $DomainName"

            Invoke-AIDnsQuery `
                -QueryName "_kerberos._tcp.$DomainName" `
                -Type 'SRV' `
                -Description "Kerberos TCP SRV records for $DomainName"

            Invoke-AIDnsQuery `
                -QueryName "_kerberos._udp.$DomainName" `
                -Type 'SRV' `
                -Description "Kerberos UDP SRV records for $DomainName"
        }

        Invoke-AIDnsQuery `
            -QueryName "_gc._tcp.$($Forest.RootDomain)" `
            -Type 'SRV' `
            -Description "Global Catalog SRV records for forest root domain"

        Invoke-AIDnsQuery `
            -QueryName "_ldap._tcp.gc._msdcs.$($Forest.RootDomain)" `
            -Type 'SRV' `
            -Description "Global Catalog LDAP records under _msdcs"

        foreach ($Dc in $DcInventory) {
            Invoke-AIDnsQuery `
                -QueryName $Dc.HostName `
                -Type 'A' `
                -ExpectedTarget $Dc.IPv4Address `
                -Description "A record for domain controller $($Dc.HostName)"
        }

        $Sites = @($DcInventory | Select-Object -ExpandProperty Site -Unique | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })

        foreach ($Site in $Sites) {
            foreach ($DomainName in $Forest.Domains) {
                Invoke-AIDnsQuery `
                    -QueryName "_ldap._tcp.$Site._sites.dc._msdcs.$DomainName" `
                    -Type 'SRV' `
                    -Description "Site-specific LDAP DC SRV records for site $Site in $DomainName"
            }

            Invoke-AIDnsQuery `
                -QueryName "_gc._tcp.$Site._sites.$($Forest.RootDomain)" `
                -Type 'SRV' `
                -Description "Site-specific Global Catalog SRV records for site $Site"
        }
    }
    catch {
        Write-Error "Failed to test AD DNS resolution. $($_.Exception.Message)"
    }
}