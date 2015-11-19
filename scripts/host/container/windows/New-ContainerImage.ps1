<#
    .SYNOPSIS

    Connects to a container host, creates a container and pushes all the necessary files up to 
    the and then executes the Chef cookbook that installs all the required applications.


    .DESCRIPTION

    The New-ContainerImage script takes all the actions necessary to configure a new container image.


    .PARAMETER credential

    The credential that should be used to connect to the container host.


    .PARAMETER authenticateWithCredSSP

    A flag that indicates whether remote powershell sessions should be authenticated with the CredSSP mechanism.


    .PARAMETER containerHost

    The name of the container host machine.
    
    
    .PARAMETER containerBaseImage
    
    The name of the container base image on which the container is based.


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

    New-WindowsResource -computerName "MyMachine" -installationDirectory "c:\installers" -logDirectory "c:\logs"
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

    [Parameter(Mandatory = $false)]
    [string] $resourceName                                      = '',

    [Parameter(Mandatory = $false)]
    [string] $resourceVersion                                   = '',

    [Parameter(Mandatory = $true)]
    [string[]] $cookbookNames                                   = $(throw 'Please specify the names of the cookbooks that should be executed.'),

    [Parameter(Mandatory = $false)]
    [string] $installationDirectory                             = $(Join-Path $PSScriptRoot 'configuration'),

    [Parameter(Mandatory = $false)]
    [string] $logDirectory                                      = $(Join-Path $PSScriptRoot 'logs'),

    [Parameter(Mandatory = $true,
               ParameterSetName = 'FromUserSpecification')]
    [string] $dataCenterName                                    = '',

    [Parameter(Mandatory = $true,
               ParameterSetName = 'FromUserSpecification')]
    [string] $clusterEntryPointAddress                          = '',

    [Parameter(Mandatory = $false,
               ParameterSetName = 'FromUserSpecification')]
    [string] $globalDnsServerAddress                            = '',

    [Parameter(Mandatory = $true,
               ParameterSetName = 'FromMetaCluster')]
    [string] $environmentName                                   = 'Development',

    [Parameter(Mandatory = $false,
               ParameterSetName = 'FromMetaCluster')]
    [string] $consulLocalAddress                                = "http://localhost:8500"
)

Write-Verbose "New-ContainerImage - credential: $credential"
Write-Verbose "New-ContainerImage - authenticateWithCredSSP: $authenticateWithCredSSP"
Write-Verbose "New-ContainerImage - containerHost: $containerHost"
Write-Verbose "New-ContainerImage - containerBaseImage: $containerBaseImage"
Write-Verbose "New-ContainerImage - resourceName: $resourceName"
Write-Verbose "New-ContainerImage - resourceVersion: $resourceVersion"
Write-Verbose "New-ContainerImage - cookbookNames: $cookbookNames"
Write-Verbose "New-ContainerImage - installationDirectory: $installationDirectory"
Write-Verbose "New-ContainerImage - logDirectory: $logDirectory"

switch ($psCmdlet.ParameterSetName)
{
    'FromUserSpecification' {
        Write-Verbose "New-ContainerImage - dataCenterName: $dataCenterName"
        Write-Verbose "New-ContainerImage - clusterEntryPointAddress: $clusterEntryPointAddress"
        Write-Verbose "New-ContainerImage - globalDnsServerAddress: $globalDnsServerAddress"
    }

    'FromMetaCluster' {
        Write-Verbose "New-ContainerImage - environmentName: $environmentName"
        Write-Verbose "New-ContainerImage - consulLocalAddress: $consulLocalAddress"
    }
}

# Stop everything if there are errors
$ErrorActionPreference = 'Stop'

$commonParameterSwitches =
    @{
        Verbose = $PSBoundParameters.ContainsKey('Verbose');
        Debug = $PSBoundParameters.ContainsKey('Debug');
        ErrorAction = 'Stop'
    }