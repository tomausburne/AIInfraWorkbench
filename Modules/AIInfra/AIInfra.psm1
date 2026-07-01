#requires -Version 5.1

$PrivateFunctions = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Private\*.ps1') -ErrorAction SilentlyContinue
foreach ($FunctionFile in $PrivateFunctions) {
    . $FunctionFile.FullName
}

$PublicFunctions = Get-ChildItem -Path (Join-Path $PSScriptRoot 'Public\*.ps1') -ErrorAction SilentlyContinue
foreach ($FunctionFile in $PublicFunctions) {
    . $FunctionFile.FullName
}

$PublicFunctionNames = $PublicFunctions | ForEach-Object {
    [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
}

Export-ModuleMember -Function $PublicFunctionNames

