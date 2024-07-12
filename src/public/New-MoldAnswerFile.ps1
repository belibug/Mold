<#
.SYNOPSIS
    Creates an answer file for a Mold template.

.DESCRIPTION
    This function generates a JSON file (`Mold_Answer_File.json`) in the specified directory to be used as an answer file for a Mold template. Answer File can be fed to "Invoke-Mold" to provide answer as JSON content and skip interactive questions. Useful during automations or non-console execution of Mold templates.

.PARAMETER TemplatePath
    The path to the Mold template directory. This parameter is mandatory when using the 'TemplatePath' parameter set.

.PARAMETER Name
    The name of the Mold template. This parameter is mandatory when using the 'Name' parameter set.

.PARAMETER OutputDirectory
    The path to the directory where the answer file will be created. Defaults to the current working directory.

.PARAMETER Force
    If specified, the function will overwrite an existing answer file without prompting.

.EXAMPLE
    New-MoldAnswerFile -TemplatePath 'C:\Templates\MyProject' -OutputDirectory 'C:\Answers'

    Creates the answer file 'Mold_Answer_File.json' in the 'C:\Answers' directory based on the template in 'C:\Templates\MyProject'.

.EXAMPLE
    New-MoldAnswerFile -Name 'MyTemplate'

    Creates the answer file 'Mold_Answer_File.json' in the current working directory based on the template named 'MyTemplate'.

.NOTES
    The function retrieves the template either by path or by name.
    It reads the template's manifest file ('MoldManifest.json') to determine the questions and their types.
    It generates an answer file with placeholders for user responses, including question details like caption, description, and available options. Fill the answer file manually before feeding it to Invoke-Mold command.
    The generated answer file can be used to automate the input process when invoking the Mold template.
#>
function New-MoldAnswerFile {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(ParameterSetName = 'TemplatePath', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TemplatePath,
        [Parameter(ParameterSetName = 'Name', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        [string]$OutputDirectory = (Get-Location).Path,
        [switch]$Force
    )
    if ($PSBoundParameters.ContainsKey('Name')) {
        $TemplateDetails = Get-MoldTemplate -Name $Name
        if ($TemplateDetails.ManifestFile) {
            $TemplatePath = Split-Path -Path $TemplateDetails.ManifestFile -Parent
        } else {
            Write-Error "No Mold Template found by name $Name" -ErrorAction Stop
        }
    }

    # Validate MoldTemplate
    Test-MoldHealth -Path $TemplatePath
    $MoldManifest = Join-Path -Path $TemplatePath -ChildPath 'MoldManifest.json'

    $data = Get-Content -Path $MoldManifest -Raw | ConvertFrom-Json
    $Answer = New-Object System.Collections.ArrayList

    function GetMyOptionsForQuestion {
        param(
            $data
        )
        if ($data.Type -eq 'TEXT') {
            if ($data.Default -eq 'MANDATORY') {
                $Output = 'Non Empty String'
            } else {
                $Output = 'Any string value'
            }
        }
        if ($data.Type -eq 'CHOICE' -or $data.Type -eq 'BLOCK') {
            $Output = $data.CHOICE.PSObject.Properties.Name -join ','
        }
        return $Output
    }

    $data.parameters.PSObject.Properties.Name | ForEach-Object {

        $AnsObj = [ordered]@{
            Key         = $_
            Caption     = $data.parameters.$_.Caption
            Description = $data.parameters.$_.Message
            Options     = GetMyOptionsForQuestion $data.parameters.$_
            Answer      = 'YOUR_ANSWER'
        }
        $Answer.Add($AnsObj) | Out-Null
    }

    if (Test-Path -Path $OutputDirectory -PathType Container ) {
        $AnswerFile = Join-Path -Path $OutputDirectory -ChildPath 'Mold_Answer_File.json'
        $Answer | ConvertTo-Json | Out-File -FilePath $AnswerFile -Force:$Force
    } else {
        Write-Error "Given $OutputDirectory is not present or accessible" -ErrorAction Stop
    }
}