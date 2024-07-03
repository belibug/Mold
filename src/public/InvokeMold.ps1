function Invoke-Mold {
    param (
        $Path = 'C:\Localwork\Projects\Mold\sample\psfunc\mold.json'
    )
    $data = Get-Content -Raw $Path | ConvertFrom-Json -AsHashtable
    $result = New-Object System.Collections.ArrayList

    $data.parameters.Keys | ForEach-Object {
        $q = [MoldQ]::new($data.parameters.$_)
        $q.Answer = Read-AwesomeHost $q
        $q.Key = $_
        $result.Add($q) | Out-Null
    }
    return $result.ToArray()
}
Invoke-Mold