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
        'name'               = $MetaResult.ShortName
        'version'            = '0.0.1'
        'title'              = $MetaResult.Title
        'description'        = 'MOLD Template'
        'guid'               = New-Guid | ForEach-Object Guid
        'includeFileTypes'   = 'ps1, txt, md, json, xml, psm1, psd1'
        'includeLiteralFile' = 'config'
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