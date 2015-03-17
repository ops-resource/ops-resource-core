<#
    .SYNOPSIS

    Verifies that a given windows machine can indeed is configured correctly.


    .DESCRIPTION

    The Test-LocalNetworkResource script verifies that a given windows machine is configured correctly.


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
    [string] $computerName  = $(throw "Please specify the name of the machine that should be configured as a Jenkins slave."),
    [string] $testDirectory = $(Join-Path $PSScriptRoot "verification"),
    [string] $logDirectory  = $(Join-Path $PSScriptRoot "logs")
)

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

$session = New-PSSession -ComputerName $computerName
if ($session -eq $null)
{
    throw "Failed to connect to $computerName"
}

Write-Verbose "Connected to $computerName via $($session.Name)"

$testWindowsResource = Join-Path $PSScriptRoot 'Test-WindowsResource.ps1'
& $testWindowsResource -session $session -testDirectory $testDirectory -logDirectory $logDirectory