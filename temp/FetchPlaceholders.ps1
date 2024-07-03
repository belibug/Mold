$template = Get-Content -Raw 'C:\Localwork\Projects\Mold\sample\psfunc\content.ps1'
$pattern = '<% MOLD_([^%]+) %>'


$matches = [regex]::matches($template, $pattern)
$placeholders = $matches | ForEach-Object { $_.Groups[1].Value }
$placeholders