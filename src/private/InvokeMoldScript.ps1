function Invoke-MoldScriptFile {
    param(
        [hashtable]$MoldData,
        [string]$ScriptPath,
        [string]$DestinationPath
    )
    if (-not (Test-Path $MoldScriptFile)) {
        Write-Verbose 'No MOLD_SCRIPT found in template directory, Ignoring script run'
        return
    }
    Push-Location -StackName 'MoldScriptExecution'
    if (-not (Test-Path $DestinationPath)) { 
        Write-Error 'Destination path not accessible, unable to run MOLD_SCRIPT' -ErrorAction Stop
    }
    Set-Location $DestinationPath
    Invoke-Command -ScriptBlock {
        param([hashtable]$MoldData, [string]$scriptPath)
        & $scriptPath -MoldData $MoldData
    } -ArgumentList $MoldData , $MoldScriptFile
    Pop-Location -StackName 'MoldScriptExecution'
}