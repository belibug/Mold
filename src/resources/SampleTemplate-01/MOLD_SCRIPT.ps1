param($MoldData)
# File name will be GetSomething.ps1 for function name input of Get-Something
$FuncFileName = $($MoldData.FunctionName -replace '-', '') + '.ps1'
Rename-Item -Path 'Function.ps1' -NewName $FuncFileName