<#
.Synopsis
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    Example of how to use this cmdlet
.EXAMPLE
    Another example of how to use this cmdlet
#>
function New-HypervVm
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([void])]
    Param
    (
        [Parameter(Mandatory = $true)]
        [string] $vmName,
        
        [Parameter(Mandatory = $true)]
        [string] $osVhdPath,
        
        [Parameter(Mandatory = $true)]
        [int[]] $vmAdditionalDiskSizesInGb,
        
        [Parameter(Mandatory = $true)]
        [string] $vmNetwork,
        
        [Parameter(Mandatory = $true)]
        [string] $computerName,
        
        [Parameter(Mandatory = $true)]
        [string] $administratorName,
        
        [Parameter(Mandatory = $true)]
        [string] $administratorPassword
    )
    
    Write-Verbose "New-HypervVm - vmName: $vmName"
    Write-Verbose "New-HypervVm - vmDiskSizes $vmDiskSizes"
    Write-Verbose "New-HypervVm - vmNetwork $vmNetwork"
    Write-Verbose "New-HypervVm - iso $iso"
    Write-Verbose "New-HypervVm - computerName $computerName"
    Write-Verbose "New-HypervVm - administratorName $administratorName"
    
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
        -Path '' `
        -VHDPath $osVhdPath `
        -MemoryStartupBytes $(2 * 1024 * 1024 * 1024) `
        -SwitchName $switch `
        -Generation 2 `
        -BootDevice 'VHD' `
        @commonParameterSwitches
        
     $vm | Set-Vm `
        -ProcessorCount 1 `
        -Passthru `
        @commonParameterSwitches
        
    foreach($diskSize in $vmAdditionalDiskSizesInGb)
    {
        New-Vhd `
            -Path '' `
            -SizeBytes "$($diskSize)GB" `
            -VHDFormat 'VHDX'
            -Dynamic `
            @commonParameterSwitches
        Add-VMHardDiskDrive `
            -Path '' `
            -VM $vm `
            @commonParameterSwitches
    }
}