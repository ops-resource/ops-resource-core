<#
    .SYNOPSIS

    Creates a new 40Gb VHDX with an installation of Windows as given by the windows install ISO file.


    .DESCRIPTION

    The New-StandardVhdFromWindowsIso script takes all the actions to create a new VHDX virtual hard drive with a windows install.


    .PARAMETER osIsoFile

    The full path to the ISO file that contains the windows installation.


    .PARAMETER osEdition

    The SKU or edition of the operating system that should be taken from the ISO and applied to the disk.


    .PARAMTER configPath

    The full path to the directory that contains the unattended file that contains the parameters for an unattended setup
    and any necessary script files which will be used during the configuration of the operating system.


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
    [string] $configPath,

    [Parameter(Mandatory = $true)]
    [string] $machineName,

    [Parameter(Mandatory = $true)]
    [PSCredential] $localAdminCredential,

    [Parameter(Mandatory = $true)]
    [string] $vhdPath,

    [Parameter(Mandatory = $true)]
    [string] $hypervHost,

    [Parameter(Mandatory = $false)]
    [string] $staticMacAddress = '00155d026501',

    [Parameter(Mandatory = $true)]
    [string] $wsusServer,

    [Parameter(Mandatory = $true)]
    [string] $wsusTargetGroup,

    [Parameter(Mandatory = $false)]
    [string] $scriptPath = $PSScriptRoot,

    [Parameter(Mandatory = $true)]
    [string] $tempPath = $(Join-Path $env:Temp ([System.Guid]::NewGuid.ToString()))
)

Write-Verbose "New-StandardVhdFromWindowsIso - osIsoFile = $osIsoFile"
Write-Verbose "New-StandardVhdFromWindowsIso - osEdition = $osEdition"
Write-Verbose "New-StandardVhdFromWindowsIso - configPath = $configPath"
Write-Verbose "New-StandardVhdFromWindowsIso - machineName = $machineName"
Write-Verbose "New-StandardVhdFromWindowsIso - vhdPath = $vhdPath"
Write-Verbose "New-StandardVhdFromWindowsIso - hypervHost = $hypervHost"
Write-Verbose "New-StandardVhdFromWindowsIso - wsusServer = $wsusServer"
Write-Verbose "New-StandardVhdFromWindowsIso - wsusTargetGroup = $wsusTargetGroup"
Write-Verbose "New-StandardVhdFromWindowsIso - scriptPath = $scriptPath"
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


# -------------------------- Script functions --------------------------------

function Get-ConnectionInformationForVm
{
    [CmdletBinding()]
    param(
        [string] $machineName,
        [string] $hypervHost,
        [pscredential] $localAdminCredential,
        [int] $timeOutInSeconds
    )

    Write-Verbose "Get-ConnectionInformationForVm - machineName = $machineName"
    Write-Verbose "Get-ConnectionInformationForVm - hypervHost = $hypervHost"
    Write-Verbose "Get-ConnectionInformationForVm - localAdminCredential = $localAdminCredential"
    Write-Verbose "Get-ConnectionInformationForVm - timeOutInSeconds = $timeOutInSeconds"

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

    # Just because we have a positive connection does not mean that connection will stay there
    # During initialization the machine will reboot a number of times so it is possible
    # that we get caught out due to one of these reboots. In that case we'll just try again.
    $maxRetry = 10
    $count = 0

    $result = New-Object psObject
    Add-Member -InputObject $result -MemberType NoteProperty -Name IPAddress -Value $null
    Add-Member -InputObject $result -MemberType NoteProperty -Name Session -Value $null

    [System.Management.Automation.Runspaces.PSSession]$vmSession = $null
    while (($vmSession -eq $null) -and ($count -lt $maxRetry))
    {
        $count = $count + 1

        try
        {
            $ipAddress = Wait-VmIPAddress `
                -vmName $machineName `
                -hypervHost $hypervHost `
                -timeOutInSeconds $timeOutInSeconds `
                @commonParameterSwitches
            if (($ipAddress -eq $null) -or ($ipAddress -eq ''))
            {
                throw "Failed to obtain an IP address for $machineName within the specified timeout of $timeOutInSeconds seconds."
            }

            # The guest OS may be up and running, but that doesn't mean we can connect to the
            # machine through powershell remoting, so ...
            $waitResult = Wait-WinRM `
                -ipAddress $ipAddress `
                -credential $localAdminCredential `
                -timeOutInSeconds $timeOutInSeconds `
                @commonParameterSwitches
            if (-not $waitResult)
            {
                throw "Waiting for $machineName to be ready for remote connections has timed out with timeout of $timeOutInSeconds"
            }

            Write-Verbose "Wait-WinRM completed successfully, making connection to machine $ipAddress ..."
            $vmSession = New-PSSession `
                -computerName $ipAddress `
                -credential $localAdminCredential `
                @commonParameterSwitches

            $result.IPAddress = $ipAddress
            $result.Session = $vmSession
        }
        catch
        {
            Write-Verbose "Failed to connect to the VM. Most likely due to a VM reboot. Trying another $($maxRetry - $count) times ..."
        }
    }

    return $result
}

function Invoke-Sysprep
{
    [CmdletBinding()]
    param(
        [string] $machineName,
        [string] $hypervHost,
        [pscredential] $localAdminCredential,
        [int] $timeOutInSeconds,
        [string] $tempPath
    )

    Write-Verbose "Invoke-Sysprep - machineName = $machineName"
    Write-Verbose "Invoke-Sysprep - hypervHost = $hypervHost"
    Write-Verbose "Invoke-Sysprep - localAdminCredential = $localAdminCredential"
    Write-Verbose "Invoke-Sysprep - timeOutInSeconds = $timeOutInSeconds"
    Write-Verbose "Invoke-Sysprep - tempPath = $tempPath"

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

    $result = Get-ConnectionInformationForVm `
        -machineName $machineName `
        -hypervHost $hypervHost `
        -localAdminCredential $localAdminCredential `
        -timeOutInSeconds $timeOutInSeconds `
        @commonParameterSwitches
    if ($result.Session -eq $null)
    {
        throw "Failed to connect to $machineName"
    }

    Wait-MachineCompletesInitialization -session $result.Session @commonParameterSwitches

    # sysprep
    $remoteDirectory = "c:\sysprep"
    Copy-FilesToRemoteMachine -session $result.Session -remoteDirectory $remoteDirectory -localDirectory $tempPath

    Write-Verbose "Starting sysprep ..."
    Invoke-Command `
        -Session $result.Session `
        -ArgumentList @( $remoteDirectory ) `
        -ScriptBlock {
            param(
                [string] $configDir = ''
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

            # Clean up output file from the windows image convert script if it is there
            if (Test-Path "$ENV:SystemDrive\UnattendResources")
            {
                Remove-Item -Force -Verbose -Recurse "$ENV:SystemDrive\UnattendResources"
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
                if (Test-Path "$ENV:SystemDrive\Temp")
                {
                    Remove-Item -Force -Recurse "$ENV:SystemDrive\Temp";
                }

                if (Test-Path "$ENV:SystemDrive\Sysprep")
                {
                    Remove-Item -Force -Recurse "$ENV:SystemDrive\Sysprep";
                }
            }

            $logonScript | Out-String | Out-File -FilePath "$ENV:SystemDrive\Logon.ps1"

            # sysprep
            # Note that apparently this can't be done just remotely because sysprep starts but doesn't actually
            # run (i.e. it exits without doing any work). So this needs to be done from the local machine
            # that is about to be sysprepped.
            $cmd = "Write-Output 'Executing $sysPrepScript on VM'; & c:\Windows\system32\sysprep\sysprep.exe /oobe /generalize /shutdown /unattend:`"$configDir\unattend.xml`""
            $sysprepCmd = Join-Path $configDir 'sysprep.ps1'

            Set-Content -Value $cmd -Path $sysprepCmd

            & powershell -File "$sysprepCmd"
        } `
        -Verbose `
        -ErrorAction Continue

    # Wait till machine is stopped
    $waitResult = Wait-VmStopped `
        -vmName $machineName `
        -hypervHost $hypervHost `
        -timeOutInSeconds $timeOutInSeconds `
        @commonParameterSwitches

    if (-not $waitResult)
    {
        throw "VM $machineName failed to shut down within $timeOutInSeconds seconds."
    }
}

function New-VhdFromIso
{
    [CmdletBinding()]
    param(
        [string] $osIsoFile,
        [string] $osEdition,
        [string] $vhdPath,
        [string] $configPath,
        [string] $scriptPath
    )

    Write-Verbose "New-VhdFromIso - osIsoFile = $osIsoFile"
    Write-Verbose "New-VhdFromIso - osEdition = $osEdition"
    Write-Verbose "New-VhdFromIso - vhdPath = $vhdPath"
    Write-Verbose "New-VhdFromIso - configPath = $configPath"
    Write-Verbose "New-VhdFromIso - scriptPath = $scriptPath"

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

    $convertWindowsImageUrl = 'https://gallery.technet.microsoft.com/scriptcenter/Convert-WindowsImageps1-0fe23a8f/file/59237/7/Convert-WindowsImage.ps1'
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

    $unattendPath = Join-Path $configPath 'unattend.xml'

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

    # Copy the additional script files to the drive
    $driveLetter = Mount-Vhdx -vhdPath $vhdPath @commonParameterSwitches
    try
    {
        # Copy the remaining configuration scripts
        $unattendScriptsDirectory = "$($driveLetter):\UnattendResources"
        if (-not (Test-Path $unattendScriptsDirectory))
        {
            New-Item -Path $unattendScriptsDirectory -ItemType Directory | Out-Null
        }

        Copy-Item -Path "$configPath\*" -Destination $unattendScriptsDirectory @commonParameterSwitches
    }
    finally
    {
        Dismount-Vhdx -vhdPath $vhdPath @commonParameterSwitches
    }
}

function New-VmFromVhdAndWaitForBoot
{
    [CmdletBinding()]
    param(
        [string] $vhdPath,
        [string] $machineName,
        [string] $hypervHost,
        [string] $staticMacAddress,
        [string] $bootWaitTimeout
    )

    Write-Verbose "New-VmFromVhd - vhdPath = $vhdPath"
    Write-Verbose "New-VmFromVhd - machineName = $machineName"
    Write-Verbose "New-VmFromVhd - hypervHost = $hypervHost"
    Write-Verbose "New-VmFromVhd - staticMacAddress = $staticMacAddress"
    Write-Verbose "New-VmFromVhd - bootWaitTimeout = $bootWaitTimeout"

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

    # Create a new Hyper-V virtual machine based on a VHDX Os disk
    if ((Get-VM -ComputerName $hypervHost | Where-Object { $_.Name -eq $machineName}).Count -gt 0)
    {
        Stop-VM $machineName -ComputerName $hypervHost -TurnOff -Confirm:$false -Passthru | Remove-VM -ComputerName $hypervHost -Force -Confirm:$false
    }

    $vmSwitch = Get-VMSwitch -ComputerName $hypervHost @commonParameterSwitches | Select-Object -First 1

    $vm = New-HypervVm `
        -hypervHost $hypervHost `
        -vmName $machineName `
        -osVhdPath $vhdPath `
        -vmNetworkSwitch $vmSwitch.Name `
        @commonParameterSwitches

    # Ensure that the VM has a specific Mac address so that it will get a known IP address
    # That IP address will be added to the trustedhosts list so that we can remote into
    # the machine without having it be attached to the domain.
    $vm | Get-VMNetworkAdapter | Set-VMNetworkAdapter -StaticMacAddress $staticMacAddress @commonParameterSwitches

    Start-VM -Name $machineName -ComputerName $hypervHost @commonParameterSwitches
    $waitResult = Wait-VmGuestOS `
        -vmName $machineName `
        -hypervHost $hypervHost `
        -timeOutInSeconds $bootWaitTimeout `
        @commonParameterSwitches

    if (-not $waitResult)
    {
        throw "Waiting for $machineName to start past the given timeout of $bootWaitTimeout"
    }
}

function Restart-MachineToApplyPatches
{
    [CmdletBinding()]
    param(
        [string] $machineName,
        [string] $hypervHost,
        [pscredential] $localAdminCredential,
        [int] $timeOutInSeconds
    )

    Write-Verbose "Restart-MachineToApplyPatches - machineName = $machineName"
    Write-Verbose "Restart-MachineToApplyPatches - hypervHost = $hypervHost"
    Write-Verbose "Restart-MachineToApplyPatches - localAdminCredential = $localAdminCredential"
    Write-Verbose "Restart-MachineToApplyPatches - timeOutInSeconds = $timeOutInSeconds"

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

    $result = Get-ConnectionInformationForVm `
        -machineName $machineName `
        -hypervHost $hypervHost `
        -localAdminCredential $localAdminCredential `
        -timeOutInSeconds $timeOutInSeconds `
        @commonParameterSwitches
    if ($result.Session -eq $null)
    {
        throw "Failed to connect to $machineName"
    }

    Wait-MachineCompletesInitialization -session $result.Session @commonParameterSwitches

    # Now that we know we can get into the machine we can invoke commands on the machine, so now
    # we reboot the machine so that all updates are properly installed
    Restart-Computer `
        -ComputerName $result.IPAddress `
        -Credential $localAdminCredential `
        -Force `
        -Wait `
        -For PowerShell `
        -Delay 5 `
        -Timeout $timeOutInSeconds `
        @commonParameterSwitches
}

function Update-VhdWithWindowsPatches
{
    [CmdletBinding()]
    param(
        [string] $vhdPath,
        [string] $wsusServer,
        [string] $wsusTargetGroup,
        [string] $scriptPath,
        [string] $tempPath
    )

    Write-Verbose "Update-VhdWithWindowsPatches - vhdPath = $vhdPath"
    Write-Verbose "Update-VhdWithWindowsPatches - wsusServer = $wsusServer"
    Write-Verbose "Update-VhdWithWindowsPatches - wsusTargetGroup = $wsusTargetGroup"
    Write-Verbose "Update-VhdWithWindowsPatches - scriptPath = $scriptPath"
    Write-Verbose "Update-VhdWithWindowsPatches - tempPath = $tempPath"

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

    $applyWindowsUpdateUrl = 'https://gallery.technet.microsoft.com/Offline-Servicing-of-VHDs-df776bda/file/104350/1/Apply-WindowsUpdate.ps1'
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
}

function Wait-MachineCompletesInitialization
{
    [CmdletBinding()]
    param(
        [System.Management.Automation.Runspaces.PSSession] $session
    )

    Write-Verbose "Wait-MachineCompletesInitialization - session = $session"

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

    Write-Verbose "Waiting for machine to complete initialization ..."

    Invoke-Command `
        -Session $session `
        -ScriptBlock {
            function Get-IsMachineInitializing
            {
                # Based on the answers from here:
                # http://serverfault.com/questions/750885/how-to-remotely-detect-windows-has-completed-patch-configuration-after-reboot
                # We should look for TrustedInstaller and Wuauclt. However it seems that even these disappear before
                # the initialization is complete. So we added some others based on getting the process list while
                # the machine was initializing
                return (Get-Process 'cmd', 'ngen', 'TrustedInstaller', 'windeploy', 'Wuauclt' -ErrorAction SilentlyContinue).Length -ne 0
            }

            while (Get-IsMachineInitializing)
            {
                while (Get-IsMachineInitializing)
                {
                    Start-Sleep -Seconds 10 -Verbose
                }

                # Now wait another 30 seconds to see that nothing else pops back up
                Write-Verbose "Expecting machine configuration to be complete. Waiting 30 seconds for safety ..."
                Start-Sleep -Seconds 30 -Verbose
            }

            Write-Verbose "Installers completed configuration ..."
        } `
        @commonParameterSwitches
}

# -------------------------- Script start --------------------------------

if (-not (Test-Path $tempPath))
{
    New-Item -Path $tempPath -ItemType Directory | Out-Null
}

New-VhdFromIso `
    -osIsoFile $osIsoFile `
    -osEdition $osEdition `
    -vhdPath $vhdPath `
    -configPath $configPath `
    -scriptPath $scriptPath `
    @commonParameterSwitches

Update-VhdWithWindowsPatches `
    -vhdPath $vhdPath `
    -wsusServer $wsusServer `
    -wsusTargetGroup $wsusTargetGroup `
    -scriptPath $scriptPath `
    -tempPath $tempPath `
    @commonParameterSwitches

$timeOutInSeconds = 900
New-VmFromVhdAndWaitForBoot `
    -vhdPath $vhdPath `
    -machineName $machineName `
    -hypervHost $hypervHost `
    -staticMacAddress $staticMacAddress `
    -bootWaitTimeout $timeOutInSeconds `
    @commonParameterSwitches

Restart-MachineToApplyPatches `
    -machineName $machineName `
    -hypervHost $hypervHost `
    -localAdminCredential $localAdminCredential `
    -timeOutInSeconds $timeOutInSeconds `
    @commonParameterSwitches

    # Apply missing updates

Invoke-Sysprep `
    -machineName $machineName `
    -hypervHost $hypervHost `
    -localAdminCredential $localAdminCredential `
    -timeOutInSeconds $timeOutInSeconds `
    -tempPath $tempPath `
    @commonParameterSwitches

# Delete VM
Remove-VM `
    -computerName $hypervHost `
    -Name $machineName `
    -Force `
    @commonParameterSwitches

# Optimize the VHDX
#
# Mounting the drive using Mount-DiskImage instead of Mount-Vhd because for the latter we need Hyper-V to be installed
# which we can't do on a VM
$driveLetter = Mount-Vhdx -vhdPath $vhdPath @commonParameterSwitches
try
{
    # Remove root level files we don't need anymore
    attrib -s -h "$($driveLetter):\pagefile.sys"
    Remove-Item -Path "$($driveLetter):\pagefile.sys" -Force -Verbose

    # Clean up all the user profiles except for the default one
    $userProfileDirectories = Get-ChildItem -Path "$($driveLetter):\Users\*" -Directory -Exclude 'Default', 'Public'
    foreach($userProfileDirectory in $userProfileDirectories)
    {
        Remove-Item -Path $userProfileDirectory.FullName -Recurse -Force @commonParameterSwitches
    }

    # Clean up the WinSXS store, and remove any superceded components. Updates will no longer be able to be uninstalled,
    # but saves a considerable amount of disk space.
    dism.exe /image:$($driveLetter):\ /Cleanup-Image /StartComponentCleanup /ResetBase
}
finally
{
    Dismount-Vhdx -vhdPath $vhdPath @commonParameterSwitches
}

# Mark drive as read-only?