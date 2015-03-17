<#
    .SYNOPSIS

    Creates a new Azure VM image for a Windows machine that can serve as a Jenkins master.


    .DESCRIPTION

    The New-AzureWindowsImage script creates a new Azure VM image for a Windows machine that can serve as a Jenkins master.


    .PARAMETER configFile

    The full path to the configuration file that contains all the information about the setup of the jenkins master VM. The XML file is expected to look like:

    <?xml version="1.0" encoding="utf-8"?>
    <configuration>
        <authentication>
            <certificate name="${CertificateName}" />
        </authentication>
        <cloudservice name="${ServiceName}" location="${ServiceLocation}" affinity="${ServiceAffinity}">
            <domain name="${DomainName}" organizationalunit="${DomainOrganizationalUnit}">
                <admin domainname="${DomainNameForAdmin}" name="${AdminUserName}" password="${AdminPassword}" />
            </domain>
            <image name="${ImageName}" label="${ImageLabel}">
                <baseimage>${BaseImageName}</baseimage>
            </machine>
        </cloudservice>
        <desiredstate>
            <installerpath>${DirectoryWithInstallers}</installerpath>
            <entrypoint name="${InstallerMainScriptName}" />
        </desiredstate>
    </configuration>


    .PARAMETER azureScriptDirectory

    The full path to the directory that contains the Azure helper scripts. Defaults to the directory containing the current script.


    .EXAMPLE

    New-AzureWindowsImage -configFile 'c:\temp\azurejenkinsmaster.xml' -azureScriptDirectory 'c:\temp\source'
#>
[CmdletBinding(SupportsShouldProcess = $True)]
param(
    [string] $configFile = $(throw "Please provide a configuration file path."),
    [string] $azureScriptDirectory = $PSScriptRoot,
    [string] $logDirectory = $(throw "Please specify a log directory.")
)

# Stop everything if there are errors
$ErrorActionPreference = 'Stop'

$commonParameterSwitches =
    @{
        Verbose = $PSBoundParameters.ContainsKey('Verbose');
        Debug = $PSBoundParameters.ContainsKey('Debug');
        ErrorAction = "Stop"
    }

# Load the helper functions
$winrmHelpers = Join-Path (Split-Path -Parent $azureScriptDirectory) WinRM.ps1
. $winrmHelpers
$azureHelpers = Join-Path $azureScriptDirectory Azure.ps1
. $azureHelpers

if (-not (Test-Path $configFile))
{
    throw "File not found. Configuration file path is invalid: $configFile"
}

# Get the data from the configuration file
# XML file is expected to look like:
# <?xml version="1.0" encoding="utf-8"?>
# <configuration>
#     <authentication>
#         <certificate name="${CertificateName}" />
#     </authentication>
#     <cloudservice name="${ServiceName}" location="${ServiceLocation}" affinity="${ServiceAffinity}">
#         <domain name="${DomainName}" organizationalunit="${DomainOrganizationalUnit}">
#             <admin domainname="${DomainNameForAdmin}" name="${AdminUserName}" password="${AdminPassword}" />
#         </domain>
#         <image name="${ImageName}" label="${ImageLabel}">
#             <baseimage>${BaseImageName}</baseimage>
#         </machine>
#     </cloudservice>
#     <desiredstate>
#         <installerpath>${DirectoryWithInstallers}</installerpath>
#         <entrypoint name="${InstallerMainScriptName}" />
#     </desiredstate>
# </configuration>
$config = ([xml](Get-Content $configFile)).configuration

$subscriptionName = $config.authentication.subscription.name
Write-Verbose "subscriptionName: $subscriptionName"

$sslCertificateName = $config.authentication.certificates.ssl
Write-Verbose "sslCertificateName: $sslCertificateName"

$adminName = $config.authentication.admin.name
Write-Verbose "adminName: $adminName"

$adminPassword = $config.authentication.admin.password

$baseImage = $config.service.image.baseimage
Write-Verbose "baseImage: $baseImage"

$storageAccount = $config.service.image.storageaccount
Write-Verbose "storageAccount: $storageAccount"

$resourceGroupName = $config.service.name
Write-Verbose "resourceGroupName: $resourceGroupName"

$installationDirectory = $config.desiredstate.installerpath
Write-Verbose "installationDirectory: $installationDirectory"

$installationScript = $config.desiredstate.entrypoint.name
Write-Verbose "installationScript: $installationScript"

$imageName = $config.service.image.name
Write-Verbose "imageName: $imageName"

$imageLabel = $config.service.image.label
Write-Verbose "imageLabel: $imageLabel"

$remoteConfigurationDirectory = 'c:\configuration'
$remoteLogDirectory = "c:\logs"

# Set the storage account for the selected subscription
Set-AzureSubscription -SubscriptionName $subscriptionName -CurrentStorageAccount $storageAccount @commonParameterSwitches

# The name of the VM is technically irrevant because we're only after the disk in the end. So make sure it's unique but don't bother
# with an actual name
$now = [System.DateTimeOffset]::Now
$vmName = ("ajm-" + $now.DayOfYear.ToString("000") + "-" + $now.Hour.ToString("00") + $now.Minute.ToString("00") + $now.Second.ToString("00"))
Write-Verbose "vmName: $vmName"

try
{
    New-AzureVmFromTemplate `
        -resourceGroupName $resourceGroupName `
        -storageAccount $storageAccount `
        -baseImage $baseImage `
        -vmName $vmName `
        -sslCertificateName $sslCertificateName `
        -adminName $adminName `
        -adminPassword $adminPassword

    $vm = Get-AzureVM -ServiceName $resourceGroupName -Name $vmName
    Write-Verbose ("New-AzureVmFromTemplate complete - VM state: " + $vm.Status)

    $session = Get-PSSessionForAzureVM `
        -resourceGroupName $resourceGroupName `
        -vmName $vmName `
        -adminName $adminName `
        -adminPassword $adminPassword

    $vm = Get-AzureVM -ServiceName $resourceGroupName -Name $vmName
    Write-Verbose ("Get-PSSessionForAzureVM complete - VM state: " + $vm.Status)

    # Create the installer directory on the virtual machine
    Copy-FilesToRemoteMachine -session $session -localDirectory $installationDirectory -remoteDirectory $remoteConfigurationDirectory

    $vm = Get-AzureVM -ServiceName $resourceGroupName -Name $vmName
    Write-Verbose ("Copy-FilesToRemoteMachine complete - VM state: " + $vm.Status)

    # Execute the remote installation scripts
    $hasError = $false
    try
    {
        Invoke-Command `
            -Session $session `
            -ArgumentList @( (Join-Path $remoteConfigurationDirectory (Split-Path -Leaf $installationScript)), $remoteConfigurationDirectory, $remoteLogDirectory ) `
            -ScriptBlock {
                param(
                    [string] $installationScript,
                    [string] $configurationDirectory,
                    [string] $logDirectory
                )

                & $installationScript -configurationDirectory $configurationDirectory -logDirectory $logDirectory -cookbookName 'master'
            } `
             @commonParameterSwitches
    }
    catch
    {
        $hasError = $true
        Write-Output ("Error while installing applications. Exception is: " + $_.Exception.ToString())
    }
    finally
    {
        Write-Verbose "Copying log files from VM ..."
        Copy-FilesFromRemoteMachine -session $session -remoteDirectory $remoteLogDirectory -localDirectory $logDirectory

        Write-Verbose "Copied log files from VM"

        Remove-FilesFromRemoteMachine -session $session -remoteDirectory $remoteConfigurationDirectory
        Remove-FilesFromRemoteMachine -session $session -remoteDirectory $remoteLogDirectory
    }

    if (-not $hasError)
    {
        $vm = Get-AzureVM -ServiceName $resourceGroupName -Name $vmName
        Write-Verbose ("Execute installation script complete - VM state: " + $vm.Status)

        New-AzureSyspreppedVMImage -session $session -resourceGroupName $resourceGroupName -vmName $vmName -imageName $imageName -imageLabel $imageLabel
    }
}
finally
{
    $vm = Get-AzureVM -ServiceName $resourceGroupName -Name $vmName
    if ($vm -ne $null)
    {
        Remove-AzureVM -ServiceName $resourceGroupName -Name $vmName -DeleteVHD @commonParameterSwitches
    }
}


