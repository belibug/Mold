$description = [ordered]@{
    'Caption' = 'Module Description'
    'Message' = 'What does your module do? Describe in simple words'
    'Prompt'  = 'Description'
    'Type'    = 'TEXT'
    'Default' = 'ModuleTools Module'
}
$metadata = [ordered]@{
    'name'        = 'NewPowerShellModule'
    'version'     = '0.2.0'
    'title'       = 'New PowerShell Module'
    'description' = 'Plaster template for creating the files for a PowerShell module.'
}
$data = [ordered]@{
    metadata   = $metadata
    parameters = @{
        description = $description
    }
}
$data | ConvertTo-Json | Out-File tmold.json