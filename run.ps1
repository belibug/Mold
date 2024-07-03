Import-Module ./dist/Mold
$Project = 'C:\Localwork\Projects\Mold\sample\s2'
Remove-Item -Path "$Project\MoldManifest.json" -Force -ErrorAction SilentlyContinue
New-MoldManifest -Path $Project -Verbose
Invoke-Mold -TemplatePath 'C:\Localwork\Projects\Mold\sample\s2' -Verbose