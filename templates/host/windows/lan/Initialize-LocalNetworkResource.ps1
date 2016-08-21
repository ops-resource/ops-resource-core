<#
    .SYNOPSIS

    Connects to the remote machine, pushes all the necessary files up to it, executes the Chef cookbook that installs
    all the required applications and then verifies that all the applications have been installed correctly.


    .DESCRIPTION

    The Initialize-LocalNetworkResource script takes all the actions necessary configure the remote machine.


    .PARAMETER credential

    The credential that should be used to connect to the remote machine.


    .PARAMETER authenticateWithCredSSP

    A flag that indicates whether remote powershell sessions should be authenticated with the CredSSP mechanism.


    .PARAMETER computerName

    The name of the machine that should be set up.


    .EXAMPLE

    Initialize-LocalNetworkResource -computerName "MyServer"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [PSCredential] $credential                                  = $null,

    [Parameter(Mandatory = $false)]
    [switch] $authenticateWithCredSSP,

    [Parameter(Mandatory = $true)]
    [string] $computerName                                      = $(throw 'Please specify the name of the machine that should be configured.')
)

Write-Verbose "Initialize-LocalNetworkResource - credential: $credential"
Write-Verbose "Initialize-LocalNetworkResource - authenticateWithCredSSP: $authenticateWithCredSSP"
Write-Verbose "Initialize-LocalNetworkResource - computerName: $computerName"

# Stop everything if there are errors
$ErrorActionPreference = 'Stop'

$commonParameterSwitches =
    @{
        Verbose = $PSBoundParameters.ContainsKey('Verbose');
        Debug = $false;
        ErrorAction = "Stop"
    }

$startTime = [System.DateTimeOffset]::Now
try
{
    $resourceName = '${ProductName}'
    $resourceVersion = '${VersionSemanticFull}'
    $cookbookNames = '${CookbookNames}'.Split(';')

    $installationDirectory = $(Join-Path $PSScriptRoot 'configuration')
    $testDirectory = $(Join-Path $PSScriptRoot 'verification')
    $logDirectory = $(Join-Path $PSScriptRoot 'logs')

    $installationScript = Join-Path $PSScriptRoot 'New-LocalNetworkResource.ps1'
    $verificationScript = Join-Path $PSScriptRoot 'Test-LocalNetworkResource.ps1'


    & $installationScript `
        -credential $credential `
        -authenticateWithCredSSP:$authenticateWithCredSSP `
        -computerName $computerName `
        -resourceName $resourceName `
        -resourceVersion $resourceVersion `
        -cookbookNames $cookbookNames `
        -installationDirectory $installationDirectory `
        -logDirectory $logDirectory `
        @commonParameterSwitches

    & $verificationScript `
        -credential $credential `
        -authenticateWithCredSSP:$authenticateWithCredSSP `
        -computerName $computerName `
        -testDirectory $testDirectory `
        -logDirectory $logDirectory `
        @commonParameterSwitches
}
finally
{
    $endTime = [System.DateTimeOffset]::Now
    Write-Output ("Resource initialization started: " + $startTime)
    Write-Output ("Resource initialization completed: " + $endTime)
    Write-Output ("Total time: " + ($endTime - $startTime))
}
