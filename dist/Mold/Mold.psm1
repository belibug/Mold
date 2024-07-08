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
<#
.SYNOPSIS
   Creates a new project or file from a Mold template.

.DESCRIPTION
   This function creates a new project or file based on a Mold template. It can either use a template from a specified path or retrieve a template by name. The function then interactively gathers input from the user, substitutes placeholders in the template files, and optionally executes a script to further customize the generated output.

.PARAMETER TemplatePath
   The path to the Mold template directory.

.PARAMETER Name
   The name of the Mold template to use.

.PARAMETER DestinationPath
   The path where the generated project or file will be created. Defaults to the current working directory.

.PARAMETER AnswerFile
   The path to an answer file containing pre-filled responses to template questions. Use New-MoldAnswerFile to generate the answer file skeleton for a given template.

.EXAMPLE
   Invoke-Mold -TemplatePath 'C:\Templates\MyProject'

   .EXAMPLE
   Invoke-Mold -TemplatePath 'C:\Templates\MyProject' -AnswerFile GoldProject.json

   Creates a new project based on the template located at 'C:\Templates\MyProject'. The user will be prompted for input to customize the project.

.EXAMPLE
   Invoke-Mold -Name 'WebTemplate'

   Creates a new project based on the Mold template named 'WebTemplate'. The template will be retrieved from a central location.

.NOTES
   This function requires the 'MoldManifest.json' file to be present in the template directory.
   The function supports placeholder substitution in template files using the format '<% MOLD_{Type}_{Key} %>'.
   The function can optionally execute a 'MOLD_SCRIPT.ps1' file to further customize the generated output.
#>
function Invoke-Mold {
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName = 'TemplatePath', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TemplatePath,
        [Parameter(ParameterSetName = 'Name', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        [string]$DestinationPath = (Get-Location).Path,
        [string]$AnswerFile
    )

    if ($PSBoundParameters.ContainsKey('Name')) {
        $TemplateDetails = Get-MoldTemplate -Name $Name
        if ($TemplateDetails.ManifestFile) {
            $TemplatePath = Split-Path -Path $TemplateDetails.ManifestFile -Parent
        } else {
            Write-Error "No Mold Template found by name $Name" -ErrorAction Stop
        }
    }

    # Validate MoldTemplate
    Test-MoldHealth -Path $TemplatePath
    $MoldManifest = Join-Path -Path $TemplatePath -ChildPath 'MoldManifest.json'

    $data = Get-Content -Raw $MoldManifest | ConvertFrom-Json -AsHashtable
    $result = New-Object System.Collections.arrayList

    if ($PSBoundParameters.ContainsKey('AnswerFile')) {
        Test-ValidateAnswerFileParameter -AnswerFile $AnswerFile -ManifestFile $MoldManifest
        $AnswerContent = Get-Content -Raw $AnswerFile | ConvertFrom-Json
        foreach ($Key in $data.parameters.keys) {
            $q = [MoldQ]::new($data.parameters.$Key)
            $TheAnswer = $AnswerContent | Where-Object { $_.Key -eq $Key }
            $q.answer = $TheAnswer.Answer
            $q.Key = $Key
            $result.add($q) | Out-Null
        }
    } else {
        #region Get Answers interactively
        $data.parameters.Keys | ForEach-Object {
            $q = [MoldQ]::new($data.parameters.$_)
            $q.answer = Read-awesomeHost $q
            $q.Key = $_
            $result.add($q) | Out-Null
        }
    }

    $DataForScriptRunning = @{}
    $result | ForEach-Object {
        $DataForScriptRunning.Add($_.Key, $_.Answer)
    }
    #endregion

    #region Placeholder Subtitution
    $locaTempFolder = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), $data.metadata.name)
    # Cleanup if folder exists
    if (Test-Path $locaTempFolder) { Remove-Item $locaTempFolder -Recurse -Force }
    New-Item -ItemType Directory -Path $locaTempFolder | Out-Null
    Copy-Item -Path "$TemplatePath\*" -Destination "$locaTempFolder" -Recurse -Exclude ('MoldManifest.json', 'MOLD_SCRIPT.ps1')

    $allowedExtensions = $data.metadata.FileTypes -split ',' | ForEach-Object { ".$($_.Trim())" }
    $allowedFilenames = $data.metadata.LiteralFile -split ',' | ForEach-Object { $_.Trim() }
    $allFilesInLocalTemp = Get-ChildItem -File -Recurse -Path $locaTempFolder | Where-Object {
        $_.Extension -in $allowedExtensions -or $_.BaseName -in $allowedFilenames
    }

    #TODO use dot net to speed up this process
    $allFilesInLocalTemp | ForEach-Object {
        try {
            # process only text that is in UTF8 encoding
            $EachFileContent = Get-Content $_ -Raw -Encoding 'UTF8' -ErrorAction Stop
        } catch {
            break
        }

        $result | Where-Object { $_.Type -ne 'BLOCK' } | ForEach-Object {
            $MOLDParam = '<% MOLD_{0}_{1} %>' -f $_.Type, $_.Key
            $EachFileContent = $EachFileContent -replace $MOLDParam, $_.Answer
        }

        #TODO instead of regex replace which is leaving blank line, use line delete option
        $result | Where-Object { $_.Type -eq 'BLOCK' } | ForEach-Object {
            $BlockStart = '<% MOLD_{0}_{1}_{2} %>' -f $_.Type, $_.Key, 'START'
            $BlockEnd = '<% MOLD_{0}_{1}_{2} %>' -f $_.Type, $_.Key, 'END'
            if ($_.Answer -eq 'Yes') {
                $EachFileContent = $EachFileContent -replace $BlockStart, $null
                $EachFileContent = $EachFileContent -replace $BlockEnd, $null
            } else {
                $EachFileContent = $EachFileContent -replace "(?s)$BlockStart.*?$BlockEnd", $null
            }
        }
        Out-File -FilePath $_ -InputObject $EachFileContent
    }

    if (-not (Test-Path $DestinationPath -PathType Container)) {
        New-Item -Path $DestinationPath -ItemType Directory -Force
    }

    #region Script Runner
    $MoldScriptFile = Join-Path -Path $TemplatePath -ChildPath 'MOLD_SCRIPT.ps1'
    if (Test-Path $MoldScriptFile) {
        $MoldScriptFile = (Resolve-Path $MoldScriptFile).Path
        Invoke-MoldScriptFile -MoldData $DataForScriptRunning -ScriptPath $MoldScriptFile -WorkingDirectory $locaTempFolder
    }
    #endregion

    # Copy all files to destination
    try {
        Copy-Item -Path "$locaTempFolder\*" -Destination $DestinationPath -Recurse -Force -ErrorAction Stop
    } catch {
        $Error[0]
        Write-Error 'Something went wrong while copying'
    }
    #endregion
}
<#
.SYNOPSIS
    Creates an answer file for a Mold template.

.DESCRIPTION
    This function generates a JSON file (`Mold_Answer_File.json`) in the specified directory to be used as an answer file for a Mold template. Answer File can be fed to "Invoke-Mold" to provide answer as JSON content and skip interactive questions. Useful during automations or non-console execution of Mold templates.

.PARAMETER TemplatePath
    The path to the Mold template directory. This parameter is mandatory when using the 'TemplatePath' parameter set.

.PARAMETER Name
    The name of the Mold template. This parameter is mandatory when using the 'Name' parameter set.

.PARAMETER OutputDirectory
    The path to the directory where the answer file will be created. Defaults to the current working directory.

.PARAMETER Force
    If specified, the function will overwrite an existing answer file without prompting.

.EXAMPLE
    New-MoldAnswerFile -TemplatePath 'C:\Templates\MyProject' -OutputDirectory 'C:\Answers'

    Creates the answer file 'Mold_Answer_File.json' in the 'C:\Answers' directory based on the template in 'C:\Templates\MyProject'.

.EXAMPLE
    New-MoldAnswerFile -Name 'MyTemplate'

    Creates the answer file 'Mold_Answer_File.json' in the current working directory based on the template named 'MyTemplate'.

.NOTES
    The function retrieves the template either by path or by name.
    It reads the template's manifest file ('MoldManifest.json') to determine the questions and their types.
    It generates an answer file with placeholders for user responses, including question details like caption, description, and available options. Fill the answer file manually before feeding it to Invoke-Mold command.
    The generated answer file can be used to automate the input process when invoking the Mold template.
#>
function New-MoldAnswerFile {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(ParameterSetName = 'TemplatePath', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TemplatePath,
        [Parameter(ParameterSetName = 'Name', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        [string]$OutputDirectory = (Get-Location).Path,
        [switch]$Force
    )
    if ($PSBoundParameters.ContainsKey('Name')) {
        $TemplateDetails = Get-MoldTemplate -Name $Name
        if ($TemplateDetails.ManifestFile) {
            $TemplatePath = Split-Path -Path $TemplateDetails.ManifestFile -Parent
        } else {
            Write-Error "No Mold Template found by name $Name" -ErrorAction Stop
        }
    }

    # Validate MoldTemplate
    Test-MoldHealth -Path $TemplatePath
    $MoldManifest = Join-Path -Path $TemplatePath -ChildPath 'MoldManifest.json'

    $data = Get-Content -Path $MoldManifest -Raw | ConvertFrom-Json
    $Answer = New-Object System.Collections.ArrayList

    function GetMyOptionsForQuestion {
        param(
            $data
        )
        if ($data.Type -eq 'TEXT') {
            if ($data.Default -eq 'MANDATORY') {
                $Output = 'Non Empty String'
            } else {
                $Output = 'Any string value'
            }
        }
        if ($data.Type -eq 'CHOICE') {
            $Output = $data.CHOICE.PSObject.Properties.Name -join ','
        }
        return $Output
    }

    $data.parameters.PSObject.Properties.Name | ForEach-Object {

        $AnsObj = [ordered]@{
            Key         = $_
            Caption     = $data.parameters.$_.Caption
            Description = $data.parameters.$_.Message
            Options     = GetMyOptionsForQuestion $data.parameters.$_
            Answer      = 'YOUR_ANSWER'
        }
        $Answer.Add($AnsObj) | Out-Null
    }

    if (Test-Path -Path $OutputDirectory -PathType Container ) {
        $AnswerFile = Join-Path -Path $OutputDirectory -ChildPath 'Mold_Answer_File.json'
        $Answer | ConvertTo-Json | Out-File -FilePath $AnswerFile -Force:$Force
    } else {
        Write-Error "Given $OutputDirectory is not present or accessible" -ErrorAction Stop
    }
}
<#
.SYNOPSIS
   Creates a new MoldManifest.json file for a Mold template.

.DESCRIPTION
   This function creates a new MoldManifest.json file in the specified directory, which is used to define the structure and parameters of a Mold template. Generate Mold Template for any file or project easily using this command.

.PARAMETER Path
   The path to the directory where template conten is store, the MoldManifest.json file will be created in same directory.

.EXAMPLE
   New-MoldManifest -Path 'C:\Templates\MyProject'

   Creates a new MoldManifest.json file in the 'C:\Templates\MyProject' directory. The user will be prompted for input to define the template's metadata and parameters.

.NOTES
    This generates the necessary MoldManifest.json file template. Once created ensure you edit the file to update the placeholder questions/responses.
#>

function New-MoldManifest {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]
        $Path
    )
    $MoldManifest = Join-Path -Path $Path -ChildPath 'MoldManifest.json'
    # Validation before starting the workflow
    Test-MoldStatus -Path $Path -NewManifest

    ## Find Parameters
    $PlaceHolders = Get-MoldPlaceHolder -Path $Path

    $MetaQuestions = Get-Content -Raw "$PSScriptRoot\resources\NewMoldQuestions.json" | ConvertFrom-Json -AsHashtable
    $MetaResult = @{}

    #region Get Answers interactively
    $MetaQuestions.parameters.Keys | ForEach-Object {
        $q = [MoldQ]::new($MetaQuestions.parameters.$_)
        $q.answer = Read-awesomeHost $q
        $q.Key = $_
        $MetaResult.add($q.Key, $q.answer) | Out-Null
    }

    # Process Parameters
    $parameters = [ordered]@{}
    $placeholders | ForEach-Object {
        $parameters.$($_.Split('_')[1]) = GenerateQuestion $_
    }

    $metadata = [ordered]@{
        'name'        = $MetaResult.ShortName
        'version'     = '0.0.1'
        'title'       = $MetaResult.Title
        'description' = 'MOLD Template'
        'guid'        = New-Guid | ForEach-Object Guid
        'FileTypes'   = 'ps1, txt, md, json, xml, psm1, psd1'
        'LiteralFile' = 'config'
    }

    $data = [ordered]@{
        metadata   = $metadata
        parameters = $parameters
    }
    $data | ConvertTo-Json -Depth 5 | Out-File -FilePath $MoldManifest
    if ($?) {
        'Manifest created' | Write-Host -ForegroundColor Green
    }
}
function Test-MoldTemplate {
    [CmdletBinding()]
    param (
        [string]$TemplatePath
    )
    Write-Warning "ode Not implemented for Test-MoldTemplate $TemplatePath"
}
<#
.SYNOPSIS
   Updates a MoldManifest.json file based on changes in a content of template directory.

.DESCRIPTION
   This function updates an existing MoldManifest.json file to reflect changes made to the corresponding Mold template project directory. It first validates the template directory and reads the existing manifest. Then, it compares the placeholders found in the template files with the parameters defined in the manifest. If it finds new placeholders, it adds them to the manifest. If it finds placeholders that are no longer present in the template, it removes them from the manifest. If it finds placeholders whose types have changed, it updates their types in the manifest. Finally, it writes the updated manifest back to the MoldManifest.json file.

.PARAMETER TemplatePath
   The path to the Mold template directory.

.EXAMPLE
   Update-MoldManifest -TemplatePath 'C:\Templates\MyProject'

   Updates the MoldManifest.json file in the 'C:\Templates\MyProject' directory based on any changes made to the template files.

.NOTES
   This function requires the 'MoldManifest.json' file to be present in the template directory. It only updates existing template MoldManifest.json file.
#>

function Update-MoldManifest {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]
        $TemplatePath
    )
    # Validate MoldTemplate
    Test-MoldHealth -Path $TemplatePath
    $MoldManifest = Join-Path -Path $TemplatePath -ChildPath 'MoldManifest.json'
    $ChangesMade = 0

    $data = Get-Content -Raw $MoldManifest | ConvertFrom-Json -AsHashtable

    $AllPaceholders = Get-MoldPlaceHolder -Path $TemplatePath

    # Checking PlaceHolders against MoldManifest - to add/update variables
    $AllPaceholders | ForEach-Object {
        $PhType, $PhName, $Extra = $_.split('_')
        if ($data.parameters.Keys -contains $PhName ) {
            if ($data.parameters.$PhName.Type -ne $PhType) {
                Write-Host "Type has changed for: $PhName"
                $data.parameters.remove($PhName)
                $NewQuestion = GenerateQuestion $_
                $data.parameters.add($PhName, $NewQuestion)
                $ChangesMade++
            }
        } else {
            Write-Host "Found new Placeholder: $PhName"
            $NewQuestion = GenerateQuestion $_
            $data.parameters.add($PhName, $NewQuestion)
            $ChangesMade++
        }
    }
    # Checking MoldManifest against PlaceHolders - to remove stale variables
    $keysToRemove = @()
    $data.parameters.Keys | ForEach-Object {
        if ($data.parameters.$_.Type -eq 'BLOCK') {
            $dataPlaceHolder = '{0}_{1}_{2}' -f $data.parameters.$_.Type, $_, 'START'
        } else {
            $dataPlaceHolder = '{0}_{1}' -f $data.parameters.$_.Type, $_
        }
        if ($AllPaceholders -notcontains $dataPlaceHolder) {
            Write-Host "No longer valid placeholder: $_"
            $keysToRemove += $_
            $ChangesMade++
        }
    }
    $keysToRemove.foreach({ $data.parameters.remove($_) })
    if ($ChangesMade -gt 0) {
        Write-Host "Updated $ChangesMade parameters in MoldManifest"
        $result = $data | ConvertTo-Json -Depth 5 -ErrorAction Stop
        Out-File -InputObject $result -FilePath $MoldManifest -Encoding utf8 -ErrorAction Stop
    } else {
        Write-Host 'No changes found in templatePath, MoldManifest unchanged'
    }
}
$TemplateName_ScriptBlock = {
    param (
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameters )

    $commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters | Out-Null
    $presetData = Get-MoldTemplate
    $presetData.Name | Where-Object { $_ -like "$wordToComplete*" }
}
Register-ArgumentCompleter -CommandName Get-MoldTemplate -ParameterName Name -ScriptBlock $TemplateName_ScriptBlock
Register-ArgumentCompleter -CommandName Invoke-Mold -ParameterName Name -ScriptBlock $TemplateName_ScriptBlock
Register-ArgumentCompleter -CommandName New-MoldAnswerFile -ParameterName Name -ScriptBlock $TemplateName_ScriptBlock
class MoldQ {
    #TODO Mandatory parameters in class
    [string]$Type
    [string]$Key
    [string]$Caption
    [string]$Message
    [string]$Prompt
    [string]$Default
    [hashtable]$Choice
    [string]$Answer

    MoldQ ([hashtable]$obj) {
        $this.Caption = $obj.Caption
        $this.Key = $obj.Key
        $this.Message = $obj.Message
        $this.Prompt = $obj.Prompt
        $this.Default = $obj.Default
        $this.Type = $obj.Type
        $this.Choice = $obj.Choice
    }
}

function GenerateQuestion {
    param(
        [string]$MoldVariable
    )
    Write-Verbose "Working on MoldVariable $MoldVariable"
    if ($MoldVariable -match '^BLOCK_.+$') {
        $question = [ordered]@{
            'Caption' = $MoldVariable.Split('_')[1]
            'Message' = 'Do you want to include?'
            'Prompt'  = 'Response'
            'Type'    = 'BLOCK'
            'Default' = 'No'
            'Choice'  = [ordered]@{
                'Yes' = 'Block text between Start and END will be included'
                'No'  = 'Block text will be removed'
            }
        }
    }
    if ($MoldVariable -match '^TEXT_.+$') {
        $question = [ordered]@{
            'Caption' = $MoldVariable.Split('_')[1]
            'Message' = 'Ask your question'
            'Prompt'  = 'Response'
            'Type'    = 'TEXT'
            'Default' = ''
        }
    }
    if ($MoldVariable -match '^CHOICE_.+$') {
        $question = [ordered]@{
            'Caption' = $MoldVariable.Split('_')[1]
            'Message' = 'Choose One'
            'Prompt'  = 'Response'
            'Type'    = 'CHOICE'
            'Default' = 'Default'
            'Choice'  = [ordered]@{
                'One'     = 'Selecting one'
                'Two'     = 'Selecting Two'
                'Three'   = 'Selecting Three'
                'Default' = 'Selecting Default'
            }
        }
    }
    return $question
}
function Get-MoldPlaceHolder {
    param (
        [Parameter(Mandatory)]
        [string]
        $Path
    )

    $Files = Get-ChildItem -Path $Path -File -Recurse -Exclude 'MOLD_SCRIPT.ps1'
    $PlaceHolders = @()
    $Files |
    Where-Object { $_.Length -lt 1MB } | #HACK, easy way to avoid reading large files which will slow down program
    ForEach-Object {
        Write-Verbose "Processing File $_"
        try {
            $FileContent = Get-Content -Raw $_ -ErrorAction Stop -Encoding utf8
            $pattern = '<% MOLD_([^%]+) %>'
            if (-not $FileContent) { return }
            $ParamMatch = [regex]::matches($FileContent, $pattern)
        } catch {
            Write-Verbose "Skipping, failed to read $_"
            return
        }
        $ParamMatch = $ParamMatch | ForEach-Object { $_.Groups[1].Value }

        #Check if block parameter has both START and END
        if ($ParamMatch -like 'BLOCK_*') {
            if (-not($ParamMatch -like '*_START' -and $ParamMatch -like '*_END')) {
                Write-Error 'Incomplete Block statement, Block must have start and end!' -ErrorAction Stop
            }
        }
        $PlaceHolders += $ParamMatch
    }
    return $PlaceHolders
}
function Get-TemplatesFromPath {
    [OutputType([System.Collections.ArrayList])]
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $Path,
        [switch]$Recurse
    )
    $ValidManifestFiles = New-Object System.Collections.ArrayList
    $Output = New-Object System.Collections.ArrayList

    $MMFiles = Get-ChildItem -Path $Path -Filter 'MoldManifest.json' -Recurse:$Recurse
    if (-not $MMFiles) {
        Write-Verbose "No MoldManifest files found in given $path"
        return $null
    }
    $MMFiles | ForEach-Object {
        if (Test-ValidMoldManifestFile -ManifestPath $_.FullName) {
            $ValidManifestFiles.Add($_.FullName) | Out-Null
        }
    }
    $ValidManifestFiles | ForEach-Object {
        $data = Get-Content $_ -Raw | ConvertFrom-Json
        $obj = [pscustomobject]@{
            Name         = $data.metadata.name
            Version      = $data.metadata.version
            Description  = $data.metadata.description
            GUID         = $data.metadata.guid
            ManifestFile = $_
        }
        $Output.Add($obj) | Out-Null
    }
    return $Output
}
function Invoke-MoldScriptFile {
    param(
        [hashtable]$MoldData,
        [string]$ScriptPath,
        [string]$WorkingDirectory
    )
    if (-not (Test-Path $ScriptPath)) {
        Write-Verbose 'No MOLD_SCRIPT found in template directory, Ignoring script run'
        return
    }
    Push-Location -StackName 'MoldScriptExecution'
    if (-not (Test-Path $WorkingDirectory)) {
        Write-Error 'Destination path not accessible, unable to run MOLD_SCRIPT' -ErrorAction Stop
    }
    Set-Location $WorkingDirectory
    Invoke-Command -ScriptBlock {
        param([hashtable]$MoldData, [string]$scriptPath)
        & $scriptPath -MoldData $MoldData
    } -ArgumentList $MoldData , $ScriptPath
    Pop-Location -StackName 'MoldScriptExecution'
}
function Read-AwesomeHost {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [MoldQ]$Ask
    )
    ## For standard questions
    if ($Ask.Type -eq 'TEXT') {
        do {
            $response = $Host.UI.Prompt($Ask.Caption, $Ask.Message, $Ask.Prompt)
        } while ($Ask.Default -eq 'MANDATORY' -and [string]::IsNullOrEmpty($response.Values))

        if ([string]::IsNullOrEmpty($response.Values)) {
            $result = $Ask.Default
        } else {
            $result = $response.Values
        }
    }
    ## For Choice based
    if ($Ask.Type -eq 'CHOICE' -or $Ask.Type -eq 'BLOCK') {
        $Cs = @()
        $Ask.Choice.Keys | ForEach-Object {
            $Cs += New-Object System.Management.Automation.Host.ChoiceDescription "&$_", $($Ask.Choice.$_)
        }
        $options = [System.Management.Automation.Host.ChoiceDescription[]]($Cs)
        $IndexOfDefault = $Cs.Label.IndexOf('&' + $Ask.Default)
        $response = $Host.UI.PromptForChoice($Ask.Caption, $Ask.Message, $options, $IndexOfDefault)
        $result = $Cs.Label[$response] -replace '&'
    }
    return $result
}
function Test-MoldHealth {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Path
    )
    $ErrorActionPreference = 'Stop'
    $MoldManifest = Join-Path -Path $Path -ChildPath 'MoldManifest.json'
    # Check if path exists
    if (-not(Test-Path -Path $Path)) {
        Write-Error 'Template Path not found or accessible'
    }
    # Check if path exists
    if (-not(Test-Path -Path $MoldManifest)) {
        Write-Error 'Not a valid Mold Template, missing MoldManifest.json file'
    }
    #TODO MoldManifest Schema check json
}
function Test-MoldStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$Path,
        [switch]$NewManifest
    )
    $ErrorActionPreference = 'Stop'
    $MoldManifest = Join-Path -Path $Path -ChildPath 'MoldManifest.json'
    # Check if directory exists
    If (-not (Test-Path $Path -ErrorAction SilentlyContinue)) {
        Write-Error 'Path provided either does not exists'
    }
    If (-not (Get-ChildItem $Path -ErrorAction SilentlyContinue)) {
        Write-Error 'Path provided is empty and has no files'
    }
    # Check if it already has MoldManifest, if so abort
    if ($NewManifest) {
        if (Test-Path $MoldManifest) {
            Write-Error 'MoldManifest file already present, use Update-Mold or start over'
        }
    }
}
function Test-ValidMoldManifestFile {
    [OutputType([bool])]
    [CmdletBinding()]
    param (
        $ManifestPath
    )
    $ManifestSchema = Get-Content "$PSScriptRoot\resources\SimpleMoldSchema.json" -Raw

    if (Test-Json -Path $ManifestPath -Schema $ManifestSchema -ErrorAction SilentlyContinue) {
        Write-Verbose "passed json test : $ManifestPath"
        return $true
    } else {
        Write-Verbose "Failed json test : $ManifestPath"
        return $false
    }
}
function Test-ValidateAnswerFileParameter {
    [CmdletBinding()]
    param (
        [string]$AnswerFile,
        [string]$ManifestFile
    )
    $AnswerFile, $ManifestFile | ForEach-Object {
        if (-not(Test-Path $_)) { Write-Error "$_ not found or accessible" -ErrorAction Stop }
    }
    $AnswerData = Get-Content -Raw -Path $AnswerFile | ConvertFrom-Json -ErrorAction Stop
    $ManifestData = Get-Content -Raw -Path $ManifestFile | ConvertFrom-Json -ErrorAction Stop

    $ManifestData.parameters.PSObject.Properties.Name | ForEach-Object {
        if ($AnswerData.Key -notcontains $_) { Write-Error "$_ is missing in Answer File" }
    }
}

