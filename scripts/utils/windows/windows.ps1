<#
    .SYNOPSIS

    Gets the registered owner for the current machine.


    .DESCRIPTION

    The Get-RegisteredOwner function gets the registered owner for the current machine.


    .OUTPUTS

    The name of the registered owner for the current machine.
#>
function Get-RegisteredOwner
{
    [CmdletBinding()]
    param()

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

    $result = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name RegisteredOwner @commonParameterSwitches
    return $result.RegisteredOwner
}

<#
    .SYNOPSIS

    Invokes sysprep on a machine and waits for the machine to shut down.


    .DESCRIPTION

    The Invoke-Sysprep function invokes sysprep on a machine and waits for the machine to shut down


    .PARAMETER connectionInformation

    A custom object containing the connection information for the machine. Available properties are:

        Name             The machine name of the machine
        IPAddress        The IP address of the machine
        Session          A powershell remoting session


    .PARAMETER timeOutInSeconds

    The amount of time in seconds the function should wait for the guest OS to be started.


    .PARAMETER unattendFile

    The full path to the unattend.xml file that should be used for the sysprep. If no file is specified a default
    file will be created.
#>
function Invoke-Sysprep
{
    [CmdletBinding()]
    param(
        [psobject] $connectionInformation,
        [int] $timeOutInSeconds,
        [string] $unattendFile
    )

    Write-Verbose "Invoke-Sysprep - machineName = $machineName"
    Write-Verbose "Invoke-Sysprep - timeOutInSeconds = $timeOutInSeconds"
    Write-Verbose "Invoke-Sysprep - unattendFile = $unattendFile"

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

    Wait-MachineCompletesInitialization -session $connectionInformation.Session @commonParameterSwitches

    # sysprep
    if (Test-Path $unattendFile)
    {
        Copy-ItemToRemoteMachine -session $connectionInformation.Session -localPath $unattendFile -remotePath 'c:\unattend.xml'
    }

    Write-Verbose "Starting sysprep ..."
    Invoke-Command `
        -Session $connectionInformation.Session `
        -ScriptBlock {
            # Clean up output file from the windows image convert script if it is there
            if (Test-Path "$($ENV:SystemDrive)\Convert-WindowsImageInfo.txt")
            {
                Remove-Item -Force -Verbose "$($ENV:SystemDrive)\Convert-WindowsImageInfo.txt"
            }

            # Clean up output file from the windows image convert script if it is there
            if (Test-Path "$($ENV:SystemDrive)\UnattendResources")
            {
                Remove-Item -Force -Verbose -Recurse "$($ENV:SystemDrive)\UnattendResources"
            }

            # Remove Unattend entries from the autorun key if they exist
            foreach ($regvalue in (Get-Item -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run).Property)
            {
                if ($regvalue -like "Unattend*")
                {
                    # could be multiple unattend* entries
                    foreach ($unattendvalue in $regvalue)
                    {
                        Remove-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run -name $unattendvalue  -Verbose
                    }
                }
            }

            # logon script
            $logonScript = {
                # Remove Unattend entries from the autorun key if they exist
                foreach ($regvalue in (Get-Item -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run).Property)
                {
                    if ($regvalue -like "Unattend*")
                    {
                        # could be multiple unattend* entries
                        foreach ($unattendvalue in $regvalue)
                        {
                            Remove-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run -name $unattendvalue -Verbose
                        }
                    }
                }

                # Clean up unattend file if it is there
                if (Test-Path "$($ENV:SystemDrive)\Unattend.xml")
                {
                    Remove-Item -Force "$($ENV:SystemDrive)\Unattend.xml";
                }

                # Clean up logon file if it is there
                if (Test-Path "$($ENV:SystemDrive)\Logon.ps1")
                {
                    Remove-Item -Force "$($ENV:SystemDrive)\Logon.ps1";
                }

                # Clean up temp
                if (Test-Path "$($ENV:SystemDrive)\Temp")
                {
                    Remove-Item -Force -Recurse "$($ENV:SystemDrive)\Temp";
                }

                if (Test-Path "$($ENV:SystemDrive)\Sysprep")
                {
                    Remove-Item -Force -Recurse "$($ENV:SystemDrive)\Sysprep";
                }
            }

            $logonScriptPath = "$($ENV:SystemDrive)\Logon.ps1"
            Set-Content -Value ($logonScript | Out-String) -Path $logonScriptPath -Verbose

            # In order to run the logon script we use the 'setupcomplete.cmd' script approach as documented here:
            # https://technet.microsoft.com/en-us/library/cc766314%28v=ws.10%29.aspx
            $setupCompleteScriptPath = "$env:windir\Setup\Scripts\SetupComplete.cmd"
            $setupCompleteScriptDirectory = Split-Path -Path $setupCompleteScriptPath -Parent
            $setupCompleteScript = "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell -NoLogo -NonInteractive -ExecutionPolicy Unrestricted -File $logonScriptPath"

            if (-not (Test-Path $setupCompleteScriptDirectory))
            {
                New-Item -Path $setupCompleteScriptDirectory -ItemType Directory
            }
            Set-Content -Value $setupCompleteScript -Path $setupCompleteScriptPath -Verbose

            if (-not (Test-Path "$($ENV:SystemDrive)\unattend.xml"))
            {
                $unattendContent = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <!--
        This file describes the different configuration phases for a windows machine.

        For more information about the different stages see: https://technet.microsoft.com/en-us/library/hh824982.aspx
    -->

    <!--
         This configuration pass is used to create and configure information in the Windows image, and is specific to the hardware that the
         Windows image is installing to.

        After the Windows image boots for the first time, the specialize configuration pass runs. During this pass, unique security IDs (SIDs)
        are created. Additionally, you can configure many Windows features, including network settings, international settings, and domain information.
        The answer file settings for the specialize pass appear in audit mode. When a computer boots to audit mode, the auditSystem pass runs, and
        the computer processes the auditUser settings.
    -->
    <settings pass="specialize">

        <component name="Microsoft-Windows-Shell-Setup"
                   processorArchitecture="amd64"
                   publicKeyToken="31bf3856ad364e35"
                   language="neutral"
                   versionScope="nonSxS"
                   xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
                   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <ComputerName>RSC-SYSPREPED</ComputerName>
        </component>
    </settings>
</unattend>
"@

                Set-Content -Path "$($driveLetter):\unattend.xml" -Value $unattendContent
            }

            # sysprep
            # Note that apparently this can't be done just remotely because sysprep starts but doesn't actually
            # run (i.e. it exits without doing any work). So this needs to be done from the local machine
            # that is about to be sysprepped.
            $configDir = "$($ENV:SystemDrive))\Sysprep"
            if (-not (Test-Path $configDir))
            {
                New-Item -Path $configDir -ItemType Directory | Out-Null
            }

            $sysprepCmd = Join-Path $configDir 'sysprep.ps1'
            $cmd = "Write-Output 'Executing $sysPrepScript on VM'; & c:\Windows\system32\sysprep\sysprep.exe /oobe /generalize /shutdown /unattend:`"$($ENV:SystemDrive)\Unattend.xml`""

            Set-Content -Value $cmd -Path $sysprepCmd -Verbose

            Write-Output "Starting sysprep ..."
            & powershell -File "$sysprepCmd"
        } `
        -Verbose `
        -ErrorAction Continue

    # Wait till machine is stopped
    $waitResult = Wait-MachineShutdown `
        -machineName $connectionInformation.Name `
        -timeOutInSeconds $timeOutInSeconds `
        @commonParameterSwitches

    if (-not $waitResult)
    {
        throw "Machine $machineName failed to shut down within $timeOutInSeconds seconds."
    }
}

<#
    .SYNOPSIS

    Waits for a machine to turn off as indicated by the lack of network connection.


    .DESCRIPTION

    The Wait-MachineShutdown function waits for a machine to turn off as indicated by the lack of network connection.


    .PARAMETER machineName

    The name of the machine.


    .PARAMETER timeOutInSeconds

    The maximum amount of time in seconds that this function will wait for VM to enter
    the off state.
#>
function Wait-MachineShutdown
{
    [CmdletBinding()]
    param(
        [string] $machineName,

        [Parameter()]
        [ValidateScript({$_ -ge 1 -and $_ -le [system.int64]::maxvalue})]
        [int] $timeOutInSeconds = 900 #seconds
    )

    Write-Verbose "Wait-MachineShutdown - machineName = $machineName"
    Write-Verbose "Wait-MachineShutdown - timeOutInSeconds = $timeOutInSeconds"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

    $startTime = Get-Date
    $endTime = $startTime + (New-TimeSpan -Seconds $timeOutInSeconds)
    Write-Verbose "Waiting till: $endTime"

    while ($true)
    {
        Write-Verbose "Start of the while loop ..."
        if ((Get-Date) -ge $endTime)
        {
            Write-Verbose "The machine $machineName failed to shut down in the alotted time of $timeOutInSeconds"
            return $false
        }

        Write-Verbose "Waiting for machine $machineName to shut down [total wait time so far: $((Get-Date) - $startTime)] ..."
        try
        {
            Write-Verbose "Pinging machine ..."
            $pingResult = Test-NetConnection -ComputerName $machineName @commonParameterSwitches

            if ($pingResult.PingSucceeded)
            {
                Write-Verbose "Machine $machineName has turned off"
                return $true
            }
        }
        catch
        {
            Write-Verbose "Could not connect to $machineName. Error was $($_.Exception.Message)"
        }

        Write-Verbose "Waiting for 5 seconds ..."
        Start-Sleep -seconds 5
    }

    Write-Verbose "Waiting for machine $machineName to stop failed outside the normal failure paths."
    return $false
}