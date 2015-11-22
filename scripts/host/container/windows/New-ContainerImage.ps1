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
    
    
    .PARAMETER containerImage
    
    The name of the container image that should be created by the current script.


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

    New-ContainerImage 
        -containerHost "MyMachine" 
        -containerBaseImage 'MyBaseImage'
        -containerImage 'MyCoolContainer'
        -resourceName 'MyNewService'
        -resourceVersion '0.1.0'
        -cookbookNames @( 'cookbook1', 'cookbook2', 'cookbook3' ) 
        -installationDirectory "c:\temp\installers" 
        -logDirectory "c:\temp\logs"
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
    [string] $containerImage                                    = $(throw 'Please specify the name of the container image that should be created.')

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
Write-Verbose "New-ContainerImage - containerImage: $containerImage"
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
    
# Load the helper functions
. (Join-Path $PSScriptRoot sessions.ps1)

if (-not (Test-Path $installationDirectory))
{
    throw "Unable to find the directory containing the installation files. Expected it at: $installationDirectory"
}

if (-not (Test-Path $logDirectory))
{
    New-Item -Path $logDirectory -ItemType Directory | Out-Null
}

$containerHostSession = New-Session -computerName $containerHost -credential $credential -authenticateWithCredSSP:$authenticateWithCredSSP @commonParameterSwitches
if ($containerHostSession -eq $null)
{
    throw "Failed to connect to $containerHost"
}

# Make sure that the remote log directory exists because if something goes wrong with the script we try to copy from that directory
# however the copy action on 'c:\logs' if it doesn't exist somehow then tries to copy to all the folders with the term 'logs' in it from
# the windows directory.
Invoke-Command `
    -Session $containerHostSession `
    -ArgumentList @( $containerBaseImage ) `
    -ScriptBlock {
        param(
            [string] $containerBaseImage
        )

        # Install the package provider if it's not there
        if ((Get-PackageProvider -ListAvailable | Where-Object { $_.Name -eq 'ContainerProvider' } | Select-Object -First 1) -eq $null)
        {
            Install-PackageProvider -Name ContainerProvider -Force -ForceBootstrap -Verbose   
        }
        
        # download base image if required
        $existingContainers = Get-ContainerImage | Where-Object { $_.Name -eq $containerBaseImage }
        if (($existingContainers -eq $null) -or ($existingContainers.Count -eq 0))
        {
            Install-ContainerImage -Name $containerBaseImage -Verbose
        }
    } `
    @commonParameterSwitches

# create a new container
$containerName = [System.Guid]::NewGuid().ToString()
<#
$container = New-Container `
    -Name $containerName `
    -ContainerImageName $containerBaseImage ` 
    -ComputerName $containerHost `
    -Credential $credential `
    -SwitchName '' `
    @commonParameterSwitches
#>
# At the moment you cannot create a new container remotely because the powershell
# functions haven't been published. So we'll remote into the host machine first
Invoke-Command `
    -Session $containerHostSession `
    -ArgumentList @( $containerBaseImage ) `
    -ScriptBlock {
        param(
            [string] $containerName,
            [string] $containerBaseImage
        )
        
        # Assume there is only one VM switch
        $switch = Get-VmSwitch

        $container = New-Container `
            -Name $containerName `
            -ContainerImageName $containerBaseImage ` 
            -SwitchName $switch.Name `
            @commonParameterSwitches
        Start-Container -Container $container @commonParameterSwitches
        
        # Install SSL cert of some kind to secure the connection so that we 
        # can create a session to the container
    } `
    @commonParameterSwitches

# note that this isn't going to work. We can't remote into the container from any other
# machine then the container host
$newWindowsResource = Join-Path $PSScriptRoot 'New-WindowsResource.ps1'
switch ($psCmdlet.ParameterSetName)
{
    'FromUserSpecification' {
        & $newWindowsResource `
            -session $containerSession `
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
        & $newWindowsResource `
            -session $containerSession `
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
