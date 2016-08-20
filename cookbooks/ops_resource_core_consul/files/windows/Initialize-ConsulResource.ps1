[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# -------------------------- Script classes --------------------------------

class ConsulProvisioner
{
    [string[]] Dependencies()
    {
        return @( 'Meta', 'Provisioning' )
    }

    [void] EnableAndStartService([string] $serviceName)
    {
        Set-Service `
            -Name $serviceName `
            -StartupType Automatic `
            -Verbose

        $service = Get-Service -Name $serviceName -Verbose
        if ($service.Status -ne 'Running')
        {
            Start-Service -Name $serviceName -Verbose
        }
    }

    [psobject] GetServiceMetadata([string] $serviceName)
    {
        $configPath = "c:\meta\service_$($serviceName).json"
        $json = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($configPath))  -Verbose

        return $json
    }

    [string] MachineIp()
    {
        $result = ''
        $adapters = Get-NetAdapter -Verbose
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

    [void] Configure([string] $configurationUrl)
    {
        $this.ConfigureConsul($configurationUrl)
        $this.ConfigureConsulTemplate($configurationUrl)
    }

    [void] ConfigureConsul([string] $configurationUrl)
    {
        $serviceName = 'consul'
        $response = Invoke-WebRequest `
            -Uri "$($configurationUrl)/environment" `
            -Method Get `
            -UseDefaultCredentials `
            -UseBasicParsing `
            -Verbose

        if ($response.StatusCode -ne 200)
        {
            throw "Failed to get configuration data from server. Response was $($response.StatusCode)"
        }

        $consulInformation = ConvertFrom-Json -InputObject $response.Content -Verbose
        $configuration = ConvertFrom-Json -InputObject ([System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($consulInformation.Value))) -Verbose

        $meta = $this.GetServiceMetadata($serviceName)
        $json = ConvertFrom-Json -InputObject ([System.IO.File]::ReadAllText($meta.service.application_config))  -Verbose
        $json.datacenter = $configuration.consul_datacenter
        $json.recursors = $configuration.consul_recursors
        $json.retry_join = $configuration.consul_lanservers

        # Clear the addresses and only set it if we're on a server
        $json.addresses = @()

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

        $textContent = ConvertTo-Json -InputObject $json
        Out-File -FilePath $meta.service.application_config -InputObject $textContent -Force -NoNewline -Verbose
    }

    [void] ConfigureConsulTemplate([string] $configurationUrl)
    {
        $metaConsul = $this.GetServiceMetadata('consul')
        $metaConsulTemplate = $this.GetServiceMetadata('consultemplate')

        # overwrite some of the values with consul template parameters
        $lines = Get-Content -Path $metaConsul.service.application_config
        for($i = 0; $i -lt $lines.Length; $i++)
        {
            $currentLine = $lines[$i]

            # Replace the values in the following sections in the consul config with the consultemplate parameters
            switch -Regex ($currentLine)
            {
                # "dns_config" : {
                #    "allow_stale" : true,
                #},
                '("allow_stale")(\s)?(:)(\s)?(\")' {
                    $lines[$i] = "`"allow_stale`" : {{key `"resource/$($env:COMPUTERNAME)/service/consul/config/dns/allowstale`"}},"
                }

                # "dns_config" : {
                #    "max_stale" : "30s",
                #},
                '("max_stale")(\s)?(:)(\s)?(\")' {
                    $lines[$i] = "`"max_stale`" : `"{{key `"resource/$($env:COMPUTERNAME)/service/consul/config/dns/maxstale`"}}`","
                }

                # "dns_config" : {
                #    "node_ttl" : "60s",
                #},
                '("node_ttl")(\s)?(:)(\s)?(\")' {
                    $lines[$i] = "`"node_ttl`" : `"{{key `"resource/$($env:COMPUTERNAME)/service/consul/config/dns/nodettl`"}}`","
                }

                # "dns_config" : {
                #        "service_ttl": {
                #        "*": "120s"
                #        }
                #    },
                '("\*")(\s)?(:)(\s)?(\")' {
                    $lines[$i] = "`"*`": `"{{key `"resource/$($env:COMPUTERNAME)/service/consul/config/dns/servicettl`"}}`""
                }

                # "log_level" : "debug"
                '("log_level")(\s)?(:)(\s)?(\")' {
                    $lines[$i] = "`"log_level`" : `"{{key `"resource/$($env:COMPUTERNAME)/service/consul/config/loglevel`"}}`""
                }
            }
        }

        Out-File -FilePath (Join-Path $metaConsulTemplate.Service.template_path 'consul_default.json.ctmpl') -InputObject $lines -Force -NoNewline -Verbose
    }

    [string] ResourceName()
    {
        return 'Consul'
    }

    [void] Start()
    {
        $this.StartConsul()
        $this.StartConsulTemplate()
    }

    [void] StartConsul()
    {
        $meta = $this.GetServiceMetadata('consul')
        $this.EnableAndStartService($meta.service.win_service)
    }

    [void] StartConsulTemplate()
    {
        $meta = $this.GetServiceMetadata('consultemplate')
        $this.EnableAndStartService($meta.service.win_service)
    }
}

# -------------------------- Script start ------------------------------------

[ConsulProvisioner]::New()
