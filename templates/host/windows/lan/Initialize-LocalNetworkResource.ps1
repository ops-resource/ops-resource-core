<#
    .SYNOPSIS

    Connects to the remote machine, pushes all the necessary files up to it, executes the Chef cookbook that installs
    all the required applications and then verifies that all the applications have been installed correctly.


    .DESCRIPTION

    The New-WindowsResource script takes all the actions necessary configure the remote machine.


    .PARAMETER computerName

    The name of the machine that should be set up.


    .PARAMETER dataCenterName

    The name of the consul data center to which the remote machine should belong once configuration is completed.


    .PARAMETER clusterEntryPointAddress

    The DNS name of a machine that is part of the consul cluster to which the remote machine should be joined.


    .PARAMETER globalDnsServerAddress

    The DNS name or IP address of the DNS server that will be used by Consul to handle DNS fallback.


    .PARAMETER environmentName

    The name of the environment to which the remote machine should be added.


    .EXAMPLE

    New-WindowsResource -computerName "AKTFSJS01"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $computerName = $(throw 'Please specify the name of the machine that should be configured.'),

    [Parameter(Mandatory = $true,
               ParameterSetName = 'FromUserSpecification')]
    [string] $dataCenterName                                    = '',

    [Parameter(Mandatory = $true,
               ParameterSetName = 'FromUserSpecification')]
    [string] $clusterEntryPointAddress                          = '',

    [Parameter(Mandatory = $false,
               ParameterSetName = 'FromUserSpecification')]
    [string] $globalDnsServerAddress                            = '',

    [Parameter(Mandatory = $false,
               ParameterSetName = 'FromMetaCluster')]
    [string] $environmentName                                   = 'Development'
)

Write-Verbose "Initialize-LocalNetworkResource - computerName: $computerName"

# Stop everything if there are errors
$ErrorActionPreference = 'Stop'

$commonParameterSwitches =
    @{
        Verbose = $PSBoundParameters.ContainsKey('Verbose');
        Debug = $PSBoundParameters.ContainsKey('Debug');
        ErrorAction = "Stop"
    }

$resourceName = '${ProductName}'
$resourceVersion = '${VersionSemanticFull}'
$cookbookNames = '${CookbookNames}'.Split(';')

$installationDirectory = $(Join-Path $PSScriptRoot 'configuration')
$testDirectory = $(Join-Path $PSScriptRoot 'verification')
$logDirectory = $(Join-Path $PSScriptRoot 'logs')

$installationScript = Join-Path $PSScriptRoot 'New-LocalNetworkResource.ps1'
$verificationScript = Join-Path $PSScriptRoot 'Test-LocalNetworkResource.ps1'

switch ($psCmdlet.ParameterSetName)
{
    'FromUserSpecification' {
        & $installationScript `
            -computerName $computerName `
            -resourceName $resourceName `
            -resourceVersion $resourceVersion `
            -cookbookNames $cookbookNames `
            -installationDirectory $installationDirectory `
            -logDirectory $logDirectory `
            -dataCenterName $dataCenterName `
            -clusterEntryPointAddress $clusterEntryPointAddress `
            -globalDnsServerAddress $globalDnsServerAddress `
            @commonParameterSwitches
    }

    'FromMetaCluster' {
        & $installationScript `
            -computerName $computerName `
            -resourceName $resourceName `
            -resourceVersion $resourceVersion `
            -cookbookNames $cookbookNames `
            -installationDirectory $installationDirectory `
            -logDirectory $logDirectory `
            -environmentName $environmentName `
            @commonParameterSwitches
    }
}

& $verificationScript -computerName $computerName -testDirectory $testDirectory -logDirectory $logDirectory @commonParameterSwitches
