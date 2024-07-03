function Get-Mold {
    param (
        $Path
    )
    Write-Verbose 'This will retrive all Molds'
}
function Invoke-Mold {
    param (
        $Path 
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
function Test-Mold {
    param (
        $Path
    )
    Write-Verbose 'This will test mold and existing templates'
}
function Update-Mold {
    param (
        $Path
    )
    Write-Verbose 'This will update existing mold templates'
}
class MoldQ {
    #TODO Make certain things as mandatory
    [string]$Type
    [string]$Key
    [string]$Caption
    [string]$Message
    [string]$Prompt
    [string]$Default
    [hashtable]$Choice
    [string]$Answer

    MoldQ ([hashtable]$obj) {
        $this.Caption = $obj.Caption
        $this.Key = $obj.Key
        $this.Message = $obj.Message
        $this.Prompt = $obj.Prompt
        $this.Default = $obj.Default
        $this.Type = $obj.Type
        $this.Choice = $obj.Choice
    }
}

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
function Read-AwesomeHost {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [MoldQ]$Ask
    )
    ## For standard questions
    if ($Ask.Type -eq 'TEXT') {
        do {
            $response = $Host.UI.Prompt($Ask.Caption, $Ask.Message, $Ask.Prompt)
        } while ($Ask.Default -eq 'MANDATORY' -and [string]::IsNullOrEmpty($response.Values))

        if ([string]::IsNullOrEmpty($response.Values)) {
            $result = $Ask.Default
        } else {
            $result = $response.Values
        }
    } 
    ## For Choice based
    if ($Ask.Type -eq 'CHOICE' -or $Ask.Type -eq 'YESNO') {
        $Cs = @()
        $Ask.Choice.Keys | ForEach-Object {
            $Cs += New-Object System.Management.Automation.Host.ChoiceDescription "&$_", $($Ask.Choice.$_)
        }
        $options = [System.Management.Automation.Host.ChoiceDescription[]]($Cs)
        $IndexOfDefault = $Cs.Label.IndexOf('&' + $Ask.Default)
        $response = $Host.UI.PromptForChoice($Ask.Caption, $Ask.Message, $options, $IndexOfDefault)
        $result = $Cs.Label[$response] -replace '&'
    }
    return $result
}

