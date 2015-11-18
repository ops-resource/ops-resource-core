<#
    .SYNOPSIS

    Creates a powershell remote session for a connection to the given remote computer.


    .DESCRIPTION

    The New-Session function creates a powershell remote session for a connection to the given remote computer.


    .PARAMETER credential

    The credential that should be used to connect to the remote machine.


    .PARAMETER authenticateWithCredSSP

    A flag that indicates whether remote powershell sessions should be authenticated with the CredSSP mechanism.


    .PARAMETER computerName

    The name of the machine to which a connection should be made.


    .EXAMPLE

    New-Session -computerName "MyMachine"
#>

function New-Session
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $computerName           = $(throw "Please specify the name of the machine that should be configured."),

        [Parameter(Mandatory = $false)]
        [PSCredential] $credential = $null,

        [Parameter(Mandatory = $false)]
        [switch] $authenticateWithCredSSP
    )

    Write-Verbose "New-Session - computerName: $computerName"
    Write-Verbose "New-Session - credential: $credential"
    Write-Verbose "New-Session - authenticateWithCredSSP: $authenticateWithCredSSP"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = 'Stop'
        }

    if ($authenticateWithCredSSP -and ($credential -ne $null))
    {
        $session = New-PSSession -ComputerName $computerName -Authentication Credssp -Credential $credential
    }
    else
    {
        if ($credential -ne $null)
        {
            $session = New-PSSession -ComputerName $computerName -Credential $credential
        }
        else
        {
            $session = New-PSSession -ComputerName $computerName
        }
    }

    return $session
}