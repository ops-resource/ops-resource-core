<#
    .SYNOPSIS

    Connects to the Hyper-V host machine, creates a new Hyper-V virtual machine, pushes all the necessary files up to the
    new Hyper-V virtual machine, executes the Chef cookbook that installs all the required applications and then
    verifies that all the applications have been installed correctly.


    .DESCRIPTION

    The Initialize-HyperVResource script takes all the actions necessary to create and configure a new Hyper-V virtual machine.


    .PARAMETER credential

    The credential that should be used to connect to the remote machine.


    .PARAMETER authenticateWithCredSSP

    A flag that indicates whether remote powershell sessions should be authenticated with the CredSSP mechanism.


    .PARAMETER osName

    The name of the OS that should be used to create the new VM.


    .PARAMETER hypervHost

    The name of the machine on which the hyper-v server is located.


    .PARAMETER unattendedJoinFile

    The full path to the file that contains the XML fragment for an unattended domain join. This is expected to look like:

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

    Initialize-HyperVResource hypervhost "MyHyperVServer"
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
    [string] $unattendedJoinFile                                = '',

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

Write-Verbose "Initialize-HyperVResource - credential: $credential"
Write-Verbose "Initialize-HyperVResource - authenticateWithCredSSP: $authenticateWithCredSSP"
Write-Verbose "Initialize-HyperVResource - osName = $osName"
Write-Verbose "Initialize-HyperVResource - hypervHost: $hypervHost"
switch ($psCmdlet.ParameterSetName)
{
    'FromUserSpecification' {
        Write-Verbose "New-HyperVResource - hypervHost = $hypervHost"
        Write-Verbose "New-HyperVResource - dataCenterName = $dataCenterName"
        Write-Verbose "New-HyperVResource - clusterEntryPointAddress = $clusterEntryPointAddress"
        Write-Verbose "New-HyperVResource - globalDnsServerAddress = $globalDnsServerAddress"
    }

    'FromMetaCluster' {
        Write-Verbose "New-HyperVResource - environmentName = $environmentName"
        Write-Verbose "New-HyperVResource - consulLocalAddress = $consulLocalAddress"
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

    $installationScript = Join-Path $PSScriptRoot 'New-HyperVResource.ps1'
    $verificationScript = Join-Path $PSScriptRoot 'Test-LocalNetworkResource.ps1'

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
                -installationDirectory $installationDirectory `
                -logDirectory $logDirectory `
                -osName $osName `
                -machineName $machineName `
                -hypervHost $hypervHost `
                -unattendedJoinFile $unattendedJoinFile `
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
                -installationDirectory $installationDirectory `
                -logDirectory $logDirectory `
                -osName $osName `
                -machineName $machineName `
                -environmentName $environmentName `
                -consulLocalAddress $consulLocalAddress `
                @commonParameterSwitches
        }
    }

    & $verificationScript `
        -credential $credential `
        -authenticateWithCredSSP:$authenticateWithCredSSP `
        -computerName $machineName `
        -testDirectory $testDirectory `
        -logDirectory $logDirectory `
        @commonParameterSwitches
}
finally
{
    $endTime = [System.DateTimeOffset]::Now
    Write-Output ("Resource initialization started: " + $startTime)
    Write-Output ("Resource initialization completed: " + $endTime)
    Write-Output ("Total time: " + ($endTime - $startTime))
}
