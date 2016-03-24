<#
    .SYNOPSIS

    Dismounts the VHDX drive from the operating system.


    .DESCRIPTION

    The Dismount-Vhdx function dismounts the VHDX drive from the operating system.


    .PARAMETER vhdPath

    The full path to the VHDX file that has been mounted.
#>
function Dismount-Vhdx
{
    [CmdletBinding()]
    param(
        [string] $vhdPath
    )

    Write-Verbose "Dismount-Vhdx - vhdPath = $vhdPath"

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

    Dismount-DiskImage -ImagePath $vhdPath @commonParameterSwitches
}

<#
    .SYNOPSIS

    Gets the connection information used to connect to a given Hyper-V VM.


    .DESCRIPTION

    The Get-ConnectionInformationForVm function gets the connection information used to connect to a given Hyper-V VM.


    .PARAMETER machineName

    The name of the VM.


    .PARAMETER hypervHost

    The name of the Hyper-V host machine.


    .PARAMETER localAdminCredential

    The credentials for the local administrator account.


    .PARAMETER timeOutInSeconds

    The amount of time that the function will wait for at the individual stages for a connection.


    .OUTPUTS

    A custom object containing the connection information for the VM. Available properties are:

        IPAddress        The IP address of the VM
        Session          A powershell remoting session
#>
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

<#
    .SYNOPSIS

    Gets the drive letter for the drive with the given drive number


    .DESCRIPTION

    The Get-DriveLetter function returns the drive letter for the drive with the given drive number


    .PARAMETER driveNumber

    The number of the drive.


    .OUTPUT

    The letter of the drive.
#>
function Get-DriveLetter
{
    [CmdletBinding()]
    [OutputType([char])]
    param(
        [int] $driveNumber
    )

    # The first drive is C which is ASCII 67
    return [char]($driveNumber + 67)
}

<#
    .SYNOPSIS

    Gets the IP address for a given hyper-V VM.


    .DESCRIPTION

    The Get-IPAddressForVm function gets the IP address for a given VM.


    .PARAMETER vmName

    The name of the VM.


    .PARAMETER hypervHost

    The name of the machine which is the Hyper-V host for the domain.


    .OUTPUT

    The letter of the drive.
#>
function Get-IPAddressForVm
{
    [CmdletBinding()]
    param(
        [string] $vmName,
        [string] $hypervHost
    )

    Write-Verbose "Get-IPAddressForVm - vmName = $vmName"
    Write-Verbose "Get-IPAddressForVm - hypervHost = $hypervHost"

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

    # Get the IPv4 address for the VM
    $ipAddress = Get-VM -Name $vmName -ComputerName $hypervHost |
        Select-Object -ExpandProperty NetworkAdapters |
        Select-Object -ExpandProperty IPAddresses |
        Select-Object -First 1

    return $ipAddress
}

<#
    .SYNOPSIS

    Mounts the VHDX drive in the operating system and returns the drive letter for the new drive.


    .DESCRIPTION

    The Mount-Vhdx function mounts the VHDX drive in the operating system and returns the
    drive letter for the new drive.


    .PARAMETER vhdPath

    The full path to the VHDX file that has been mounted.


    .OUTPUTS

    The drive letter for the newly mounted drive.
#>
function Mount-Vhdx
{
    [CmdletBinding()]
    param(
        [string] $vhdPath
    )

    Write-Verbose "Mount-Vhdx - vhdPath = $vhdPath"

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

    # store all the known drive letters because we can't directly get the drive letter
    # from the mounting operation so we have to compare the before and after pictures.
    $before = (Get-Volume).DriveLetter

    # Mounting the drive using Mount-DiskImage instead of Mount-Vhd because for the latter we need Hyper-V to be installed
    # which we can't do on a VM
    Mount-DiskImage -ImagePath $vhdPath -StorageType VHDX | Out-Null

    # Get all the current drive letters. The only new one should be the drive we just mounted
    $after = (Get-Volume).DriveLetter
    $driveLetter = compare $before $after -Passthru

    return $driveLetter
}

<#
    .SYNOPSIS

    Creates a new Hyper-V virtual machine with the given properties.


    .DESCRIPTION

    The New-HypervVm function creates a new Hyper-V virtual machine with the provided properties.


    .PARAMETER vmName

    The name of the VM.


    .PARAMETER osVhdPath

    The full path of the VHD that contains the pre-installed OS.


    .PARAMETER vmAdditionalDiskSizesInGb

    An array containing the sizes, in Gb, of any additional VHDs that should be attached to the virtual machine.


    .PARAMETER vmNetworkSwitch

    The name of the virtual network switch that the virtual machine should be connected to.


    .PARAMETER vmStoragePath

    The full path of the directory where the virtual machine files should be stored.


    .PARAMETER vhdStoragePath

    The full path of the directory where the virtual hard drive files should be stored.
#>
function New-HypervVm
{
    [CmdletBinding()]
    [OutputType([void])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    Param
    (
        [Parameter(Mandatory = $false)]
        [string] $hypervHost = $env:COMPUTERNAME,

        [Parameter(Mandatory = $true)]
        [string] $vmName,

        [Parameter(Mandatory = $true)]
        [string] $osVhdPath,

        [Parameter(Mandatory = $false)]
        [int[]] $vmAdditionalDiskSizesInGb,

        [Parameter(Mandatory = $true)]
        [string] $vmNetworkSwitch,

        [Parameter(Mandatory = $false)]
        [string] $vmStoragePath,

        [Parameter(Mandatory = $false)]
        [string] $vhdStoragePath
    )

    Write-Verbose "New-HypervVm - vmName: $vmName"
    Write-Verbose "New-HypervVm - osVhdPath: $osVhdPath"
    Write-Verbose "New-HypervVm - vmAdditionalDiskSizesInGb: $vmAdditionalDiskSizesInGb"
    Write-Verbose "New-HypervVm - vmNetworkSwitch: $vmNetworkSwitch"
    Write-Verbose "New-HypervVm - vmStoragePath: $vmStoragePath"
    Write-Verbose "New-HypervVm - vhdStoragePath: $vhdStoragePath"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

    # Make sure we have a local path to the VHD file
    $osVhdLocalPath = $osVhdPath
    if ($osVhdLocalPath.StartsWith("$([System.IO.Path]::DirectorySeparatorChar)$([System.IO.Path]::DirectorySeparatorChar)"))
    {
        $uncServerPath = "\\$($hypervHost)\"
        $shareRoot = $osVhdLocalPath.SubString($uncServerPath.Length, $osVhdLocalPath.IndexOf('\', $uncServerPath.Length) - $uncServerPath.Length)

        $shareList = Get-WmiObject -Class Win32_Share -ComputerName $hypervHost @commonParameterSwitches
        $localShareRoot = $shareList | Where-Object { $_.Name -eq $shareRoot} | Select-Object -ExpandProperty Path

        $osVhdLocalPath = $osVhdLocalPath.Replace((Join-Path $uncServerPath $shareRoot), $localShareRoot)
    }

    $vmMemoryInBytes = 2 * 1024 * 1024 * 1024
    if (($vmStoragePath -ne $null) -and ($vmStoragePath -ne ''))
    {
        $vm = New-Vm `
            -Name $vmName `
            -Path $vmStoragePath `
            -VHDPath $osVhdLocalPath `
            -MemoryStartupBytes $vmMemoryInBytes `
            -SwitchName $vmNetworkSwitch `
            -Generation 2 `
            -BootDevice 'VHD' `
            -ComputerName $hypervHost `
            -Confirm:$false `
            @commonParameterSwitches
    }
    else
    {
        $vm = New-Vm `
            -Name $vmName `
            -VHDPath $osVhdLocalPath `
            -MemoryStartupBytes $vmMemoryInBytes `
            -SwitchName $vmNetworkSwitch `
            -Generation 2 `
            -BootDevice 'VHD' `
            -ComputerName $hypervHost `
            -Confirm:$false `
            @commonParameterSwitches
    }

     $vm = $vm |
        Set-Vm `
            -ProcessorCount 1 `
            -Confirm:$false `
            -Passthru `
            @commonParameterSwitches

    if ($vmAdditionalDiskSizesInGb -eq $null)
    {
        $vmAdditionalDiskSizesInGb = [int[]](@())
    }

    for ($i = 0; $i -lt $vmAdditionalDiskSizesInGb.Length; $i++)
    {
        $diskSize = $vmAdditionalDiskSizesInGb[$i]

        $driveLetter = Get-DriveLetter -driveNumber ($i + 1)
        $path = Join-Path $vhdStoragePath "$($vmName)_$($driveLetter).vhdx"
        New-Vhd `
            -Path $path `
            -SizeBytes "$($diskSize)GB" `
            -VHDFormat 'VHDX'
            -Dynamic `
            @commonParameterSwitches
        Add-VMHardDiskDrive `
            -Path $path `
            -VM $vm `
            @commonParameterSwitches
    }

    return $vm
}


<#
    .SYNOPSIS

    Creates a new Hyper-V virtual machine with the given properties.


    .DESCRIPTION

    The New-HypervVm function creates a new Hyper-V virtual machine with the provided properties.


    .PARAMETER vmName

    The name of the machine that should be created. Will also be used as the name of the VM.


    .PARAMETER baseVhdx

    The full path of the template VHDx that contains the pre-installed OS.


    .PARAMETER vhdxStoragePath

    The full path of the directory where the virtual hard drive files should be stored.


    .PARAMETER hypervHost

    The name of the machine which is the Hyper-V host for the domain.


    .PARAMETER registeredOwner

    The name of the owner that owns the new machine.


    .PARAMETER domainName

    The name of the domain to which the machine should be attached.


    .PARAMETER unattendedJoin

    The XML fragment for an unattended domain join. This is expected to look like:

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
function New-HypervVmOnDomain
{
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUsePSCredentialType', '')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $vmName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $baseVhdx,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $vhdxStoragePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $hypervHost,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $registeredOwner,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $domainName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $unattendedJoin
    )

    Write-Verbose "New-HypervVmOnDomain - vmName = $vmName"
    Write-Verbose "New-HypervVmOnDomain - baseVhdx = $baseVhdx"
    Write-Verbose "New-HypervVmOnDomain - vhdxStoragePath = $vhdxStoragePath"
    Write-Verbose "New-HypervVmOnDomain - hypervHost = $hypervHost"
    Write-Verbose "New-HypervVmOnDomain - registeredOwner = $registeredOwner"
    Write-Verbose "New-HypervVmOnDomain - unattendedJoin = $unattendedJoin"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

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
            <ComputerName>$vmName</ComputerName>
        </component>

        <!--
            Join the domain
        -->
        $unattendedJoin

        <!--
            Set the DNS search order
        -->
        <component name="Microsoft-Windows-DNS-Client"
                   processorArchitecture="amd64"
                   publicKeyToken="31bf3856ad364e35"
                   language="neutral"
                   versionScope="nonSxS"
                   xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
                   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <DNSDomain>$domainName</DNSDomain>
            <DNSSuffixSearchOrder>
                <DomainName wcm:action="add" wcm:keyValue="1">$domainName</DomainName>
            </DNSSuffixSearchOrder>
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
        </component>
    </settings>
</unattend>
"@

    # Create a copy of the VHDX file and then mount it
    $vhdxPath = Join-Path $vhdxStoragePath "$($vmName.ToLower()).vhdx"
    Copy-Item -Path $baseVhdx -Destination $vhdxPath -Verbose

    try
    {
        $driveLetter = Mount-Vhdx -vhdPath $vhdxPath @commonParameterSwitches

        Set-Content -Path "$($driveLetter):\unattend.xml" -Value $unattendContent
    }
    finally
    {
        Dismount-Vhdx -vhdPath $vhdxPath @commonParameterSwitches
    }

    $vmSwitch = Get-VMSwitch -ComputerName $hypervHost @commonParameterSwitches | Select-Object -First 1

    New-HypervVm `
        -hypervHost $hypervHost `
        -vmName $vmName `
        -osVhdPath $vhdxPath `
        -vmAdditionalDiskSizesInGb $additionalDrives `
        -vmNetworkSwitch $vmSwitch.Name `
        -vmStoragePath '' `
        -vhdStoragePath '' `
        @commonParameterSwitches
}

<#
    .SYNOPSIS

    Waits for the guest operating system to be started.


    .DESCRIPTION

    The Wait-VmGuestOS function waits for the guest operating system on a given VM to be started.


    .PARAMETER vmName

    The name of the VM.


    .PARAMETER hypervHost

    The name of the VM host machine.


    .PARAMETER timeOutInSeconds

    The amount of time in seconds the function should wait for the guest OS to be started.


    .OUTPUTS

    Returns $true if the guest OS was started within the timeout period or $false if the guest OS was not
    started within the timeout period.
#>
function Wait-VmGuestOS
{
    [CmdLetBinding()]
    param(
        [string] $vmName,
        [string] $hypervHost,

        [Parameter()]
        [ValidateScript({$_ -ge 1 -and $_ -le [system.int64]::maxvalue})]
        [int] $timeOutInSeconds = 900 #seconds
    )

    Write-Verbose "Wait-VmGuestOS - vmName = $vmName"
    Write-Verbose "Wait-VmGuestOS - hypervHost = $hypervHost"
    Write-Verbose "Wait-VmGuestOS - timeOutInSeconds = $timeOutInSeconds"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

    $startTime = Get-Date
    $endTime = $startTime + (New-TimeSpan -Seconds $timeOutInSeconds)
    do
    {
        if ((Get-Date) -ge $endTime)
        {
            Write-Verbose "The VM $vmName failed to shut down in the alotted time of $timeOutInSeconds"
            return $false
        }

        Write-Verbose "Waiting for VM $vmName to be ready for use [total wait time so far: $((Get-Date) - $startTime)] ..."
        Start-Sleep -seconds 5
    }
    until ((Get-VMIntegrationService -VMName $vmName -ComputerName $hypervHost @commonParameterSwitches | Where-Object { $_.name -eq "Heartbeat" }).PrimaryStatusDescription -eq "OK")

    return $true
}

<#
    .SYNOPSIS

    Waits for the guest operating system on a VM to be provided with an IP address.


    .DESCRIPTION

    The Wait-VmIPAddress function waits for the guest operating system on a VM to be provided with an IP address.


    .PARAMETER vmName

    The name of the VM.


    .PARAMETER hypervHost

    The name of the VM host machine.


    .PARAMETER timeOutInSeconds

    The amount of time in seconds the function should wait for the guest OS to be assigned an IP address.


    .OUTPUTS

    Returns the IP address of the VM or $null if no IP address could be obtained within the timeout period.
#>
function Wait-VmIPAddress
{
    [CmdletBinding()]
    param(
        [string] $vmName,
        [string] $hypervHost,

        [Parameter()]
        [ValidateScript({$_ -ge 1 -and $_ -le [system.int64]::maxvalue})]
        [int] $timeOutInSeconds = 900 #seconds
    )

    Write-Verbose "Wait-VmIPAddress - vmName = $vmName"
    Write-Verbose "Wait-VmIPAddress - hypervHost = $hypervHost"
    Write-Verbose "Wait-VmIPAddress - timeOutInSeconds = $timeOutInSeconds"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

    $startTime = Get-Date
    $endTime = $startTime + (New-TimeSpan -Seconds $timeOutInSeconds)
    while ((Get-Date) -le $endTime)
    {
        $ipAddress = Get-IPAddressForVm -vmName $vmName -hypervHost $hypervHost @commonParameterSwitches
        if (($ipAddress -ne $null) -and ($ipAddress -ne ''))
        {
            return $ipAddress
        }

        Write-Verbose "Waiting for VM $vmName to be given an IP address [total wait time so far: $((Get-Date) - $startTime)] ..."
        Start-Sleep -seconds 5
    }

    return $null
}

<#
    .SYNOPSIS

    Waits for a Hyper-V VM to be in the off state.


    .DESCRIPTION

    The Wait-VmStopped function waits for a Hyper-V VM to enter the off state.


    .PARAMETER vmName

    The name of the VM.


    .PARAMETER hypervHost

    The name of the VM host machine.


    .PARAMETER timeOutInSeconds

    The maximum amount of time in seconds that this function will wait for VM to enter
    the off state.
#>
function Wait-VmStopped
{
    [CmdletBinding()]
    param(
        [string] $vmName,

        [string] $hypervHost,

        [Parameter()]
        [ValidateScript({$_ -ge 1 -and $_ -le [system.int64]::maxvalue})]
        [int] $timeOutInSeconds = 900 #seconds
    )

    Write-Verbose "Wait-VmStopped - vmName = $vmName"
    Write-Verbose "Wait-VmStopped - hypervHost = $hypervHost"
    Write-Verbose "Wait-VmStopped - timeOutInSeconds = $timeOutInSeconds"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

    $startTime = Get-Date
    $endTime = $startTime + (New-TimeSpan -Seconds $timeOutInSeconds)
    Write-Verbose "Waiting till: $endTime"

    while ($true)
    {
        Write-Verbose "Start of the while loop ..."
        if ((Get-Date) -ge $endTime)
        {
            Write-Verbose "The VM $vmName failed to shut down in the alotted time of $timeOutInSeconds"
            return $false
        }

        Write-Verbose "Waiting for VM $vmName to shut down [total wait time so far: $((Get-Date) - $startTime)] ..."
        try
        {
            Write-Verbose "Getting VM state ..."
            $integrationServices = Get-VM -Name $vmName -ComputerName $hypervHost @commonParameterSwitches | Get-VMIntegrationService

            $offCount = 0
            foreach($service in $integrationServices)
            {
                Write-Verbose "vm $vmName integration service $($service.Name) is at state $($service.PrimaryStatusDescription)"
                if (($service.PrimaryStatusDescription -eq $null) -or ($service.PrimaryStatusDescription -eq ''))
                {
                    $offCount = $offCount + 1
                }
            }

            if ($offCount -eq $integrationServices.Length)
            {
                Write-Verbose "VM $vmName has turned off"
                return $true
            }

        }
        catch
        {
            Write-Verbose "Could not connect to $vmName. Error was $($_.Exception.Message)"
        }

        Write-Verbose "Waiting for 5 seconds ..."
        Start-Sleep -seconds 5
    }

    Write-Verbose "Waiting for VM $name to stop failed outside the normal failure paths."
    return $false
}