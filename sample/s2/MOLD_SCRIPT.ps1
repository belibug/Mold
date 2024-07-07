$data = @()
$data += Get-Location 
$data += Get-ChildItem -Recurse
$data | Out-File 'out.txt' | Out-Null