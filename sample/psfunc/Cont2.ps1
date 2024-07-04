<% MOLD_SHOW_HELP_Start %>
<#
.SYNPOSIS
It works
#>
<% MOLD_SHOW_HELP_End %>
function <% MOLD_TEXT_FuncName %> {
    [CmdletBinding()]
    param (
        <% MOLD_TEXT_Param1 %>
        <% MOLD_CHOICE_Param2 %>
    )
    Write-Host '<% MOLD_TEXT_Content %>'
}