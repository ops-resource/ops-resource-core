<#
    .SYNOPSIS

    Creates a new 40Gb VHDX with an installation of Windows as given by the windows install ISO file.


    .DESCRIPTION

    The New-StandardVhdFromWindowsIso script takes all the actions to create a new VHDX virtual hard drive with a windows install.


    .PARAMETER osIsoFile

    The full path to the ISO file that contains the windows installation.


    .PARAMETER osEdition

    The SKU or edition of the operating system that should be taken from the ISO and applied to the disk.


    .PARAMTER unattendPath

    The full path to the unattended file that contains the parameters for an unattended setup.


    .PARAMETER machineName

    The name of the machine that will be created.


    .PARAMETER localAdminCredential

    The credential for the local administrator on the new machine.


    .PARAMETER vhdPath

    The full path to where the VHDX file should be output.


    .PARAMETER hypervHost

    The name of the Hyper-V host machine on which a temporary VM can be created.


    .PARAMETER wsusServer

    The name of the WSUS server that can be used to download updates from.


    .PARAMETER wsusTargetGroup

    The name of the WSUS computer target group that should be used to determine which updates should be installed.


    .PARAMETER scriptPath

    The full path to the directory that contains the Convert-WindowsImage and the Apply-WindowsUpdate scripts.


    .PARAMETER convertWindowsImageUrl

    The URL from where the Convert-WindowsImage script can be downloaded.


    .PARAMETER applyWindowsUpdateUrl

    The URL from where the Apply-WindowsUpdate script can be downloaded.


    .PARAMETER tempPath

    The full path to the directory in which temporary files can be stored.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $osIsoFile = $(throw 'Please specify the full path of the windows install ISO file.'),

    [Parameter(Mandatory = $false)]
    [string] $osEdition = '',

    [Parameter(Mandatory = $true)]
    [string] $unattendPath,

    [Parameter(Mandatory = $true)]
    [string] $machineName,

    [Parameter(Mandatory = $true)]
    [PSCredential] $localAdminCredential,

    [Parameter(Mandatory = $true)]
    [string] $vhdPath,

    [Parameter(Mandatory = $true)]
    [string] $hypervHost,

    [Parameter(Mandatory = $true)]
    [string] $staticMacAddress = '00155d026501',

    [Parameter(Mandatory = $true)]
    [string] $wsusServer,

    [Parameter(Mandatory = $true)]
    [string] $wsusTargetGroup,

    [Parameter(Mandatory = $false)]
    [string] $scriptPath = $PSScriptRoot,

    [Parameter(Mandatory = $false)]
    [string] $convertWindowsImageUrl = 'https://gallery.technet.microsoft.com/scriptcenter/Convert-WindowsImageps1-0fe23a8f/file/59237/7/Convert-WindowsImage.ps1',

    [Parameter(Mandatory = $false)]
    [string] $applyWindowsUpdateUrl = 'https://gallery.technet.microsoft.com/Offline-Servicing-of-VHDs-df776bda/file/104350/1/Apply-WindowsUpdate.ps1',

    [Parameter(Mandatory = $true)]
    [string] $tempPath = $(Join-Path $env:Temp ([System.Guid]::NewGuid.ToString()))
)

Write-Verbose "New-StandardVhdFromWindowsIso - osIsoFile = $osIsoFile"
Write-Verbose "New-StandardVhdFromWindowsIso - osEdition = $osEdition"
Write-Verbose "New-StandardVhdFromWindowsIso - unattendPath = $unattendPath"
Write-Verbose "New-StandardVhdFromWindowsIso - machineName = $machineName"
Write-Verbose "New-StandardVhdFromWindowsIso - vhdPath = $vhdPath"
Write-Verbose "New-StandardVhdFromWindowsIso - hypervHost = $hypervHost"
Write-Verbose "New-StandardVhdFromWindowsIso - wsusServer = $wsusServer"
Write-Verbose "New-StandardVhdFromWindowsIso - wsusTargetGroup = $wsusTargetGroup"
Write-Verbose "New-StandardVhdFromWindowsIso - scriptPath = $scriptPath"
Write-Verbose "New-StandardVhdFromWindowsIso - convertWindowsImageUrl = $convertWindowsImageUrl"
Write-Verbose "New-StandardVhdFromWindowsIso - applyWindowsUpdateUrl = $applyWindowsUpdateUrl"
Write-Verbose "New-StandardVhdFromWindowsIso - tempPath = $tempPath"

$ErrorActionPreference = 'Stop'

$commonParameterSwitches =
    @{
        Verbose = $PSBoundParameters.ContainsKey('Verbose');
        Debug = $false;
        ErrorAction = 'Stop'
    }

. (Join-Path $PSScriptRoot hyperv.ps1)
. (Join-Path $PSScriptRoot sessions.ps1)
. (Join-Path $PSScriptRoot WinRM.ps1)

if (-not (Test-Path $tempPath))
{
    New-Item -Path $tempPath -ItemType Directory | Out-Null
}

$convertWindowsImagePath = Join-Path $scriptPath 'Convert-WindowsImage.ps1'
if (-not (Test-Path $convertWindowsImagePath))
{
    Invoke-WebRequest `
        -Uri $convertWindowsImageUrl `
        -UseBasicParsing `
        -Method Get `
        -OutFile $convertWindowsImagePath `
        @commonParameterSwitches
}

$applyWindowsUpdatePath = Join-Path $scriptPath 'Apply-WindowsUpdate.ps1'
if (-not (Test-Path $applyWindowsUpdatePath))
{
    Invoke-WebRequest `
        -Uri $applyWindowsUpdateUrl `
        -UseBasicParsing `
        -Method Get `
        -OutFile $(Join-Path $scriptPath 'Apply-WindowsUpdate.ps1') `
        @commonParameterSwitches
}

. $convertWindowsImagePath
Convert-WindowsImage `
    -SourcePath $osIsoFile `
    -Edition $osEdition `
    -VHDPath $vhdPath `
    -SizeBytes 40GB `
    -VHDFormat 'VHDX' `
    -VHDType 'Dynamic' `
    -VHDPartitionStyle 'GPT' `
    -BCDinVHD 'VirtualMachine' `
    -UnattendPath $unattendPath `
    @commonParameterSwitches

# Grab all the update packages for the given OS
$mountPath = Join-Path $tempPath 'VhdMount'
if (-not (Test-Path $mountPath))
{
    New-Item -Path $mountPath -ItemType Directory | Out-Null
}

& $applyWindowsUpdatePath `
    -VhdPath $vhdPath `
    -MountDir $mountPath `
    -WsusServerName $wsusServer `
    -WsusServerPort 8530 `
    -WsusTargetGroupName $wsusTargetGroup `
    -WsusContentPath "\\$($wsusServer)\WsusContent" `
    @commonParameterSwitches

# Create a new Hyper-V virtual machine based on a VHDX Os disk
if ((Get-VM -ComputerName $hypervHost | Where-Object { $_.Name -eq $machineName}).Count -gt 0)
{
    Stop-VM $machineName -ComputerName $hypervHost -TurnOff -Confirm:$false -Passthru | Remove-VM -ComputerName $hypervHost -Force -Confirm:$false
}

$vmSwitch = Get-VMSwitch -ComputerName $hypervHost @commonParameterSwitches | Select-Object -First 1

New-HypervVm `
    -hypervHost $hypervHost `
    -vmName $machineName `
    -osVhdPath $vhdPath `
    -vmNetworkSwitch $vmSwitch.Name `
    @commonParameterSwitches

# Ensure that the VM has a specific Mac address so that it will get a known IP address
# That IP address will be added to the trustedhosts list so that we can remote into
# the machine without having it be attached to the domain.
Get-VM -Name $machineName |
    Get-VMNetworkAdapter |
    Set-VMNetworkAdapter -StaticMacAddress $staticMacAddress

$waitResult = Start-VMAndWaitForGuestOSToBeStarted `
    -vmName $machineName `
    -vmHost $hypervHost `
    @commonParameterSwitches

if (-not $waitResult)
{
    throw "Waiting for $machineName to start past the given timeout of $timeOutInSeconds"
}

# Get the IPv4 address for the VM
$ipAddress = Get-VM -Name $machineName -ComputerName $hypervHost |
    Select-Object -ExpandProperty NetworkAdapters |
    Select-Object -ExpandProperty IPAddresses |
    Select-Object -First 1

# The guest OS may be up and running, but that doesn't mean we can connect to the
# machine through powershell remoting, so ...
$timeOutInSeconds = 900
$waitResult = Wait-WinRM `
    -ipAddress $ipAddress `
    -credential $localAdminCredential `
    -timeOutInSeconds $timeOutInSeconds `
    @commonParameterSwitches

if (-not $waitResult)
{
    throw "Waiting for $machineName to be ready for remote connections has timed out with timeout of $timeOutInSeconds"
}

# Because the machine isn't on the domain we won't be able to remote into it easily
# Neither machine trusts the other one
# In this case we assume that the machine has been added to the trusted host list
#
# The WinRM service on the VM should be up. If it's not we're doomed anyway.
$vmSession = New-PSSession `
    -computerName $ipAddress `
    -credential $localAdminCredential `
    @commonParameterSwitches

# Reboot the machine so that all updates are properly installed
Invoke-Command `
    -Session $vmSession `
    -ScriptBlock { Restart-Computer -Force }

$timeOutInSeconds = 900
$waitResult = Wait-WinRM `
    -ipAddress $ipAddress `
    -credential $localAdminCredential `
    -timeOutInSeconds $timeOutInSeconds `
    @commonParameterSwitches

if (-not $waitResult)
{
    throw "Waiting for $machineName to be restarted has timed out with timeout of $timeOutInSeconds"
}

# The WinRM service on the VM should be up. If it's not we're doomed anyway.
$vmSession = New-PSSession `
    -computerName $ipAddress `
    -credential $localAdminCredential `
    @commonParameterSwitches

# sysprep
# Note that apparently this can't be done just remotely because sysprep starts but doesn't actually
# run (i.e. it exits without doing any work). So this needs to be done from the local machine
# that is about to be sysprepped.
$cmd = 'Write-Output "Executing $sysPrepScript on VM"; & c:\Windows\system32\sysprep\sysprep.exe /oobe /generalize /shutdown /unattend:"c:\unattend.xml"'
$sysprepCmd = Join-Path $tempPath 'sysprep.ps1'

$remoteDirectory = "c:\sysprep"
Set-Content -Value $cmd -Path $sysprepCmd
Copy-FilesToRemoteMachine -session $vmSession -remoteDirectory $remoteDirectory -localDirectory $tempDir

Write-Verbose "Starting sysprep ..."
Invoke-Command `
    -Session $vmSession `
    -ArgumentList @( (Join-Path $remoteDirectory (Split-Path -Leaf $sysprepCmd)) ) `
    -ScriptBlock {
        param(
            [string] $sysPrepScript = ''
        )

        # Clean up unattend file if it is there
        if (Test-Path "$ENV:SystemDrive\Unattend.xml")
        {
            Remove-Item -Force -Verbose "$ENV:SystemDrive\Unattend.xml"
        }

        # Clean up output file from the windows image convert script if it is there
        if (Test-Path "$ENV:SystemDrive\Convert-WindowsImageInfo.txt")
        {
            Remove-Item -Force -Verbose "$ENV:SystemDrive\Convert-WindowsImageInfo.txt"
        }

        # Remove Unattend entries from the autorun key if they exist
        foreach ($regvalue in (Get-Item -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run).Property)
        {
            if ($regvalue -like "Unattend*")
            {
                # could be multiple unattend* entries
                foreach ($unattendvalue in $regvalue)
                {
                    Remove-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run -name $unattendvalue  -Verbose
                }
            }
        }

        # logon script
        $logonScript = {
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
        }

        $logonScript | Out-String | Out-File -FilePath "$($driveLetter):\Logon.ps1"

        & "$sysPrepScript"
    } `
    -Verbose `
    -ErrorAction Continue

# Wait till machine is stopped
$waitResult = Wait-VmStopped `
    -vmName $machineName `
    -vmHost $hypervHost `
    -timeOutInSeconds $timeOutInSeconds `
    @commonParameterSwitches

if (-not $waitResult)
{
    throw "VM $machineName failed to shut down within $timeOutInSeconds seconds."
}

# Delete VM but keep VHDX
Remove-VM `
    -computerName $hypervHost `
    -Name $machineName `
    @commonParameterSwitches

# Optimize the VHDX
$driveLetter = (Mount-VHD -Path $vhdPath -ReadOnly -Passthru | Get-Disk | Get-Partition | Get-Volume).DriveLetter
try
{
    # Remove root level files we don't need anymore
    attrib -s -h "$($driveLetter):\pagefile.sys"
    Remove-Item -Path "$($driveLetter):\pagefile.sys" -Force -Verbose
    Remove-Item -Path "$($driveLetter):\unattend.xml" -Force -Verbose

    # Clean up all the user profiles except for the default one
    $userProfileDirectories = Get-ChildItem -Path "$($driveLetter):\Users\*" -Directory -Exclude 'Default', 'Public'
    foreach($userProfileDirectory in $userProfileDirectories)
    {
        Remove-Item -Path $userProfileDirectory.FullName -Recurse -Force @commonParameterSwitches
    }

    # Clean up the WinSXS store, and remove any superceded components. Updates will no longer be able to be uninstalled,
    # but saves a considerable amount of disk space.
    dism.exe /image:$($driveLetter):\ /Cleanup-Image /StartComponentCleanup /ResetBase

    Optimize-VHD -Path $vhdPath -Mode Full @commonParameterSwitches
}
finally
{
    Dismount-VHD -Path $vhdPath @commonParameterSwitches
}

# Mark drive as read-only?