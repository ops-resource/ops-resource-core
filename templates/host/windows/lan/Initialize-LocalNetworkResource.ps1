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


    .PARAMETER isConsulClusterLeader

    A flag that indicates whether or not configure the consul agent as a cluser leader or not. Defaults to false.


    .PARAMETER consulDomain

    The name of the consul domain


    .PARAMETER dataCenterName

    The name of the consul data center to which the remote machine should belong once configuration is completed.


    .PARAMETER lanEntryPointAddress

    The DNS name of a machine that is part of the consul cluster to which the remote machine should be joined.


    .PARAMETER lanEntryPointAddress

    The DNS name of a machine that is part of the meta consul remote cluster to which the remote machine should be joined.


    .PARAMETER globalDnsServerAddress

    The DNS name or IP address of the DNS server that will be used by Consul to handle DNS fallback.


    .PARAMETER environmentName

    The name of the environment to which the remote machine should be added.


    .PARAMETER consulLocalAddress

    The URL to the local consul agent.


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
    [string] $computerName                                      = $(throw 'Please specify the name of the machine that should be configured.'),

    [bool] $isConsulClusterLeader                               = $false,

    [Parameter(Mandatory = $false,
               ParameterSetName = 'FromUserSpecification')]
    [string] $consulDomain                                      = '',

    [Parameter(Mandatory = $true,
               ParameterSetName = 'FromUserSpecification')]
    [string] $dataCenterName                                    = '',

    [Parameter(Mandatory = $false,
               ParameterSetName = 'FromUserSpecification')]
    [string] $lanEntryPointAddress                              = '',

    [Parameter(Mandatory = $false,
               ParameterSetName = 'FromUserSpecification')]
    [string] $wanEntryPointAddress                              = '',

    [Parameter(Mandatory = $false,
               ParameterSetName = 'FromUserSpecification')]
    [string] $globalDnsServerAddress                            = '',

    [Parameter(Mandatory = $false,
               ParameterSetName = 'FromMetaCluster')]
    [string] $environmentName                                   = 'Development',

    [Parameter(Mandatory = $false,
               ParameterSetName = 'FromMetaCluster')]
    [string] $consulLocalAddress                                = "http://localhost:8500"
)

Write-Verbose "Initialize-LocalNetworkResource - credential: $credential"
Write-Verbose "Initialize-LocalNetworkResource - authenticateWithCredSSP: $authenticateWithCredSSP"
Write-Verbose "Initialize-LocalNetworkResource - computerName: $computerName"
Write-Verbose "Initialize-LocalNetworkResource - isConsulClusterLeader: $isConsulClusterLeader"
switch ($psCmdlet.ParameterSetName)
{
    'FromUserSpecification' {
        Write-Verbose "Initialize-LocalNetworkResource - consulDomain: $consulDomain"
        Write-Verbose "Initialize-LocalNetworkResource - dataCenterName: $dataCenterName"
        Write-Verbose "Initialize-LocalNetworkResource - lanEntryPointAddress: $lanEntryPointAddress"
        Write-Verbose "Initialize-LocalNetworkResource - wanEntryPointAddress: $wanEntryPointAddress"
        Write-Verbose "Initialize-LocalNetworkResource - globalDnsServerAddress: $globalDnsServerAddress"
    }

    'FromMetaCluster' {
        Write-Verbose "Initialize-LocalNetworkResource - environmentName: $environmentName"
    }
}

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

    switch ($psCmdlet.ParameterSetName)
    {
        'FromUserSpecification' {
            & $installationScript `
                -credential $credential `
                -authenticateWithCredSSP:$authenticateWithCredSSP `
                -computerName $computerName `
                -resourceName $resourceName `
                -resourceVersion $resourceVersion `
                -cookbookNames $cookbookNames `
                -installationDirectory $installationDirectory `
                -logDirectory $logDirectory `
                -consulDomain $consulDomain `
                -dataCenterName $dataCenterName `
                -lanEntryPointAddress $lanEntryPointAddress `
                -wanEntryPointAddress $wanEntryPointAddress `
                -globalDnsServerAddress $globalDnsServerAddress `
                @commonParameterSwitches
        }

        'FromMetaCluster' {
            & $installationScript `
                -credential $credential `
                -authenticateWithCredSSP:$authenticateWithCredSSP `
                -computerName $computerName `
                -resourceName $resourceName `
                -resourceVersion $resourceVersion `
                -cookbookNames $cookbookNames `
                -installationDirectory $installationDirectory `
                -logDirectory $logDirectory `
                -environmentName $environmentName `
                -consulLocalAddress $consulLocalAddress `
                @commonParameterSwitches
        }
    }

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
