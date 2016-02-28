<#
    .SYNOPSIS

    Gets the registered owner for the current machine.


    .DESCRIPTION

    The Get-RegisteredOwner function gets the registered owner for the current machine.


    .OUTPUTS

    The name of the registered owner for the current machine.
#>
function Get-RegisteredOwner
{
    [CmdletBinding()]
    param()

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

    $result = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name RegisteredOwner @commonParameterSwitches
    return $result.RegisteredOwner
}