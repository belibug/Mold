$TemplateName_ScriptBlock = {
    param (
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )

    $commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters | Out-Null
    $presetData = Get-MoldTemplate
    $presetData.Name | Where-Object { $_ -like "$wordToComplete*" }
}
Register-ArgumentCompleter -CommandName Get-MoldTemplate -ParameterName Name -ScriptBlock $TemplateName_ScriptBlock
Register-ArgumentCompleter -CommandName Invoke-Mold -ParameterName Name -ScriptBlock $TemplateName_ScriptBlock
Register-ArgumentCompleter -CommandName New-MoldAnswerFile -ParameterName Name -ScriptBlock $TemplateName_ScriptBlock