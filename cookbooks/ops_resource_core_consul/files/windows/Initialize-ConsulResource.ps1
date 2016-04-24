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
    }
}

# -------------------------- Script start ------------------------------------

[ConsulProvisioner]::New('consul', $commonParameterSwitches)
