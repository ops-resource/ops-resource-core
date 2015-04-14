# Load the System.Web assembly otherwise Powershell can't find the System.Web.HttpUtility class
Add-Type -AssemblyName System.Web

function ConvertFrom-ConsulEncodedValue
{
    [CmdletBinding()]
    param(
        [string] $encodedValue
    )

    return [System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($encodedValue))
}

function Get-ConsulMetaServer
{
    [CmdletBinding()]
    param(
        [string] $consulLocalAddress = "http://$($env:ComputerName):8500"
    )

    # Go to the local consul node and get the address and the data center for the meta server
    $consulHttpUri = "$consulLocalAddress/v1/kv/environment/meta/http"
    $consulHttpResponse = Invoke-WebRequest -Uri $consulHttpUri
    $json = ConvertFrom-Json -InputObject $consulHttpResponse
    $consulHttp = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value

    $consulDataCenterUri = "$consulLocalAddress/v1/kv/environment/meta/datacenter"
    $consulDataCenterResponse = Invoke-WebRequest -Uri $consulDataCenterUri
    $json = ConvertFrom-Json -InputObject $consulDataCenterResponse
    $consulDataCenter = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value

    $result = New-Object psobject
    Add-Member -InputObject $result -MemberType NoteProperty -Name DataCenter -Value $consulDataCenter
    Add-Member -InputObject $result -MemberType NoteProperty -Name Http -Value $consulHttp

    return $result
}

function Get-ConsulTargetEnvironmentData
{
    [CmdletBinding()]
    param(
        [string] $environment = 'staging',
        [string] $consulLocalAddress = "http://$($env:ComputerName):8500"
    )

    $lowerCaseEnvironment = $environment.ToLower()

    # Go to the local consul node and get the address and the data center for the meta server
    $meta = Get-ConsulMetaServer -consulLocalAddress $consulLocalAddress

    # Get the name of the datacenter for our environment (e.g. the production environment is in the MyCompany-MyLocation01 datacenter)
    $consulDataCenterUri = "$($meta.Http)/v1/kv/environment/$lowerCaseEnvironment/datacenter?dc=$([System.Web.HttpUtility]::UrlEncode($meta.DataCenter))"
    $consulDataCenterResponse = Invoke-WebRequest -Uri $consulDataCenterUri
    $json = ConvertFrom-Json -InputObject $consulDataCenterResponse
    $consulDataCenter = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value

    # Get the http URL
    $consulHttpUri = "$($meta.Http)/v1/kv/environment/$lowerCaseEnvironment/http?dc=$([System.Web.HttpUtility]::UrlEncode($meta.DataCenter))"
    $consulHttpResponse = Invoke-WebRequest -Uri $consulHttpUri
    $json = ConvertFrom-Json -InputObject $consulHttpResponse
    $consulHttp = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value

    # Get the DNS URL
    $consulDnsUri = "$($meta.Http)/v1/kv/environment/$lowerCaseEnvironment/dns?dc=$([System.Web.HttpUtility]::UrlEncode($meta.DataCenter))"
    $consulDnsResponse = Invoke-WebRequest -Uri $consulDnsUri
    $json = ConvertFrom-Json -InputObject $consulDnsResponse
    $consulDns = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value

    # Get the serf_lan URL
    $consulSerfLanUri = "$($meta.Http)/v1/kv/environment/$lowerCaseEnvironment/serf_lan?dc=$([System.Web.HttpUtility]::UrlEncode($meta.DataCenter))"
    $consulSerfLanResponse = Invoke-WebRequest -Uri $consulSerfLanUri
    $json = ConvertFrom-Json -InputObject $consulSerfLanResponse
    $consulSerfLan = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value

    # Get the serf_wan URL
    $consulSerfWanUri = "$($meta.Http)/v1/kv/environment/$lowerCaseEnvironment/serf_wan?dc=$([System.Web.HttpUtility]::UrlEncode($meta.DataCenter))"
    $consulSerfWanResponse = Invoke-WebRequest -Uri $consulSerfWanUri
    $json = ConvertFrom-Json -InputObject $consulSerfWanResponse
    $consulSerfWan = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value

    # Get the server URL
    $consulServerUri = "$($meta.Http)/v1/kv/environment/$lowerCaseEnvironment/server?dc=$([System.Web.HttpUtility]::UrlEncode($meta.DataCenter))"
    $consulServerResponse = Invoke-WebRequest -Uri $consulServerUri
    $json = ConvertFrom-Json -InputObject $consulServerResponse
    $consulServer = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value

    $result = New-Object psobject
    Add-Member -InputObject $result -MemberType NoteProperty -Name DataCenter -Value $consulDataCenter
    Add-Member -InputObject $result -MemberType NoteProperty -Name Http -Value $consulHttp
    Add-Member -InputObject $result -MemberType NoteProperty -Name Dns -Value $consulDns
    Add-Member -InputObject $result -MemberType NoteProperty -Name SerfLan -Value $consulSerfLan
    Add-Member -InputObject $result -MemberType NoteProperty -Name SerfWan -Value $consulSerfWan
    Add-Member -InputObject $result -MemberType NoteProperty -Name Server -Value $consulServer

    return $result
}

function Get-GlobalDnsAddress
{
    [CmdletBinding()]
    param(
        [string] $environment = 'staging',
        [string] $consulLocalAddress = "http://$($env:ComputerName):8500"
    )

    $lowerCaseEnvironment = $environment.ToLower()

    # Go to the local consul node and get the address and the data center for the meta server
    $meta = Get-ConsulMetaServer -environment $environment -consulLocalAddress $consulLocalAddress

    # Get the DNS server fallback URL
    $dnsFallbackUri = "$($meta.Http)/v1/kv/environment/$lowerCaseEnvironment/dns_fallback?dc=$([System.Web.HttpUtility]::UrlEncode($meta.DataCenter))"
    $dnsFallbackResponse = Invoke-WebRequest -Uri $dnsFallbackUri
    $json = ConvertFrom-Json -InputObject $dnsFallbackResponse
    $dnsFallback = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value

    return $dnsFallback
}

function Get-ResourceNamesForService
{
    [CmdletBinding()]
    param(
        [string] $environment = 'staging',
        [string] $consulLocalAddress = "http://$($env:ComputerName):8500",
        [string] $service,
        [string] $tag = ''
    )

    $server = Get-ConsulTargetEnvironmentData -environment $environment -consulLocalAddress $consulLocalAddress

    $serviceUri = "$($server.Http)/v1/catalog/service/$($service)"
    if ($tag -ne '')
    {
        $serviceUri += "?tag=$([System.Web.HttpUtility]::UrlEncode($tag))"
    }

    $serviceResponse = Invoke-WebRequest -Uri $serviceUri
    $json = ConvertFrom-Json -InputObject $serviceResponse
    $serviceAddress = $json[0].Address

    return $serviceAddress
}

function Get-ConsulKeyValue
{
    [CmdletBinding()]
    param(
        [string] $environment = 'staging',
        [string] $consulLocalAddress = "http://$($env:ComputerName):8500",
        [string] $keyPath
    )

    $server = Get-ConsulTargetEnvironmentData -environment $environment -consulLocalAddress $consulLocalAddress

    $keyUri = "$($server.Http)/v1/kv/$($keyPath)?dc=$([System.Web.HttpUtility]::UrlEncode($server.DataCenter))"

    $keyResponse = Invoke-WebRequest -Uri $keyUri
    $json = ConvertFrom-Json -InputObject $keyResponse
    $value = ConvertFrom-ConsulEncodedValue -encodedValue $json.Value

    return $value
}