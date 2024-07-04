
function a {
    [CmdletBinding()]
    param (
        <% sMOLD_TEXT_Param1 %>
        <% sMOLD_CHOICE_Param2 %>
    )
    Write-Host '<% sMOLD_TEXT_Content %>'
}
