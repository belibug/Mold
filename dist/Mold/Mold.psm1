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
    Write-Warning 'Code Not yet implemented for Get-MoldTemplate'
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

    $allowedExtensions = $data.metadata.includeFileTypes -split ',' | ForEach-Object { ".$($_.Trim())" }
    $allowedFilenames = $data.metadata.includeLiteralFile -split ',' | ForEach-Object { $_.Trim() }
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

    # Copy all files to destination
    try { 
        Copy-Item -Path "$locaTempFolder\*" -Destination $DestinationPath -Recurse -Force -ErrorAction Stop 
    } catch {
        $Error[0]
        Write-Error 'Something went wrong while copying'
    }
    #endregion

    #region Script Runner
    $MoldScriptFile = (Join-Path -Path $TemplatePath -ChildPath 'MOLD_SCRIPT.ps1' | Resolve-Path).Path
    Invoke-MoldScriptFile -MoldData $DataForScriptRunning -ScriptPath $MoldScriptFile -DestinationPath $DestinationPath
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
   
    # Process Parameters
    $parameters = [ordered]@{}
    $placeholders | ForEach-Object {
        $parameters.$($_.Split('_')[1]) = GenerateQuestion $_
    }

    $metadata = [ordered]@{
        'name'               = 'NewPowerShellModule'
        'version'            = '0.2.0'
        'title'              = 'New PowerShell Module'
        'description'        = 'Plaster template for creating the files for a PowerShell module.'
        'guid'               = New-Guid | ForEach-Object Guid
        'includeFileTypes'   = 'ps1, txt, md, json, xml, psm1, psd1'
        'includeLiteralFile' = 'config'
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
        $PhType, $PhName = $_.split('_')
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
        $dataPlaceHolder = '{0}_{1}' -f $data.parameters.$_.Type, $_
        if ($AllPaceholders -notcontains $dataPlaceHolder) {
            Write-Host "No longer valid placeholder: $_"
            $keysToRemove += $_
            $ChangesMade++
        }
    }
    $keysToRemove.foreach({ $data.parameters.remove($_) })
    if ($ChangesMade -gt 0) {
        Write-Host "Updated $ChangesMade parameters in MoldManifest"
        $data | ConvertTo-Json -Depth 5 | Out-File -FilePath $MoldManifest -Encoding utf8
    } else {
        Write-Host 'No changes found in templatePath, MoldManifest unchanged' 
    }
}
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
        $PlaceHolders += $ParamMatch | ForEach-Object { $_.Groups[1].Value }
    }
    return $PlaceHolders
}
function Invoke-MoldScriptFile {
    param(
        [hashtable]$MoldData,
        [string]$ScriptPath,
        [string]$DestinationPath
    )
    if (-not (Test-Path $MoldScriptFile)) {
        Write-Verbose 'No MOLD_SCRIPT found in template directory, Ignoring script run'
        return
    }
    Push-Location -StackName 'MoldScriptExecution'
    if (-not (Test-Path $DestinationPath)) { 
        Write-Error 'Destination path not accessible, unable to run MOLD_SCRIPT' -ErrorAction Stop
    }
    Set-Location $DestinationPath
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

