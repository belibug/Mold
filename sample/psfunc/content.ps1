<% MOLD_YESNO_HELP_START %>
<#
.SYNPOSIS
It works
#>
<% MOLD_YESNO_HELP_END %>
function <% MOLD_TEXT_FuncName %> {
    [CmdletBinding()]
    param (
        <% MOLD_TEXT_Param1 %>
        <% MOLD_CHOICE_Param2 %>
    )
    Write-Host '<% MOLD_TEXT_Content %>'
}