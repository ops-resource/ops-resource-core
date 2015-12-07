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

        [Parameter(Mandatory = $true)]
        [int[]] $vmAdditionalDiskSizesInGb,

        [Parameter(Mandatory = $true)]
        [string] $vmNetworkSwitch,

        [Parameter(Mandatory = $true)]
        [string] $vmStoragePath,

        [Parameter(Mandatory = $true)]
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
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = 'Stop'
        }

    $vm = New-Vm `
        -Name $vmName `
        -Path $vmStoragePath `
        -VHDPath $osVhdPath `
        -MemoryStartupBytes $(2 * 1024 * 1024 * 1024) `
        -SwitchName $vmNetworkSwitch `
        -Generation 2 `
        -BootDevice 'VHD' `
        -ComputerName $hypervHost `
        @commonParameterSwitches

     $vm |
        Set-Vm `
            -ProcessorCount 1 `
            -Passthru `
            @commonParameterSwitches

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

