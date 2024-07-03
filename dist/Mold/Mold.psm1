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
    Write-Verbose 'This will invoke mold from existing templates'
}
function New-Mold {
    param (
        $Path
    )
    $q1 = [MOLDQ]::new()
    $q1
    Write-Verbose 'This will create a new mold templates'
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
class MOLDQ {
    [string]$Type
    [string]$Caption
    [string]$Message
    [string]$Prompt
    [string]$Default
    [string[]]$Choice
    [string]$Answer

    # MOLDQ ([string]$caption, [string]$message, [string]$prompt, [string]$default, [string]$type, [string[]]$choice) {
    #     $this.Caption = $caption
    #     $this.Message = $message
    #     $this.Prompt = $prompt
    #     $this.Default = $default
    #     $this.Type = $type
    #     $this.Choice = $choice
    # }
}


