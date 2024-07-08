<#
.SYNOPSIS
   Updates a MoldManifest.json file based on changes in a content of template directory.

.DESCRIPTION
   This function updates an existing MoldManifest.json file to reflect changes made to the corresponding Mold template project directory. It first validates the template directory and reads the existing manifest. Then, it compares the placeholders found in the template files with the parameters defined in the manifest. If it finds new placeholders, it adds them to the manifest. If it finds placeholders that are no longer present in the template, it removes them from the manifest. If it finds placeholders whose types have changed, it updates their types in the manifest. Finally, it writes the updated manifest back to the MoldManifest.json file.

.PARAMETER TemplatePath
   The path to the Mold template directory.

.EXAMPLE
   Update-MoldManifest -TemplatePath 'C:\Templates\MyProject'

   Updates the MoldManifest.json file in the 'C:\Templates\MyProject' directory based on any changes made to the template files.

.NOTES
   This function requires the 'MoldManifest.json' file to be present in the template directory. It only updates existing template MoldManifest.json file.
#>

function Update-MoldManifest {
    [CmdletBinding(SupportsShouldProcess)]
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

    $AllPaceholders = Get-MoldPlaceHolder -Path $TemplatePath

    # Checking PlaceHolders against MoldManifest - to add/update variables
    $AllPaceholders | ForEach-Object {
        $PhType, $PhName, $Extra = $_.split('_')
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
        if ($data.parameters.$_.Type -eq 'BLOCK') {
            $dataPlaceHolder = '{0}_{1}_{2}' -f $data.parameters.$_.Type, $_, 'START'
        } else {
            $dataPlaceHolder = '{0}_{1}' -f $data.parameters.$_.Type, $_
        }
        if ($AllPaceholders -notcontains $dataPlaceHolder) {
            Write-Host "No longer valid placeholder: $_"
            $keysToRemove += $_
            $ChangesMade++
        }
    }
    $keysToRemove.foreach({ $data.parameters.remove($_) })
    if ($ChangesMade -gt 0) {
        Write-Host "Updated $ChangesMade parameters in MoldManifest"
        $result = $data | ConvertTo-Json -Depth 5 -ErrorAction Stop
        Out-File -InputObject $result -FilePath $MoldManifest -Encoding utf8 -ErrorAction Stop
    } else {
        Write-Host 'No changes found in templatePath, MoldManifest unchanged'
    }
}