. 'src/private/Class_MOLDQ.ps1'


$tj = Get-Content -Raw 'C:\Localwork\Projects\Mold\temp\mold-test.json' | ConvertFrom-Json -AsHashtable

# Loop through PSObject properties and add them to the Hashtable
# $q1 = [MoldQ]::new($tj.parameters.EnableGit)
$q1 = [MoldQ]::new($tj.parameters.EnableGit)
# $q1
Read-AwesomeHost $q1