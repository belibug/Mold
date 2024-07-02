BeforeAll {
    $data = Get-MTProjectInfo
}

Describe 'General Module Control' {
    It 'Should import without errors' {
        ## PENDING
        { Import-Module -Name $data.OutputModuleDir -ErrorAction Stop } | Should -Not -Throw 
        Get-Module -Name $data.ProjectName | Should -Not -BeNullOrEmpty
    }
}