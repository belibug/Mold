BeforeAll {
    $data = Get-MTProjectInfo
    $files = Get-ChildItem $data.OutputModuleDir
}

Describe 'Module and Manifest testing' {
    Context 'Test <_.Name>' -ForEach $files {
        It 'is valid PowerShell Code' {
            $psFile = Get-Content -Path $_ -ErrorAction Stop
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
            $errors.Count | Should -Be 0
        }
    }
}