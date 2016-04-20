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

try
{
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

    # send request to URL. Request should contain:
    # - container ID: e.g. machine MAC, container ID, etc. etc.
    # - resource ID: e.g. ops-resource-core, webserver etc.
    $body = ""
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

    $scriptPath = Split-Path -Path $PSScriptRoot -Parent @commonParameterSwitches
    $scriptsToExecute = Get-ChildItem -Path $scriptPath -Filter 'Initialize-*Resource.ps1' -File
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


