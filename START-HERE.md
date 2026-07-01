# Start Here

This is the shortest path to testing the Workbench in your lab.

## 1. Copy The Folder

Copy `AIInfraWorkbench` to your domain-joined lab management VM.

Recommended paths:

```text
E:\AIInfraWorkbench
```

or:

```text
C:\AIInfraWorkbench
```

## 2. Open Windows PowerShell 5.1

Use Windows PowerShell first, not PowerShell 7, because PowerShell 5.1 is the work compatibility target.

## 3. Import The Module

From the project folder:

```powershell
Set-Location E:\AIInfraWorkbench
Import-Module .\Modules\AIInfra\AIInfra.psd1 -Force
Get-Command -Module AIInfra
```

If you copied it to `C:`, use:

```powershell
Set-Location C:\AIInfraWorkbench
Import-Module .\Modules\AIInfra\AIInfra.psd1 -Force
Get-Command -Module AIInfra
```

## 4. Run The First Discovery Command

```powershell
Get-AIForestSummary
```

## 5. Create The First Report

```powershell
Get-AIForestSummary | New-AIForestSummaryReport
```

The report will be created in the `Reports` folder.

## 6. Initialize Git When Ready

After you create your GitHub and work repository URLs, run:

```powershell
.\Scripts\Initialize-GitRepository.ps1 `
    -GitHubRemoteUrl "https://github.com/YOURACCOUNT/AIInfraWorkbench.git" `
    -WorkRemoteUrl "https://YOUR-WORK-GIT-SERVER/AIInfraWorkbench.git"
```

Then push to each remote:

```powershell
git push -u github main
git push -u work main
```

