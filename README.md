# AI Infrastructure Engineer Workbench

A PowerShell 5.1-compatible infrastructure workbench for Active Directory, Windows Server, and enterprise documentation.

This project is designed to be built and tested first in a home Hyper-V lab, then reviewed and published to one or more Git repositories.

## Current Focus

- PowerShell 5.1 compatibility
- Read-only Active Directory discovery by default
- Lab-first testing
- Portable folder structure
- Git-friendly project layout

## First Commands

Import the module from the project root:

```powershell
Import-Module .\Modules\AIInfra\AIInfra.psd1 -Force
```

Run the first discovery command from a domain-joined management workstation:

```powershell
Get-AIForestSummary
```

Create a basic HTML report:

```powershell
Get-AIForestSummary | New-AIForestSummaryReport
```

## Recommended Lab Workflow

1. Build and edit the project on the home workstation.
2. Publish to a private GitHub repository.
3. Pull the repository onto a domain-joined lab management VM.
4. Test in Windows PowerShell 5.1 first.
5. Test in PowerShell 7 as an optional compatibility check.
6. Publish the tested version to the work repository when appropriate.

## Safety Rules

- Discovery commands are read-only by default.
- Production changes require explicit approval and separate commands.
- PowerShell 5.1 remains the baseline runtime.
- Scripts should not require execution policy changes in managed work environments.

