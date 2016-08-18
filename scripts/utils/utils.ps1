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

<#
    .SYNOPSIS

    Test if the given command exists.


    .DESCRIPTION

    The Test-Command function tests if the given command exists.


    .PARAMETER commandName

    The name of the command to test.


    .OUTPUTS

    Returns $true if the command exists, otherwise returns $false
#>
function Test-Command
{
    [CmdletBinding()]
    param(
        [string] $commandName
    )

    try
    {
      Get-Command -Name $commandName
      return $true
    }
    catch
    {
      $global:error.RemoveAt(0)
      return $false
    }
}