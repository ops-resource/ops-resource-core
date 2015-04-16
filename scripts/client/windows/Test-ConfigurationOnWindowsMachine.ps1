<#
    .SYNOPSIS

    Executes the tests that verify whether the current machine has all the tools installed to allow it to work as a Windows Jenkins master.


    .DESCRIPTION

    The Test-ConfigurationOnWindowsMachine script executes the tests that verify whether the current machine has all the tools installed to
    allow it to work as a jenkins windows machine.


    .EXAMPLE

    Test-ConfigurationOnWindowsMachine.ps1
#>
[CmdletBinding()]
param(
    [string] $testDirectory = "c:\verification",
    [string] $logDirectory  = "c:\logs"
)

Write-Verbose "Test-ConfigurationOnWindowsMachine - testDirectory: $testDirectory"
Write-Verbose "Test-ConfigurationOnWindowsMachine - logDirectory: $logDirectory"

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
& choco install ruby -version 2.0.0.57600 --accept-license --confirm --force --verbose

# Patch PATH for ruby
$rubyPath = "C:\tools\ruby200"
$env:PATH += ";$rubyPath\bin"

# install ruby2.devkit
Write-Output "Installing ruby2.devkit via chocolatey ..."
& choco install ruby2.devkit -version 4.7.2.2013022402 --accept-license --confirm --force --verbose

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

# Read the gems that need to be installed from a list

Write-Output "Installing bundler gem ..."
& gem install bundler --version 1.8.2 --no-document --conservative --minimal-deps --verbose

# Install all the ruby gems that are required
$bundleFiles = Get-ChildItem -Path $testDirectory -Include 'gemfile' -Recurse
foreach($bundleFile in $bundleFiles)
{
    Write-Output "Installing gem files from $($bundleFile.FullName)"

    # Run bundle in a separate process so that this script can decide if there are errors or not. The issue is that on
    # windows 'bundle' throws out a warning saying 'DL is deprecated, please use Fiddle'. However this warning is thrown
    # out on the error stream which makes Powershell think the process failed. By running in a separate process under
    # our control we can ignore the warnings.
    $process = Start-Process -FilePath 'bundle' -ArgumentList "install --clean --gemfile=`"$($bundleFile.FullName)`" --no-cache" -PassThru
    $process.WaitForExit()

    if ($process.ExitCode -ne 0)
    {
        throw "Failed to restore the Ruby gems for $($bundleFile.FullName)"
    }
    else
    {
        Write-Output "Installed $($bundleFile.FullName). Bundle exit code was $($process.ExitCode)"
    }
}

# rspec may push data to the error stream which powershell will consider a failure, even if it's not.
$rspecPattern = "./*/*_spec.rb"
Write-Output "Executing ServerSpec tests from: $pwd. With pattern: $rspecPattern"

$stOutFile = "c:\logs\rspec_stout.txt"
$stErrFile = "c:\logs\rspec_sterr.txt"
$process = Start-Process -FilePath 'rspec.bat' -ArgumentList "--format documentation --format RspecJunitFormatter --out c:\logs\serverspec.xml --pattern $rspecPattern" -NoNewWindow -PassThru -Wait -WorkingDirectory $testDirectory -RedirectStandardOutput $stOutFile -RedirectStandardError $stErrFile
$process.WaitForExit()

Write-Output "Output"
Get-Content $stOutFile

Write-Output "Errors: "
Get-Content $stErrFile

if ($process.ExitCode -ne 0)
{
    throw "rspec exited with: $($process.ExitCode)"
}
