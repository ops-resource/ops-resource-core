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

    [Parameter(Mandatory = $true,
               ParameterSetName = 'FromUserSpecification')]
    [string] $hypervHost                                        = '',

    [Parameter(Mandatory = $true,
               ParameterSetName = 'FromUserSpecification')]
    [string] $vhdxTemplatePath                                  = "\\$($hypervHost)\vmtemplates",

    [Parameter(Mandatory = $true,
               ParameterSetName = 'FromUserSpecification')]
    [string] $hypervHostVmStoragePath                           = "\\$(hypervHost)\vms\machines",

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

Write-Verbose "Initialize-HyperVImage - credential: $credential"
Write-Verbose "Initialize-HyperVImage - authenticateWithCredSSP: $authenticateWithCredSSP"
Write-Verbose "Initialize-HyperVImage - osName = $osName"
Write-Verbose "Initialize-HyperVImage - hypervHost: $hypervHost"
switch ($psCmdlet.ParameterSetName)
{
    'FromUserSpecification' {
        Write-Verbose "Initialize-HyperVImage - hypervHost = $hypervHost"
        Write-Verbose "Initialize-HyperVImage - vhdxTemplatePath = $vhdxTemplatePath"
        Write-Verbose "Initialize-HyperVImage - hypervHostVmStoragePath = $hypervHostVmStoragePath"
        Write-Verbose "Initialize-HyperVImage - dataCenterName = $dataCenterName"
        Write-Verbose "Initialize-HyperVImage - clusterEntryPointAddress = $clusterEntryPointAddress"
        Write-Verbose "Initialize-HyperVImage - globalDnsServerAddress = $globalDnsServerAddress"
    }

    'FromMetaCluster' {
        Write-Verbose "Initialize-HyperVImage - environmentName = $environmentName"
        Write-Verbose "Initialize-HyperVImage - consulLocalAddress = $consulLocalAddress"
    }
}

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
    switch ($psCmdlet.ParameterSetName)
    {
        'FromUserSpecification' {
            & $installationScript `
                -credential $credential `
                -authenticateWithCredSSP:$authenticateWithCredSSP `
                -resourceName $resourceName `
                -resourceVersion $resourceVersion `
                -cookbookNames $cookbookNames `
                -imageName $previewImageName `
                -installationDirectory $installationDirectory `
                -logDirectory $logDirectory `
                -osName $osName `
                -machineName $machineName `
                -hypervHost $hypervHost `
                -vhdxTemplatePath $vhdxTemplatePath `
                -hypervHostVmStoragePath $hypervHostVmStoragePath `
                -dataCenterName $dataCenterName `
                -clusterEntryPointAddress $clusterEntryPointAddress `
                -globalDnsServerAddress $globalDnsServerAddress `
                @commonParameterSwitches

                & $verificationScript `
                    -credential $credential `
                    -authenticateWithCredSSP:$authenticateWithCredSSP `
                    -imageName $previewImageName `
                    -testDirectory $testDirectory `
                    -logDirectory $logDirectory `
                    -machineName $machineName `
                    -hypervHost $hypervHost `
                    -vhdxTemplatePath $vhdxTemplatePath `
                    -hypervHostVmStoragePath $hypervHostVmStoragePath `
                    -dataCenterName $dataCenterName `
                    -clusterEntryPointAddress $clusterEntryPointAddress `
                    -globalDnsServerAddress $globalDnsServerAddress `
                    @commonParameterSwitches
        }

        'FromMetaCluster' {
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
                -environmentName $environmentName `
                -consulLocalAddress $consulLocalAddress `
                @commonParameterSwitches

                & $verificationScript `
                    -credential $credential `
                    -authenticateWithCredSSP:$authenticateWithCredSSP `
                    -imageName $previewImageName `
                    -testDirectory $testDirectory `
                    -logDirectory $logDirectory `
                    -machineName $machineName `
                    -environmentName $environmentName `
                    -consulLocalAddress $consulLocalAddress `
                    @commonParameterSwitches
        }
    }

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
