#requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()]
    [string]
    $ProjectRoot = (Split-Path $PSScriptRoot -Parent),

    [Parameter()]
    [string]
    $GitHubRemoteUrl,

    [Parameter()]
    [string]
    $WorkRemoteUrl
)

Push-Location $ProjectRoot

try {
    if (-not (Test-Path (Join-Path $ProjectRoot '.git'))) {
        git init
    }

    git branch -M main
    git add .

    $HasCommit = $true
    git rev-parse --verify HEAD 2>$null
    if ($LASTEXITCODE -ne 0) {
        $HasCommit = $false
    }

    if (-not $HasCommit) {
        git commit -m "Initial AIInfraWorkbench scaffold"
    }

    $ExistingRemotes = git remote

    if (-not [string]::IsNullOrWhiteSpace($GitHubRemoteUrl) -and $ExistingRemotes -notcontains 'github') {
        git remote add github $GitHubRemoteUrl
    }

    if (-not [string]::IsNullOrWhiteSpace($WorkRemoteUrl) -and $ExistingRemotes -notcontains 'work') {
        git remote add work $WorkRemoteUrl
    }

    git status
    git remote -v
}
finally {
    Pop-Location
}

