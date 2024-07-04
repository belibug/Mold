function Get-Mold {
    param (
        $Path
    )
    Write-Verbose 'This will retrive all Molds'
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
        [string]$answerFile
    )
    
    # Validate MoldTemplate
    Test-MoldHealth -Path $TemplatePath
    $MoldManifest = Join-Path -Path $TemplatePath -ChildPath 'MoldManifest.json'

    $data = Get-Content -Raw $MoldManifest | ConvertFrom-Json -AsHashtable
    $result = New-Object System.Collections.arrayList

    $data.parameters.Keys | ForEach-Object {
        $q = [MoldQ]::new($data.parameters.$_)
        $q.answer = Read-awesomeHost $q
        $q.Key = $_
        $result.add($q) | Out-Null
    }
    $result
    # return $result.Toarray()

    # Create Content
    $locaTempFolder = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), $data.metadata.name)
    ## Cleanup if folder exists
    if (Test-Path $locaTempFolder) { Remove-Item $locaTempFolder -Recurse -Force }
    New-Item -ItemType Directory -Path $locaTempFolder | Out-Null
    Copy-Item -Path "$TemplatePath\*" -Destination "$locaTempFolder" -Recurse -Exclude 'MoldManifest.json'

    # Invoke-Item $locaTempFolder
    $allowedExtensions = $data.metadata.includeFileTypes -split ',' | ForEach-Object { ".$($_.Trim())" }
    $allowedFilenames = $data.metadata.includeLiteralFile -split ',' | ForEach-Object { $_.Trim() }
    $allFilesInLocalTemp = Get-ChildItem -File -Recurse -Path $locaTempFolder | Where-Object {
        $_.Extension -in $allowedExtensions -or $_.BaseName -in $allowedFilenames
    }
    #-or $_.BaseName -in $allowedFilenames
    $allFilesInLocalTemp
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
            $MOLDParam
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


    # Copy changed files back to destination
    Copy-Item -Path "$locaTempFolder\*" -Destination $DestinationPath -Recurse -Force
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
        'includeFileTypes'   = 'ps1, txt, md, json'
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
function Test-Mold {
    param (
        $Path
    )
    Write-Verbose 'This will test mold and existing templates'
}
function Update-Mold {
    param (
        $Path
    )
    Write-Verbose 'This will update existing mold templates'
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

    $Files = Get-ChildItem -Path $Path -File -Recurse
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

