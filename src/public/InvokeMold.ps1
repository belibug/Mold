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
    # Copy all files to destination
    try { 
        Copy-Item -Path "$locaTempFolder\*" -Destination $DestinationPath -Recurse -Force -ErrorAction Stop 
    } catch {
        $Error[0]
        Write-Error 'Something went wrong while copying'
    }
    #endregion

    #region Script Runner
    $MoldScriptFile = Join-Path -Path $TemplatePath -ChildPath 'MOLD_SCRIPT.ps1'
    if (Test-Path $MoldScriptFile) {
        $MoldScriptFile = (Resolve-Path $MoldScriptFile).Path
        Invoke-MoldScriptFile -MoldData $DataForScriptRunning -ScriptPath $MoldScriptFile -DestinationPath $DestinationPath
    }
    #endregion
}