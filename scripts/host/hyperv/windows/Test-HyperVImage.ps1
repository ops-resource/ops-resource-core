<#
    .SYNOPSIS

    Verifies that a given Hyper-V image can indeed be used to run the selected resource.


    .DESCRIPTION

    The Test-HyperVImage script verifies that a given image can indeed be used to run the selected resource.


    .PARAMETER credential

    The credential that should be used to connect to the remote machine.


    .PARAMETER authenticateWithCredSSP

    A flag that indicates whether remote powershell sessions should be authenticated with the CredSSP mechanism.


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


    .PARAMETER osName

    The name of the OS that should be used to create the new VM.


    .PARAMETER machineName

    The name of the machine that should be created


    .PARAMETER hypervHost

    The name of the machine on which the hyper-v server is located.


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
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [PSCredential] $credential                                  = $null,

    [Parameter(Mandatory = $false)]
    [switch] $authenticateWithCredSSP,

    [Parameter(Mandatory = $false)]
    [string] $imageName                                         = "$($resourceName)-$($resourceVersion).vhdx",

    [string] $testDirectory                                     = $(Join-Path $PSScriptRoot "verification"),

    [Parameter(Mandatory = $false)]
    [string] $logDirectory                                      = $(Join-Path $PSScriptRoot 'logs'),

    [Parameter(Mandatory = $true)]
    [string] $machineName                                       = '',

    [Parameter(Mandatory = $true,
               ParameterSetName = 'FromUserSpecification')]
    [string] $hypervHost                                        = '',

    [Parameter(Mandatory = $true,
               ParameterSetName = 'FromUserSpecification')]
    [string] $vhdxTemplatePath                                  = "\\$($hypervHost)\vmtemplates",

    [Parameter(Mandatory = $true,
               ParameterSetName = 'FromUserSpecification')]
    [string] $hypervHostVmStoragePath                           = "\\$($hypervHost)\vms\machines",

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

Write-Verbose "Test-HyperVImage - credential = $credential"
Write-Verbose "Test-HyperVImage - authenticateWithCredSSP = $authenticateWithCredSSP"
Write-Verbose "Test-HyperVImage - imageName = $imageName"
Write-Verbose "Test-HyperVImage - testDirectory = $testDirectory"
Write-Verbose "Test-HyperVImage - logDirectory = $logDirectory"
Write-Verbose "Test-HyperVImage - machineName = $machineName"

switch ($psCmdlet.ParameterSetName)
{
    'FromUserSpecification' {
        Write-Verbose "Test-HyperVImage - hypervHost = $hypervHost"
        Write-Verbose "Test-HyperVImage - vhdxTemplatePath = $vhdxTemplatePath"
        Write-Verbose "Test-HyperVImage - hypervHostVmStoragePath = $hypervHostVmStoragePath"
        Write-Verbose "Test-HyperVImage - dataCenterName = $dataCenterName"
        Write-Verbose "Test-HyperVImage - clusterEntryPointAddress = $clusterEntryPointAddress"
        Write-Verbose "Test-HyperVImage - globalDnsServerAddress = $globalDnsServerAddress"
    }

    'FromMetaCluster' {
        Write-Verbose "Test-HyperVImage - environmentName = $environmentName"
        Write-Verbose "Test-HyperVImage - consulLocalAddress = $consulLocalAddress"
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

if (-not (Test-Path $testDirectory))
{
    throw "Unable to find the directory containing the test files. Expected it at: $testDirectory"
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
        -keyPath 'service\hyperv\storagesubpath' `
        @commonParameterSwitches
    $hypervHostVmStoragePath = "\\$($hypervHost)\$($hypervHostVmStorageSubPath)"

    $vhdxTemplatePath = Get-ConsulKeyValue `
        -environment $environmentName `
        -consulLocalAddress $consulLocalAddress `
        -keyPath 'service\hyperv\templatesubpath' `
        @commonParameterSwitches
}

if (-not (Test-Path $hypervHostVmStoragePath))
{
    throw "Unable to find the directory where the Hyper-V VMs are stored. Expected it at: $hypervHostVmStoragePath"
}

if (-not (Test-Path $vhdxTemplatePath))
{
    throw "Unable to find the directory where the Hyper-V templates are stored. Expected it at: $vhdxTemplatePath"
}

$vhdxStoragePath = "$($hypervHostVmStoragePath)\hdd"
$baseVhdx = Get-ChildItem -Path $vhdxTemplatePath -File -Filter "$($imageName).vhdx" | Select-Object -First 1

try
{
    New-HypervVmFromBaseImage `
        -vmName $machineName `
        -baseVhdx $baseVhdx `
        -hypervHost $hypervHost `
        -vhdxStoragePath $vhdxStoragePath `
        @commonParameterSwitches

    Start-VM -Name $machineName -ComputerName $hypervHost @commonParameterSwitches
    timeOutInSeconds = 900
    $connection = Get-ConnectionInformationForVm `
        -machineName $machineName `
        -hypervHost $hypervHost `
        -localAdminCredential $credential `
        -timeOutInSeconds $timeOutInSeconds `
        @commonParameterSwitches

    Write-Verbose "Connected to $computerName via $($connection.Session.Name)"

    $testWindowsResource = Join-Path $PSScriptRoot 'Test-WindowsResource.ps1'
    & $testWindowsResource -session $connection.Session -testDirectory $testDirectory -logDirectory $logDirectory
}
finally
{
    # Stop the VM
    try
    {
        Stop-VM `
            -ComputerName $hypervHost `
            -Name $machineName `
            -Force `
            @commonParameterSwitches
    }
    catch
    {
        # just ignore it
    }

    # Delete the VM. If the delete goes wrong we want to know, because we'll have a random VM
    # trying to do stuff on the environment.
    Remove-VM `
        -computerName $hypervHost `
        -Name $machineName `
        -Force `
        @commonParameterSwitches
}