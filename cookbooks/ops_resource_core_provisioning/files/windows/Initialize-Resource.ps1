<#
    .SYNOPSIS

    Executes all configuration and provisioning steps necessary to link the current resource to a given environment.


    .DESCRIPTION

    The Initialize-Resource script executes all configuration and provisioning steps necessary to link the current resource to a given environment.
    The configuration information is obtained by sending a GET request to a URI specified either in a custom
    JSON file in '<HOMEDRIVE>:\provisioning\provisioning.json' or by getting the content of the ProvisioningEntryPoint
    environment variable.

    It is expected that the JSON file has the following elements:

        {
            "entrypoint": "http://example.com/provisioning"
        }
#>
[Cmdletbinding()]
param(
)

# Stop everything if there are errors
$ErrorActionPreference = 'Stop'

$commonParameterSwitches =
    @{
        Verbose = $PSBoundParameters.ContainsKey('Verbose');
        Debug = $false;
        ErrorAction = "Stop"
    }

# -------------------------- Script functions --------------------------------

<#
    .SYNOPSIS

    Gets information describing the configuration of the current resource


    .DESCRIPTION

    The Get-ConfigurationInformation function gets information that describes the configuration of the current resource


    .OUTPUTS

    A custom object describing the configuration. The object is expected to have the following properties:

        Name
        ID
        ConfigurationUri
#>
function Get-ConfigurationInformation
{
    [CmdletBinding()]
    param(
        [string[]] $resourceNames
    )

    # send request to URL. Request should contain:
    # - container ID: e.g. machine MAC, container ID, etc. etc.
    # - resource ID: e.g. ops-resource-core, webserver etc.
    $configurationRequest = New-ConfigurationRequest `
        @commonParameterSwitches

    $body = ConvertTo-Json $configurationRequest
    $response = Invoke-WebRequest `
        -Uri $environmentInformation.ConfigurationUri `
        -Method Get `
        -Body $body `
        -ContentType 'application/json' `
        -UseDefaultCredentials `
        -UseBasicParsing `
        @commonParameterSwitches

    if ($response.StatusCode -ne 200)
    {
        Write-Error "Failed to get configuration data from server. Response was $($response.StatusCode)"
    }

    $json = ConvertFrom-Json -InputObject $response.Content @commonParameterSwitches
}

<#
    .SYNOPSIS

    Gets information describing the environment that the current resource should be connected to.


    .DESCRIPTION

    The Get-EnvironmentInformation function gets the information that describes the environment to which the current resource should be connected.


    .OUTPUTS

    A custom object describing the environment. The object is expected to have the following properties:

        Name
        ID
        ConfigurationUri
#>
function Get-EnvironmentInformation
{
    [CmdletBinding()]
    param(

    )

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = "Stop"
        }

    $provisioningBaseUri = ''

    $expectedConfigurationFile = Join-Path $env:HOMEDRIVE 'provisioning\provisioning.json'
    if (Test-Path $expectedConfigurationFile)
    {
        # Read configuration file
        $content = Get-Content -Path $expectedConfigurationFile @commonParameterSwitches
        $json = ConvertFrom-Json $content
        $provisioningBaseUri = $json.entrypoint
    }
    else
    {
        $provisioningBaseUri = $env:ProvisioningEntryPoint
    }

    if (($provisioningBaseUri -eq $null) -or ($provisioningBaseUri -eq ''))
    {
        throw
    }

    $environmentRequest = New-EnvironmentRequest `
        @commonParameterSwitches

    $body = ConvertTo-Json $environmentRequest
    $response = Invoke-WebRequest `
        -Uri $provisioningBaseUri `
        -Method Get `
        -Body $body `
        -ContentType 'application/json' `
        -UseDefaultCredentials `
        -UseBasicParsing `
        @commonParameterSwitches

    if ($response.StatusCode -ne 200)
    {
        Write-Error "Failed to get configuration data from server. Response was $($response.StatusCode)"
    }

    $json = ConvertFrom-Json -InputObject $response.Content @commonParameterSwitches

    # object that contains:
    # - Environment name
    # - Environment ID
    # - Uri / IP of the configuration server for the environment
}

function New-ConfigurationRequest
{
    [CmdletBinding()]
    param()

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = "Stop"
        }

    $result = New-Object psobject
    Add-Member -InputObject $result -MemberType NoteProperty -Name MachineId -Value ''
}

<#
    .SYNOPSIS

    Gets the MAC and IP addresses for all active network adapters.


    .DESCRIPTION

    The New-MachineIdentifiers function gets the information that describes the machine.


    .OUTPUTS

    An array containing custom objects that store the MacAddress and the IP address for all active network adapters on the machine.
#>
function New-MachineIdentifiers
{
    [CmdletBinding()]
    param()

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = "Stop"
        }

    $info = @()
    $adapters = Get-NetAdapter @commonParameterSwitches
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
            $result = New-Object psobject
            Add-Member -InputObject $result -MemberType NoteProperty -Name MacAddress -Value $adapter.MacAddress
            Add-Member -InputObject $result -MemberType NoteProperty -Name IPAddresses -Value $address

            $info += $result
        }
    }

    return $info
}

# -------------------------- Script start ------------------------------------

try
{
    $environmentInformation = Get-EnvironmentInformation `
        @commonParameterSwitches

    $scriptPath = Split-Path -Path $PSScriptRoot -Parent @commonParameterSwitches
    $scriptsToExecute = Get-ChildItem -Path $scriptPath -Filter 'Initialize-*Resource.ps1' -File

    $configurationInformation = Get-ConfigurationInformation `
        -resourceNames '' `
        @commonParameterSwitches
    foreach($script in $scriptsToExecute)
    {
        try
        {
            & $script `
                @commonParameterSwitches
        }
        catch
        {

        }
    }
}
finally
{
    try
    {
        Set-Service `
            -Name 'Provisioning' `
            -StartupType Disabled `
            @commonParameterSwitches

        Stop-Service `
            -Name 'Provisioning' `
            -NoWait `
            -Force `
            @commonParameterSwitches
    }
    catch
    {
        Write-Error "Failed to stop the service. Error was $($_.Exception.ToString())"
    }
}


