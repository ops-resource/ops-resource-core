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

    The full path to the directory on the remote machine where the verification files should be placed. Defaults to 'c:\temp\verification'.


    .PARAMETER remoteLogDirectory

    The full path to the directory on the remote machine where the log files should be placed. Defaults to 'c:\temp\logs'.


    .EXAMPLE

    Test-WindowsResource -session $session -testDirectory "c:\tests" -logDirectory "c:\logs"
#>
[CmdletBinding(SupportsShouldProcess = $True)]
param(
    [System.Management.Automation.Runspaces.PSSession] $session = $(throw 'Please provide a Powershell remoting session that can be used to connect to the machine for which the configuration needs to be verified.'),
    [string] $testDirectory                                     = $(Join-Path $PSScriptRoot "verification"),
    [string] $logDirectory                                      = $(Join-Path $PSScriptRoot "logs"),
    [string] $remoteVerificationDirectory                       = 'c:\temp\verification',
    [string] $remoteLogDirectory                                = 'c:\temp\logs'
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
        Debug = $false;
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

    Copy-FilesToRemoteMachine -session $session -localDirectory $testDirectory -remoteDirectory $remoteVerificationDirectory

    # Verify that everything is there
    Invoke-Command `
        -Session $session `
        -ArgumentList @( (Join-Path $remoteVerificationDirectory 'Test-ConfigurationOnWindowsMachine.ps1'), $remoteVerificationDirectory, $remoteLogDirectory ) `
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

    Remove-FilesFromRemoteMachine -session $session -remoteDirectory $remoteVerificationDirectory
    Remove-FilesFromRemoteMachine -session $session -remoteDirectory $remoteLogDirectory
}

$pesterLog = Join-Path $logDirectory 'pester.xml'
if (-not (Test-Path $pesterLog))
{
    throw "Test failed. No pester log produced."
}

$pesterXml = [xml](Get-Content $pesterLog)
$testNode = $pesterXml["test-results"]
$tests = $testNode.total
$failures = $testNode.failures
$errors = $testNode.errors

if (($tests -gt 0) -and ($failures -eq 0) -and ($errors -eq 0))
{
    Write-Output "Test PASSED"
}
else
{
    throw "Test FAILED"
}