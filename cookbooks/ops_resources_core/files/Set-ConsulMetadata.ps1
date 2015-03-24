[CmdletBinding()]
param(
    [string] $metaFile = $(throw "Please provide the full path of the meta.json file."),
    [string] $consulServiceName = $(throw "Please provide the name of the consul service.")
)

$ErrorActionPreference = 'Stop'

# verify that the json file exists
if (-not (Test-Path $metaFile))
{
    throw "Could not locate the meta.json file. Was supposed to be located at $metaFile but it was not."
}

# verify that the consul service is up and running
$service = Get-Service -Name $consulServiceName
if ($service -eq $null)
{
    throw "Consul has not be registered as a service."
}

if ($service.Status -ne 'Running')
{
    # Wait for the service to start for a maximum of 10 mins
    Start-Service -Name $consulServiceName
}

# Read the json file
$resourceMetadata = Get-Content -Path $metaFile

# Push the meta data up to the consul cluster
$machineName = [System.Net.Dns]::GetHostName()
Invoke-WebRequest -Uri "http://localhost:8500/v1/kv/resources/$machineName" -Method Put -Body $resourceMetadata
