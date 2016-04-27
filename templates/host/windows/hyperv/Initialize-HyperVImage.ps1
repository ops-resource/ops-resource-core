<#
    .SYNOPSIS

    Connects to the Hyper-V host machine, creates a new Hyper-V virtual machine, pushes all the necessary files up to the
    new Hyper-V virtual machine, executes the Chef cookbook that installs all the required applications and then
    verifies that all the applications have been installed correctly.


    .DESCRIPTION

    The Initialize-HyperVImage script takes all the actions necessary to create and configure a new Hyper-V virtual machine.


    .PARAMETER credential

    The credential that should be used to connect to the remote machine.


    .PARAMETER authenticateWithCredSSP

    A flag that indicates whether remote powershell sessions should be authenticated with the CredSSP mechanism.


    .PARAMETER osName

    The name of the OS that should be used to create the new VM.


    .PARAMETER hypervHost

    The name of the machine on which the hyper-v server is located.


    .PARAMETER vhdxTemplatePath

    The UNC path to the directory that contains the Hyper-V images.


    .PARAMETER hypervHostVmStoragePath

    The UNC path to the directory that stores the Hyper-V VM information.


    .EXAMPLE

    Initialize-HyperVImage hypervhost "MyHyperVServer"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [PSCredential] $credential                                  = $null,

    [Parameter(Mandatory = $false)]
    [switch] $authenticateWithCredSSP,

    [Parameter(Mandatory = $true)]
    [string] $osName                                            = '',

    [Parameter(Mandatory = $true)]
    [string] $hypervHost                                        = '',

    [Parameter(Mandatory = $true)]
    [string] $vhdxTemplatePath                                  = "\\$($hypervHost)\vmtemplates",

    [Parameter(Mandatory = $true)]
    [string] $hypervHostVmStoragePath                           = "\\$(hypervHost)\vms\machines"
)

Write-Verbose "Initialize-HyperVImage - credential: $credential"
Write-Verbose "Initialize-HyperVImage - authenticateWithCredSSP: $authenticateWithCredSSP"
Write-Verbose "Initialize-HyperVImage - osName = $osName"
Write-Verbose "Initialize-HyperVImage - isConsulClusterLeader: $isConsulClusterLeader"
Write-Verbose "Initialize-HyperVImage - hypervHost: $hypervHost"
    Write-Verbose "Initialize-HyperVImage - hypervHost = $hypervHost"
    Write-Verbose "Initialize-HyperVImage - vhdxTemplatePath = $vhdxTemplatePath"
    Write-Verbose "Initialize-HyperVImage - hypervHostVmStoragePath = $hypervHostVmStoragePath"


# Stop everything if there are errors
$ErrorActionPreference = 'Stop'

$commonParameterSwitches =
    @{
        Verbose = $PSBoundParameters.ContainsKey('Verbose');
        Debug = $false;
        ErrorAction = "Stop"
    }

. (Join-Path $PSScriptRoot 'utils.ps1')

$startTime = [System.DateTimeOffset]::Now
try
{
    $resourceName = '${ProductName}'
    $resourceVersion = '${VersionSemanticFull}'
    $cookbookNames = '${CookbookNames}'.Split(';')

    $installationDirectory = $(Join-Path $PSScriptRoot 'configuration')
    $testDirectory = $(Join-Path $PSScriptRoot 'verification')
    $logDirectory = $(Join-Path $PSScriptRoot 'logs')

    $installationScript = Join-Path $PSScriptRoot 'New-HypervImage.ps1'
    $verificationScript = Join-Path $PSScriptRoot 'Test-HypervImage.ps1'

    $previewPrefix = "preview_"
    $imageName = "$($resourceName)-$($resourceVersion).vhdx"
    $previewImageName = "$($previewPrefix)$($imageName)"
    $machineName = New-RandomMachineName @commonParameterSwitches

    & $installationScript `
        -credential $credential `
        -authenticateWithCredSSP:$authenticateWithCredSSP `
        -resourceName $resourceName `
        -resourceVersion $resourceVersion `
        -cookbookNames $cookbookNames `
        -imageName $imageName `
        -installationDirectory $installationDirectory `
        -logDirectory $logDirectory `
        -osName $osName `
        -machineName $machineName `
        @commonParameterSwitches

    & $verificationScript `
        -credential $credential `
        -authenticateWithCredSSP:$authenticateWithCredSSP `
        -imageName $previewImageName `
        -testDirectory $testDirectory `
        -logDirectory $logDirectory `
        -machineName $machineName `
        @commonParameterSwitches

    # If the tests pass, then rename the image
    Rename-Item -Path (Join-Path $vhdxTemplatePath $previewImageName) -NewName $imageName -Force @commonParameterSwitches

    # Now make the image file read-only
    Set-ItemProperty -Path (Join-Path $vhdxTemplatePath $imageName) -Name IsReadOnly -Value $true
}
finally
{
    $endTime = [System.DateTimeOffset]::Now
    Write-Output ("Image initialization started: " + $startTime)
    Write-Output ("Image initialization completed: " + $endTime)
    Write-Output ("Total time: " + ($endTime - $startTime))
}
