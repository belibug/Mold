function GenerateQuestion {
    param(
        [string]$MoldVariable
    )
    Write-Verbose "Working on MoldVariable $MoldVariable"
    if ($MoldVariable -match '^BLOCK_.+$') {
        $question = [ordered]@{
            'Caption' = $MoldVariable.Split('_')[1]
            'Message' = 'Do you want to include?'
            'Prompt'  = 'Response'
            'Type'    = 'BLOCK'
            'Default' = 'No'
            'Choice'  = [ordered]@{
                'Yes' = 'Block text between Start and END will be included'
                'No'  = 'Block text will be removed'
            }
        }
    }
    if ($MoldVariable -match '^TEXT_.+$') {
        $question = [ordered]@{
            'Caption' = $MoldVariable.Split('_')[1]
            'Message' = 'Ask your question'
            'Prompt'  = 'Response'
            'Type'    = 'TEXT'
            'Default' = ''
        }
    }
    if ($MoldVariable -match '^CHOICE_.+$') {
        $question = [ordered]@{
            'Caption' = $MoldVariable.Split('_')[1]
            'Message' = 'Choose One'
            'Prompt'  = 'Response'
            'Type'    = 'CHOICE'
            'Default' = 'Default'
            'Choice'  = [ordered]@{
                'One'     = 'Selecting one'
                'Two'     = 'Selecting Two'
                'Three'   = 'Selecting Three'
                'Default' = 'Selecting Default'
            }
        }
    }
    return $question
}