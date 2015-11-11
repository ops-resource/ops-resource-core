<#
    .SYNOPSIS

    Verifies that a given windows machine can indeed is configured correctly.


    .DESCRIPTION

    The Test-LocalNetworkResource script verifies that a given windows machine is configured correctly.


    .PARAMETER credential

    The credential that should be used to connect to the remote machine.


    .PARAMETER authenticateWithCredSSP

    A flag that indicates whether remote powershell sessions should be authenticated with the CredSSP mechanism.


    .PARAMETER computerName

    The name of the machine for which the configuration should be verified.


    .PARAMETER testDirectory

    The directory in which all the test files can be found.


    .PARAMETER logDirectory

    The directory in which all the logs should be stored.


    .EXAMPLE

    Test-LocalNetworkResource -computerName "AKTFSJS01" -testDirectory "c:\tests" -logDirectory "c:\logs"
#>
[CmdletBinding(SupportsShouldProcess = $True)]
param(
    [Parameter(Mandatory = $true)]
    [PSCredential] $credential       = $(throw 'Please provide the credential object that should be used to connect to the remote machine.'),

    [Parameter(Mandatory = $false)]
    [switch] $authenticateWithCredSSP,

    [Parameter(Mandatory = $true)]
    [string] $computerName           = $(throw "Please specify the name of the machine that should be configured as a Jenkins slave."),

    [string] $testDirectory          = $(Join-Path $PSScriptRoot "verification"),

    [string] $logDirectory           = $(Join-Path $PSScriptRoot "logs")
)

Write-Verbose "Test-LocalNetworkResource - credential: $credential"
Write-Verbose "Test-LocalNetworkResource - authenticateWithCredSSP: $authenticateWithCredSSP"
Write-Verbose "Test-LocalNetworkResource - computerName: $computerName"
Write-Verbose "Test-LocalNetworkResource - testDirectory: $testDirectory"
Write-Verbose "Test-LocalNetworkResource - logDirectory: $logDirectory"

# Stop everything if there are errors
$ErrorActionPreference = 'Stop'

$commonParameterSwitches =
    @{
        Verbose = $PSBoundParameters.ContainsKey('Verbose');
        Debug = $PSBoundParameters.ContainsKey('Debug');
        ErrorAction = "Stop"
    }

if (-not (Test-Path $testDirectory))
{
    throw "Unable to find the directory containing the test files. Expected it at: $testDirectory"
}

if (-not (Test-Path $logDirectory))
{
    New-Item -Path $logDirectory -ItemType Directory | Out-Null
}

if ($authenticateWithCredSSP)
{
    $session = New-PSSession -ComputerName $computerName -Authentication Credssp -Credential $credential
}
else
{
    $session = New-PSSession -ComputerName $computerName -Credential $credential
}

if ($session -eq $null)
{
    throw "Failed to connect to $computerName"
}

Write-Verbose "Connected to $computerName via $($session.Name)"

$testWindowsResource = Join-Path $PSScriptRoot 'Test-WindowsResource.ps1'
& $testWindowsResource -session $session -testDirectory $testDirectory -logDirectory $logDirectory