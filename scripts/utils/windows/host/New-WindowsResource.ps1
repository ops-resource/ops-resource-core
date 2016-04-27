<#
    .SYNOPSIS

    Connects to the remote machine, pushes all the necessary files up to it and then executes the Chef cookbook that installs
    all the required applications.


    .DESCRIPTION

    The New-WindowsResource script takes all the actions necessary to configure the machine.


    .PARAMETER session

    The powershell remote session that can be used to connect to the machine that should be configured.


    .PARAMETER resourceName

    The name of the resource that is being created.


    .PARAMETER resourceVersion

    The version of the resource that is being created.


    .PARAMETER cookbookNames

    An array containing the names of the cookbooks that should be executed to install all the required applications on the machine.


    .PARAMETER installationDirectory

    The directory in which all the installer packages and cookbooks can be found. It is expected that the cookbooks are stored
    in a 'cookbooks' sub-directory of the installationDirectory.


    .PARAMETER logDirectory

    The directory in which all the logs should be stored.


    .PARAMETER remoteConfigurationDirectory

    The full path to the directory on the remote machine where the configuration files should be placed. Defaults to 'c:\temp\configuration'.


    .PARAMETER remoteLogDirectory

    The full path to the directory on the remote machine where the log files should be placed. Defaults to 'c:\temp\logs'.


    .EXAMPLE

    New-WindowsResource -session $session -installationDirectory "c:\installers" -logDirectory "c:\logs"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [System.Management.Automation.Runspaces.PSSession] $session = $(throw 'Please provide a Powershell remoting session that can be used to connect to the machine that needs to be initialized.'),

    [Parameter(Mandatory = $false)]
    [string] $resourceName                                      = '',

    [Parameter(Mandatory = $false)]
    [string] $resourceVersion                                   = '',

    [Parameter(Mandatory = $false)]
    [string[]] $cookbookNames                                   = $(throw 'Please specify the names of the cookbooks that should be executed.'),

    [Parameter(Mandatory = $false)]
    [string] $installationDirectory                             = $(Join-Path $PSScriptRoot 'configuration'),

    [Parameter(Mandatory = $false)]
    [string] $logDirectory                                      = $(Join-Path $PSScriptRoot 'logs'),

    [Parameter(Mandatory = $false)]
    [string] $remoteConfigurationDirectory                      = 'c:\temp\configuration',

    [Parameter(Mandatory = $false)]
    [string] $remoteLogDirectory                                = 'c:\temp\logs'
)

Write-Verbose "New-WindowsResource - session: $($session.Name)"
Write-Verbose "New-WindowsResource - resourceName: $resourceName"
Write-Verbose "New-WindowsResource - resourceVersion: $resourceVersion"
Write-Verbose "New-WindowsResource - cookbookNames: $cookbookNames"
Write-Verbose "New-WindowsResource - installationDirectory: $installationDirectory"
Write-Verbose "New-WindowsResource - logDirectory: $logDirectory"
Write-Verbose "New-WindowsResource - remoteConfigurationDirectory: $remoteConfigurationDirectory"
Write-Verbose "New-WindowsResource - remoteLogDirectory: $remoteLogDirectory"

# Stop everything if there are errors
$ErrorActionPreference = 'Stop'

$commonParameterSwitches =
    @{
        Verbose = $PSBoundParameters.ContainsKey('Verbose');
        Debug = $false;
        ErrorAction = 'Stop'
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

if ($session -eq $null)
{
    throw 'Failed to connect to the remote machine'
}

Write-Verbose "Connecting to $($session.Name)"
try
{
    # Make sure that the remote log directory exists because if something goes wrong with the script we try to copy from that directory
    # however the copy action on 'c:\logs' if it doesn't exist somehow then tries to copy to all the folders with the term 'logs' in it from
    # the windows directory.
    Invoke-Command `
        -Session $session `
        -ArgumentList @( $remoteLogDirectory ) `
        -ScriptBlock {
            param(
                [string] $logDirectory
            )

            if (-not (Test-Path $logDirectory))
            {
                New-Item -Path $logDirectory -ItemType Directory
            }
        } `
        @commonParameterSwitches

    # Create the installer directory on the virtual machine
    Write-Output "Copying configuration files to remote resource ..."
    Copy-FilesToRemoteMachine -session $session -localDirectory $installationDirectory -remoteDirectory $remoteConfigurationDirectory

    # Execute the remote installation scripts
    $installationScript = Join-Path $installationDirectory 'Install-ApplicationsOnWindowsWithChef.ps1'

    Write-Output "Configuring remote resource ..."
    Invoke-Command `
        -Session $session `
        -ArgumentList @( $resourceName, $resourceVersion, (Join-Path $remoteConfigurationDirectory (Split-Path -Leaf $installationScript)), $remoteConfigurationDirectory, $remoteLogDirectory, $cookbookNames ) `
        -ScriptBlock {
            param(
                [string] $resourceName,
                [string] $resourceVersion,
                [string] $installationScript,
                [string] $configurationDirectory,
                [string] $logDirectory,
                [string[]] $cookbookNames
            )

            Write-Output "New-WindowsResource - Configuring remote - resourceName: $resourceName"
            Write-Output "New-WindowsResource - Configuring remote - resourceVersion: $resourceVersion"
            Write-Output "New-WindowsResource - Configuring remote - installationScript: $installationScript"
            Write-Output "New-WindowsResource - Configuring remote - configurationDirectory: $configurationDirectory"
            Write-Output "New-WindowsResource - Configuring remote - logDirectory: $logDirectory"
            Write-Output "New-WindowsResource - Configuring remote - cookbookNames: $cookbookNames"

            & $installationScript -resourceName $resourceName -resourceVersion $resourceVersion -configurationDirectory $configurationDirectory -logDirectory $logDirectory -cookbookNames $cookbookNames
        } `
        @commonParameterSwitches
}
finally
{
    try
    {
        Write-Verbose "Copying log files from remote resource ..."
        Copy-FilesFromRemoteMachine -session $session -remoteDirectory $remoteLogDirectory -localDirectory $logDirectory

        Write-Verbose "Copied log files from remote resource"
    }
    catch
    {
        Write-Error "Failed to copy log files from remote machine. Error was $($_.Exception.ToString())"
    }

    Remove-FilesFromRemoteMachine -session $session -remoteDirectory $remoteConfigurationDirectory
    Remove-FilesFromRemoteMachine -session $session -remoteDirectory $remoteLogDirectory
}