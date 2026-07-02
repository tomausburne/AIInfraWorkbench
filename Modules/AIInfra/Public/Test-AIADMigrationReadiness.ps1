function Test-AIADMigrationReadiness {
    [CmdletBinding()]
    param(
        [Parameter()]
        [int]
        $WarnDeltaHours = 24,

        [Parameter()]
        [string]
        $DnsServer,

        [Parameter()]
        [switch]
        $SkipDnsChecks,

        [Parameter()]
        [switch]
        $SkipReplicationPortCheck
    )

    function New-AIReadinessCheck {
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
        Import-Module ActiveDirectory -ErrorAction Stop

        $Checks = @()

        $DcInventory = @(Get-AIDomainControllerInventory)
        $FsmoRoles = @(Get-AIFSMORoleInventory)

        $ReplicationParams = @{
            WarnDeltaHours = $WarnDeltaHours
        }

        if ($SkipReplicationPortCheck) {
            $ReplicationParams['SkipPortCheck'] = $true
        }

        $ReplicationHealth = @(Get-AIADReplicationHealth @ReplicationParams)

        $DnsResults = @()
        if (-not $SkipDnsChecks) {
            $DnsParams = @{}

            if (-not [string]::IsNullOrWhiteSpace($DnsServer)) {
                $DnsParams['DnsServer'] = $DnsServer
            }

            $DnsResults = @(Test-AIADDnsResolution @DnsParams)
        }

        if ($DcInventory.Count -gt 0) {
            $Checks += New-AIReadinessCheck `
                -Category 'Domain Controllers' `
                -CheckName 'Domain controller inventory' `
                -Status 'Pass' `
                -Summary "Discovered $($DcInventory.Count) domain controller(s)." `
                -Details (($DcInventory | Select-Object -ExpandProperty HostName) -join '; ')
        }
        else {
            $Checks += New-AIReadinessCheck `
                -Category 'Domain Controllers' `
                -CheckName 'Domain controller inventory' `
                -Status 'Fail' `
                -Blocking $true `
                -Summary 'No domain controllers were discovered.' `
                -Details 'The migration readiness check cannot continue reliably without domain controller inventory.'
        }

        $Dc2016 = @($DcInventory | Where-Object { $_.IsWindowsServer2016 })
        $Dc2022 = @($DcInventory | Where-Object { $_.IsWindowsServer2022 })

        if ($Dc2022.Count -gt 0) {
            $Checks += New-AIReadinessCheck `
                -Category 'Domain Controllers' `
                -CheckName 'Windows Server 2022 DC presence' `
                -Status 'Pass' `
                -Summary "Found $($Dc2022.Count) Windows Server 2022 domain controller(s)." `
                -Details (($Dc2022 | Select-Object -ExpandProperty HostName) -join '; ')
        }
        else {
            $Checks += New-AIReadinessCheck `
                -Category 'Domain Controllers' `
                -CheckName 'Windows Server 2022 DC presence' `
                -Status 'Fail' `
                -Blocking $true `
                -Summary 'No Windows Server 2022 domain controllers were found.' `
                -Details 'At least one Windows Server 2022 domain controller should exist before migration readiness can be considered good.'
        }

        if ($Dc2016.Count -gt 0) {
            $Checks += New-AIReadinessCheck `
                -Category 'Domain Controllers' `
                -CheckName 'Windows Server 2016 DCs remaining' `
                -Status 'Warning' `
                -Summary "$($Dc2016.Count) Windows Server 2016 domain controller(s) still exist." `
                -Details (($Dc2016 | Select-Object -ExpandProperty HostName) -join '; ')
        }
        else {
            $Checks += New-AIReadinessCheck `
                -Category 'Domain Controllers' `
                -CheckName 'Windows Server 2016 DCs remaining' `
                -Status 'Pass' `
                -Summary 'No Windows Server 2016 domain controllers were found.' `
                -Details 'All discovered domain controllers are past the Windows Server 2016 migration target.'
        }

        $Domains = @($DcInventory | Select-Object -ExpandProperty Domain -Unique)
        $ExpectedFsmoRoleCount = 2 + (3 * $Domains.Count)

        if ($FsmoRoles.Count -eq $ExpectedFsmoRoleCount) {
            $Checks += New-AIReadinessCheck `
                -Category 'FSMO Roles' `
                -CheckName 'FSMO role discovery' `
                -Status 'Pass' `
                -Summary "Discovered all expected FSMO roles: $($FsmoRoles.Count)." `
                -Details (($FsmoRoles | ForEach-Object { "$($_.Role)=$($_.RoleHolder)" }) -join '; ')
        }
        else {
            $Checks += New-AIReadinessCheck `
                -Category 'FSMO Roles' `
                -CheckName 'FSMO role discovery' `
                -Status 'Fail' `
                -Blocking $true `
                -Summary "Discovered $($FsmoRoles.Count) FSMO role(s), expected $ExpectedFsmoRoleCount." `
                -Details 'Review FSMO role discovery before proceeding with domain controller migration.'
        }

        $FsmoOn2016 = @($FsmoRoles | Where-Object { $_.IsWindowsServer2016 })

        if ($FsmoOn2016.Count -gt 0) {
            $Checks += New-AIReadinessCheck `
                -Category 'FSMO Roles' `
                -CheckName 'FSMO roles on Windows Server 2016' `
                -Status 'Warning' `
                -Summary "$($FsmoOn2016.Count) FSMO role(s) are still hosted on Windows Server 2016 domain controllers." `
                -Details (($FsmoOn2016 | ForEach-Object { "$($_.Role)=$($_.RoleHolder)" }) -join '; ')
        }
        else {
            $Checks += New-AIReadinessCheck `
                -Category 'FSMO Roles' `
                -CheckName 'FSMO roles on Windows Server 2016' `
                -Status 'Pass' `
                -Summary 'No FSMO roles are hosted on Windows Server 2016 domain controllers.' `
                -Details 'FSMO placement appears ready from a 2016-to-2022 migration perspective.'
        }

        $ReplicationFailing = @($ReplicationHealth | Where-Object { $_.Status -eq 'Failing' })
        $ReplicationWarning = @($ReplicationHealth | Where-Object { $_.Status -eq 'Warning' })

        if ($ReplicationFailing.Count -gt 0) {
            $Checks += New-AIReadinessCheck `
                -Category 'Replication' `
                -CheckName 'AD replication health' `
                -Status 'Fail' `
                -Blocking $true `
                -Summary "$($ReplicationFailing.Count) replication link(s) are failing." `
                -Details (($ReplicationFailing | Select-Object -First 10 | ForEach-Object { "$($_.DomainController) -> $($_.Partner): $($_.LastReplicationResultMessage)" }) -join '; ')
        }
        elseif ($ReplicationWarning.Count -gt 0) {
            $Checks += New-AIReadinessCheck `
                -Category 'Replication' `
                -CheckName 'AD replication health' `
                -Status 'Warning' `
                -Summary "$($ReplicationWarning.Count) replication link(s) are in warning state." `
                -Details (($ReplicationWarning | Select-Object -First 10 | ForEach-Object { "$($_.DomainController) -> $($_.Partner)" }) -join '; ')
        }
        else {
            $Checks += New-AIReadinessCheck `
                -Category 'Replication' `
                -CheckName 'AD replication health' `
                -Status 'Pass' `
                -Summary 'No failing or warning replication links were found.' `
                -Details "Warning threshold: $WarnDeltaHours hour(s)."
        }

        if ($SkipDnsChecks) {
            $Checks += New-AIReadinessCheck `
                -Category 'DNS Resolution' `
                -CheckName 'AD DNS resolution checks' `
                -Status 'Warning' `
                -Summary 'DNS resolution checks were skipped.' `
                -Details 'This was requested by using -SkipDnsChecks.'
        }
        else {
            $DnsFailures = @($DnsResults | Where-Object { $_.Status -eq 'Fail' })
            $DnsWarnings = @($DnsResults | Where-Object { $_.Status -eq 'Warning' })

            if ($DnsFailures.Count -gt 0) {
                $Checks += New-AIReadinessCheck `
                    -Category 'DNS Resolution' `
                    -CheckName 'AD DNS resolution checks' `
                    -Status 'Fail' `
                    -Blocking $true `
                    -Summary "$($DnsFailures.Count) AD DNS resolution check(s) failed." `
                    -Details (($DnsFailures | Select-Object -First 10 | ForEach-Object { "$($_.RecordType) $($_.QueryName): $($_.Error)" }) -join '; ')
            }
            elseif ($DnsWarnings.Count -gt 0) {
                $Checks += New-AIReadinessCheck `
                    -Category 'DNS Resolution' `
                    -CheckName 'AD DNS resolution checks' `
                    -Status 'Warning' `
                    -Summary "$($DnsWarnings.Count) AD DNS resolution check(s) returned warnings." `
                    -Details (($DnsWarnings | Select-Object -First 10 | ForEach-Object { "$($_.RecordType) $($_.QueryName)" }) -join '; ')
            }
            else {
                $Checks += New-AIReadinessCheck `
                    -Category 'DNS Resolution' `
                    -CheckName 'AD DNS resolution checks' `
                    -Status 'Pass' `
                    -Summary "All AD DNS resolution checks passed. Total checks: $($DnsResults.Count)." `
                    -Details 'Client-side AD DNS resolution appears healthy from this management workstation.'
            }
        }

        $BlockingFailures = @($Checks | Where-Object { $_.Status -eq 'Fail' -and $_.Blocking })
        $Warnings = @($Checks | Where-Object { $_.Status -eq 'Warning' })

        $OverallReadiness = 'Ready'
        if ($BlockingFailures.Count -gt 0) {
            $OverallReadiness = 'Blocked'
        }
        elseif ($Warnings.Count -gt 0) {
            $OverallReadiness = 'Warning'
        }

        foreach ($Check in $Checks) {
            $Check | Add-Member -MemberType NoteProperty -Name OverallReadiness -Value $OverallReadiness -Force
            $Check | Add-Member -MemberType NoteProperty -Name GeneratedAt -Value (Get-Date) -Force
            $Check
        }
    }
    catch {
        Write-Error "Failed to test AD migration readiness. $($_.Exception.Message)"
    }
}