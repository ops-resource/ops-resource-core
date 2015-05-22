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

    Converts the value into a base-64 encoded string.


    .DESCRIPTION

    The ConvertTo-ConsulEncodedValue function converts the value into a base-64 encoded string.


    .PARAMETER encodedValue

    The input data.


    .OUTPUTS

    The base-64 encoded data.
#>
function ConvertTo-ConsulEncodedValue
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $value
    )

    Write-Verbose "ConvertTo-ConsulEncodedValue - value: $value"

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    return [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($value))
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

    Gets the DNS recursor address that will be used by consul to resolve DNS queries outside the consul domain.


    .DESCRIPTION

    The Get-DnsFallbackIp function gets the DNS recursor address that will be used by consul to
    resolve DNS queries outside the consul domain.


    .PARAMETER environment

    The name of the environment for which the key value should be returned.


    .PARAMETER consulLocalAddress

    The URL to the local consul agent.


    .OUTPUTS

    The IP or address of the DNS server that will be used to by consul to resolve DNS queries from outside the consul domain.
#>
function Get-DnsFallbackIp
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $environment = 'staging',

        [ValidateNotNullOrEmpty()]
        [string] $consulLocalAddress = "http://$($env:ComputerName):8500"
    )

    Write-Verbose "Get-DnsFallbackIp - environment: $environment"
    Write-Verbose "Get-DnsFallbackIp - consulLocalAddress: $consulLocalAddress"

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

<#
    .SYNOPSIS

    Adds an external service to the given consul environment.


    .DESCRIPTION

    The Set-ConsulExternalService function adds an external service to the given consul environment


    .PARAMETER environment

    The name of the environment to which the external service should be added.


    .PARAMETER httpUrl

    The URL to one of the consul agents. Defaults to the localhost address.


    .PARAMETER dataCenter

    The URL to the local consul agent.


    .PARAMETER serviceName

    The name of the service that should be added.


    .PARAMETER serviceUrl

    The URL of the service that should be added.
#>
function Set-ConsulExternalService
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [Parameter(ParameterSetName='ByName')]
        [string] $environment = 'staging',

        [ValidateNotNullOrEmpty()]
        [string] $httpUrl = "http://localhost:8500",

        [ValidateNotNullOrEmpty()]
        [Parameter(ParameterSetName='ByUrl')]
        [string] $dataCenter,

        [ValidateNotNullOrEmpty()]
        [string] $serviceName,

        [ValidateNotNullOrEmpty()]
        [string] $serviceUrl
    )

    switch ($PsCmdlet.ParameterSetName)
    {
        "ByName"
        {
            $server = Get-ConsulTargetEnvironmentData -environment $environment -consulLocalAddress $httpUrl @commonParameterSwitches
            $url = $server.Http
            $dc = $server.DataCenter
        }
        "ByUrl"
        {
            $url = $httpUrl
            $dc = $dataCenter
        }
    }

    $value = @"
{
  "Datacenter": "$dataCenter",
  "Node": "$serviceName",
  "Address": "$serviceUrl",
  "Service": {
    "Service": "$serviceName",
    "Address": "$serviceUrl"
  }
}
"@

    $uri = "$($url)/v1/catalog/register?dc=$([System.Web.HttpUtility]::UrlEncode($dc))"
    $response = Invoke-WebRequest -Uri $uri -Method Put -Body $value -UseBasicParsing @commonParameterSwitches
    if ($response.StatusCode -ne 200)
    {
        throw "Failed to add external service [$serviceName - $serviceUrl] on [$dc]"
    }
}

<#
    .SYNOPSIS

    Sets a key-value pair on the given consul environment.


    .DESCRIPTION

    The Set-ConsulKeyValue function sets a key-value pair on the given consul environment.


    .PARAMETER environment

    The name of the environment on which the key value should be set.


    .PARAMETER httpUrl

    The URL to one of the consul agents. Defaults to the localhost address.


    .PARAMETER dataCenter

    The URL to the local consul agent.


    .PARAMETER keyPath

    The path to the key that should be set


    .PARAMETER value

    The value that should be set.
#>
function Set-ConsulKeyValue
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [Parameter(ParameterSetName='ByName')]
        [string] $environment = 'staging',

        [ValidateNotNullOrEmpty()]
        [string] $httpUrl = "http://localhost:8500",

        [ValidateNotNullOrEmpty()]
        [Parameter(ParameterSetName='ByUrl')]
        [string] $dataCenter,

        [ValidateNotNullOrEmpty()]
        [string] $keyPath,

        [ValidateNotNullOrEmpty()]
        [string] $value
    )

    switch ($PsCmdlet.ParameterSetName)
    {
        "ByName"
        {
            $server = Get-ConsulTargetEnvironmentData -environment $environment -consulLocalAddress $httpUrl @commonParameterSwitches
            $url = $server.Http
            $dc = $server.DataCenter
        }
        "ByUrl"
        {
            $url = $httpUrl
            $dc = $dataCenter
        }
    }

    $uri = "$($url)/v1/kv/$($keyPath)?dc=$([System.Web.HttpUtility]::UrlEncode($dc))"
    $response = Invoke-WebRequest -Uri $uri -Method Put -Body $value -UseBasicParsing @commonParameterSwitches
    if ($response.StatusCode -ne 200)
    {
        throw "Failed to set Key-Value pair [$keyPath] - [$value] on [$dc]"
    }
}

function Set-ConsulMetaServer
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [Parameter(ParameterSetName='ByName')]
        [string] $environment = 'staging',

        [ValidateNotNullOrEmpty()]
        [Parameter(ParameterSetName='ByName')]
        [string] $consulLocalAddress = "http://$($env:ComputerName):8500",

        [ValidateNotNullOrEmpty()]
        [Parameter(ParameterSetName='ByUrl')]
        [string] $dataCenter,

        [ValidateNotNullOrEmpty()]
        [Parameter(ParameterSetName='ByUrl')]
        [string] $httpUrl,

        [ValidateNotNullOrEmpty()]
        [string] $metaDataCenter,

        [ValidateNotNullOrEmpty()]
        [string] $metaHttpUrl
    )

    switch ($PsCmdlet.ParameterSetName)
    {
        "ByName"
        {
            Set-ConsulKeyValue `
                -environment $environment `
                -consulLocalAddress $consulLocalAddress `
                -keyPath 'environment/meta/datacenter' `
                -value $metaDataCenter `
                @commonParameterSwitches

            Set-ConsulKeyValue `
                -environment $environment `
                -consulLocalAddress $consulLocalAddress `
                -keyPath 'environment/meta/http' `
                -value $metaHttpUrl `
                @commonParameterSwitches
        }
        "ByUrl"
        {
            Set-ConsulKeyValue `
                -dataCenter $datacenter `
                -httpUrl $httpUrl `
                -keyPath 'environment/meta/datacenter' `
                -value $metaDataCenter `
                @commonParameterSwitches

            Set-ConsulKeyValue `
                -dataCenter $datacenter `
                -httpUrl $httpUrl `
                -keyPath 'environment/meta/http' `
                -value $metaHttpUrl `
                @commonParameterSwitches
        }
    }

    # Go to the local consul node and get the address and the data center for the meta server

}

function Set-ConsulTargetEnvironmentData
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $metaDataCenter,

        [ValidateNotNullOrEmpty()]
        [string] $metaHttpUrl,

        [ValidateNotNullOrEmpty()]
        [string] $targetEnvironment = 'staging',

        [ValidateNotNullOrEmpty()]
        [string] $dataCenter,

        [ValidateNotNullOrEmpty()]
        [string] $httpUrl,

        [ValidateNotNullOrEmpty()]
        [string] $dnsUrl,

        [ValidateNotNullOrEmpty()]
        [string] $serfLanUrl,

        [ValidateNotNullOrEmpty()]
        [string] $serfWanUrl,

        [ValidateNotNullOrEmpty()]
        [string] $serverUrl
    )

    $lowerCaseEnvironment = $targetEnvironment.ToLower()

    # Set the name of the data center
    Set-ConsulKeyValue `
        -keyPath "environment/$lowerCaseEnvironment/datacenter" `
        -value $dataCenter `
        -dataCenter $metaDatacenter `
        -httpUrl $metaHttpUrl `
        @commonParameterSwitches

    # Set the http URL
    Set-ConsulKeyValue `
        -keyPath "environment/$lowerCaseEnvironment/http" `
        -value $httpUrl `
        -dataCenter $metaDatacenter `
        -httpUrl $metaHttpUrl `
        @commonParameterSwitches

    # Set the DNS URL
    Set-ConsulKeyValue `
        -keyPath "environment/$lowerCaseEnvironment/dns" `
        -value $dnsUrl `
        -dataCenter $metaDatacenter `
        -httpUrl $metaHttpUrl `
        @commonParameterSwitches

    # Set the serf_lan URL
    Set-ConsulKeyValue `
        -keyPath "environment/$lowerCaseEnvironment/serf_lan" `
        -value $serfLanUrl `
        -dataCenter $metaDatacenter `
        -httpUrl $metaHttpUrl `
        @commonParameterSwitches

    # Set the serf_wan URL
    Set-ConsulKeyValue `
        -keyPath "environment/$lowerCaseEnvironment/serf_wan" `
        -value $serfWanUrl `
        -dataCenter $metaDatacenter `
        -httpUrl $metaHttpUrl `
        @commonParameterSwitches

    # Set the server URL
    Set-ConsulKeyValue `
        -keyPath "environment/$lowerCaseEnvironment/server" `
        -value $serverUrl `
        -dataCenter $metaDatacenter `
        -httpUrl $metaHttpUrl `
        @commonParameterSwitches
}

function Set-DnsFallbackIp
{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [Parameter(ParameterSetName='ByName')]
        [string] $environment = 'staging',

        [ValidateNotNullOrEmpty()]
        [Parameter(ParameterSetName='ByName')]
        [string] $consulLocalAddress = "http://$($env:ComputerName):8500",

        [ValidateNotNullOrEmpty()]
        [Parameter(ParameterSetName='ByUrl')]
        [string] $dataCenter,

        [ValidateNotNullOrEmpty()]
        [Parameter(ParameterSetName='ByUrl')]
        [string] $httpUrl,

        [ValidateNotNullOrEmpty()]
        [string] $targetEnvironment,

        [ValidateNotNullOrEmpty()]
        [string] $dnsRecursorIP
    )

    $lowerCaseEnvironment = $targetEnvironment.ToLower()
    switch ($PsCmdlet.ParameterSetName)
    {
        "ByName"
        {
            Set-ConsulKeyValue `
                -environment $environment `
                -consulLocalAddress $consulLocalAddress `
                -keyPath "environment/$lowerCaseEnvironment/dns_fallback" `
                -value $dnsRecursorIP `
                @commonParameterSwitches
        }
        "ByUrl"
        {
            Set-ConsulKeyValue `
                -dataCenter $dataCenter `
                -httpUrl $httpUrl `
                -keyPath "environment/$lowerCaseEnvironment/dns_fallback" `
                -value $dnsRecursorIP `
                @commonParameterSwitches
        }
    }
}