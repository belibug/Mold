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