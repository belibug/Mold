function Test-MoldHealth {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Path
    )
    $ErrorActionPreference = 'Stop'
    $MoldManifest = Join-Path -Path $Path -ChildPath 'MoldManifest.json'
    # Check if path exists
    if (-not(Test-Path -Path $Path)) {
        Write-Error 'Template Path not found or accessible'
    }
    # Check if path exists
    if (-not(Test-Path -Path $MoldManifest)) {
        Write-Error 'Not a valid Mold Template, missing MoldManifest.json file'
    }
    #TODO MoldManifest Schema check json
}