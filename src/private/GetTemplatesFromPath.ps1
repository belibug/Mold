function Get-TemplatesFromPath {
    [OutputType([System.Collections.ArrayList])]
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Path,
        [switch]$Recurse
    )
    $ValidManifestFiles = New-Object System.Collections.ArrayList
    $Output = New-Object System.Collections.ArrayList

    $MMFiles = Get-ChildItem -Path $Path -Filter 'MoldManifest.json' -Recurse:$Recurse
    if (-not $MMFiles) {
        Write-Verbose "No MoldManifest files found in given $path"
        return $null
    }
    $MMFiles | ForEach-Object {
        if (Test-ValidMoldManifestFile -ManifestPath $_.FullName) {
            $ValidManifestFiles.Add($_.FullName) | Out-Null
        }
    }
    $ValidManifestFiles | ForEach-Object {
        $data = Get-Content $_ -Raw | ConvertFrom-Json
        $obj = [pscustomobject]@{
            Name         = $data.metadata.name
            Version      = $data.metadata.version
            Description  = $data.metadata.description
            GUID         = $data.metadata.guid
            ManifestFile = $_
        }
        $Output.Add($obj) | Out-Null
    }
    return $Output
}