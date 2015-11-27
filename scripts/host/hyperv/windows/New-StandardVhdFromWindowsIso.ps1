<#
    .SYNOPSIS

    Creates a new 40Gb VHDX with an installation of Windows as given by the windows install ISO file.


    .DESCRIPTION

    The New-StandardVhdFromWindowsIso script takes all the actions to create a new VHDX virtual hard drive with a windows install.


    .PARAMETER osIsoFile

    The full path to the ISO file that contains the windows installation.
    
    
    .PARAMTER unattendPath
    
    The full path to the unattended file that contains the parameters for an unattended setup.
    
    
    .PARAMETER vhdPath
    
    The full path to where the VHDX file should be output. 
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $osIsoFile = $(throw 'Please specify the full path of the windows install ISO file.'),

    [Parameter(Mandatory = $true)]
    [string] $unattendPath,
    
    [Parameter(Mandatory = $true)]
    [string] $vhdPath
)

Write-Verbose "New-StandardVhdFromWindowsIso - osIsoFile $osIsoFile"
Write-Verbose "New-StandardVhdFromWindowsIso - unattendPath $unattendPath"
Write-Verbose "New-StandardVhdFromWindowsIso - vhdPath $vhdPath"

# Stop everything if there are errors
$ErrorActionPreference = 'Stop'

$commonParameterSwitches =
    @{
        Verbose = $PSBoundParameters.ContainsKey('Verbose');
        Debug = $PSBoundParameters.ContainsKey('Debug');
        ErrorAction = 'Stop'
    }

. (Join-Path $PSScriptRoot 'Convert-WindowsImage.ps1')
Convert-WindowsImage `
    -SourcePath $osIsoFile `
    -VHDPath $vhdPath `
    -SizeBytes '40GB' `
    -VHDFormat 'VHDX' `
    -VHDType 'Dynamic' `
    -VHDPartitionStyle 'GPT' `
    -BCDinVHD 'VirtualMachine' `
    -UnattendPath $unattendPath `
    @commonParameterSwitches