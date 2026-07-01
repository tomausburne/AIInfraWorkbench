function Write-AILog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Message,

        [Parameter()]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]
        $Level = 'Information'
    )

    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $Line = '{0} [{1}] {2}' -f $Timestamp, $Level, $Message

    switch ($Level) {
        'Information' { Write-Verbose $Line }
        'Warning' { Write-Warning $Message }
        'Error' { Write-Error $Message }
    }
}

