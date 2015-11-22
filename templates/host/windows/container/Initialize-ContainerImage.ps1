<#
    .SYNOPSIS

    Connects to the remote machine, pushes all the necessary files up to it, executes the Chef cookbook that installs
    all the required applications and then verifies that all the applications have been installed correctly.


    .DESCRIPTION

    The New-WindowsResource script takes all the actions necessary configure the remote machine.


    .PARAMETER credential

    The credential that should be used to connect to the remote machine.


    .PARAMETER authenticateWithCredSSP

    A flag that indicates whether remote powershell sessions should be authenticated with the CredSSP mechanism.


    .PARAMETER containerHost

    The name of the container host machine.
    
    
    .PARAMETER containerBaseImage
    
    The name of the container base image on which the container is based.
    
    
    .PARAMETER containerImage
    
    The name of the container image that should be created by the current script.


    .PARAMETER dataCenterName

    The name of the consul data center to which the remote machine should belong once configuration is completed.


    .PARAMETER clusterEntryPointAddress

    The DNS name of a machine that is part of the consul cluster to which the remote machine should be joined.


    .PARAMETER globalDnsServerAddress

    The DNS name or IP address of the DNS server that will be used by Consul to handle DNS fallback.


    .PARAMETER environmentName

    The name of the environment to which the remote machine should be added.


    .PARAMETER consulLocalAddress

    The URL to the local consul agent.


    .EXAMPLE

    Initialize-ContainerImage 
        -containerHost "MyHost"
        -containerImage 'MyImage'
        -containerImage 'MyCoolContainer'
        -environmentName 'staging'
        -consulLocalAddress 'http://myhost:8500'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [PSCredential] $credential                                  = $null,

    [Parameter(Mandatory = $false)]
    [switch] $authenticateWithCredSSP,

    [Parameter(Mandatory = $true)]
    [string] $containerHost                                     = $(throw 'Please specify the name of the machine on which the containers can be created.'),
    
    [Parameter(Mandatory = $true)]
    [string] $containerBaseImage                                = $(throw 'Please specify the name of the container base image.'),
    
    [Parameter(Mandatory = $true)]
    [string] $containerImage                                = $(throw 'Please specify the name of the container image that should be created.')

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
    [string] $environmentName                                   = 'Development',

    [Parameter(Mandatory = $false,
               ParameterSetName = 'FromMetaCluster')]
    [string] $consulLocalAddress                                = "http://localhost:8500"
)

Write-Verbose "Initialize-ContainerImage - credential: $credential"
Write-Verbose "Initialize-ContainerImage - authenticateWithCredSSP: $authenticateWithCredSSP"
Write-Verbose "Initialize-ContainerImage - containerHost: $containerHost"
Write-Verbose "Initialize-ContainerImage - containerBaseImage: $containterBaseImage"
Write-Verbose "Initialize-ContainerImage - containerImage: $containterImageName"
switch ($psCmdlet.ParameterSetName)
{
    'FromUserSpecification' {
        Write-Verbose "Initialize-ContainerImage - dataCenterName: $dataCenterName"
        Write-Verbose "Initialize-ContainerImage - clusterEntryPointAddress: $clusterEntryPointAddress"
        Write-Verbose "Initialize-ContainerImage - globalDnsServerAddress: $globalDnsServerAddress"
    }

    'FromMetaCluster' {
        Write-Verbose "Initialize-ContainerImage - environmentName: $environmentName"
    }
}

# Stop everything if there are errors
$ErrorActionPreference = 'Stop'

$commonParameterSwitches =
    @{
        Verbose = $PSBoundParameters.ContainsKey('Verbose');
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

    $installationScript = Join-Path $PSScriptRoot 'New-ContainerImage.ps1'
    $verificationScript = Join-Path $PSScriptRoot 'Test-ContainerImage.ps1'

    switch ($psCmdlet.ParameterSetName)
    {
        'FromUserSpecification' {
            & $installationScript `
                -credential $credential `
                -authenticateWithCredSSP:$authenticateWithCredSSP `
                -containerHost $containerHost `
                -containerBaseImage $containerBaseImage `
                -containerImage $containerImage `
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
                -credential $credential `
                -authenticateWithCredSSP:$authenticateWithCredSSP `
                -containerHost $containerHost `
                -containerBaseImage $containerBaseImage `
                -containerImage $containerImage `
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
        -containerHost $containerHost `
        -containerImage $containerImage `
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