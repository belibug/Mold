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