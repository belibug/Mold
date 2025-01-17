BeforeDiscovery {
    $PrivFiles = Get-ChildItem -Path .\src\private -Filter '*.ps1' -Recurse
    $PubFiles = Get-ChildItem -Path .\src\private -Filter '*.ps1' -Recurse
    $files = $PrivFiles
    $files += $PubFiles
}
BeforeAll {
    $ScriptAnalyzerSettings = @{
        IncludeDefaultRules = $true
        Severity            = @('Warning', 'Error')
        ExcludeRules        = @('PSAvoidUsingWriteHost')
    }
}
Describe 'File: <_.basename>' -ForEach $files {
    Context 'Code Quality Check' {
        It 'is valid PowerShell Code' {
            $psFile = Get-Content -Path $_ -ErrorAction Stop
            $errors = $null
            $null = [System.Management.Automation.PSParser]::Tokenize($psFile, [ref]$errors)
            $errors.Count | Should -Be 0
        }
        It 'passess ScriptAnalyzer' {
            $saResults = Invoke-ScriptAnalyzer -Path $_ -Settings $ScriptAnalyzerSettings
            $saResults | Should -BeNullOrEmpty -Because $($saResults.Message -join ';')
        }
    }
}