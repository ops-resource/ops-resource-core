<#
    .SYNOPSIS

    Verifies that a given image can indeed be used to create a Windows machine that serves as a Jenkins master.


    .DESCRIPTION

    The Verify-AzureWindowsImage script verifies that a given image can indeed be used to create a Windows machine that serves as a Jenkins master.


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

    Verify-AzureWindowsImage -configFile 'c:\init\azurejenkinsmaster.xml' -azureScriptDirectory 'c:\init\source'
#>
[CmdletBinding(SupportsShouldProcess = $True)]
param(
    [string] $configFile = $(throw "Please provide a configuration file path."),
    [string] $azureScriptDirectory = $PSScriptRoot,
    [string] $testDirectory = $PSScriptRoot,
    [string] $logDirectory =  $(throw "Please specify a log directory.")
)

Write-Verbose "Test-AzureImage - configFile: $configFile"
Write-Verbose "Test-AzureImage - azureScriptDirectory: $azureScriptDirectory"
Write-Verbose "Test-AzureImage - testDirectory: $testDirectory"
Write-Verbose "Test-AzureImage - logDirectory: $logDirectory"

# Stop everything if there are errors
$ErrorActionPreference = 'Stop'

$commonParameterSwitches =
    @{
        Verbose = $PSBoundParameters.ContainsKey('Verbose');
        Debug = $false;
        ErrorAction = "Stop"
    }

# Load the helper functions
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

$storageAccount = $config.service.image.storageaccount
Write-Verbose "storageAccount: $storageAccount"

$resourceGroupName = $config.service.name
Write-Verbose "resourceGroupName: $resourceGroupName"

$imageName = $config.service.image.name
Write-Verbose "imageName: $imageName"

$imageLabel = $config.service.image.label
Write-Verbose "imageLabel: $imageLabel"

# Set the storage account for the selected subscription
Set-AzureSubscription -SubscriptionName $subscriptionName -CurrentStorageAccount $storageAccount @commonParameterSwitches

# The name of the VM is technically irrevant because we're only going to create it to check that the image is correct.
# So make sure it's unique but don't bother with an actual name
$now = [System.DateTimeOffset]::Now
$vmName = ("tajm-" + $now.DayOfYear.ToString("000") + "-" + $now.Hour.ToString("00") + $now.Minute.ToString("00") + $now.Second.ToString("00"))
Write-Verbose "vmName: $vmName"

try
{
    # Create a VM with the template
    New-AzureVmFromTemplate `
        -resourceGroupName $resourceGroupName `
        -storageAccount $storageAccount `
        -baseImage $imageName `
        -vmName $vmName `
        -sslCertificateName $sslCertificateName `
        -adminName $adminName `
        -adminPassword $adminPassword

    $session = Get-PSSessionForAzureVM `
        -resourceGroupName $resourceGroupName `
        -vmName $vmName `
        -adminName $adminName `
        -adminPassword $adminPassword

    $testWindowsResource = Join-Path $PSScriptRoot 'Test-WindowsResource.ps1'
    & $testWindowsResource -session $session -testDirectory $testDirectory -logDirectory $logDirectory
}
finally
{
    $vm = Get-AzureVM -ServiceName $resourceGroupName -Name $vmName
    if ($vm -ne $null)
    {
        Remove-AzureVM -ServiceName $resourceGroupName -Name $vmName -DeleteVHD @commonParameterSwitches
    }
}
