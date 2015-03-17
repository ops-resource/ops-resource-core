<#
    .SYNOPSIS

    Connects to the remote machine, pushes all the necessary files up to it and then executes the Chef cookbook that installs
    all the required applications.


    .DESCRIPTION

    The New-WindowsResource script takes all the actions necessary to configure the machine.


    .PARAMETER computerName

    The name of the machine that should be set up.


    .PARAMETER cookbookNames

    An array containing the names of the cookbooks that should be executed to install all the required applications on the machine.


    .PARAMETER installationDirectory

    The directory in which all the installer packages and cookbooks can be found. It is expected that the cookbooks are stored
    in a 'cookbooks' sub-directory of the installationDirectory.


    .PARAMETER logDirectory

    The directory in which all the logs should be stored.


    .EXAMPLE

    New-WindowsResource -computerName "AKTFSJS01" -installationDirectory "c:\installers" -logDirectory "c:\logs"
#>
[CmdletBinding()]
param(
    [string] $computerName          = $(throw "Please specify the name of the machine that should be configured."),
    [string[]] $cookbookNames       = $(throw "Please specify the names of the cookbooks that should be executed."),
    [string] $installationDirectory = $(Join-Path $PSScriptRoot "configuration"),
    [string] $logDirectory          = $(Join-Path $PSScriptRoot "logs")
)

# Stop everything if there are errors
$ErrorActionPreference = 'Stop'

$commonParameterSwitches =
    @{
        Verbose = $PSBoundParameters.ContainsKey('Verbose');
        Debug = $PSBoundParameters.ContainsKey('Debug');
        ErrorAction = "Stop"
    }

# Load the helper functions
$winrmHelpers = Join-Path $PSScriptRoot WinRM.ps1
. $winrmHelpers

if (-not (Test-Path $installationDirectory))
{
    throw "Unable to find the directory containing the installation files. Expected it at: $installationDirectory"
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

# Create the installer directory on the virtual machine
$remoteConfigurationDirectory = "c:\configuration"
$remoteLogDirectory = "c:\logs"
Copy-FilesToRemoteMachine -session $session -localDirectory $installationDirectory -remoteDirectory $remoteConfigurationDirectory

# Execute the remote installation scripts
$installationScript = Join-Path $installationDirectory "Install-ApplicationsOnWindowsWithChef.ps1"

try
{
    Invoke-Command `
        -Session $session `
        -ArgumentList @( (Join-Path $remoteConfigurationDirectory (Split-Path -Leaf $installationScript)), $remoteConfigurationDirectory, $remoteLogDirectory, "slave_windows" ) `
        -ScriptBlock {
            param(
                [string] $installationScript,
                [string] $configurationDirectory,
                [string] $logDirectory,
                [string] $cookbookName
            )

            & $installationScript -configurationDirectory $configurationDirectory -logDirectory $logDirectory -cookbookName $cookbookName
        } `
        @commonParameterSwitches
}
finally
{
    Write-Verbose "Copying log files from remote machine ..."
    Copy-FilesFromRemoteMachine -session $session -remoteDirectory $remoteLogDirectory -localDirectory $logDirectory

    Write-Verbose "Copied log files from remote machine"

    Remove-FilesFromRemoteMachine -session $session -remoteDirectory $remoteConfigurationDirectory
    Remove-FilesFromRemoteMachine -session $session -remoteDirectory $remoteLogDirectory
}