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
   
    # Process Parameters
    $parameters = [ordered]@{}
    $placeholders | ForEach-Object {
        $parameters.$($_.Split('_')[1]) = GenerateQuestion $_
    }

    $metadata = [ordered]@{
        'name'               = 'NewPowerShellModule'
        'version'            = '0.2.0'
        'title'              = 'New PowerShell Module'
        'description'        = 'Plaster template for creating the files for a PowerShell module.'
        'guid'               = New-Guid | ForEach-Object Guid
        'includeFileTypes'   = 'ps1, txt, md, json'
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