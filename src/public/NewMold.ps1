function New-Mold {
    param (
        $Path
    )

    ## Find Parameters
    $template = Get-Content -Raw '/Users/beli/localwork/Mold/sample/psfunc/content.ps1'
    $pattern = '<% MOLD_([^%]+) %>'
    $parameters = [regex]::matches($template, $pattern)
    $placeholders = $parameters | ForEach-Object { $_.Groups[1].Value }
    # $placeholders

    # Process Parameters
    $parameters = [ordered]@{}
    $placeholders | ForEach-Object {
        $parameters.$($_.Split('_')[1]) = GenerateQuestion $_
    }

    $metadata = [ordered]@{
        'name'        = 'NewPowerShellModule'
        'version'     = '0.2.0'
        'title'       = 'New PowerShell Module'
        'description' = 'Plaster template for creating the files for a PowerShell module.'
    }

    $data = [ordered]@{
        metadata   = $metadata
        parameters = $parameters
    }
    $data | ConvertTo-Json -Depth 5 | Out-File ./tmold.json
}