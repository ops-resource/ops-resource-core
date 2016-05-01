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
    [string] $osName                                            = '',

    [Parameter(Mandatory = $true)]
    [string] $machineName                                       = '',

    [Parameter(Mandatory = $true)]
    [string] $hypervHost                                        = '',

    [Parameter(Mandatory = $true)]
    [string] $unattendedJoinFile                                = ''
)

Write-Verbose "New-HyperVResource - credential = $credential"
Write-Verbose "New-HyperVResource - authenticateWithCredSSP = $authenticateWithCredSSP"
Write-Verbose "New-HyperVResource - resourceName = $resourceName"
Write-Verbose "New-HyperVResource - resourceVersion = $resourceVersion"
Write-Verbose "New-HyperVResource - osName = $osName"
Write-Verbose "New-HyperVResource - hypervHost = $hypervHost"

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

$hypervHostVmStoragePath = "\\$(hypervHost)\vms\machines"
$unattendedJoin = Get-Content -Path $unattendedJoinFile -Encoding Ascii @commonParameterSwitches

$vhdxStoragePath = "$($hypervHostVmStoragePath)\hdd"
$baseVhdx = Get-ChildItem -Path $vhdxTemplatePath -File -Filter "$($osName)*.vhdx" | Sort-Object LastWriteTime | Select-Object -First 1
$registeredOwner = Get-RegisteredOwner @commonParameterSwitches

New-HypervVmOnDomain `
    -machineName $machineName `
    -baseVhdx $baseVhdx `
    -vhdxStoragePath $vhdxStoragePath `
    -hypervHost $hypervHost `
    -registeredOwner $registeredOwner `
    -domainName $env:USERDNSDOMAIN `
    -unattendedJoin $unattendedJoin `
    @commonParameterSwitches

Start-VM -Name $machineName -ComputerName $hypervHost @commonParameterSwitches
$connection = Get-ConnectionInformationForVm `
    -machineName $machineName `
    -hypervHost $hypervHost `
    -localAdminCredential $credential `
    -timeOutInSeconds 900 `
    @commonParameterSwitches

# verify
