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

    The individual services will be provisioned by executing code in a separate provisioning script provided when the individual
    services are installed. The service provisioning script should be installed in the c:\ops\provisioning directory.
    Each script should return a class with the following members:

        class MyProvisioner
        {
            [string[]] Dependencies()
            {
                # return an array containing the names of all the resources we depend on
            }

            [void] Configure([string] $provisioningUrl)
            {
                # execute the provisioning code here
            }

            [string] ResourceName()
            {
                # return the name of the resource
            }

            [void] Start()
            {
                # execute the service starting code here
            }
        }
#>
[Cmdletbinding()]
param(
)

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

    Orders the provisioners in the list based on their dependencies. Dependencies first, dependents last.


    .DESCRIPTION

    The Order-ByDependencies function orders the provisioners in the list based on their dependencies.


    .PARAMETER provisionersToSort

    The collection of provisioners that should be sorted.


    .OUTPUTS

    An array containing the provisioners in dependency sorted order.
#>
function Order-ByDependencies
{
    [CmdletBinding()]
    param(
        [object[]] $provisionersToSort
    )

    $sortedObjects = New-Object System.Collections.Generic.List[object]

    # Find all dependency free provisioners
    $dependencyFreeProvisioners = @()
    $provisionersLeftToSort = New-Object System.Collections.Generic.List[object]
    foreach($provisioner in $provisionersToSort)
    {
        $dependencies = $provisioner.Dependencies()
        if (($dependencies -eq $null) -or ($dependencies.Length -eq 0))
        {
            $dependencyFreeProvisioners += $provisioner
            continue
        }

        # If the dependencies don't have a provisioner then we're in the clear too
        if (($provisionersToSort | Where-Object { $dependencies -contains $_.ResourceName() }).Length -eq 0)
        {
            $dependencyFreeProvisioners += $provisioner
            continue
        }

        # The provisioner has existing dependencies. Will need to sort it later
        $provisionersLeftToSort.Add($provisioner)
    }

    $sortedObjects.AddRange($dependencyFreeProvisioners)
    while ($provisionersLeftToSort.Count -gt 0)
    {
        $i = 0
        while ($i -lt $provisionersLeftToSort.Count)
        {
            $provisioner = $provisionersLeftToSort[$i]
            $dependencies = $provisioner.Dependencies()
            $existingDependencies = @()

            foreach($dependency in $dependencies)
            {
                if (($provisionersToSort | Where-Object { $dependency -eq $_.ResourceName() }).Length -eq 1)
                {
                    $existingDependencies += $dependency
                }
            }

            if (($sortedObjects | Where-Object { $existingDependencies -contains $_.ResourceName() }).Length -eq $existingDependencies.Length)
            {
                $sortedObjects.Add($provisioner)
                $provisionersLeftToSort.RemoveAt($i)
            }
            else
            {
                $i++
            }
        }
    }

    return $sortedObjects.ToArray()
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

    $scriptPath = Split-Path -Path $PSScriptRoot -Parent @commonParameterSwitches
    $scriptsToExecute = Get-ChildItem -Path $scriptPath -Filter 'Initialize-*Resource.ps1' -File

    $provisioners = @()
    foreach($script in $scriptsToExecute)
    {
        try
        {
            $provisioner = & $script
            if (($provisioner -ne $null) -and (($provisioner | Get-Member -MemberType Method -Name 'ResourceName','Dependencies','Provision' ).Length -eq 3))
            {
                $provisioners += $provisioner
            }
        }
        catch
        {
            Write-Log `
                -message "Failed to get the provisioner object from $($script). The error was $($_.Exception.ToString())" `
                -logPath $logPath `
                @commonParameterSwitches
        }
    }

    $provisioners = SortBy-Dependencies `
        -provisionersToSort $provisioners `
        @commonParameterSwitches

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

    $provisioningBaseUri = "$($provisioningBaseUri)/v1/kv/provisioning/$($env:COMPUTERNAME)/service"
    foreach($provisioner in $provisioners)
    {
        $resourceName = $provisioner.ResourceName()
        try
        {
            Write-Log `
                -message "Invoking provisioning for the $($resourceName) ..." `
                -logPath $logPath `
                @commonParameterSwitches

            $provisioner.Configure("$($provisioningBaseUri)/$($resourceName.ToLower())")
        }
        catch
        {
             Write-Log `
                -message "Failure during the configuration of $($resourceName). Error was: $($_.Exception.ToString())" `
                -logPath $logPath `
                @commonParameterSwitches
        }
    }

    foreach($provisioner in $provisioners)
    {
        $resourceName = $provisioner.ResourceName()
        try
        {
            Write-Log `
                -message "Starting $($resourceName) services ..." `
                -logPath $logPath `
                @commonParameterSwitches

            $provisioner.Start()
        }
        catch
        {
             Write-Log `
                -message "Failure during the starting of $($resourceName). Error was: $($_.Exception.ToString())" `
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


