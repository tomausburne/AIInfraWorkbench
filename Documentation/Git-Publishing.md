# Git Publishing

This project can be published to two repositories:

- A private GitHub repository for home and lab development.
- A work Git repository for enterprise review and storage.

## Two Remote Pattern

Example remote names:

| Remote | Purpose |
| --- | --- |
| `github` | Private GitHub repository |
| `work` | Work Git repository |

## Example Commands

Initialize the repository:

```powershell
git init
git add .
git commit -m "Initial AIInfraWorkbench scaffold"
```

Add remotes:

```powershell
git remote add github https://github.com/YOURACCOUNT/AIInfraWorkbench.git
git remote add work https://YOUR-WORK-GIT-SERVER/AIInfraWorkbench.git
```

Push to GitHub:

```powershell
git push -u github main
```

Push to work:

```powershell
git push -u work main
```

If Git creates a `master` branch by default, rename it to `main`:

```powershell
git branch -M main
```

