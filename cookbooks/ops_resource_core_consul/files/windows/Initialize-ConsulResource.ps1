[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$commonParameterSwitches =
    @{
        Verbose = $PSBoundParameters.ContainsKey('Verbose');
        Debug = $false;
        ErrorAction = "Stop"
    }

# -------------------------- Script classes --------------------------------

class ConsulProvisioner
{
    [hashtable] $commonParameterSwitches
    [string] $serviceName

    ConsulProvisioner ([string] $serviceName, [hashtable] $commonParameterSwitches)
    {
        $this.serviceName = $serviceName
        $this.commonParameterSwitches = $commonParameterSwitches
    }

    [string] ResourceName()
    {
        return 'Consul'
    }

    [string[]] Dependencies()
    {
        return @( 'Meta', 'Provisioning' )
    }

    [void] Provision([psobject] $configuration)
    {
        # Update the consul configuration
        $configPath = 'c:\ops\consul\bin\consul_default.json'
        $templatePath = 'c:\meta\consultemplate\templates\consul\consul_default.json.ctmpl'

        $json = ConvertFrom-Json -InputObject (Get-Content -Path $configPath)  @($this.commonParameterSwitches)
        $json.datacenter = $configuration.consul_datacenter
        $json.recursors = $configuration.consul_recursors
        $json.retry_join = $configuration.consul_lanservers

        if ($configuration.consul_isserver)
        {
            $json.bootstrap_expect = $configuration.consul_numberofservers
            $json.server = $true
            $json.domain = $configuration.consul_domain

            $addresses = New-Object psobject -Property @{
                dns = $this.MachineIp()
            }
            $json.addresses = $addresses

            $json.retry_join_wan = $configuration.consul_wanservers
        }

        ConvertTo-Json -InputObject $json | Out-File -FilePath $configPath -Force -NoNewline @($this.commonParameterSwitches)








        # overwrite some of the values with consul template parameters
        ConvertTo-Json -InputObject $json | Out-File -FilePath $templatePath -Force -NoNewline @($this.commonParameterSwitches)












        # Make sure the service starts automatically when the machine starts, and then start the service if required
        Set-Service `
            -Name $this.serviceName `
            -StartupType Automatic `
            @($this.commonParameterSwitches)

        $service = Get-Service -Name $this.serviceName @($this.commonParameterSwitches)
        if ($service.Status -ne 'Running')
        {
            Start-Service -Name $this.serviceName @($this.commonParameterSwitches)
        }








        # Start the consultemplate service








    }

    [string] MachineIp()
    {
        $result = ''
        $adapters = Get-NetAdapter @($this.commonParameterSwitches)
        foreach($adapter in $adapters)
        {
            if ($adapter.Status -ne 'Up')
            {
                continue
            }

            $address = Get-NetIPAddress -InterfaceAlias $adapter.InterfaceAlias |
                Where-Object { $_.AddressFamily -ne 'IPv6' }

            if (($address -ne $null) -and ($address -ne ''))
            {
                $result = $address.IPAddress
                break
            }
        }

        return $result
    }
}

# -------------------------- Script start ------------------------------------

[ConsulProvisioner]::New('consul', $commonParameterSwitches)
