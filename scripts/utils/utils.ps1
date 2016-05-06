<#
    .SYNOPSIS

    Creates a new 15 character string that can be used as a computer name.


    .DESCRIPTION

    The New-RandomMachineName function creates a new 15 character string that can be used as a computer name.


    .OUTPUTS

    A random 15 character string that can be used as a computer name.
#>
function New-RandomMachineName
{
    [CmdletBinding()]
    param()

    $name = -join (0..14 | Foreach-Object {[char][int]((65..90) + (48..57) | Get-Random)})
    return $name
}