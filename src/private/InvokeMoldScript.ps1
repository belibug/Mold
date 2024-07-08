function Invoke-MoldScriptFile {
    param(
        [hashtable]$MoldData,
        [string]$ScriptPath,
        [string]$WorkingDirectory
    )
    if (-not (Test-Path $ScriptPath)) {
        Write-Verbose 'No MOLD_SCRIPT found in template directory, Ignoring script run'
        return
    }
    Push-Location -StackName 'MoldScriptExecution'
    if (-not (Test-Path $WorkingDirectory)) {
        Write-Error 'Destination path not accessible, unable to run MOLD_SCRIPT' -ErrorAction Stop
    }
    Set-Location $WorkingDirectory
    Invoke-Command -ScriptBlock {
        param([hashtable]$MoldData, [string]$scriptPath)
        & $scriptPath -MoldData $MoldData
    } -ArgumentList $MoldData , $ScriptPath
    Pop-Location -StackName 'MoldScriptExecution'
}