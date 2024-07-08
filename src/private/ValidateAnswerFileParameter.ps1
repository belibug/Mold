function Test-ValidateAnswerFileParameter {
    [CmdletBinding()]
    param (
        [string]$AnswerFile,
        [string]$ManifestFile
    )
    $AnswerFile, $ManifestFile | ForEach-Object {
        if (-not(Test-Path $_)) { Write-Error "$_ not found or accessible" -ErrorAction Stop }
    }
    $AnswerData = Get-Content -Raw -Path $AnswerFile | ConvertFrom-Json -ErrorAction Stop
    $ManifestData = Get-Content -Raw -Path $ManifestFile | ConvertFrom-Json -ErrorAction Stop

    $ManifestData.parameters.PSObject.Properties.Name | ForEach-Object {
        if ($AnswerData.Key -notcontains $_) { Write-Error "$_ is missing in Answer File" }
    }
}