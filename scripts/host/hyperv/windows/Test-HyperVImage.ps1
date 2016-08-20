<#
    .SYNOPSIS

    Verifies that a given Hyper-V image can indeed be used to run the selected resource.


    .DESCRIPTION

    The Test-HyperVImage script verifies that a given image can indeed be used to run the selected resource.


    .PARAMETER credential

    The credential that should be used to connect to the remote machine.


    .PARAMETER authenticateWithCredSSP

    A flag that indicates whether remote powershell sessions should be authenticated with the CredSSP mechanism.


    .PARAMETER resourceName

    The name of the resource that is being created.


    .PARAMETER resourceVersion

    The version of the resource that is being created.


    .PARAMETER cookbookNames

    An array containing the names of the cookbooks that should be executed to install all the required applications on the machine.


    .PARAMETER installationDirectory

    The directory in which all the installer packages and cookbooks can be found. It is expected that the cookbooks are stored
    in a 'cookbooks' sub-directory of the installationDirectory.


    .PARAMETER logDirectory

    The directory in which all the logs should be stored.


    .PARAMETER osName

    The name of the OS that should be used to create the new VM.


    .PARAMETER machineName

    The name of the machine that should be created


    .PARAMETER hypervHost

    The name of the machine on which the hyper-v server is located.


    .PARAMETER vhdxTemplatePath

    The UNC path to the directory that contains the Hyper-V images.


    .PARAMETER hypervHostVmStoragePath

    The UNC path to the directory that stores the Hyper-V VM information.


    .PARAMETER configPath

    The full path to the directory that contains the unattended file that contains the parameters for an unattended setup
    and any necessary script files which will be used during the configuration of the operating system.


    .PARAMETER staticMacAddress

    An optional static MAC address that is applied to the VM so that it can be given a consistent IP address.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [PSCredential] $credential                                  = $null,

    [Parameter(Mandatory = $false)]
    [switch] $authenticateWithCredSSP,

    [Parameter(Mandatory = $false)]
    [string] $imageName                                         = "$($resourceName)-$($resourceVersion).vhdx",

    [string] $testDirectory                                     = $(Join-Path $PSScriptRoot "verification"),

    [Parameter(Mandatory = $false)]
    [string] $logDirectory                                      = $(Join-Path $PSScriptRoot 'logs'),

    [Parameter(Mandatory = $true)]
    [string] $machineName                                       = '',

    [Parameter(Mandatory = $true)]
    [string] $hypervHost                                        = '',

    [Parameter(Mandatory = $true)]
    [string] $vhdxTemplatePath                                  = "\\$($hypervHost)\vmtemplates",

    [Parameter(Mandatory = $true)]
    [string] $hypervHostVmStoragePath                           = "\\$($hypervHost)\vms\machines",

    [Parameter(Mandatory = $true)]
    [string] $configPath                                        = '',

    [Parameter(Mandatory = $false)]
    [string] $staticMacAddress                                  = ''
)

Write-Verbose "Test-HyperVImage - credential = $credential"
Write-Verbose "Test-HyperVImage - authenticateWithCredSSP = $authenticateWithCredSSP"
Write-Verbose "Test-HyperVImage - imageName = $imageName"
Write-Verbose "Test-HyperVImage - testDirectory = $testDirectory"
Write-Verbose "Test-HyperVImage - logDirectory = $logDirectory"
Write-Verbose "Test-HyperVImage - machineName = $machineName"
Write-Verbose "Test-HyperVImage - hypervHost = $hypervHost"
Write-Verbose "Test-HyperVImage - vhdxTemplatePath = $vhdxTemplatePath"
Write-Verbose "Test-HyperVImage - hypervHostVmStoragePath = $hypervHostVmStoragePath"
Write-Verbose "Test-HyperVImage - configPath = $configPath"
Write-Verbose "Test-HyperVImage - staticMacAddress = $staticMacAddress"

$ErrorActionPreference = 'Stop'

$commonParameterSwitches =
    @{
        Verbose = $PSBoundParameters.ContainsKey('Verbose');
        Debug = $false;
        ErrorAction = 'Stop'
    }

# Load the helper functions
. (Join-Path $PSScriptRoot consul.ps1)
. (Join-Path $PSScriptRoot hyperv.ps1)
. (Join-Path $PSScriptRoot networking.ps1)
. (Join-Path $PSScriptRoot sessions.ps1)
. (Join-Path $PSScriptRoot WinRM.ps1)

# -------------------- Functions ------------------------

function Close-FirewallPort
{
    [CmdletBinding()]
    param(
        [int] $port = 8950
    )

    Write-Verbose "Close-FirewallPort - port = $port"

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

    $fwPort = New-Object -ComObject HNetCfg.FWOpenPort
    $fwPort.Port = $port
    $fwPort.Name = 'Test-HyperVImage-Port'
    $fwPort.Enabled = $false

    $fwMgr = New-Object -ComObject HNetCfg.FwMgr
    $profile = $fwMgr.LocalPolicy.CurrentProfile
    $profile.GloballyOpenPorts.Add($fwPort)
}

function New-TestConsulConfig
{
    [CmdletBinding()]
    param(
        [string] $datacenter,
        [string] $ipAddress,
        [int] $basePort = 8900,
        [string] $configPath
    )

    Write-Verbose "New-TestConsulConfig - datacenter = $datacenter"
    Write-Verbose "New-TestConsulConfig - ipAddress = $ipAddress"
    Write-Verbose "New-TestConsulConfig - basePort = $basePort"
    Write-Verbose "New-TestConsulConfig - configPath = $configPath"

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

    $consulConfig = @"
{
  "bootstrap_expect" : 1,
  "server": true,
  "datacenter": "$($datacenter)",

  "client_addr": "$($ipAddress)",

  "ports": {
    "http": $($basePort + 0),
    "dns": $($basePort + 1),
    "rpc": $($basePort + 2),
    "serf_lan": $($basePort + 3),
    "serf_wan": $($basePort + 4),
    "server": $($basePort + 5)
  },

  "dns_config" : {
    "allow_stale" : true,
    "max_stale" : "150s",
    "node_ttl" : "300s",
    "service_ttl": {
      "*": "300s"
    }
  },

  "retry_join_wan": [],
  "retry_interval_wan": "30s",

  "retry_join": [],
  "retry_interval": "30s",

  "recursors": [],

  "disable_remote_exec": true,
  "disable_update_check": true,

  "log_level" : "warn"
}
"@
    $consulConfig | Out-File -FilePath $configPath -Encoding ascii @commonParameterSwitches
}

function Open-FirewallPort
{
    [CmdletBinding()]
    param(
        [int] $port = 8950
    )

    Write-Verbose "Open-FirewallPort - port = $port"

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = 'Stop'
        }

    $fwPort = New-Object -ComObject HNetCfg.FWOpenPort
    $fwPort.Port = $port
    $fwPort.Name = 'Test-HyperVImage-Port'
    $fwPort.Enabled = $true

    $fwMgr = New-Object -ComObject HNetCfg.FwMgr
    $profile = $fwMgr.LocalPolicy.CurrentProfile
    $profile.GloballyOpenPorts.Add($fwPort)
}

# -------------------- Script ---------------------------

if (-not (Test-Path $testDirectory))
{
    throw "Unable to find the directory containing the test files. Expected it at: $testDirectory"
}

if (-not (Test-Path $logDirectory))
{
    New-Item -Path $logDirectory -ItemType Directory | Out-Null
}

if (-not (Test-Path $hypervHostVmStoragePath))
{
    throw "Unable to find the directory where the Hyper-V VMs are stored. Expected it at: $hypervHostVmStoragePath"
}

if (-not (Test-Path $vhdxTemplatePath))
{
    throw "Unable to find the directory where the Hyper-V templates are stored. Expected it at: $vhdxTemplatePath"
}

$basePort = 8950
try
{
    Open-FirewallPort -port $basePort @commonParameterSwitches

    # Configure a consul agent that can be used as the configuration stored
    $datacenter = "TestHyperVImage".ToLower()
    $consulConfig = Join-Path $PSScriptRoot 'testconsul_default.json'
    New-TestConsulConfig `
        -datacenter $datacenter `
        -ipAddress $((get-netadapter | get-netipaddress | ? addressfamily -eq 'IPv4').ipaddress) `
        -basePort $basePort `
        -configPath $consulConfig `
        @commonParameterSwitches

    Write-Verbose "Starting consul ..."
    $arguments = @(
        "agent",
        "-dev",
        "-config-file=$($consulConfig)",
        "-data-dir=$(Join-Path $PSScriptRoot 'consul')"
    )
    $consulProcess = Start-Process `
        -FilePath (Join-Path $PSScriptRoot 'consul.exe') `
        -ArgumentList $arguments `
        -WindowStyle Minimized `
        -RedirectStandardOutput (Join-Path $logDirectory 'consul_out.log') `
        -RedirectStandardError (Join-Path $logDirectory 'consul_err.log') `
        -PassThru `
        @commonParameterSwitches

    # Wait for Consul to spin up
    Start-Sleep -Seconds 5

    Write-Verbose "Consul started ..."
    try
    {
        $dnsIPAddresses = @(Get-DnsServerIPAddressesFromCurrentMachine @commonParameterSwitches)
        $jsonObject = New-Object psobject -Property @{
            "consul_datacenter" = "$($datacenter)"
            "consul_recursors" = $dnsIPAddresses
            "consul_lanservers" = ""

            "consul_isserver" = $true
            "consul_numberofservers" = 1
            "consul_domain" = "imagetest"
            "consul_wanservers" = ""
        }

        Write-Verbose "Setting test configuration in consul ..."
        $consultestconfig = ConvertTo-Json -InputObject $jsonObject @commonParameterSwitches
        $consulBaseUrl = "http://$($env:COMPUTERNAME):$($basePort)"
        $keyPath = "provisioning/$($machineName)/service"
        Set-ConsulKeyValue `
            -httpUrl $consulBaseUrl `
            -dataCenter $datacenter `
            -keyPath "$($keyPath)/consul/environment" `
            -value $consultestconfig `
            @commonParameterSwitches

        $configurationScript = Join-Path $PSScriptRoot 'New-HyperVResource.ps1'
        $connection = & $configurationScript `
            -credential $credential `
            -authenticateWithCredSSP:$authenticateWithCredSSP `
            -imageName $imageName `
            -machineName $machineName `
            -hypervHost $hypervHost `
            -vhdxTemplatePath $vhdxTemplatePath `
            -hypervHostVmStoragePath $hypervHostVmStoragePath `
            -configPath $configPath `
            -staticMacAddress $staticMacAddress `
            -provisioningBootstrapUrl "$($consulBaseUrl)/v1/kv/$($keyPath)" `
            @commonParameterSwitches

        Write-Verbose "Connected to $computerName via $($connection.Session.Name)"

        $testWindowsResource = Join-Path $PSScriptRoot 'Test-WindowsResource.ps1'
        & $testWindowsResource -session $connection.Session -testDirectory $testDirectory -logDirectory $logDirectory
    }
    catch
    {
        Write-Output "Test failed: Error was: $($_.Exception.ToString())"
        throw $_.Exception.Message;
    }
    finally
    {
        # Stop consul
        $consulProcess.Kill()
    }
}
catch
{
    Write-Output "Test failed: Error was: $($_.Exception.ToString())"
    throw $_.Exception.Message;
}
finally
{
    try
    {
        Close-FirewallPort -port $basePort @commonParameterSwitches
    }
    catch
    {

    }

    # Stop the VM
    try
    {
        Stop-VM `
            -ComputerName $hypervHost `
            -Name $machineName `
            -Force `
            @commonParameterSwitches
    }
    catch
    {
        Write-Output "Stopping VM failed: Error was: $($_.Exception.ToString())"
    }

    # Delete the VM. If the delete goes wrong we want to know, because we'll have a random VM
    # trying to do stuff on the environment.
    Remove-VM `
        -computerName $hypervHost `
        -Name $machineName `
        -Force `
        @commonParameterSwitches
}