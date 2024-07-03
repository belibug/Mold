function Test-MoldStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path,
        [switch]$NewManifest
    )
    $ErrorActionPreference = 'Stop'
    $MoldManifest = Join-Path -Path $Path -ChildPath 'MoldManifest.json'
    # Check if directory exists
    If (-not (Test-Path $Path -ErrorAction SilentlyContinue)) {
        Write-Error 'Path provided either does not exists'
    }
    If (-not (Get-ChildItem $Path -ErrorAction SilentlyContinue)) {
        Write-Error 'Path provided is empty and has no files'
    }
    # Check if it already has MoldManifest, if so abort
    if ($NewManifest) {
        if (Test-Path $MoldManifest) {
            Write-Error 'MoldManifest file already present, use Update-Mold or start over'
        }
    }
}