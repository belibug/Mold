<% MOLD_BLOCK_HELP_Start %><#
.SYNPOSIS
It works
#><% MOLD_BLOCK_HELP_End %>
function <% MOLD_TEXT_FuncName %> {
    [CmdletBinding()]
    param (
        <% sMOLD_TEXT_Param1 %>
        <% sMOLD_CHOICE_Param2 %>
    )
    Write-Host '<% sMOLD_TEXT_Content %>'
}