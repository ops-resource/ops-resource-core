<#
    .SYNOPSIS

    Connects to the remote machine, pushes all the necessary files up to it and then executes the Chef cookbook that installs
    all the required applications.


    .DESCRIPTION

    The New-HyperVResource script takes all the actions necessary to configure the machine.


    .PARAMETER credential

    The credential that should be used to connect to the remote machine.


    .PARAMETER authenticateWithCredSSP

    A flag that indicates whether remote powershell sessions should be authenticated with the CredSSP mechanism.


    .PARAMETER hypervHost

    The name of the machine on which the hyper-v server is located.


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

    New-HyperVResource
        -hypervHost "MyHost"
        -installationDirectory "c:\installers"
        -logDirectory "c:\logs"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [PSCredential] $credential                                  = $null,

    [Parameter(Mandatory = $false)]
    [switch] $authenticateWithCredSSP,

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
    [string] $hypervHost                                        = '',

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

Write-Verbose "New-HyperVResource - credential = $credential"
Write-Verbose "New-HyperVResource - authenticateWithCredSSP = $authenticateWithCredSSP"
Write-Verbose "New-HyperVResource - hypervHost = $hypervHost"
Write-Verbose "New-HyperVResource - resourceName = $resourceName"
Write-Verbose "New-HyperVResource - resourceVersion = $resourceVersion"
Write-Verbose "New-HyperVResource - cookbookNames = $cookbookNames"
Write-Verbose "New-HyperVResource - installationDirectory = $installationDirectory"
Write-Verbose "New-HyperVResource - logDirectory = $logDirectory"

switch ($psCmdlet.ParameterSetName)
{
    'FromUserSpecification' {
        Write-Verbose "New-HyperVResource - dataCenterName = $dataCenterName"
        Write-Verbose "New-HyperVResource - clusterEntryPointAddress = $clusterEntryPointAddress"
        Write-Verbose "New-HyperVResource - globalDnsServerAddress = $globalDnsServerAddress"
    }

    'FromMetaCluster' {
        Write-Verbose "New-HyperVResource - environmentName = $environmentName"
        Write-Verbose "New-HyperVResource - consulLocalAddress = $consulLocalAddress"
    }
}

# Stop everything if there are errors
$ErrorActionPreference = 'Stop'

$commonParameterSwitches =
    @{
        Verbose = $PSBoundParameters.ContainsKey('Verbose');
        Debug = $false;
        ErrorAction = 'Stop'
    }

# Load the helper functions
. (Join-Path $PSScriptRoot hyperv.ps1)
. (Join-Path $PSScriptRoot sessions.ps1)
. (Join-Path $PSScriptRoot windows.ps1)

if (-not (Test-Path $installationDirectory))
{
    throw "Unable to find the directory containing the installation files. Expected it at: $installationDirectory"
}

if (-not (Test-Path $logDirectory))
{
    New-Item -Path $logDirectory -ItemType Directory | Out-Null
}

if ($psCmdlet.ParameterSetName -eq 'FromMetaCluster')
{
    . $(Join-Path $PSScriptRoot 'Consul.ps1')

    $consulDomain = Get-ConsulDomain `
        -environment $environmentName `
        -consulLocalAddress $consulLocalAddress `
        @commonParameterSwitches
    $hypervHost = "host.hyperv.service.$($consulDomain)"

    $hypervHostVmStorageSubPath = Get-ConsulKeyValue `
        -environment $environmentName `
        -consulLocalAddress $consulLocalAddress `
        -keyPath '' `
        @commonParameterSwitches
    $hypervHostVmStoragePath = "\\$($hypervHost)\$($hypervHostVmStorageSubPath)"
}
else
{
    $hypervHostVmStoragePath = "\\$(hypervHost)\vms\machines"
    $machineOU = 'servers'
}

$vhdxStoragePath = "$($hypervHostVmStoragePath)\$(hdd)"
$baseVhdx = Get-ChildItem -Path $vhdxTemplatePath -File -Filter "$($osName)*.vhdx" | Sort-Object LastWriteTime | Select-Object -First 1
$registeredOwner = Get-RegisteredOwner @commonParameterSwitches

$machineName = ""
$domainAdminUserName = ""
$domainAdminPassword = ""

New-HypervVmOnDomain `
    -machineName $machineName `
    -baseVhdx $baseVhdx `
    -vhdxStoragePath $vhdxStoragePath `
    -hypervHost $hypervHost `
    -registeredOwner $registeredOwner `
    -domainName $env:USERDNSDOMAIN `
    -machineOU $machineOU `
    -domainAdministratorUserName $domainAdminUserName `
    -domainAdministratorPassword $domainAdminPassword `
    @commonParameterSwitches

Start-VM -Name $machineName -ComputerName $hypervHost @commonParameterSwitches
$connection = Get-ConnectionInformationForVm `
    -machineName $machineName `
    -hypervHost $hypervHost `
    -localAdminCredential $credential `
    -timeOutInSeconds 900 `
    @commonParameterSwitches

$newWindowsResource = Join-Path $PSScriptRoot 'New-WindowsResource.ps1'
switch ($psCmdlet.ParameterSetName)
{
    'FromUserSpecification' {
        & $newWindowsResource `
            -session $connection.Session `
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
            -session $connection.Session `
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
