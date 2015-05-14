<#
    .SYNOPSIS

    Takes all the actions necessary to prepare a Windows machine for use. The final use of the machine depends on the Chef cookbook that is
    provided.


    .DESCRIPTION

    The Install-ApplicationsOnWindowsWithChef script takes all the actions necessary to prepare a Windows machine for use.


    .PARAMETER resourceName

    The name of the resource that is being created.


    .PARAMETER resourceVersion

    The version of the resource that is being created.


    .PARAMETER configurationDirectory

    The directory in which all the installer packages and cookbooks can be found. It is expected that the cookbooks are stored
    in a 'cookbooks' sub-directory of the configurationDirectory.


    .PARAMETER logDirectory

    The directory in which all the logs should be stored.


    .PARAMETER cookbookNames

    An array containing the names of the cookbooks that should be used to configure the current machine.


    .EXAMPLE

    Install-ApplicationsOnWindowsWithChef -configurationDirectory "c:\configuration" -logDirectory "c:\logs" -cookbookNames "myCookbook", "myOtherCookbook"
#>
[CmdletBinding()]
param(
    [string] $resourceName           = '',
    [string] $resourceVersion        = '',
    [string] $configurationDirectory = "c:\configuration",
    [string] $logDirectory           = "c:\logs",
    [string[]] $cookbookNames        = "jenkinsmaster"
)

function Install-Msi
{
    param(
        [string] $msiFile,
        [string] $logFile
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = "msiexec.exe"
    $startInfo.RedirectStandardError = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.UseShellExecute = $false
    $startInfo.Arguments = "/i $msiFile /Lime! $logFile /qn"

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $startInfo
    $p.Start() | Out-Null
    $p.WaitForExit()

    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    Write-Output $stdout

    if ($p.ExitCode -ne 0)
    {
        if (($sterr -ne $null) -and ($sterr -ne ''))
        {
            Write-Error $stderr
        }

        throw "Failed to install: $msiFile. Exit code was: $($p.ExitCode)"
    }
}

function Uninstall-Msi
{
    param(
        [string] $msiFile,
        [string] $logFile
    )

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = "msiexec.exe"
    $startInfo.RedirectStandardError = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.UseShellExecute = $false
    $startInfo.Arguments = "/x $msiFile /Lime! $logFile /qn"

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $startInfo
    $p.Start() | Out-Null
    $p.WaitForExit()

    $stdout = $p.StandardOutput.ReadToEnd()
    $stderr = $p.StandardError.ReadToEnd()
    Write-Output $stdout

    if ($p.ExitCode -ne 0)
    {
        if (($sterr -ne $null) -and ($sterr -ne ''))
        {
            Write-Error $stderr
        }

        throw "Failed to uninstall: $msiFile. Exit code was: $($p.ExitCode)"
    }
}

function New-MetaFile
{
    [CmdletBinding()]
    param(
        [string] $configurationDirectory,
        [string] $resourceName,
        [string] $resourceVersion
    )

    Write-Output 'Gathering data for machine meta file ...'

    $now = [System.DateTimeOffset]::Now
    $meta = New-Object psobject
    Add-Member -InputObject $meta -MemberType NoteProperty -Name createdBy -Value ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
    Add-Member -InputObject $meta -MemberType NoteProperty -Name createdFrom -Value $resourceName
    Add-Member -InputObject $meta -MemberType NoteProperty -Name version -Value $resourceVersion

    Add-Member -InputObject $meta -MemberType NoteProperty -Name buildDate -Value $now.ToString('yyyy-MM-dd')
    Add-Member -InputObject $meta -MemberType NoteProperty -Name buildTime -Value $now.ToString('HH:mm:ss')
    Add-Member -InputObject $meta -MemberType NoteProperty -Name buildTimeOffset -Value $now.ToString('zzz')

    $cookbooksMeta = @()

    $cookbookDirectories = Get-ChildItem -Path (Join-Path $configurationDirectory 'cookbooks') -Directory
    foreach($cookbook in $cookbookDirectories)
    {
        $path = Join-Path $cookbook.FullName 'metadata.rb'

        # Old cookbook metadata file type
        if (Test-Path $path)
        {
            $select = Select-String -Path $path -Pattern 'version'
            $line = $select.Line.Trim()
            $cookbookVersion = $line.SubString($line.IndexOf(" ")).Trim().Trim(',').Trim("'").Trim('"')
        }
        else
        {
            # New cookbook metadata file type
            $path = Join-Path $cookbook.FullName 'metadata.json'
            $select = Select-String -Path $path -Pattern '"version":'
            $line = $select.Line.Trim()
            $cookbookVersion = $line.SubString($line.IndexOf(" ")).Trim().Trim(',').Trim("'").Trim('"')
        }

        $cookbookMeta = New-Object psobject
        Add-Member -InputObject $cookbookMeta -MemberType NoteProperty -Name name -Value $cookbook.Name
        Add-Member -InputObject $cookbookMeta -MemberType NoteProperty -Name version -Value $cookbookVersion

        $cookbooksMeta += $cookbookMeta

        Write-Output "Machine meta file: New cookbook: $($cookbook.Name) at version: $cookbookVersion"
    }
    Add-Member -InputObject $meta -MemberType NoteProperty -Name cookbooks -Value $cookbooksMeta

    $jsonText = ConvertTo-Json -InputObject $meta

    $metaFileDirectory = Join-Path (Join-Path (Join-Path (Join-Path $configurationDirectory 'cookbooks') 'ops_resource_core') 'files') 'default'
    if (-not (Test-Path $metaFileDirectory))
    {
        New-Item -Path $metaFileDirectory -ItemType Directory
    }

    $metaFile = Join-Path $metaFileDirectory 'meta.json'
    Out-File -filePath $metaFile -Encoding UTF8 -InputObject $jsonText -Verbose

    Write-Output "Wrote machine meta file to: $metaFile"
}

function Install-ChefClient
{
    [CmdletBinding()]
    param(
        [string] $configurationDirectory,
        [string] $logDirectory
    )

    # Download chef client. Note that this is obviously hard-coded but for now it will work. Later on we'll make this a configuration option
    $chefClientInstallFile = "chef-client.msi"
    $chefClientInstall = Join-Path $configurationDirectory $chefClientInstallFile
    if (-not (Test-Path $chefClientInstall))
    {
        throw 'Failed to download the chef installer.'
    }

    # Install the chef client
    Unblock-File -Path $chefClientInstall

    Write-Output "Installing chef from $chefClientInstall ..."
    $chefInstallLogFile = Join-Path $logDirectory "chef.install.log"
    Install-Msi -msiFile "$chefClientInstall" -logFile "$chefInstallLogFile"
}

function Uninstall-ChefClient
{
    [CmdletBinding()]
    param(
        [string] $configurationDirectory,
        [string] $logDirectory
    )

    # Download chef client. Note that this is obviously hard-coded but for now it will work. Later on we'll make this a configuration option
    $chefClientInstallFile = "chef-client.msi"
    $chefClientInstall = Join-Path $configurationDirectory $chefClientInstallFile
    if (-not (Test-Path $chefClientInstall))
    {
        return
    }

    Write-Output "Uninstalling chef from $chefClientInstall ..."
    $chefUninstallLogFile = Join-Path $logDirectory "chef.uninstall.log"
    try
    {
        Uninstall-Msi -msiFile "$chefClientInstall" -logFile "$chefUninstallLogFile"
    }
    catch
    {
        Write-Output ("Failed to uninstall the chef client. Error was " + $_.Exception.ToString())
    }
}

Write-Output "Install-ApplicationsOnWindowsWithChef - resourceName: $resourceName"
Write-Output "Install-ApplicationsOnWindowsWithChef - resourceVersion: $resourceVersion"
Write-Output "Install-ApplicationsOnWindowsWithChef - configurationDirectory: $configurationDirectory"
Write-Output "Install-ApplicationsOnWindowsWithChef - logDirectory: $logDirectory"
Write-Output "Install-ApplicationsOnWindowsWithChef - cookbookNames: $cookbookNames"

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

New-MetaFile -configurationDirectory $configurationDirectory -resourceName $resourceName -resourceVersion $resourceVersion

Install-ChefClient -configurationDirectory $configurationDirectory -logDirectory $logDirectory
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
        Set-Content -Path $chefConfig -Value ('cookbook_path ["' + $configurationDirectory.Replace('\', '/') + '/cookbooks"]') -Verbose

        # Make a copy of the config for debugging purposes
        Copy-Item $chefConfig $logDirectory -Verbose
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
        $cookbook = $cookbookNames -join ','
        & $chefClient --local-mode --override-runlist $cookbook --log_level info --logfile "$(Join-Path $logDirectory 'chef_client.log')"
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
            Get-ChildItem -Path $chefPath -Recurse -Force | Copy-Item -Destination $logDirectory
        }

        throw "Chef-client failed. Exit code: $LastExitCode"
    }

    Write-Output "Chef-client completed."
}
finally
{
    # delete chef from the machine
    Uninstall-ChefClient -configurationDirectory $configurationDirectory -logDirectory $logDirectory
    Remove-Item -Path $chefConfigDir -Force -Recurse -ErrorAction Continue
}