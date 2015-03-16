<#
    .SYNOPSIS
 
    Executes the tests that verify whether the current machine has all the tools installed to allow it to work as a Windows Jenkins master.
 
 
    .DESCRIPTION
 
    The Verify-ApplicationsOnWindows script executes the tests that verify whether the current machine has all the tools installed to allow it to work as a Windows Jenkins master.
 
 
    .EXAMPLE
 
    Verify-ApplicationsOnWindows
#>
[CmdletBinding()]
param(
    [string] $testDirectory = "c:\tests",
    [string] $logDirectory  = "c:\logs"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $testDirectory))
{
    throw "Expected test directory to exist."
}

if (-not (Test-Path $logDirectory))
{
    New-Item -Path $logDirectory -ItemType Directory
}

# Install Chocolatey
Write-Output "Installing chocolatey ..."
Invoke-Expression ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))

# Add chocolatey to the path
$env:ChocolateyInstall = "C:\ProgramData\chocolatey"

# Install ruby
Write-Output "Installing ruby via chocolatey ..."
& choco install ruby -version 2.0.0.57600

# Patch PATH for ruby
$rubyPath = "C:\tools\ruby200"
$env:PATH += ";$rubyPath\bin"

# install ruby2.devkit
Write-Output "Installing ruby2.devkit via chocolatey ..."
& choco install ruby2.devkit -version 4.7.2.2013022402

# patch devkit config
Write-Output "Patching ruby devkit config ..."
Add-Content -Path "C:\tools\DevKit2\config.yml" -Value " - $rubyPath"

# rerun devkit install stuff
Write-Output "Updating ruby with DevKit ..."
$currentPath = $pwd
try 
{
    sl "C:\tools\DevKit2\"
    & ruby "dk.rb" install
}
finally
{
    sl $currentPath
}

# patch the SSL certs
# Based on: http://stackoverflow.com/a/16134586/539846
$rubyCertDir = "c:\tools\rubycerts"
if (-not (Test-Path $rubyCertDir))
{
    New-Item -Path $rubyCertDir -ItemType Directory | Out-Null
}

$rubyCertFile = Join-Path $rubyCertDir "cacert.pem"
Invoke-WebRequest -Uri "http://curl.haxx.se/ca/cacert.pem" -OutFile $rubyCertFile -Verbose
Unblock-File -Path $rubyCertFile

# Permanently set the environment variable for the machine
[Environment]::SetEnvironmentVariable("SSL_CERT_FILE", "$rubyCertFile", "Machine")

# But also set it for the current process because environment variables aren't reloaded
$env:SSL_CERT_FILE = $rubyCertFile

Write-Output ("Environment variable SSL_CERT_FILE set to: " + $env:SSL_CERT_FILE)

Write-Output "Installing ruby-wmi gem ..."
& gem install ruby-wmi --version 0.4.0 --no-document --conservative --minimal-deps --verbose

Write-Output "Installing rest_client gem ..."
& gem install rest_client --version 1.7.2 --no-document --conservative --minimal-deps --verbose

Write-Output "Installing serverspec gem ..."
& gem install serverspec --version 2.7.0 --no-document --conservative --minimal-deps --verbose

Write-Output "Installing the RSpec JUnit formatter ..."
& gem install rspec_junit_formatter --version 0.2.0 --no-document --conservative --minimal-deps --verbose

$currentDir = $pwd
try
{
    Set-Location $testDirectory
    try
    {
        # rspec may push data to the error stream which powershell will consider a failure, even if it's not.
        $storedErrorActionPreference = $ErrorActionPreference
        $ErrorActionPreference = "SilentlyContinue"

        $rspecPattern = "./*/*_spec.rb"
        Write-Output "Executing ServerSpec tests from: $pwd. With pattern: $rspecPattern"
        & rspec --format documentation --format RspecJunitFormatter --out "$logDirectory\serverspec.xml" --pattern $rspecPattern
    }
    finally
    {
        $ErrorActionPreference = $storedErrorActionPreference
    }
}
finally
{
    $pwd = $currentDir
}