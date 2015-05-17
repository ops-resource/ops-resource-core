# Load the System.Web assembly otherwise Powershell can't find the System.Web.HttpUtility class
Add-Type -AssemblyName System.Web

<#
    .SYNOPSIS

    Converts the base-64 encoded value to the original data.


    .DESCRIPTION

    The ConvertFrom-ConsulEncodedValue function converts the base-64 encoded value to the original data.


    .PARAMETER encodedValue

    The base-64 encoded data.


    .OUTPUTS

    The decoded data.
#>
function ConvertFrom-ConsulEncodedValue
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $encodedValue
    )

    Write-Verbose "ConvertFrom-ConsulEncodedValue - encodedValue: $encodedValue"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    return [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($encodedValue))
}

<#
    .SYNOPSIS

    Gets the value for a given key from the key-value storage on a given data center.


    .DESCRIPTION

    The Get-ConsulKeyValue function gets the value for a given key from the key-value storage on a given data center.


    .PARAMETER environment

    The name of the environment for which the key value should be returned.


    .PARAMETER consulLocalAddress

    The URL to the local consul agent.


    .PARAMETER keyPath

    The path to the key for which the value is to be retrieved.


    .OUTPUTS

    The data that was stored under the given key.
#>
function Get-ConsulKeyValue
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $environment = 'staging',

        [ValidateNotNullOrEmpty()]
        [string] $consulLocalAddress = "http://$($env:ComputerName):8500",

        [ValidateNotNullOrEmpty()]
        [string] $keyPath
    )

    Write-Verbose "Get-ConsulKeyValue - environment: $environment"
    Write-Verbose "Get-ConsulKeyValue - consulLocalAddress: $consulLocalAddress"
    Write-Verbose "Get-ConsulKeyValue - keyPath: $keyPath"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    $server = Get-ConsulTargetEnvironmentData -environment $environment -consulLocalAddress $consulLocalAddress @commonParameterSwitches

    $keyUri = "$($server.Http)/v1/kv/$($keyPath)?dc=$([System.Web.HttpUtility]::UrlEncode($server.DataCenter))"

    $keyResponse = Invoke-WebRequest -Uri $keyUri -UseBasicParsing @commonParameterSwitches
    $json = ConvertFrom-Json -InputObject $keyResponse @commonParameterSwitches
    $value = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value @commonParameterSwitches

    return $value
}

<#
    .SYNOPSIS

    Gets the URL of the consul meta server.


    .DESCRIPTION

    The Get-ConsulMetaServer function gets the URL of the consul meta server.


    .PARAMETER consulLocalAddress

    The URL to the local consul agent.


    .OUTPUTS

    A custom object containing the information about the consul meta server. The object contains
    the following properties:

        DataCenter
        Http
#>
function Get-ConsulMetaServer
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $consulLocalAddress = "http://$($env:ComputerName):8500"
    )

    Write-Verbose "Get-ConsulMetaServer - consulLocalAddress: $consulLocalAddress"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    # Go to the local consul node and get the address and the data center for the meta server
    $consulHttpUri = "$consulLocalAddress/v1/kv/environment/meta/http"
    $consulHttpResponse = Invoke-WebRequest -Uri $consulHttpUri -UseBasicParsing @commonParameterSwitches
    $json = ConvertFrom-Json -InputObject $consulHttpResponse @commonParameterSwitches
    $consulHttp = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value @commonParameterSwitches

    $consulDataCenterUri = "$consulLocalAddress/v1/kv/environment/meta/datacenter"
    $consulDataCenterResponse = Invoke-WebRequest -Uri $consulDataCenterUri -UseBasicParsing @commonParameterSwitches
    $json = ConvertFrom-Json -InputObject $consulDataCenterResponse @commonParameterSwitches
    $consulDataCenter = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value @commonParameterSwitches

    $result = New-Object psobject
    Add-Member -InputObject $result -MemberType NoteProperty -Name DataCenter -Value $consulDataCenter
    Add-Member -InputObject $result -MemberType NoteProperty -Name Http -Value $consulHttp

    return $result
}

<#
    .SYNOPSIS

    Gets the connection information for a given environment.


    .DESCRIPTION

    The Get-ConsulTargetEnvironmentData function gets the connection information for a given environment.


    .PARAMETER environment

    The name of the environment for which the key value should be returned.


    .PARAMETER consulLocalAddress

    The URL to the local consul agent.


    .OUTPUTS

    A custom object containing the information about the consul cluser for the given environment. The object
    contains the following properties:

        DataCenter
        Http
        Dns
        SerfLan
        SerfWan
        Server
#>
function Get-ConsulTargetEnvironmentData
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $environment = 'staging',

        [ValidateNotNullOrEmpty()]
        [string] $consulLocalAddress = "http://$($env:ComputerName):8500"
    )

    Write-Verbose "Get-ConsulTargetEnvironmentData - environment: $environment"
    Write-Verbose "Get-ConsulTargetEnvironmentData - consulLocalAddress: $consulLocalAddress"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    $lowerCaseEnvironment = $environment.ToLower()

    # Go to the local consul node and get the address and the data center for the meta server
    $meta = Get-ConsulMetaServer -consulLocalAddress $consulLocalAddress @commonParameterSwitches

    # Get the name of the datacenter for our environment (e.g. the production environment is in the MyCompany-MyLocation01 datacenter)
    $consulDataCenterUri = "$($meta.Http)/v1/kv/environment/$lowerCaseEnvironment/datacenter?dc=$([System.Web.HttpUtility]::UrlEncode($meta.DataCenter))"
    $consulDataCenterResponse = Invoke-WebRequest -Uri $consulDataCenterUri -UseBasicParsing @commonParameterSwitches
    $json = ConvertFrom-Json -InputObject $consulDataCenterResponse @commonParameterSwitches
    $consulDataCenter = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value @commonParameterSwitches

    # Get the http URL
    $consulHttpUri = "$($meta.Http)/v1/kv/environment/$lowerCaseEnvironment/http?dc=$([System.Web.HttpUtility]::UrlEncode($meta.DataCenter))"
    $consulHttpResponse = Invoke-WebRequest -Uri $consulHttpUri -UseBasicParsing @commonParameterSwitches
    $json = ConvertFrom-Json -InputObject $consulHttpResponse @commonParameterSwitches
    $consulHttp = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value @commonParameterSwitches

    # Get the DNS URL
    $consulDnsUri = "$($meta.Http)/v1/kv/environment/$lowerCaseEnvironment/dns?dc=$([System.Web.HttpUtility]::UrlEncode($meta.DataCenter))"
    $consulDnsResponse = Invoke-WebRequest -Uri $consulDnsUri -UseBasicParsing @commonParameterSwitches
    $json = ConvertFrom-Json -InputObject $consulDnsResponse @commonParameterSwitches
    $consulDns = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value @commonParameterSwitches

    # Get the serf_lan URL
    $consulSerfLanUri = "$($meta.Http)/v1/kv/environment/$lowerCaseEnvironment/serf_lan?dc=$([System.Web.HttpUtility]::UrlEncode($meta.DataCenter))"
    $consulSerfLanResponse = Invoke-WebRequest -Uri $consulSerfLanUri -UseBasicParsing @commonParameterSwitches
    $json = ConvertFrom-Json -InputObject $consulSerfLanResponse @commonParameterSwitches
    $consulSerfLan = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value @commonParameterSwitches

    # Get the serf_wan URL
    $consulSerfWanUri = "$($meta.Http)/v1/kv/environment/$lowerCaseEnvironment/serf_wan?dc=$([System.Web.HttpUtility]::UrlEncode($meta.DataCenter))"
    $consulSerfWanResponse = Invoke-WebRequest -Uri $consulSerfWanUri -UseBasicParsing @commonParameterSwitches
    $json = ConvertFrom-Json -InputObject $consulSerfWanResponse @commonParameterSwitches
    $consulSerfWan = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value @commonParameterSwitches

    # Get the server URL
    $consulServerUri = "$($meta.Http)/v1/kv/environment/$lowerCaseEnvironment/server?dc=$([System.Web.HttpUtility]::UrlEncode($meta.DataCenter))"
    $consulServerResponse = Invoke-WebRequest -Uri $consulServerUri -UseBasicParsing @commonParameterSwitches
    $json = ConvertFrom-Json -InputObject $consulServerResponse @commonParameterSwitches
    $consulServer = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value @commonParameterSwitches

    $result = New-Object psobject
    Add-Member -InputObject $result -MemberType NoteProperty -Name DataCenter -Value $consulDataCenter
    Add-Member -InputObject $result -MemberType NoteProperty -Name Http -Value $consulHttp
    Add-Member -InputObject $result -MemberType NoteProperty -Name Dns -Value $consulDns
    Add-Member -InputObject $result -MemberType NoteProperty -Name SerfLan -Value $consulSerfLan
    Add-Member -InputObject $result -MemberType NoteProperty -Name SerfWan -Value $consulSerfWan
    Add-Member -InputObject $result -MemberType NoteProperty -Name Server -Value $consulServer

    return $result
}

<#
    .SYNOPSIS

    Gets the name of the environment that the local node belongs to.


    .DESCRIPTION

    The Get-EnvironmentForLocalNode function gets the name of the environment that the local node belongs to.


    .PARAMETER consulLocalAddress

    The URL to the local consul agent.


    .OUTPUTS

    The name of the environment that the local node belongs to.
#>
function Get-EnvironmentForLocalNode
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $consulLocalAddress = "http://$($env:ComputerName):8500"
    )

    Write-Verbose "Get-EnvironmentForLocalNode - consulLocalAddress: $consulLocalAddress"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    # Get the DC for the local node
    $serviceUri = "$($consulLocalAddress)/v1/agent/self"
    $serviceResponse = Invoke-WebRequest -Uri $serviceUri -UseBasicParsing @commonParameterSwitches
    if ($serviceResponse.StatusCode -ne 200)
    {
        throw "Server did not return information about the local Consul node."
    }

    $json = ConvertFrom-Json -InputObject $serviceResponse @commonParameterSwitches
    $dataCenter = $json.Config.Datacenter

    # Go to the meta node and find out which DC belongs to which environment. Note that we're doing this the nasty way
    # because we can't iterate over http addresses
    $meta = Get-ConsulMetaServer -consulLocalAddress $consulLocalAddress @commonParameterSwitches
    $consulDataCenterUri = "$($meta.Http)/v1/kv/environment/meta/datacenter?dc=$([System.Web.HttpUtility]::UrlEncode($meta.DataCenter))"
    $consulDataCenterResponse = Invoke-WebRequest -Uri $consulDataCenterUri -UseBasicParsing @commonParameterSwitches
    $json = ConvertFrom-Json -InputObject $consulDataCenterResponse @commonParameterSwitches
    $metaDatacenter = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value @commonParameterSwitches
    if ($metaDataCenter -eq $dataCenter)
    {
        return 'meta'
    }

    $consulDataCenterUri = "$($meta.Http)/v1/kv/environment/production/datacenter?dc=$([System.Web.HttpUtility]::UrlEncode($meta.DataCenter))"
    $consulDataCenterResponse = Invoke-WebRequest -Uri $consulDataCenterUri -UseBasicParsing @commonParameterSwitches
    $json = ConvertFrom-Json -InputObject $consulDataCenterResponse @commonParameterSwitches
    $metaDatacenter = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value @commonParameterSwitches
    if ($metaDataCenter -eq $dataCenter)
    {
        return 'production'
    }

    $consulDataCenterUri = "$($meta.Http)/v1/kv/environment/staging/datacenter?dc=$([System.Web.HttpUtility]::UrlEncode($meta.DataCenter))"
    $consulDataCenterResponse = Invoke-WebRequest -Uri $consulDataCenterUri -UseBasicParsing @commonParameterSwitches
    $json = ConvertFrom-Json -InputObject $consulDataCenterResponse @commonParameterSwitches
    $metaDatacenter = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value @commonParameterSwitches
    if ($metaDataCenter -eq $dataCenter)
    {
        return 'staging'
    }

    return 'unknown'
}

<#
    .SYNOPSIS

    Gets the global DNS recursor address that will be used by consul to resolve DNS queries outside the consul domain.


    .DESCRIPTION

    The Get-GlobalDnsAddress function gets the global DNS recursor address that will be used by consul to
    resolve DNS queries outside the consul domain.


    .PARAMETER environment

    The name of the environment for which the key value should be returned.


    .PARAMETER consulLocalAddress

    The URL to the local consul agent.


    .OUTPUTS

    The IP or address of the DNS server that will be used to by consul to resolve DNS queries from outside the consul domain.
#>
function Get-GlobalDnsAddress
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $environment = 'staging',

        [ValidateNotNullOrEmpty()]
        [string] $consulLocalAddress = "http://$($env:ComputerName):8500"
    )

    Write-Verbose "Get-GlobalDnsAddress - environment: $environment"
    Write-Verbose "Get-GlobalDnsAddress - consulLocalAddress: $consulLocalAddress"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    $lowerCaseEnvironment = $environment.ToLower()

    # Go to the local consul node and get the address and the data center for the meta server
    $meta = Get-ConsulMetaServer -consulLocalAddress $consulLocalAddress @commonParameterSwitches

    # Get the DNS server fallback URL
    $dnsFallbackUri = "$($meta.Http)/v1/kv/environment/$lowerCaseEnvironment/dns_fallback?dc=$([System.Web.HttpUtility]::UrlEncode($meta.DataCenter))"
    $dnsFallbackResponse = Invoke-WebRequest -Uri $dnsFallbackUri -UseBasicParsing @commonParameterSwitches
    $json = ConvertFrom-Json -InputObject $dnsFallbackResponse @commonParameterSwitches
    $dnsFallback = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value @commonParameterSwitches

    return $dnsFallback
}

<#
    .SYNOPSIS

    Gets the IP address of the node providing the given service.


    .DESCRIPTION

    The Get-ResourceNamesForService function gets the IP address of the node providing the given service.


    .PARAMETER environment

    The name of the environment for which the key value should be returned.


    .PARAMETER consulLocalAddress

    The URL to the local consul agent.


    .PARAMETER service

    The name of the service


    .PARAMETER tag

    The (optional) tag.


    .OUTPUTS

    The IP or address of the node that provides the service.
#>
function Get-ResourceNamesForService
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $environment = 'staging',

        [ValidateNotNullOrEmpty()]
        [string] $consulLocalAddress = "http://$($env:ComputerName):8500",

        [ValidateNotNullOrEmpty()]
        [string] $service,

        [ValidateNotNull()]
        [string] $tag = ''
    )

    Write-Verbose "Get-ResourceNamesForService - environment: $environment"
    Write-Verbose "Get-ResourceNamesForService - consulLocalAddress: $consulLocalAddress"
    Write-Verbose "Get-ResourceNamesForService - service: $service"
    Write-Verbose "Get-ResourceNamesForService - tag: $tag"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    $server = Get-ConsulTargetEnvironmentData -environment $environment -consulLocalAddress $consulLocalAddress @commonParameterSwitches

    $serviceUri = "$($server.Http)/v1/catalog/service/$($service)"
    if ($tag -ne '')
    {
        $serviceUri += "?tag=$([System.Web.HttpUtility]::UrlEncode($tag))"
    }

    $serviceResponse = Invoke-WebRequest -Uri $serviceUri -UseBasicParsing @commonParameterSwitches
    $json = ConvertFrom-Json -InputObject $serviceResponse @commonParameterSwitches
    $serviceAddress = $json[0].Address

    return $serviceAddress
}

function Set-ConsulKeyValue
{}