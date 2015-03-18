<#
    .SYNOPSIS

    Connects to the remote machine, pushes all the necessary files up to it, executes the Chef cookbook that installs
    all the required applications and then verifies that all the applications have been installed correctly.


    .DESCRIPTION

    The New-WindowsResource script takes all the actions necessary configure the remote machine.


    .PARAMETER computerName

    The name of the machine that should be set up.


    .EXAMPLE

    New-WindowsResource -computerName "AKTFSJS01"
#>
[CmdletBinding()]
param(
    [string] $computerName = $(throw 'Please specify the name of the machine that should be configured.')
)

# Stop everything if there are errors
$ErrorActionPreference = 'Stop'

$commonParameterSwitches =
    @{
        Verbose = $PSBoundParameters.ContainsKey('Verbose');
        Debug = $PSBoundParameters.ContainsKey('Debug');
        ErrorAction = "Stop"
    }

$cookbookNames = '${CookbookNames}'.Split(';')

$installationDirectory = $(Join-Path $PSScriptRoot 'configuration')
$testDirectory = $(Join-Path $PSScriptRoot 'verification')
$logDirectory = $(Join-Path $PSScriptRoot 'logs')

$installationScript = Join-Path $PSScriptRoot 'New-WindowsResource.ps1'
$verificationScript = Join-Path $PSScriptRoot 'Verify-WindowsResource.ps1'

& $installationScript -computerName $computerName -cookbookNames $cookbookNames -installationDirectory $installationDirectory -logDirectory $logDirectory @commonParameterSwitches

& $verificationScript -computerName $computerName -testDirectory $testDirectory -logDirectory $logDirectory @commonParameterSwitches

