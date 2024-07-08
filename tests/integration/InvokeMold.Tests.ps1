BeforeAll {
    Import-Module .\dist\Mold -Force -ErrorAction Stop
}

Describe 'Invoke Mold Integration Test' {
    BeforeAll {
        $Answer = '[{"Key":"StudenName","Caption":"StudenName","Description":"Whats the student Name?","Options":"Non Empty String","Answer":"Manju Beli"},{"Key":"ApplicationStatus","Caption":"ApplicationStatus","Description":"Choose One","Options":"Accepted,Denied,KeptOnHold","Answer":"Accpeted"}]'
        $AnswerFilePath = 'TestDrive:\Answer.json'
        Set-Content -Path $AnswerFilePath -Value $Answer
        # Invoke-Mold -Name AppStatus -AnswerFile

        # $result = Get-Content $AnswerFilePath
    }
    It 'Command exists' {
        { Get-Command -Name Invoke-Mold -ErrorAction Stop } | Should -Not -Throw
    }
    It 'Invokes command without error' {
        { Invoke-Mold -Name AppStatus -AnswerFile $AnswerFilePath -DestinationPath 'Testdrive:\' } | Should -Not -Throw
    }
    It 'Generates output files' {
        'TestDrive:\Manju_Beli.txt' | Should -Exist
    }
    It 'Content matches expected output' {
        $result = Get-Content 'TestDrive:\Manju_Beli.txt'
        (-join $result) | Should -Be 'Hello Manju BeliYour Application has been AccpetedRegards,University Management'
    }
}