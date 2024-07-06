function Get-MoldTemplate {
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]$IncludeInstalledModules,
        [switch]$ListAvailable,
        [string]$Name,
        [string]$TemplatePath,
        [switch]$Recurse
    )
    $AllTemplates = New-Object System.Collections.ArrayList


    ## If path is specified, return only templates found in path
    if ($PSBoundParameters.ContainsKey('TemplatePath')) {
        $result = Get-TemplatesFromPath -Path $TemplatePath -Recurse:$Recurse
        return $result
    }

    # Templates found in MOLD module
    $Templates = Get-TemplatesFromPath -Path $PSScriptRoot\resources -Recurse
    $AllTemplates.Add($Templates) | Out-Null

    # Templates from MOLD_TEMPLATES environment variable location
    if ($env:MOLD_TEMPLATES) {
        $env:MOLD_TEMPLATES -split (';') | ForEach-Object {
            $Templates = Get-TemplatesFromPath -Path $_ -Recurse
            $AllTemplates.Add($Templates) | Out-Null
        }
    }
    # Templates from Other Modules using PSData-extensions
    #TODO Not yet implemented

    $Out = $AllTemplates | ConvertTo-Json | ConvertFrom-Json
    return $Out
}