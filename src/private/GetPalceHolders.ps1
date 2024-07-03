function Get-MoldPlaceHolders {
    param (
        [Parameter(Mandatory)]
        [string]
        $Path
    )

    $Files = Get-ChildItem -Path $Path -File -Recurse
    $PlaceHolders = @()
    $Files | ForEach-Object {
        Write-Verbose "Processing File $_"
        $FileContent = Get-Content -Raw $_
        $pattern = '<% MOLD_([^%]+) %>'
        if ([string]::IsNullOrEmpty($FileContent)) { break }
        $ParamMatch = [regex]::matches($FileContent, $pattern)
        $PlaceHolders += $ParamMatch | ForEach-Object { $_.Groups[1].Value }
    }
    return $PlaceHolders
}