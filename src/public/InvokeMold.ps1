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
    # return $result.Toarray()

    # Create Content
    $locaTempFolder = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), $data.metadata.name)
    ## Cleanup if folder exists
    if (Test-Path $locaTempFolder) { Remove-Item $locaTempFolder -Recurse -Force }
    New-Item -ItemType Directory -Path $locaTempFolder | Out-Null
    Copy-Item -Path "$TemplatePath\*" -Destination "$locaTempFolder" -Recurse -Exclude 'MoldManifest.json'

    # Invoke-Item $locaTempFolder

    $allFilesInLocalTemp = Get-ChildItem -File -Recurse -Path $locaTempFolder
    #TODO use dot net to speed up this process
    $allFilesInLocalTemp | ForEach-Object {
        $FContent = Get-Content $_ -Raw
        $result | ForEach-Object {
            $MOLDParam = '<% MOLD_{0}_{1} %>' -f $_.Type, $_.Key
            $MOLDParam
            $FContent = $FContent -replace $MOLDParam, $_.answer
        }
        Out-File -FilePath $_ -InputObject $FContent
    }


    # Copy changed files back to destination
    Copy-Item -Path "$locaTempFolder\*" -Destination $DestinationPath -Recurse -Force
}