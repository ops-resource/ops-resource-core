<#
    .SYNOPSIS

    Verifies that a given windows container is configured correctly.


    .DESCRIPTION

    The Test-ContainerImage script verifies that a given windows container is configured correctly.


    .PARAMETER credential

    The credential that should be used to connect to the remote container host.


    .PARAMETER authenticateWithCredSSP

    A flag that indicates whether remote powershell sessions should be authenticated with the CredSSP mechanism.


    .PARAMETER containerHost

    The name of the container host.


    .PARAMETER testDirectory

    The directory in which all the test files can be found.


    .PARAMETER logDirectory

    The directory in which all the logs should be stored.


    .EXAMPLE

    Test-ContainerImage 
        -containerHost "MyMachine"
        -containerImage 'MyContainerImage'
        -testDirectory "c:\tests" 
        -logDirectory "c:\logs"
#>
[CmdletBinding(SupportsShouldProcess = $True)]
param(
    [Parameter(Mandatory = $false)]
    [PSCredential] $credential       = $null,

    [Parameter(Mandatory = $false)]
    [switch] $authenticateWithCredSSP,

    [Parameter(Mandatory = $true)]
    [string] $containerHost          = $(throw "Please specify the name of the machine on which the container host."),
    
    [Parameter(Mandatory = $true)]
    [string] $containerImage         = $(throw 'Please specify the name of the container image that should be tested.'),

    [string] $testDirectory          = $(Join-Path $PSScriptRoot "verification"),

    [string] $logDirectory           = $(Join-Path $PSScriptRoot "logs")
)

Write-Verbose "Test-ContainerImage - credential: $credential"
Write-Verbose "Test-ContainerImage - authenticateWithCredSSP: $authenticateWithCredSSP"
Write-Verbose "Test-ContainerImage - containerHost: $containerHost"
Write-Verbose "Test-ContainerImage - containerImage: $containerImage"
Write-Verbose "Test-ContainerImage - testDirectory: $testDirectory"
Write-Verbose "Test-ContainerImage - logDirectory: $logDirectory"

# Stop everything if there are errors
$ErrorActionPreference = 'Stop'

$commonParameterSwitches =
    @{
        Verbose = $PSBoundParameters.ContainsKey('Verbose');
        Debug = $PSBoundParameters.ContainsKey('Debug');
        ErrorAction = "Stop"
    }

# Load the helper functions
. (Join-Path $PSScriptRoot sessions.ps1)