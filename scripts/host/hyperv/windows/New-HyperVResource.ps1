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


    .PARAMETER resourceName

    The name of the resource that is being created.


    .PARAMETER resourceVersion

    The version of the resource that is being created.


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


    .PARAMETER unattendedJoinFile

    The full path to the file that contains the XML fragment for an unattended domain join. This is expected to look like:

    <component name="Microsoft-Windows-UnattendedJoin"
               processorArchitecture="amd64"
               publicKeyToken="31bf3856ad364e35"
               language="neutral"
               versionScope="nonSxS"
               xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <Identification>
            <MachineObjectOU>MACHINE_ORGANISATIONAL_UNIT_HERE</MachineObjectOU>
            <Credentials>
                <Domain>DOMAIN_NAME_HERE</Domain>
                <Password>ENCRYPTED_DOMAIN_ADMIN_PASSWORD</Password>
                <Username>DOMAIN_ADMIN_USERNAME</Username>
            </Credentials>
            <JoinDomain>DOMAIN_NAME_HERE</JoinDomain>
        </Identification>
    </component>


    .PARAMETER staticMacAddress

    An optional static MAC address that is applied to the VM so that it can be given a consistent IP address.


    .PARAMETER provisioningBootstrapUrl

    The URL that points to the consul base section in the consul key-value store where the provisioning information
    for the current resource is stored.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [PSCredential] $credential                                  = $null,

    [Parameter(Mandatory = $false)]
    [switch] $authenticateWithCredSSP,

    [Parameter(Mandatory = $false)]
    [string] $imageName                                         = $(throw 'An image name must be specified.'),

    [Parameter(Mandatory = $true)]
    [string] $machineName                                       = '',

    [Parameter(Mandatory = $true)]
    [string] $hypervHost                                        = '',

    [Parameter(Mandatory = $true)]
    [string] $vhdxTemplatePath                                  = "\\$($hypervHost)\vmtemplates",

    [Parameter(Mandatory = $true)]
    [string] $hypervHostVmStoragePath                           = "\\$($hypervHost)\vms\machines",

    [Parameter(Mandatory = $true)]
    [string] $unattendedJoinFile                                = '',

    [Parameter(Mandatory = $false)]
    [string] $staticMacAddress                                  = '',

    [Parameter(Mandatory = $false)]
    [string] $provisioningBootstrapUrl                          = ''
)

Write-Verbose "New-HyperVResource - credential = $credential"
Write-Verbose "New-HyperVResource - authenticateWithCredSSP = $authenticateWithCredSSP"
Write-Verbose "New-HyperVResource - imageName = $imageName"
Write-Verbose "New-HyperVResource - hypervHost = $hypervHost"
Write-Verbose "New-HyperVResource - vhdxTemplatePath = $vhdxTemplatePath"
Write-Verbose "New-HyperVResource - hypervHostVmStoragePath = $hypervHostVmStoragePath"
Write-Verbose "New-HyperVResource - staticMacAddress = $staticMacAddress"
Write-Verbose "New-HyperVResource - provisioningBootstrapUrl = $provisioningBootstrapUrl"

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
. (Join-Path $PSScriptRoot WinRM.ps1)


# -------------------- Functions ------------------------

function New-VmResource
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $machineName,

        [Parameter(Mandatory = $true)]
        [string] $baseVhdx,

        [Parameter(Mandatory = $true)]
        [string] $hypervHost,

        [Parameter(Mandatory = $true)]
        [string] $vhdxStoragePath,

        [Parameter(Mandatory = $true)]
        [string] $unattendedJoinFile,

        [Parameter(Mandatory = $false)]
        [string] $staticMacAddress
    )

    Write-Verbose "New-VmResource - machineName = $machineName"
    Write-Verbose "New-VmResource - baseVhdx = $baseVhdx"
    Write-Verbose "New-VmResource - hypervHost = $hypervHost"
    Write-Verbose "New-VmResource - vhdxStoragePath = $vhdxStoragePath"
    Write-Verbose "New-VmResource - unattendedJoinFile = $unattendedJoinFile"
    Write-Verbose "New-VmResource - staticMacAddress = $staticMacAddress"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

    $registeredOwner = Get-RegisteredOwner @commonParameterSwitches
    $unattendedJoin = Get-Content -Path $unattendedJoinFile -Encoding Ascii @commonParameterSwitches

    if (Test-Path $unattendedJoinFile)
    {
        $vm = New-HypervVmOnDomain `
            -vmName $machineName `
            -baseVhdx $baseVhdx `
            -hypervHost $hypervHost `
            -vhdxStoragePath $vhdxStoragePath `
            -registeredOwner $registeredOwner `
            -domainName $env:USERDNSDOMAIN `
            -unattendedJoin $unattendedJoin `
            @commonParameterSwitches
    }
    else
    {
        $vm = New-HypervVmFromBaseImage `
            -vmName $machineName `
            -baseVhdx $baseVhdx `
            -hypervHost $hypervHost `
            -vhdxStoragePath $vhdxStoragePath `
            @commonParameterSwitches
    }

    if ($staticMacAddress -ne '')
    {
        $vm | Get-VMNetworkAdapter | Set-VMNetworkAdapter -StaticMacAddress $staticMacAddress @commonParameterSwitches
    }

    return $vm
}

function Set-ProvisioningInformation
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [psobject] $vm,

        [Parameter(Mandatory = $true)]
        [string] $hypervHost,

        [Parameter(Mandatory = $true)]
        [string] $vhdxStoragePath,

        [Parameter(Mandatory = $false)]
        [string] $provisioningBootstrapUrl
    )

    Write-Verbose "Set-ProvisioningInformation - vm = $vm"
    Write-Verbose "Set-ProvisioningInformation - hypervHost = $hypervHost"
    Write-Verbose "Set-ProvisioningInformation - vhdxStoragePath = $vhdxStoragePath"
    Write-Verbose "Set-ProvisioningInformation - provisioningBootstrapUrl = $provisioningBootstrapUrl"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

    $vhdx = $vm |
        Select-Object vmid @commonParameterSwitches |
        Get-VHD -Computer $hypervHost @commonParameterSwitches
    $vhdxLocalPath = $vhdx.Path
    $vhdxUncPath = Join-Path $vhdxStoragePath $(Split-Path $vhdxLocalPath -Leaf)

    $driveLetter = Mount-Vhdx -vhdPath $vhdxUncPath @commonParameterSwitches
    try
    {
        # Copy the remaining configuration scripts
        $provisioningDirectory = "$($driveLetter):\provisioning"
        if (-not (Test-Path $provisioningDirectory))
        {
            New-Item -Path $provisioningDirectory -ItemType Directory | Out-Null
        }

        $json = New-Object psobject -Property @{
            'entrypoint' = $provisioningBootstrapUrl
        }

        ConvertTo-Json -InputObject $json @commonParameterSwitches | Out-File -FilePath (Join-Path $provisioningDirectory 'provisioning.json')
    }
    finally
    {
        Dismount-Vhdx -vhdPath $vhdxUncPath @commonParameterSwitches
    }
}

# -------------------- Script ---------------------------

$hypervHostVmStoragePath = "\\$(hypervHost)\vms\machines"

$vhdxStoragePath = "$($hypervHostVmStoragePath)\hdd"
$baseVhdx = Get-ChildItem -Path $vhdxTemplatePath -File -Filter "$($imageName).vhdx" | Select-Object -First 1

$vm = New-VmResource `
    -machineName $machineName `
    -baseVhdx $baseVhdx `
    -hypervHost $hypervHost `
    -vhdxStoragePath $vhdxStoragePath `
    -unattendedJoinFile $unattendedJoinFile `
    -staticMacAddress $staticMacAddress `
    @commonParameterSwitches

Set-ProvisioningInformation `
    -vm $vm `
    -hypervHost $hypervHost `
    -vhdxStoragePath $vhdxStoragePath `
    -provisioningBootstrapUrl $provisioningBootstrapUrl `
    @commonParameterSwitches

Start-VM -Name $machineName -ComputerName $hypervHost @commonParameterSwitches
$connection = Get-ConnectionInformationForVm `
    -machineName $machineName `
    -hypervHost $hypervHost `
    -localAdminCredential $credential `
    -timeOutInSeconds 900 `
    @commonParameterSwitches

return $connection
