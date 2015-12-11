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


    .PARAMETER vhdPath

    The full path to where the VHDX file should be output.


    .PARAMETER convertWindowsImagePath

    The full path to the Convert-WindowsImage script on the local disk.


    .PARAMETER convertWindowsImageUrl

    The URL from where the Convert-WindowsImage script can be downloaded.
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
    [string] $vhdPath,

    [Parameter(Mandatory = $false,
               ParameterSetName = 'UseLocalConvertScript')]
    [string] $convertWindowsImagePath = $(Join-Path $PSScriptRoot 'Convert-WindowsImage.ps1'),

    [Parameter(Mandatory = $false,
               ParameterSetName = 'DownloadConvertScript')]
    [string] $convertWindowsImageUrl = 'https://gallery.technet.microsoft.com/scriptcenter/Convert-WindowsImageps1-0fe23a8f/file/59237/7/Convert-WindowsImage.ps1',

    [Parameter(Mandatory = $false,
               ParameterSetName = 'DownloadConvertScript')]
    [string] $tempPath = $(Join-Path $env:Temp ([System.Guid]::NewGuid.ToString()))
)

Write-Verbose "New-StandardVhdFromWindowsIso - osIsoFile = $osIsoFile"
Write-Verbose "New-StandardVhdFromWindowsIso - unattendPath = $unattendPath"
Write-Verbose "New-StandardVhdFromWindowsIso - vhdPath = $vhdPath"

switch ($psCmdlet.ParameterSetName)
{
    'UseLocalConvertScript' {
        Write-Verbose "New-StandardVhdFromWindowsIso - convertWindowsImagePath = $convertWindowsImagePath"
    }

    'DownloadConvertScript' {
        Write-Verbose "New-StandardVhdFromWindowsIso - convertWindowsImageUrl = $convertWindowsImageUrl"
        Write-Verbose "New-StandardVhdFromWindowsIso - tempPath = $tempPath"
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

if ($psCmdLet.ParameterSetName -eq 'DownloadConvertScript')
{
    if (-not (Test-Path $tempPath))
    {
        New-Item -Path $tempPath -ItemType Directory | Out-Null
    }

    $convertWindowsImagePath = Join-Path $tempPath 'Convert-WindowsImage.ps1'
    Invoke-WebRequest `
        -Uri $convertWindowsImageUrl `
        -UseBasicParsing `
        -Method Get `
        -OutFile $convertWindowsImagePath `
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