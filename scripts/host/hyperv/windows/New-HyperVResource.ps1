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

    [Parameter(Mandatory = $true)]
    [string] $hypervHost                                        = $(throw 'Please specify the name of the Hyper-V host on which a new virtual machine should be configured.'),

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

if (-not (Test-Path $installationDirectory))
{
    throw "Unable to find the directory containing the installation files. Expected it at: $installationDirectory"
}

if (-not (Test-Path $logDirectory))
{
    New-Item -Path $logDirectory -ItemType Directory | Out-Null
}

# Create a copy of the VHDX file and then mount it
$vhdxStoragePath = 'UNDEFINED_VHDX_STORAGE_PATH'
$vhdxPath = Join-Path $vhdxStoragePath "$($machineName.ToLower()).vhdx"
Copy-Item -Path 'ORIGINAL_VHDX_PATH' -Destination $vhdxPath -Verbose
$driveLetter = (Mount-VHD -Path $vhdxPath -ReadOnly -Passthru | Get-Disk | Get-Partition | Get-Volume).DriveLetter

# Create the unattend.xml file to join the domain
$unattendContent = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <!--
        This file describes the different configuration phases for a windows machine.

        For more information about the different stages see: https://technet.microsoft.com/en-us/library/hh824982.aspx
    -->

    <!--
         This configuration pass is used to create and configure information in the Windows image, and is specific to the hardware that the
         Windows image is installing to.

        After the Windows image boots for the first time, the specialize configuration pass runs. During this pass, unique security IDs (SIDs)
        are created. Additionally, you can configure many Windows features, including network settings, international settings, and domain information.
        The answer file settings for the specialize pass appear in audit mode. When a computer boots to audit mode, the auditSystem pass runs, and
        the computer processes the auditUser settings.
    -->
    <settings pass="specialize">

        <component name="Microsoft-Windows-Shell-Setup"
                   processorArchitecture="amd64"
                   publicKeyToken="31bf3856ad364e35"
                   language="neutral"
                   versionScope="nonSxS"
                   xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
                   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RegisteredOwner>$registeredOwner</RegisteredOwner>
            <ComputerName>$machineName</ComputerName>

            <!--
                Set the generic product key for the Win2012 datacenter SKU. This key is only
                so that we can get a completely unattended setup. It is not the activation key!
                Also note that this only works for a Win2012 datacenter SKU and it was found
                here:
                https://technet.microsoft.com/en-us/library/jj612867.aspx
            -->
            <ProductKey>W3GGN-FT8W3-Y4M27-J84CP-Q3VJ9</ProductKey>
        </component>

        <!--
            Join the domain
        -->
        <component name="Microsoft-Windows-UnattendedJoin"
                   processorArchitecture="amd64"
                   publicKeyToken="31bf3856ad364e35"
                   language="neutral"
                   versionScope="nonSxS"
                   xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
                   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <Identification>
                <MachineObjectOU>$machineOU</MachineObjectOU>
                <Credentials>
                    <Domain>$domainName</Domain>
                    <Password>$domainAdminPassword</Password>
                    <Username>$domainAdminUserName</Username>
                </Credentials>
                <JoinDomain>$domainName</JoinDomain>
            </Identification>
        </component>
    </settings>


    <!--
        During this configuration pass, settings are applied to Windows before Windows Welcome starts.
        This pass is typically used to configure Windows Shell options, create user accounts, and specify language and
        locale settings. The answer file settings for the oobeSystem pass appear in Windows Welcome, also known as OOBE.
    -->
    <settings pass="oobeSystem">
        <!--
            Set the local Administrator account password and
            add domain users to the administrators group
        -->
        <component name="Microsoft-Windows-Shell-Setup"
                   processorArchitecture="amd64"
                   publicKeyToken="31bf3856ad364e35"
                   language="neutral"
                   versionScope="nonSxS"
                   xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
                   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <UserAccounts>
                <DomainAccounts>
                    <DomainAccountList wcm:action="add">
                        <Domain>$domainName</Domain>
                        <DomainAccount wcm:action="add">
                            <Group>Administrators</Group>
                            <Name>$domainAdminUserName</Name>
                        </DomainAccount>
                    </DomainAccountList>
                </DomainAccounts>
            </UserAccounts>
            <LogonCommands>
                 <AsynchronousCommand wcm:action="add">
                     <CommandLine>%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell -NoLogo -NonInteractive -ExecutionPolicy Unrestricted -File %SystemDrive%\Logon.ps1</CommandLine>
                     <Order>1</Order>
                 </AsynchronousCommand>
             </LogonCommands>
        </component>
    </settings>
</unattend>
"@
Set-Content -Path "$($driveLetter):\unattend.xml" -Value $unattendContent

# Create a process file that will remove the unattend file once the machine is booting
$logonContent = @'
# Remove Unattend entries from the autorun key if they exist
foreach ($regvalue in (Get-Item -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run).Property)
{
    if ($regvalue -like "Unattend*")
    {
        # could be multiple unattend* entries
        foreach ($unattendvalue in $regvalue)
        {
            Remove-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run -name $unattendvalue -Verbose
        }
    }
}

# Clean up unattend file if it is there
if (Test-Path "$ENV:SystemDrive\Unattend.xml")
{
    Remove-Item -Force "$ENV:SystemDrive\Unattend.xml";
}

# Clean up logon file if it is there
if (Test-Path "$ENV:SystemDrive\Logon.ps1")
{
    Remove-Item -Force "$ENV:SystemDrive\Logon.ps1";
}

# Clean up temp
if(Test-Path "$ENV:SystemDrive\Temp")
{
    Remove-Item -Force -Recurse "$ENV:SystemDrive\Temp";
}
'@

Set-Content -Path "$($driveLetter):\logon.ps1" -Value $logonContent

# Create a new Hyper-V virtual machine based on a VHDX Os disk
New-HypervVm `
    -hypervHost $hypervHost `
    -vmName $vmName `
    -osVhdPath $vhdxPath `
    -vmAdditionalDiskSizesInGb $additionalDrives `
    -vmNetworkSwitch $vmNetwork `
    -vmStoragePath '' `
    -vhdStoragePath '' `
    @commonParameterSwitches

Start-VMAndWaitForGuestOSToBeStarted `
    -vmName $vmName `
    -vmHost $hypervHost `
    @commonParameterSwitches

# The guest OS may be up and running, but that doesn't mean we can connect to the
# machine through powershell remoting, so ...
Wait-WinRM `
    -computerName $vmName `
    @commonParameterSwitches

$vmSession = New-Session -computerName $hypervClient -credential $credential -authenticateWithCredSSP:$authenticateWithCredSSP @commonParameterSwitches

$newWindowsResource = Join-Path $PSScriptRoot 'New-WindowsResource.ps1'
switch ($psCmdlet.ParameterSetName)
{
    'FromUserSpecification' {
        & $newWindowsResource `
            -session $vmSession `
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
            -session $vmSession `
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
