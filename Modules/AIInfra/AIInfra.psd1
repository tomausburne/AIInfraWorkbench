@{
    RootModule = 'AIInfra.psm1'
    ModuleVersion = '0.1.0'
    GUID = '5f3dc9f5-cda9-42c5-a1e9-0c01c0d699e9'
    Author = 'AIInfraWorkbench'
    CompanyName = 'AIInfraWorkbench'
    Copyright = '(c) AIInfraWorkbench. All rights reserved.'
    Description = 'PowerShell 5.1-compatible infrastructure discovery and documentation module.'
    PowerShellVersion = '5.1'
FunctionsToExport = @(
    'Get-AIADReplicationHealth',
    'Get-AIDomainControllerInventory',
    'Get-AIForestSummary',
    'Get-AIFSMORoleInventory',
    'New-AIADMigrationReadinessReport',
    'New-AIADReplicationHealthReport',
    'New-AIDomainControllerMigrationReport',
    'New-AIForestSummaryReport',
    'New-AIADDnsResolutionReport',
    'Test-AIADDnsResolution',
    'Test-AIADMigrationReadiness'
    'New-AIWorkbenchSummaryReport'
)
    CmdletsToExport = @()
    VariablesToExport = '*'
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('ActiveDirectory', 'Infrastructure', 'Documentation', 'PowerShell51')
            ProjectUri = ''
            ReleaseNotes = 'Initial scaffold release.'
        }
    }
}

