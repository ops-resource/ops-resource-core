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


    .PARAMETER configurationUri

    The URI for the configuration server in the environment that the current resource is added to.


    .PARAMETER resourceNames

    An array containing the names of all the resources that need to be configured.


    .PARAMETER logPath

    The full path to the log file.


    .OUTPUTS

    A custom object describing the configuration. The object is expected to have the following properties:


#>
function Get-ConfigurationInformation
{
    [CmdletBinding()]
    param(
        [string] $configurationUri,
        [string[]] $resourceNames,
        [string] $logPath
    )

    Write-Output "Get-ConfigurationInformation - configurationUri: $configurationUri"
    Write-Output "Get-ConfigurationInformation - resourceNames: $resourceNames"
    Write-Output "Get-ConfigurationInformation - logPath: $logPath"

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = "Stop"
        }

    $configurationRequest = New-ConfigurationRequest `
        -resourceNames $resourceNames `
        @commonParameterSwitches

    $body = ConvertTo-Json $configurationRequest
    Write-Log `
        -message "Requesting configuration information from $($configurationUri) ..." `
        -logPath $logPath `
        @commonParameterSwitches

    $response = Invoke-WebRequest `
        -Uri $configurationUri `
        -Method Get `
        -Body $body `
        -ContentType 'application/json' `
        -UseDefaultCredentials `
        -UseBasicParsing `
        @commonParameterSwitches

    if ($response.StatusCode -ne 200)
    {
        $text = "Failed to get configuration data from server. Response was $($response.StatusCode)"
        Write-Log `
            -message $text `
            -logPath $logPath `
            @commonParameterSwitches

        throw $text
    }

    $json = ConvertFrom-Json -InputObject $response.Content @commonParameterSwitches
    Write-Log `
        -message "Successfully received configuration" `
        -logPath $logPath `
        @commonParameterSwitches

    return $json
}

<#
    .SYNOPSIS

    Gets information describing the environment that the current resource should be connected to.


    .DESCRIPTION

    The Get-EnvironmentInformation function gets the information that describes the environment to which the current resource should be connected.


    .PARAMETER logPath

    The full path to the log file.


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
        [string] $logPath
    )

    Write-Output "Get-EnvironmentInformation - logPath: $logPath"

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
        $text = 'Failed to get the environment request URI. This may mean that there is no environment yet.'
        Write-Log `
            -message $text `
            -logPath $logPath `
            @commonParameterSwitches

        throw $text
    }

    $machineIdentifiers = New-MachineIdentifiers `
        @commonParameterSwitches

    $body = ConvertTo-Json $machineIdentifiers
    Write-Log `
        -message "Requesting environment information from $($provisioningBaseUri) ..." `
        -logPath $logPath `
        @commonParameterSwitches

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
        $text = "Failed to get configuration data from server. Response was $($response.StatusCode)"
        Write-Log `
            -message $text `
            -logPath $logPath `
            @commonParameterSwitches

        throw $text
    }

    $json = ConvertFrom-Json -InputObject $response.Content @commonParameterSwitches

    Write-Log `
        -message "Successfully obtained environment information" `
        -logPath $logPath `
        @commonParameterSwitches

    return $json
}

<#
    .SYNOPSIS

    Extracts the name of a resource from the provisioning script for that resource.


    .DESCRIPTION

    The Get-ResourceNameFromProvisioningScript function extracts the name of a resource from the provisioning script for that resource.


    .PARAMETER provisioningScript

    The full path to the provisioning script. The script file name is expected to match the pattern: Initialize-<RESOURCE_NAME>Resource.ps1


    .OUTPUTS

    The name of the resource that is configured by the script.
#>
function Get-ResourceNameFromProvisioningScript
{
    [CmdletBinding()]
    param(
        [string] $provisioningScript
    )

    Write-Output "Get-ResourceNameFromProvisioningScript - provisioningScript: $provisioningScript"

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = "Stop"
        }

    # Extract the resource name from the provisioning script name. The script name is expected
    # to be Initialize-<RESOURCE_NAME>Resource.ps1
    $regexFilter = '(?:Initialize-)(.+)(?:Resource\.ps1)'

    if ([System.IO.Path]::GetFileName($provisioningScript) -match $regexFilter)
    {
        return $Matches[1]
    }
    else
    {
        return ''
    }
}

<#
    .SYNOPSIS

    Creates a new custom object containing the information about the resources that should be configured.


    .DESCRIPTION

    The New-ConfigurationRequest function creates a new custom object containing the information about the resources that should be configured.


    .PARAMETER resourceNames

    An array containing the names of all the resources that need to be configured.


    .OUTPUTS

    A custom object containing the information regarding the resources that should be configured.
#>
function New-ConfigurationRequest
{
    [CmdletBinding()]
    param(
        [string[]] $resourceNames
    )

    Write-Output "New-ConfigurationRequest - resourceNames: $resourceNames"

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = "Stop"
        }

    $result = New-Object psobject
    Add-Member -InputObject $result -MemberType NoteProperty -Name Resources -Value $resourceNames

    return $result
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

<#
    .SYNOPSIS

    Writes the given message to the given log file.


    .DESCRIPTION

    The Write-Log function writes the given message to the given log file.


    .PARAMETER message

    The message that should be written to the file.


    .PARAMETER logPath

    The full path to the log file that the message should be written to.
#>
function Write-Log
{
    [CmdletBinding()]
    param(
        [string] $message,
        [string] $logPath
    )

    Write-Output "Write-Log - message: $message"
    Write-Output "Write-Log - logPath: $logPath"

    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $false;
            ErrorAction = "Stop"
        }

    Out-File -FilePath $logPath -Append -InputObject "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') - $($message)" @commonParameterSwitches
}

# -------------------------- Script start ------------------------------------

try
{
    $logPath = 'c:\logs\provisioning\initialize-resource.log'
    [psobject] $configurationInformation = $null
    try
    {
        $environmentInformation = Get-EnvironmentInformation `
            -logPath $logPath `
            @commonParameterSwitches

        $scriptPath = Split-Path -Path $PSScriptRoot -Parent @commonParameterSwitches
        $scriptsToExecute = Get-ChildItem -Path $scriptPath -Filter 'Initialize-*Resource.ps1' -File
        $resourceNames = @()
        foreach($script in $scriptsToExecute)
        {
            $resourceName = Get-ResourceNameFromProvisioningScript `
                -provisioningScript $_.Name `
                @commonParameterSwitches
            if ($resourceName -ne '')
            {
                $resourceNames += $resourceName
            }
        }

        $configurationInformation = Get-ConfigurationInformation `
            -configurationUri $environmentInformation.ConfigurationUri `
            -resourceNames $resourceNames `
            -logPath $logPath `
            @commonParameterSwitches
    }
    catch
    {
        # Connecting to the configuration server failed. This may be due to a network issue, a missing
        # configuration server or due to the fact that the provisioning step is run for the first resource
        # in the environment(s). In this case we use the default values.
        Write-Log `
            -message "Failed to acquire configuration information. This may mean that no environment is defined. Provisioning scripts will run with default values." `
            -logPath $logPath `
            @commonParameterSwitches
    }

    foreach($script in $scriptsToExecute)
    {
        try
        {
            $configuration = $null

            $resourceName = Get-ResourceNameFromProvisioningScript `
                -provisioningScript $script.Name `
                @commonParameterSwitches
            if (($resourceName -ne '') -and ($configurationInformation -ne $null))
            {
                $configuration = $configurationInformation."$resourceName"
            }

            Write-Log `
                -message "Invoking provisioning for the $($resourceName) through $($script) ..." `
                -logPath $logPath `
                @commonParameterSwitches

            & $script `
                -configuration $configuration `
                @commonParameterSwitches
        }
        catch
        {
             Write-Log `
                -message "Failure during the invocation of $($script). Error was: $($_.Exception.ToString())" `
                -logPath $logPath `
                @commonParameterSwitches
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


