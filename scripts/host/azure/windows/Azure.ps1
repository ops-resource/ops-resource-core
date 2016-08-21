<#
    .SYNOPSIS

    Creates a new Azure VM from a given base image in the given resource group.


    .DESCRIPTION

    The New-AzureVMFromTemplate function creates a new Azure VM in the given resources group. The VM will be based on
    the provided image.


    .PARAMETER resourceGroupName

    The name of the resource group in which the VM should be created.


    .PARAMETER storageAccount

    The name of the storage account in which the VM should be created. This storage account should be linked to the given
    resource group.


    .PARAMETER baseImage

    The full name of the image that the VM should be based on.


    .PARAMETER vmName

    The azure name of the VM. This will also be the computer name. May contain a maximum of 15 characters.


    .PARAMETER sslCertificateName

    The subject name of the SSL certificate in the user root store that can be used for WinRM communication with the VM. The certificate
    should have an exportable private key. Note that the certificate name has to match the public name of the machine, most likely
    $resourceName.cloudapp.net. Defaults to '$resourceGroupName.cloudapp.net'


    .PARAMETER adminName

    The name for the administrator account. Defaults to 'TheBigCheese'.


    .PARAMETER adminPassWord

    The password for the administrator account.


    .EXAMPLE

    New-AzureVMFromTemplate
        -resourceGroupName 'jenkinsresource'
        -storageAccount 'jenkinsstorage'
        -baseImage 'a699494373c04fc0bc8f2bb1389d6106__Windows-Server-2012-R2-201409.01-en.us-127GB.vhd'
        -vmName 'ajm-305-220615'
        -sslCertificateName 'jenkinsresource.cloudapp.net'
        -adminName 'TheOneInCharge'
        -adminPassword 'PeanutsOrMaybeNot'
#>
function New-AzureVMFromTemplate
{
    [CmdletBinding()]
    param(
        [string] $resourceGroupName,
        [string] $storageAccount,
        [string] $baseImage,
        [string] $vmName,
        [string] $sslCertificateName = "$resourceGroupName.cloudapp.net",
        [string] $adminName = 'TheBigCheese',
        [string] $adminPassword
    )

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = "Stop"
        }

    # For the timezone use the timezone of the current machine
    $timeZone = [System.TimeZoneInfo]::Local.StandardName
    Write-Verbose ("timeZone: " + $timeZone)

    # The media location is the name of the storage account appropriately mangled into a URL
    $mediaLocation = ("https://" + $storageAccount + ".blob.core.windows.net/vhds/" + $vmname + ".vhd")

    # Create a machine. This machine isn't actually going to be used for anything other than installing the software so it doesn't need to
    # be big (hence using the InstanceSize Basic_A0).
    Write-Output "Creating temporary virtual machine for $resourceGroupName in $mediaLocation based on $baseImage"
    $vmConfig = New-AzureVMConfig -Name $vmName -InstanceSize Basic_A0 -ImageName $baseImage -MediaLocation $mediaLocation @commonParameterSwitches

    $certificate = Get-ChildItem -Path Cert:\CurrentUser\Root | Where-Object { $_.Subject -match $sslCertificateName } | Select-Object -First 1
    $vmConfig | Add-AzureProvisioningConfig `
            -Windows `
            -TimeZone $timeZone `
            -DisableAutomaticUpdates `
            -WinRMCertificate $certificate `
            -NoRDPEndpoint `
            -AdminUserName $adminName `
            -Password $adminPassword `
            @commonParameterSwitches

    # Create the machine and start it
    New-AzureVM -ServiceName $resourceGroupName -VMs $vmConfig -WaitForBoot @commonParameterSwitches
}

<#
    .SYNOPSIS

    Gets a PSSession that can be used to connect to the remote virtual machine.


    .DESCRIPTION

    The Get-PSSessionForAzureVM function returns a PSSession that can be used to use Powershell remoting to connect to the virtual
    machine with the given name.


    .PARAMETER resourceGroupName

    The name of the resource group in which the VM exists.


    .PARAMETER vmName

    The azure name of the VM.


    .PARAMETER adminName

    The name for the administrator account.


    .PARAMETER adminPassword

    sThe password for the administrator account.


    .OUTPUTS

    Returns the PSSession for the connection to the VM with the given name.


    .EXAMPLE

    Get-PSSessionForAzureVM
        -resourceGroupName 'jenkinsresource'
        -vmName 'ajm-305-220615'
        -adminName 'TheOneInCharge'
        -adminPassword 'PeanutsOrMaybeNot'
#>
function Get-PSSessionForAzureVM
{
    [CmdletBinding()]
    param(
        [string] $resourceGroupName,
        [string] $vmName,
        [string] $adminName,
        [string] $adminPassword
    )

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = "Stop"
        }

    # Get the remote endpoint
    $uri = Get-AzureWinRMUri -ServiceName $resourceGroupName -Name $vmName @commonParameterSwitches

    # create the credential
    $securePassword = ConvertTo-SecureString $adminPassword -AsPlainText -Force @commonParameterSwitches
    $credential = New-Object pscredential($adminName, $securePassword)

    # Connect through WinRM
    $session = New-PSSession -ConnectionUri $uri -Credential $credential @commonParameterSwitches

    return $session
}

<#
    .SYNOPSIS

    Syspreps an Azure VM and then creates an image from it.


    .DESCRIPTION

    The New-AzureSyspreppedVMImage function executes sysprep on a given Azure VM and then once the VM is shut down creates an image from it.


    .PARAMETER session

    The PSSession that provides the connection between the local machine and the remote machine.


    .PARAMETER resourceGroupName

    The name of the resource group in which the VM exists.


    .PARAMETER vmName

    The azure name of the VM.


    .PARAMETER imageName

    The name of the image.


    .PARAMETER imageLabel

    The label of the image.


    .EXAMPLE

    New-AzureSyspreppedVMImage
        -session $session
        -resourceGroupName 'jenkinsresource'
        -vmName 'ajm-305-220615'
        -imageName "jenkins-master-win2012R2_0.2.0"
        -imageLabel "Jenkins master on Windows Server 2012 R2"
#>
function New-AzureSyspreppedVMImage
{
    [CmdletBinding()]
    param(
        [System.Management.Automation.Runspaces.PSSession] $session,
        [string] $resourceGroupName,
        [string] $vmName,
        [string] $imageName,
        [string] $imageLabel
    )

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = "Stop"
        }

    $cmd = 'Write-Output "Executing $sysPrepScript on VM"; & c:\Windows\system32\sysprep\sysprep.exe /oobe /generalize /shutdown'
    $tempDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
    $sysprepCmd = Join-Path $tempDir 'sysprep.ps1'

    $remoteDirectory = "c:\sysprep"
    try
    {
        if (-not (Test-Path $tempDir))
        {
            New-Item -Path $tempDir -ItemType Directory | Out-Null
        }

        Set-Content -Value $cmd -Path $sysprepCmd
        Copy-FilesToRemoteMachine -session $session -remoteDirectory $remoteDirectory -localDirectory $tempDir
    }
    finally
    {
        Remove-Item -Path $tempDir -Force -Recurse
    }

    # Sysprep
    # Note that apparently this can't be done just remotely because sysprep starts but doesn't actually
    # run (i.e. it exits without doing any work). So this needs to be done from the local machine
    # that is about to be sysprepped.
    Write-Verbose "Starting sysprep ..."
    Invoke-Command `
        -Session $session `
        -ArgumentList @( (Join-Path $remoteDirectory (Split-Path -Leaf $sysprepCmd)) ) `
        -ScriptBlock {
            param(
                [string] $sysPrepScript
            )

            & "$sysPrepScript"
        } `
         -Verbose `
         -ErrorAction Continue

    # Wait for machine to turn off. Wait for a maximum of 5 minutes before we fail it.
    $isRunning = $true
    $timeout = [System.TimeSpan]::FromMinutes(20)
    $killTime = [System.DateTimeOffset]::Now + $timeout
    $hasFailed = $false

    Write-Verbose "SysPrep is shutting down machine. Waiting ..."
    try
    {
        while ($isRunning)
        {
            $vm = Get-AzureVM -ServiceName $resourceGroupName -Name $vmName
            Write-Verbose ("$vmName is status: " + $vm.Status)

            if (($vm.Status -eq "StoppedDeallocated") -or ($vm.Status -eq "StoppedVM"))
            {
                Write-Verbose "VM stopped"
                $isRunning = $false
            }

            if ([System.DateTimeOffset]::Now -gt $killTime)
            {
                Write-Verbose "VM failed to stop within time-out"
                $isRunning = false;
                $hasFailed = $true
            }
        }
    }
    catch
    {
        Write-Verbose "Failed during time-out loop"
        # failed. Just ignore it
    }

    if ($hasFailed)
    {
        throw "Virtual machine Sysprep failed to complete within $timeout"
    }

    Write-Verbose "Sysprep complete. Starting image creation"

    Write-Verbose "ServiceName: $resourceGroupName"
    Write-Verbose "Name: $vmName"
    Write-Verbose "ImageName: $imageName"
    Write-Verbose "ImageLabel: $imageLabel"
    Save-AzureVMImage -ServiceName $resourceGroupName -Name $vmName -ImageName $imageName -OSState Generalized -ImageLabel $imageLabel  @commonParameterSwitches
}

<#
    .SYNOPSIS

    Removes a VM image from the user library.


    .DESCRIPTION

    The Remove-AzureSyspreppedVMImage function removes a VM image from the user library.


    .PARAMETER imageName

    The name of the image.


    .EXAMPLE

    Remove-AzureSyspreppedVMImage -imageName "jenkins-master-win2012R2_0.2.0"
#>
function Remove-AzureSyspreppedVMImage
{
    [CmdletBinding()]
    param(
        [string] $imageName
    )

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = "Stop"
        }

    Remove-AzureVMImage -ImageName $imageName -DeleteVHD @commonParameterSwitches
}