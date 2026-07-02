function Get-AIADReplicationHealth {
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]
        $WarnDeltaHours = 24,

        [Parameter()]
        [string]
        $Server,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        $Credential,

        [Parameter()]
        [switch]
        $SkipPortCheck
    )

    function Get-AIObjectProperty {
        param(
            [Parameter(Mandatory)]
            [object] $InputObject,

            [Parameter(Mandatory)]
            [string] $Name,

            [object] $Default = $null
        )

        $Property = $InputObject.PSObject.Properties |
            Where-Object { $_.Name -eq $Name } |
            Select-Object -First 1

        if ($null -eq $Property) {
            return $Default
        }

        return $Property.Value
    }

    try {
        Import-Module ActiveDirectory -ErrorAction Stop

        $Now = Get-Date

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

            $DomainControllers = Get-ADDomainController -Filter * @DomainParams -ErrorAction Stop |
                Sort-Object HostName

            foreach ($DomainController in $DomainControllers) {
                $CollectionError = $null
                $RawMetadata = @()

                try {
                    if (-not $SkipPortCheck) {
                        $PortOpen = Test-NetConnection -ComputerName $DomainController.HostName -Port 9389 -InformationLevel Quiet -WarningAction SilentlyContinue

                        if (-not $PortOpen) {
                            throw "ADWS TCP 9389 is not reachable on $($DomainController.HostName)."
                        }
                    }

                    $ReplicationParams = @{
                        Target = $DomainController.HostName
                        Scope  = 'Server'
                    }

                    if ($PSBoundParameters.ContainsKey('Credential')) {
                        $ReplicationParams['Credential'] = $Credential
                    }

                    $RawMetadata = @(Get-ADReplicationPartnerMetadata @ReplicationParams -ErrorAction Stop)
                }
                catch {
                    $CollectionError = $_.Exception.Message
                }

                if ($CollectionError) {
                    [pscustomobject]@{
                        Domain                       = $DomainName
                        DomainController             = $DomainController.HostName
                        Site                         = $DomainController.Site
                        IPv4Address                  = $DomainController.IPv4Address
                        OperatingSystem              = $DomainController.OperatingSystem
                        IsWindowsServer2016          = ($DomainController.OperatingSystem -like '*2016*')
                        IsWindowsServer2022          = ($DomainController.OperatingSystem -like '*2022*')
                        Partner                      = $null
                        Partition                    = $null
                        PartnerType                  = $null
                        Transport                    = $null
                        Status                       = 'Failing'
                        ConsecutiveFailures          = 1
                        TimeSinceLastSuccess         = $null
                        LastReplicationSuccess       = $null
                        LastReplicationAttempt       = $null
                        LastReplicationResult        = $null
                        LastReplicationResultMessage = $CollectionError
                        CollectionError              = $CollectionError
                    }

                    continue
                }

                if ($RawMetadata.Count -eq 0) {
                    [pscustomobject]@{
                        Domain                       = $DomainName
                        DomainController             = $DomainController.HostName
                        Site                         = $DomainController.Site
                        IPv4Address                  = $DomainController.IPv4Address
                        OperatingSystem              = $DomainController.OperatingSystem
                        IsWindowsServer2016          = ($DomainController.OperatingSystem -like '*2016*')
                        IsWindowsServer2022          = ($DomainController.OperatingSystem -like '*2022*')
                        Partner                      = $null
                        Partition                    = $null
                        PartnerType                  = $null
                        Transport                    = $null
                        Status                       = 'Warning'
                        ConsecutiveFailures          = 0
                        TimeSinceLastSuccess         = $null
                        LastReplicationSuccess       = $null
                        LastReplicationAttempt       = $null
                        LastReplicationResult        = $null
                        LastReplicationResultMessage = 'No replication partner metadata returned.'
                        CollectionError              = $null
                    }

                    continue
                }

                foreach ($Item in $RawMetadata) {
                    $LastSuccess = Get-AIObjectProperty -InputObject $Item -Name 'LastReplicationSuccess'
                    $Delta = if ($LastSuccess) { $Now - $LastSuccess } else { $null }

                    $FailuresValue = Get-AIObjectProperty -InputObject $Item -Name 'ConsecutiveReplicationFailures' -Default 0
                    $Failures = if ($null -ne $FailuresValue) { [int]$FailuresValue } else { 0 }

                    $ResultValue = Get-AIObjectProperty -InputObject $Item -Name 'LastReplicationResult'
                    $ResultCode = if ($null -ne $ResultValue) { [int]$ResultValue } else { $null }

                    $ResultMessage = Get-AIObjectProperty -InputObject $Item -Name 'LastReplicationResultMessage'

                    if ([string]::IsNullOrWhiteSpace([string]$ResultMessage) -and $null -ne $ResultCode) {
                        if ($ResultCode -eq 0) {
                            $ResultMessage = 'The operation completed successfully.'
                        }
                        else {
                            $ResultMessage = "Non-zero replication result code: $ResultCode"
                        }
                    }

                    $IsFailure = ($Failures -gt 0) -or ($null -ne $ResultCode -and $ResultCode -ne 0)
                    $IsWarning = -not $IsFailure -and $Delta -and $Delta.TotalHours -gt $WarnDeltaHours

                    $Status = 'Healthy'
                    if ($IsFailure) {
                        $Status = 'Failing'
                    }
                    elseif ($IsWarning) {
                        $Status = 'Warning'
                    }

                    [pscustomobject]@{
                        Domain                       = $DomainName
                        DomainController             = $DomainController.HostName
                        Site                         = $DomainController.Site
                        IPv4Address                  = $DomainController.IPv4Address
                        OperatingSystem              = $DomainController.OperatingSystem
                        IsWindowsServer2016          = ($DomainController.OperatingSystem -like '*2016*')
                        IsWindowsServer2022          = ($DomainController.OperatingSystem -like '*2022*')
                        Partner                      = Get-AIObjectProperty -InputObject $Item -Name 'Partner'
                        Partition                    = Get-AIObjectProperty -InputObject $Item -Name 'Partition'
                        PartnerType                  = Get-AIObjectProperty -InputObject $Item -Name 'PartnerType'
                        Transport                    = Get-AIObjectProperty -InputObject $Item -Name 'IntersiteTransport'
                        Status                       = $Status
                        ConsecutiveFailures          = $Failures
                        TimeSinceLastSuccess         = $Delta
                        LastReplicationSuccess       = $LastSuccess
                        LastReplicationAttempt       = Get-AIObjectProperty -InputObject $Item -Name 'LastReplicationAttempt'
                        LastReplicationResult        = $ResultCode
                        LastReplicationResultMessage = $ResultMessage
                        CollectionError              = $null
                    }
                }
            }
        }
    }
    catch {
        Write-Error "Failed to collect AD replication health. $($_.Exception.Message)"
    }
}