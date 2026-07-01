# AI Infrastructure Engineer Workbench Project Goals

## Goal

Build a PowerShell 5.1-compatible infrastructure workbench for Active Directory, Windows Server, Microsoft 365, Azure, and enterprise documentation.

## First Command

`Get-AIForestSummary`

## First Report

Forest Summary HTML Report

## Rules

- Must run in Windows PowerShell 5.1.
- Must be safe to run in production.
- Must be read-only by default.
- Must make no changes unless explicitly requested.
- Must export results to HTML, CSV, JSON, or Markdown where useful.

## Deployment Model

Development and testing are performed in a home Hyper-V lab first.

The workbench must be safe to transfer into a work environment later.

Work environment assumptions:

- Windows PowerShell 5.1 may be required.
- Execution policy may be controlled by enterprise policy.
- All discovery functions should be read-only by default.
- No production changes unless explicitly requested and approved.
- Scripts should be packageable for review and transfer.

