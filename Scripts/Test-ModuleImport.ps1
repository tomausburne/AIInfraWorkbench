#requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()]
    [string]
    $ProjectRoot = (Split-Path $PSScriptRoot -Parent)
)

$ManifestPath = Join-Path $ProjectRoot 'Modules\AIInfra\AIInfra.psd1'

if (-not (Test-Path $ManifestPath)) {
    throw "Module manifest not found at '$ManifestPath'."
}

Import-Module $ManifestPath -Force -ErrorAction Stop

Get-Command -Module AIInfra | Sort-Object Name

