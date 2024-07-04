Import-Module ./dist/Mold
$Project = '.\sample\psfunc'
$ProjectOut = '.\sample\s2out'
# Get-ChildItem $ProjectOut -Recurse | Remove-Item -Force
# Remove-Item -Path "$Project\MoldManifest.json" -Force -ErrorAction SilentlyContinue


# New-MoldManifest -Path $Project -Verbose


Invoke-Mold -TemplatePath $Project -DestinationPath $ProjectOut -Verbose