function Get-TemplatesFromPath {
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
    }
    $MMFiles | ForEach-Object {
        if (Test-ValidMoldManifestFile -ManifestPath $_.FullName) {
            $ValidManifestFiles.Add($_.FullName) | Out-Null
        }
    }
    $ValidManifestFiles | ForEach-Object {
        $data = (Get-Content $_ -Raw | ConvertFrom-Json).metadata
        $data | Add-Member -NotePropertyName TemplateFile -NotePropertyValue $_
        $obj = [pscustomobject]@{
            Name         = $data.name
            Version      = $data.version
            Description  = $data.description
            GUID         = $data.guid
            ManifestFile = $_
        }
        $Output.Add($obj) | Out-Null
    }
    return $Output
}