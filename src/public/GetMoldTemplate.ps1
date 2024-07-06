function Get-MoldTemplate {
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        [ValidateNotNullOrEmpty()]
        [Parameter(ParameterSetName = 'TemplatePathSet')]
        [string]$TemplatePath,
        [Parameter(ParameterSetName = 'TemplatePathSet')]
        [switch]$Recurse,
        [switch]$IncludeInstalledModules
    )

    $AllTemplates = New-Object System.Collections.ArrayList

    if ($PSBoundParameters.ContainsKey('Name')) {
        $TemplateByName = Get-MoldTemplate | Where-Object { $_.Name -eq $Name }
        if ($TemplateByName) {
            return $TemplateByName 
        } else {
            Write-Warning "Did not find any template named $Name" 
            return
        }
    }

    ## If path is specified, return only templates found in path
    if ($PSBoundParameters.ContainsKey('TemplatePath')) {
        $result = Get-TemplatesFromPath -Path $TemplatePath -Recurse:$Recurse
        return $result
    }

    # Templates found in MOLD module
    $Templates = Get-TemplatesFromPath -Path $PSScriptRoot\resources -Recurse
    $Templates | ForEach-Object { $AllTemplates.Add($_) | Out-Null }

    # Templates from MOLD_TEMPLATES environment variable location
    if ($env:MOLD_TEMPLATES) {
        $env:MOLD_TEMPLATES -split (';') | ForEach-Object {
            $Templates = Get-TemplatesFromPath -Path $_ -Recurse
            $Templates | ForEach-Object { $AllTemplates.Add($_) | Out-Null }
        }
    }
    # Templates from Other Modules using PSData-extensions
    #TODO Not yet implemented

    $Out = $AllTemplates | ConvertTo-Json | ConvertFrom-Json
    return $Out
}