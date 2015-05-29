[CmdletBinding()]
param(
    $consulServiceName = 'consul',
    $filesToUpload = @{}
)

$ErrorActionPreference = 'Stop'

# verify that the consul service is up and running
$service = Get-Service -Name $consulServiceName
if (($service -eq $null) -or ($service.Status -ne 'Running'))
{
    throw "Consul has not be registered as a service, or the service was not running."
}

$hasError = $false
$ErrorActionPreference = 'Continue'
try
{
    foreach($pair in $filesToUpload.GetEnumerator())
    {
        try
        {
            $filePath = $pair.Key
            # verify that the json file exists
            if (-not (Test-Path $filePath))
            {
                Write-Error "Could not locate the file. Was supposed to be located at $filePath but it was not."
                continue
            }

            # Read the json file
            $content = Get-Content -Path $filePath

            # Push the meta data up to the consul cluster
            $machineName = [System.Net.Dns]::GetHostName()
            $uri = "http://localhost:8500/v1/kv/resource/$machineName/configuration/$($pair.Value)"
            Write-Output "Uploading to $uri"
            $response = Invoke-WebRequest -Uri $uri -Method Put -Body $content -UseBasicParsing -UseDefaultCredentials
            Write-Output "Upload: $($response.StatusDescription)"
        }
        catch
        {
            $hasError = $true
            Write-Error "Failed to upload the configuration metadata from $filePath to the consul cluster. Error was: $($_.Exception.ToString())"
        }
    }
}
finally
{
    $ErrorActionPreference = 'Stop'
}

if ($hasError)
{
    throw "Failed to send all the meta data to the consul cluster"
}