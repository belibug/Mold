<#
.SYNOPSIS
   Gets Mold templates from various sources.

.DESCRIPTION
   This function retrieves Mold templates from different locations, including the local Template directory, path defined in environment variable  MOLD_TEMPLATES, and templates from installed modules. It can filter templates by name or path, and optionally recurse through subdirectories. The function returns an array of objects representing the found templates.

.PARAMETER Name
   The name of the Mold template to search for. Search by name, supports tab completion

.PARAMETER TemplatePath
   The path to a directory containing Mold templates.

.PARAMETER Recurse
   If specified, the function will search for templates recursively in provide path.

.PARAMETER IncludeInstalledModules
   If specified, the function will also search for templates in installed modules. (Not yet implemented)

.EXAMPLE
Get-MoldTemplate

Retrieves the Mold template from Mold Module samples, Templates in path defined in env varible MOLD_TEMPLATES

.EXAMPLE
   Get-MoldTemplate -Name 'MyTemplate'

   Retrieves the Mold template named 'MyTemplate' from any of the available sources.

.EXAMPLE
   Get-MoldTemplate -TemplatePath 'C:\Templates' -Recurse

   Retrieves all Mold templates found in the 'C:\Templates' directory and its subdirectories.

.NOTES
   The function prioritizes templates found by name.
   The function searches for templates in the following locations:
     - The templates shipped along with MOLD module
     - Directories specified in the 'MOLD_TEMPLATES' environment variable.
     - Potentially installed modules (not yet implemented).
   The function returns an array of objects with properties like 'Name', 'ManifestFile', and 'TemplatePath'.
#>
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
   #TODO Not yet implemented - PSData Extensions

   $Out = $AllTemplates | ConvertTo-Json | ConvertFrom-Json
   return $Out
}