function Test-ValidMoldManifestFile {
    [OutputType([bool])]
    [CmdletBinding()]
    param (
        $ManifestPath
    )
    $ManifestSchema = Get-Content "$PSScriptRoot\resources\SimpleMoldSchema.json" -Raw

    if (Test-Json -Path $ManifestPath -Schema $ManifestSchema -ErrorAction SilentlyContinue) {
        Write-Verbose "passed json test : $ManifestPath"
        return $true
    } else {
        Write-Verbose "Failed json test : $ManifestPath"
        return $false
    }
}