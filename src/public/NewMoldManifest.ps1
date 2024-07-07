<#
.SYNOPSIS
   Creates a new MoldManifest.json file for a Mold template.

.DESCRIPTION
   This function creates a new MoldManifest.json file in the specified directory, which is used to define the structure and parameters of a Mold template. Generate Mold Template for any file or project easily using this command.

.PARAMETER Path
   The path to the directory where template conten is store, the MoldManifest.json file will be created in same directory.

.EXAMPLE
   New-MoldManifest -Path 'C:\Templates\MyProject'

   Creates a new MoldManifest.json file in the 'C:\Templates\MyProject' directory. The user will be prompted for input to define the template's metadata and parameters.

.NOTES
    This generates the necessary MoldManifest.json file template. Once created ensure you edit the file to update the placeholder questions/responses.
#>

function New-MoldManifest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Path
    )
    $MoldManifest = Join-Path -Path $Path -ChildPath 'MoldManifest.json'
    # Validation before starting the workflow
    Test-MoldStatus -Path $Path -NewManifest

    ## Find Parameters
    $PlaceHolders = Get-MoldPlaceHolders -Path $Path
   
    $MetaQuestions = Get-Content -Raw "$PSScriptRoot\resources\NewMoldQuestions.json" | ConvertFrom-Json -AsHashtable
    $MetaResult = @{}

    #region Get Answers interactively
    $MetaQuestions.parameters.Keys | ForEach-Object {
        $q = [MoldQ]::new($MetaQuestions.parameters.$_)
        $q.answer = Read-awesomeHost $q
        $q.Key = $_
        $MetaResult.add($q.Key, $q.answer) | Out-Null
    }

    # Process Parameters
    $parameters = [ordered]@{}
    $placeholders | ForEach-Object {
        $parameters.$($_.Split('_')[1]) = GenerateQuestion $_
    }

    $metadata = [ordered]@{
        'name'        = $MetaResult.ShortName
        'version'     = '0.0.1'
        'title'       = $MetaResult.Title
        'description' = 'MOLD Template'
        'guid'        = New-Guid | ForEach-Object Guid
        'FileTypes'   = 'ps1, txt, md, json, xml, psm1, psd1'
        'LiteralFile' = 'config'
    }

    $data = [ordered]@{
        metadata   = $metadata
        parameters = $parameters
    }
    $data | ConvertTo-Json -Depth 5 | Out-File -FilePath $MoldManifest
    if ($?) {
        'Manifest created' | Write-Host -ForegroundColor Green
    }
}