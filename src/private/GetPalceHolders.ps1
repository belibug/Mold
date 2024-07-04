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