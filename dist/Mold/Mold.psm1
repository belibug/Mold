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
function Invoke-Mold {
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName = 'TemplatePath', Mandatory = $true)]
        [ValidateNotNullOrEmpty()] 
        [string]$TemplatePath,
        #TODO pending implementation. Get Manifest by name
        [Parameter(ParameterSetName = 'Name', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        [string]$DestinationPath = (Get-Location).Path,
        #TODO Provide input as answerfile
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

    #region Get Answers interactively
    $data.parameters.Keys | ForEach-Object {
        $q = [MoldQ]::new($data.parameters.$_)
        $q.answer = Read-awesomeHost $q
        $q.Key = $_
        $result.add($q) | Out-Null
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
function New-MoldManifest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $Path
    )
    $MoldManifest = Join-Path -Path $Path -ChildPath 'MoldManifest.json'
    # Validation before starting the workflow
    Test-MoldStatus -Path $Path -NewManifest

    ## Find Parameters
    $PlaceHolders = Get-MoldPlaceHolders -Path $Path
   
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
    Write-Warning 'Code Not implemented for Test-MoldTemplate'
}
function Update-MoldManifest {
    [CmdletBinding()]
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
    
    $AllPaceholders = Get-MoldPlaceHolders -Path $TemplatePath
    
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
class MoldQ {
    #TODO Make certain things as mandatory
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
function Get-MoldPlaceHolders {
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
    if (-not (Test-Path $MoldScriptFile)) {
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
    } -ArgumentList $MoldData , $MoldScriptFile
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

