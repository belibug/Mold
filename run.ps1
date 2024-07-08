Import-Module ./dist/Mold
$Project = '.\sample\s2'
$ProjectOut = '.\sample\out'
$Build = $true
$Build = $false

if ($Build) {
    Get-ChildItem $ProjectOut -Recurse | Remove-Item -Force
    Remove-Item -Path "$Project\MoldManifest.json" -Force -ErrorAction SilentlyContinue
    New-MoldManifest -Path $Project -Verbose
}

# $env:MOLD_TEMPLATES = '/Users/beli/Temp/MoldTemplates'
# Invoke-Mold -TemplatePath $Project -DestinationPath $ProjectOut -Verbose
# if (!$Build) {
#     Update-MoldManifest -TemplatePath $Project
# }
Get-MoldTemplate -TemplatePath $Project
#-TemplatePath '/Users/beli/localwork/Mold/sample' -Recurse


# $ManifestFile = '/Users/beli/localwork/Mold/src/resources/SampleTemplate-02/MoldManifest.json'

# $data = Get-Content -Path $ManifestFile -Raw | ConvertFrom-Json 
