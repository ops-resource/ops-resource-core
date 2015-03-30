<#
    .SYNOPSIS

    Verifies that a given windows machine is configured correctly.


    .DESCRIPTION

    The Test-WindowsResource script verifies that a given windows machine is configured correctly.


    .PARAMETER session

    The Powershell remoting session that can be used to connect to the machine for which the configuration should be verified.


    .PARAMETER testDirectory

    The directory in which all the test files can be found.


    .PARAMETER logDirectory

    The directory in which all the logs should be stored.


    .PARAMETER remoteVerificationDirectory

    The full path to the directory on the remote machine where the verification files should be placed. Defaults to 'c:\verification'.


    .PARAMETER remoteLogDirectory

    The full path to the directory on the remote machine where the log files should be placed. Defaults to 'c:\logs'.


    .EXAMPLE

    Test-WindowsResource -session $session -testDirectory "c:\tests" -logDirectory "c:\logs"
#>
[CmdletBinding(SupportsShouldProcess = $True)]
param(
    [System.Management.Automation.Runspaces.PSSession] $session = $(throw 'Please provide a Powershell remoting session that can be used to connect to the machine for which the configuration needs to be verified.'),
    [string] $testDirectory                                     = $(Join-Path $PSScriptRoot "verification"),
    [string] $logDirectory                                      = $(Join-Path $PSScriptRoot "logs"),
    [string] $remoteVerificationDirectory                       = 'c:\verification',
    [string] $remoteLogDirectory                                = 'c:\logs'
)

Write-Verbose "Test-WindowsResource - session: $($session.Name)"
Write-Verbose "Test-WindowsResource - testDirectory: $testDirectory"
Write-Verbose "Test-WindowsResource - logDirectory: $logDirectory"
Write-Verbose "Test-WindowsResource - remoteVerificationDirectory: $remoteVerificationDirectory"
Write-Verbose "Test-WindowsResource - remoteLogDirectory: $remoteLogDirectory"

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

if (-not (Test-Path $testDirectory))
{
    throw "Unable to find the directory containing the test files. Expected it at: $testDirectory"
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
Copy-FilesToRemoteMachine -session $session -localDirectory $testDirectory -remoteDirectory $remoteVerificationDirectory

# Verify that everything is there
Invoke-Command `
    -Session $session `
    -ArgumentList @( (Join-Path $remoteVerificationDirectory 'Verify-ConfigurationOnWindowsMachine.ps1'), (Join-Path $remoteVerificationDirectory "spec"), $remoteLogDirectory ) `
    -ScriptBlock {
        param(
            [string] $verificationScript,
            [string] $testDirectory,
            [string] $logDirectory
        )

        Write-Output "Test-WindowsResource - verifying remote - verificationScript: $verificationScript"
        Write-Output "Test-WindowsResource - verifying remote - testDirectory: $testDirectory"
        Write-Output "Test-WindowsResource - verifying remote - logDirectory: $logDirectory"

        & $verificationScript -testDirectory $testDirectory -logDirectory $logDirectory
    } `
    @commonParameterSwitches

Write-Verbose "Copying log files from remote resource ..."
Copy-FilesFromRemoteMachine -session $session -remoteDirectory $remoteLogDirectory -localDirectory $logDirectory

$serverSpecLog = Join-Path $logDirectory 'serverspec.xml'
if (-not (Test-Path $serverSpecLog))
{
    throw "Test failed. No serverspec log produced."
}

$serverSpecXml = [xml](Get-Content $serverSpecLog)
$tests = $serverSpecXml.testsuite.tests
$failures = $serverSpecXml.testsuite.failures
$errors = $serverSpecXml.testsuite.errors

if (($tests -gt 0) -and ($failures -eq 0) -and ($errors -eq 0))
{
    Write-Output "Test PASSED"
}
else
{
    throw "Test FAILED"
}