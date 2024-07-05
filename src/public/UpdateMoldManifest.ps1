function Update-MoldManifest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $TemplatePath
    )
    
    # Validate MoldTemplate
    Test-MoldHealth -Path $TemplatePath
    $MoldManifest = Join-Path -Path $TemplatePath -ChildPath 'MoldManifest.json'

    $data = Get-Content -Raw $MoldManifest | ConvertFrom-Json -AsHashtable
    
    $AllPaceholders = Get-MoldPlaceHolders -Path $TemplatePath
    
    $AllPaceholders | ForEach-Object {
        $PhType, $PhName = $_.split('_')
        if ($data.parameters.Keys -contains $PhName ) {
            
            if ($data.parameters.$PhName.Type -eq $PhType) {
                Write-Host "Found existing name and type - $PhName"
            } else {
                Write-Host "Type has changed - $PhName"
            }
        } else {
            Write-Host "found new $PhName"
        }
    }
}