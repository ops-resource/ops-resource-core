<#
    .SYNOPSIS

    Connects to a Hyper-V host, creates a new VM, pushes all the necessary files up to the VM and then executes the Chef cookbook that installs
    all the required applications. Once done, creates a Hyper-V template from the VM and removes the VM.


    .DESCRIPTION

    The New-HyperVImage script takes all the actions necessary to create a Hyper-V template.


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


    .PARAMETER imageName

    The name of the image that should be created.


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


    .PARAMETER vhdxTemplatePath

    The UNC path to the directory that contains the Hyper-V images.


    .PARAMETER hypervHostVmStoragePath

    The UNC path to the directory that stores the Hyper-V VM information.


    .PARAMETER staticMacAddress

    An optional static MAC address that is applied to the VM so that it can be given a consistent IP address.
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
    [string] $imageName                                         = "$($resourceName)-$($resourceVersion).vhdx",

    [Parameter(Mandatory = $false)]
    [string] $installationDirectory                             = $(Join-Path $PSScriptRoot 'configuration'),

    [Parameter(Mandatory = $false)]
    [string] $logDirectory                                      = $(Join-Path $PSScriptRoot 'logs'),

    [Parameter(Mandatory = $true)]
    [string] $osName                                            = '',

    [Parameter(Mandatory = $true)]
    [string] $machineName                                       = '',

    [Parameter(Mandatory = $true)]
    [string] $hypervHost                                        = '',

    [Parameter(Mandatory = $true)]
    [string] $vhdxTemplatePath                                  = "\\$($hypervHost)\vmtemplates",

    [Parameter(Mandatory = $true)]
    [string] $hypervHostVmStoragePath                           = "\\$($hypervHost)\vms\machines",

    [Parameter(Mandatory = $false)]
    [string] $staticMacAddress                                  = ''
)

Write-Verbose "New-HyperVImage - credential = $credential"
Write-Verbose "New-HyperVImage - authenticateWithCredSSP = $authenticateWithCredSSP"
Write-Verbose "New-HyperVImage - resourceName = $resourceName"
Write-Verbose "New-HyperVImage - resourceVersion = $resourceVersion"
Write-Verbose "New-HyperVImage - cookbookNames = $cookbookNames"
Write-Verbose "New-HyperVImage - installationDirectory = $installationDirectory"
Write-Verbose "New-HyperVImage - logDirectory = $logDirectory"
Write-Verbose "New-HyperVImage - osName = $osName"
Write-Verbose "New-HyperVImage - machineName = $machineName"
Write-Verbose "New-HyperVImage - hypervHost = $hypervHost"
Write-Verbose "New-HyperVImage - vhdxTemplatePath = $vhdxTemplatePath"
Write-Verbose "New-HyperVImage - hypervHostVmStoragePath = $hypervHostVmStoragePath"
Write-Verbose "New-HyperVImage - staticMacAddress = $staticMacAddress"


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

if (-not (Test-Path $hypervHostVmStoragePath))
{
    throw "Unable to find the directory where the Hyper-V VMs are stored. Expected it at: $hypervHostVmStoragePath"
}

if (-not (Test-Path $vhdxTemplatePath))
{
    throw "Unable to find the directory where the Hyper-V templates are stored. Expected it at: $vhdxTemplatePath"
}

$vhdxStoragePath = "$($hypervHostVmStoragePath)\hdd"
$baseVhdx = Get-ChildItem -Path $vhdxTemplatePath -File -Recurse -Filter "$($osName)*.vhdx" | Sort-Object LastWriteTime | Select-Object -First 1

New-HypervVmFromBaseImage `
    -vmName $machineName `
    -baseVhdx $($baseVhdx.FullName) `
    -hypervHost $hypervHost `
    -vhdxStoragePath $vhdxStoragePath `
    @commonParameterSwitches

if ($staticMacAddress -ne '')
{
    # Ensure that the VM has a specific Mac address so that it will get a known IP address
    # That IP address will be added to the trustedhosts list so that we can remote into
    # the machine without having it be attached to the domain.
    $vm | Get-VMNetworkAdapter | Set-VMNetworkAdapter -StaticMacAddress $staticMacAddress @commonParameterSwitches
}

Start-VM -Name $machineName -ComputerName $hypervHost @commonParameterSwitches
timeOutInSeconds = 900
$connection = Get-ConnectionInformationForVm `
    -machineName $machineName `
    -hypervHost $hypervHost `
    -localAdminCredential $credential `
    -timeOutInSeconds $timeOutInSeconds `
    @commonParameterSwitches

$newWindowsResource = Join-Path $PSScriptRoot 'New-WindowsResource.ps1'
& $newWindowsResource `
    -session $connection.Session `
    -resourceName $resourceName `
    -resourceVersion $resourceVersion `
    -cookbookNames $cookbookNames `
    -installationDirectory $installationDirectory `
    -logDirectory $logDirectory `
    @commonParameterSwitches

New-HypervVhdxTemplateFromVm `
    -vmName $machineName `
    -vhdPath (Join-Path $vhdxStoragePath "$($machineName).vhdx") `
    -vhdxTemplatePath (Join-Path $vhdxTemplatePath $imageName) `
    -hypervHost $hypervHost `
    -localAdminCredential $credential `
    -timeOutInSeconds $timeOutInSeconds `
    -tempPath $tempPath `
    @commonParameterSwitches
