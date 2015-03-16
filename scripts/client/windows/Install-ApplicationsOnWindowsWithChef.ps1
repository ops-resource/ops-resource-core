<#
    .SYNOPSIS
 
    Takes all the actions necessary to prepare a Windows machine for use. The final use of the machine depends on the Chef cookbook that is
    provided.
 
 
    .DESCRIPTION
 
    The Install-ApplicationsOnWindowsWithChef script takes all the actions necessary to prepare a Windows machine for use.


    .PARAMETER configurationDirectory

    The directory in which all the installer packages and cookbooks can be found. It is expected that the cookbooks are stored
    in a 'cookbooks' sub-directory of the configurationDirectory.


    .PARAMETER logDirectory

    The directory in which all the logs should be stored.


    .PARAMETER cookbookName

    The name of the cookbook that should be used to configure the current machine.
 
 
    .EXAMPLE
 
    Install-ApplicationsOnWindowsWithChef -configurationDirectory "c:\configuration" -logDirectory "c:\logs" -cookbookName "myCookbook"
#>
[CmdletBinding()]
param(
    [string] $configurationDirectory = "c:\configuration",
    [string] $logDirectory          = "c:\logs",
    [string] $cookbookName          = "master"
)

function Install-Msi
{
    param(
        [string] $msiFile,
        [string] $logFile
    )

    $p = Start-Process -FilePath "msiExec.exe" -ArgumentList "/i $msiFile /Lime! $logFile /qn" -PassThru
    $p.WaitForExit()

    if ($p.ExitCode -ne 0)
    {
        throw "Failed to install: $msiFile"
    }
}

function Uninstall-Msi
{
    param(
        [string] $msiFile,
        [string] $logFile
    )

    $p = Start-Process -FilePath "msiExec.exe" -ArgumentList "/x $msiFile /Lime! $logFile /qn" -PassThru
    $p.WaitForExit()

    if ($p.ExitCode -ne 0)
    {
        throw "Failed to install: $msiFile"
    }
}

# Stop everything if there are errors
$ErrorActionPreference = 'Stop'

$commonParameterSwitches =
    @{
        Verbose = $PSBoundParameters.ContainsKey('Verbose');
        Debug = $PSBoundParameters.ContainsKey('Debug');
        ErrorAction = "Stop"
    }

# The directory that contains all the installation files
if (-not (Test-Path $configurationDirectory))
{
    throw "Failed to find the configuration directory."
}

if (-not (Test-Path $logDirectory))
{
    New-Item -Path $logDirectory -ItemType Directory
}

# Download chef client. Note that this is obviously hard-coded but for now it will work. Later on we'll make this a configuration option
Write-Output "Downloading chef installer ..."
$chefClientInstallFile = "chef-windows-11.16.4-1.windows.msi"
$chefClientDownloadUrl = "https://opscode-omnibus-packages.s3.amazonaws.com/windows/2008r2/x86_64/" + $chefClientInstallFile
$chefClientInstall = Join-Path $configurationDirectory $chefClientInstallFile
Invoke-WebRequest -Uri $chefClientDownloadUrl -OutFile $chefClientInstall -Verbose

Write-Output "Chef download complete."
if (-not (Test-Path $chefClientInstall))
{
    throw 'Failed to download the chef installer.'
}

# Install the chef client
Unblock-File -Path $chefClientInstall

Write-Output "Installing chef from $chefClientInstall ..."
$chefInstallLogFile = Join-Path $logDirectory "chef.install.log"
Install-Msi -msiFile "$chefClientInstall" -logFile "$chefInstallLogFile"

try 
{
    # Set the path for the cookbooks
    $chefConfigDir = Join-Path $env:UserProfile ".chef"
    if (-not (Test-Path $chefConfigDir))
    {
        Write-Output "Creating the chef configuration directory ..."
        New-Item -Path $chefConfigDir -ItemType Directory | Out-Null
    }

    $chefConfig = Join-Path $chefConfigDir 'knife.rb'
    if (-not (Test-Path $chefConfig))
    {
        Write-Output "Creating the chef configuration file"
        Set-Content -Path $chefConfig -Value ('cookbook_path ["' + $configurationDirectory.Replace('\', '/') + '/cookbooks"]')

        # Make a copy of the config for debugging purposes
        Copy-Item $chefConfig $logDirectory
    }

    $opscodePath = "c:\opscode"
    if (-not (Test-Path $opscodePath))
    {
        throw "Chef install path not found."
    }

    # Add the ruby path to the $env:PATH for the current session.
    $embeddedRubyPath = "$opscodePath\chef\embedded\bin"
    if (-not (Test-Path $embeddedRubyPath))
    {
        throw "Embedded ruby path not found."
    }

    $env:PATH += ";" + $embeddedRubyPath

    # Execute the chef client as: chef-client -z -o $cookbookname
    $chefClient = "$opscodePath\chef\bin\chef-client.bat"
    if (-not (Test-Path $chefClient))
    {
        throw "Chef client not found"
    }

    Write-Output "Running chef-client ..."
    try 
    {
        & $chefClient -z -o $cookbookName
    }
    catch 
    {
        Write-Output ("chef-client failed. Error was: " + $_.Exception.ToString())
    }

    if (($LastExitCode -ne $null) -and ($LastExitCode -ne 0))
    {
        $userProfile = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
        $chefPath = "$userProfile\.chef\local-mode-cache\cache"
        if (Test-Path $chefPath)
        {
            Get-ChildItem -Path $chefPath -Include *.pid,*.out | Copy-Item -Destination $logDirectory
        }

        throw "Chef-client failed. Exit code: $LastExitCode"
    }

    Write-Output "Chef-client completed."
}
finally
{
    Write-Output "Uninstalling chef ..."

    # delete chef from the machine
    $chefUninstallLogFile = Join-Path $logDirectory "chef.uninstall.log"
    Uninstall-Msi -msiFile $chefClientInstall -logFile $chefUninstallLogFile

    Remove-Item -Path $chefConfigDir -Force -Recurse -ErrorAction SilentlyContinue
}