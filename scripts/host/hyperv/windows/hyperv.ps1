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


    .EXAMPLE
    Example of how to use this cmdlet


    .EXAMPLE
    Another example of how to use this cmdlet
#>
function New-HypervVm
{
    [CmdletBinding()]
    [OutputType([void])]
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
            -MemoryStartupBytes $vmMemoryInBytes `
            -SwitchName $vmNetworkSwitch `
            -Generation 2 `
            -BootDevice 'VHD' `
            -ComputerName $hypervHost `
            -Confirm:$false
            @commonParameterSwitches
    }

     $vm |
        Set-Vm `
            -ProcessorCount 1 `
            -Confirm:$false
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
}

<#
    .SYNOPSIS

    Starts a Hyper-V VM and waits for the guest operating system to be started.


    .DESCRIPTION

    The Start-VMAndWaitForGuestOSToBeStarted function starts a Hyper-V VM and waits for the
    guest operating system to be started.


    .PARAMETER vmName

    The name of the VM.


    .PARAMETER vmHost

    The name of the VM host machine.
#>
function Start-VMAndWaitForGuestOSToBeStarted
{
    [CmdLetBinding()]
    param(
        [string] $vmName,
        [string] $vmHost
    )

    Write-Verbose "Start-VMAndWaitForGuestOSToBeStarted - vmName = $vmName"
    Write-Verbose "Start-VMAndWaitForGuestOSToBeStarted - vmHost = $vmHost"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

    Start-VM `
        -Name $vmName `
        -ComputerName $vmHost `
        @commonParameterSwitches

    do
    {
        Start-Sleep -milliseconds 100
    }
    until ((Get-VMIntegrationService -VMName $vmToStart -ComputerName $vmHost @commonParameterSwitches | Where-Object { $_.name -eq "Heartbeat" }).PrimaryStatusDescription -eq "OK")
}