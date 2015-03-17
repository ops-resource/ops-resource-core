<#
    .SYNOPSIS

    Verifies that a given windows machine can indeed be used as a Jenkins slave.


    .DESCRIPTION

    The Verify-JenkinsWindowsSlave script verifies that a given windows machine can indeed be used as a Jenkins slave.


    .PARAMETER computerName

    The name of the machine that should be set up as a Jenkins slave machine.


    .PARAMETER testDirectory

    The directory in which all the test files can be found.


    .PARAMETER logDirectory

    The directory in which all the logs should be stored.


    .EXAMPLE

    Verify-JenkinsWindowsSlave -computerName "AKTFSJS01" -testDirectory "c:\tests" -logDirectory "c:\logs"
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

$session = New-PSSession -ComputerName $computerName
if ($session -eq $null)
{
    throw "Failed to connect to $computerName"
}

Write-Verbose "Connected to $computerName via $($session.Name)"

$remoteDirectory = 'c:\verification'
$remoteLogDirectory = "c:\logs"
Copy-FilesToRemoteMachine -session $session -localDirectory $testDirectory -remoteDirectory $remoteDirectory

# Verify that everything is there
Invoke-Command `
    -Session $session `
    -ArgumentList @( (Join-Path $remoteDirectory 'Verify-ConfigurationOnWindowsMachine.ps1'), (Join-Path $remoteDirectory "spec"), $remoteLogDirectory ) `
    -ScriptBlock {
        param(
            [string] $verificationScript,
            [string] $testDirectory,
            [string] $logDirectory
        )

        & $verificationScript -testDirectory $testDirectory -logDirectory $logDirectory
    } `
    @commonParameterSwitches

Write-Verbose "Copying log files from VM ..."
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