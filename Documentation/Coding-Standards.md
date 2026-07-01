# Coding Standards

## Baseline

- Target Windows PowerShell 5.1.
- Use advanced functions with `[CmdletBinding()]`.
- Keep discovery commands read-only by default.
- Return objects, not formatted text.
- Let report functions handle formatting.
- Use approved PowerShell verbs when practical.
- Avoid PowerShell 7-only syntax in core module files.

## Avoid In Core Code

- `ForEach-Object -Parallel`
- Ternary operators
- Null coalescing operators
- Pipeline chain operators
- Cross-platform assumptions
- Changes to production systems without explicit action commands

## Function Layout

```powershell
function Get-AIThing {
    [CmdletBinding()]
    param()

    begin {
    }

    process {
    }

    end {
    }
}
```

## Error Handling

- Use `try` and `catch` around external dependencies.
- Use `-ErrorAction Stop` when a terminating error is needed.
- Include useful context in error messages.
- Do not hide errors that affect data quality.

