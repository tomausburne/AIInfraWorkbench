# Development Workflow

## Environments

| Environment | Purpose |
| --- | --- |
| Home workstation | Editing, Codex work, Git publishing |
| Lab management VM | Domain-joined testing against Hyper-V lab |
| Work environment | Reviewed production use |

## Recommended Flow

1. Edit files on the home workstation or in Codex.
2. Commit changes to Git.
3. Push to GitHub.
4. Pull the latest code onto the lab management VM.
5. Test in Windows PowerShell 5.1.
6. Fix issues and repeat.
7. Push approved changes to the work repository.

## Lab Management VM

The lab management VM should be domain joined and have:

- Windows PowerShell 5.1
- PowerShell 7, optional
- RSAT Active Directory tools
- RSAT DNS tools
- RSAT Group Policy tools
- Git
- VS Code

The Workbench should be run from the management VM, not directly from a domain controller.

