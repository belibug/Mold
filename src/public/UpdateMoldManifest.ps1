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
    $ChangesMade = 0

    $data = Get-Content -Raw $MoldManifest | ConvertFrom-Json -AsHashtable
    
    $AllPaceholders = Get-MoldPlaceHolders -Path $TemplatePath
    
    # Checking PlaceHolders against MoldManifest - to add/update variables
    $AllPaceholders | ForEach-Object {
        $PhType, $PhName = $_.split('_')
        if ($data.parameters.Keys -contains $PhName ) {
            if ($data.parameters.$PhName.Type -ne $PhType) {
                Write-Host "Type has changed for: $PhName"
                $data.parameters.remove($PhName)
                $NewQuestion = GenerateQuestion $_
                $data.parameters.add($PhName, $NewQuestion)
                $ChangesMade++
            }
        } else {
            Write-Host "Found new Placeholder: $PhName"
            $NewQuestion = GenerateQuestion $_
            $data.parameters.add($PhName, $NewQuestion)
            $ChangesMade++
        }
    }
    # Checking MoldManifest against PlaceHolders - to remove stale variables
    $keysToRemove = @()
    $data.parameters.Keys | ForEach-Object {
        $dataPlaceHolder = '{0}_{1}' -f $data.parameters.$_.Type, $_
        if ($AllPaceholders -notcontains $dataPlaceHolder) {
            Write-Host "No longer valid placeholder: $_"
            $keysToRemove += $_
            $ChangesMade++
        }
    }
    $keysToRemove.foreach({ $data.parameters.remove($_) })
    if ($ChangesMade -gt 0) {
        Write-Host "Updated $ChangesMade parameters in MoldManifest"
        $data | ConvertTo-Json -Depth 5 | Out-File -FilePath $MoldManifest -Encoding utf8
    } else {
        Write-Host 'No changes found in templatePath, MoldManifest unchanged' 
    }
}