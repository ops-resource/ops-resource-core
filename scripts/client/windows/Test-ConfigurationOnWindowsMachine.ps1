<#
    .SYNOPSIS

    Executes the tests that verify whether the current machine has all the tools installed to allow it to work as a Windows Jenkins master.


    .DESCRIPTION

    The Test-ConfigurationOnWindowsMachine script executes the tests that verify whether the current machine has all the tools installed to
    allow it to work as a jenkins windows machine.


    .EXAMPLE

    Test-ConfigurationOnWindowsMachine.ps1
#>
[CmdletBinding()]
param(
    [string] $testDirectory = "c:\temp\verification",
    [string] $logDirectory  = "c:\temp\logs"
)

Write-Verbose "Test-ConfigurationOnWindowsMachine - testDirectory: $testDirectory"
Write-Verbose "Test-ConfigurationOnWindowsMachine - logDirectory: $logDirectory"

$ErrorActionPreference = "Stop"

if (-not (Test-Path $testDirectory))
{
    throw "Expected test directory to exist."
}

if (-not (Test-Path $logDirectory))
{
    New-Item -Path $logDirectory -ItemType Directory
}

$pesterModulePath = Join-Path (Join-Path $testDirectory 'tools') 'pester'
$env:PSModulePath = $env:PSModulePath + ';' + "$pesterModulePath"
Import-Module (Join-Path $pesterModulePath 'Pester.psm1')

Invoke-Pester -Path (Join-Path $testDirectory 'tests') -OutputXml (Join-Path $logDirectory 'pester.xml') -Verbose
