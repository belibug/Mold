Import-Module ./dist/Mold
$Project = 'C:\Localwork\Projects\Mold\sample\examrecord'
$ProjectOut = 'C:\Localwork\Projects\Mold\sample\s2out'
# Remove-Item -Path "$Project\MoldManifest.json" -Force -ErrorAction SilentlyContinue


# New-MoldManifest -Path $Project -Verbose


Invoke-Mold -TemplatePath $Project -DestinationPath $ProjectOut -Verbose