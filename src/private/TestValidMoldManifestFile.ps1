function Test-ValidMoldManifestFile {
    [CmdletBinding()]
    param (
        $ManifestPath
    )
    $ManifestSchema = Get-Content "$PSScriptRoot\resources\SimpleMoldSchema.json" -Raw

    #PS5-WorkAround
    if (Test-Json -Path $ManifestPath -Schema $ManifestSchema -ErrorAction SilentlyContinue) {
        Write-Verbose "passed json test : $ManifestPath"
        return $true
    } else {
        Write-Verbose "Failed json test : $ManifestPath"
        return $false
    }
}