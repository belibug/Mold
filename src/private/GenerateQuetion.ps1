function GenerateQuestion {
    param(
        [string]$variable
    )
    $question = [ordered]@{
        'Caption' = 'Title caption'
        'Message' = 'Ask your question'
        'Prompt'  = 'small prompt'
        'Default' = 'SomeDefault'
    }
    if ($variable -match '^YESNO_.+$') {
        $question.Type = 'YESNO'
        $question.Choice = [ordered]@{
            'Yes' = 'Select YES'
            'No'  = 'Select No'
        }
    }
    if ($variable -match '^TEXT_.+$') {
        $question.Type = 'TEXT'
    }
    if ($variable -match '^CHOICE_.+$') {
        $question.Type = 'CHOICE'
        $question.Choice = [ordered]@{
            'Yes'      = 'Enable pester to perform testing'
            'MayBe'    = 'Skip pester testing'
            'Whatever' = 'Enable pester to perform testing'
            'No'       = 'Skip pester testing'
        }
    }
    return $question
}