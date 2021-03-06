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

    Install-ApplicationsOnWindowsWithChef -configurationDirectory "c:\init\configuration" -logDirectory "c:\init\logs" -cookbookNames "myCookbook", "myOtherCookbook"
#>
[CmdletBinding()]
param(
    [string] $resourceName           = '',
    [string] $resourceVersion        = '',
    [string] $configurationDirectory = "c:\init\configuration",
    [string] $logDirectory           = "c:\init\logs",
    [string[]] $cookbookNames        = ""
)

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
        Debug = $false;
        ErrorAction = "Stop"
    }

# ----------------------- SCRIPT FUNCTIONS ------------------------------------

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
            $searchPattern = '"version"'
            $select = Select-String -Path $path -Pattern $searchPattern
            $line = $select.Line.Trim()
            $startingIndex = $line.IndexOf($searchPattern) + $searchPattern.Length
            $cookbookVersion = $line.SubString($startingIndex, $line.IndexOf(',', $startingIndex) - $startingIndex).Trim().Trim(@(':', ',', "'", '"', ' ')).Trim()
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

    $chefClientInstallFile = "chef-client.msi"
    $chefClientInstall = Join-Path $configurationDirectory $chefClientInstallFile
    if (-not (Test-Path $chefClientInstall))
    {
        throw 'Failed to find the chef installer.'
    }

    # Install the chef client
    Unblock-File -Path $chefClientInstall

    Write-Output "Installing chef from $chefClientInstall ..."
    $chefInstallLogFile = Join-Path $logDirectory "chef.install.log"
    Install-Msi -msiFile "$chefClientInstall" -logFile "$chefInstallLogFile"
}

function Install-ChefService
{
    [CmdletBinding()]
    param(
        [string] $configurationDirectory
    )

    $chefServerInstallFile = "chefservice.exe"
    $chefServerInstall = Join-Path $configurationDirectory $chefServerInstallFile
    if (-not (Test-Path $chefServerInstall))
    {
        throw 'Failed to download the chef service executable.'
    }

    # Install the chef client
    Unblock-File -Path $chefServerInstall

    Write-Output "Installing chef service from $chefServerInstall ..."
    & $chefServerInstall -install
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

function Uninstall-ChefService
{
    [CmdletBinding()]
    param(
        [string] $configurationDirectory
    )

    $chefServerInstallFile = "chefservice.exe"
    $chefServerInstall = Join-Path $configurationDirectory $chefServerInstallFile
    if (-not (Test-Path $chefServerInstall))
    {
        throw 'Failed to download the chef service executable.'
    }

    # Install the chef client
    Unblock-File -Path $chefServerInstall

    Write-Output "Uninstalling chef service from $chefServerInstall ..."
    & $chefServerInstall -uninstall
}

# ----------------------- SCRIPT START ------------------------------------

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

# This should add the location of chef and ruby to the PATH
Install-ChefClient -configurationDirectory $configurationDirectory -logDirectory $logDirectory
try
{
    # We can't install Windows features / updates when running over WinRM (see here: https://github.com/test-kitchen/test-kitchen/issues/655)
    # So we have to run this via a service like this one: https://github.com/ebsco/chefservice
    Install-ChefService -configurationDirectory $configurationDirectory
    try
    {
        # Set the path for the cookbooks
        $chefConfig = Join-Path $configurationDirectory 'client.rb'
        if (-not (Test-Path $chefConfig))
        {
            Write-Output "Creating the chef configuration file"
            Set-Content -Path $chefConfig -Value ('cookbook_path ["' + $configurationDirectory.Replace('\', '/') + '/cookbooks"]') -Verbose

            # Make a copy of the config for debugging purposes
            Copy-Item $chefConfig $logDirectory -Verbose
        }

        $chefClient = "$configurationDirectory\eis-chef.exe"
        if (-not (Test-Path $chefClient))
        {
            throw "Chef client not found"
        }

        Write-Output "Running chef-client ..."
        $previousErrorPreference = $ErrorActionPreference
        $ErrorActionPreference = 'SilentlyContinue'
        try
        {
            $cookbook = $cookbookNames -join ','

            # Redirect the error stream to the output stream because ruby writes warnings to the error stream which makes powershell consider the run as a failure,
            # even if it isn't
            $expression = "& $chefClient --local-mode --config `"$chefConfig`" --override-runlist `"$cookbook`" --log_level debug --logfile `"$(Join-Path $logDirectory 'chef_client.log')`" 2>&1"
            Write-Output "Invoking chef client as:"
            Write-Output $expression
            Invoke-Expression -Command $expression @commonParameterSwitches
        }
        finally
        {
            $ErrorActionPreference = $previousErrorPreference
        }

        if (($LastExitCode -ne $null) -and ($LastExitCode -ne 0))
        {
            $userProfile = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
            $chefPath = "$userProfile\.chef\local-mode-cache\cache"
            if (Test-Path $chefPath)
            {
                Get-ChildItem -Path $chefPath -Recurse -Force | Copy-Item -Destination $logDirectory -Force @commonParameterSwitches
            }

            throw "Chef-client failed. Exit code: $LastExitCode"
        }

        Write-Output "Chef-client completed."
    }
    finally
    {
        Uninstall-ChefService -configurationDirectory $configurationDirectory
    }
}
finally
{
    # delete chef from the machine
    Uninstall-ChefClient -configurationDirectory $configurationDirectory -logDirectory $logDirectory

    $chefConfigDir = Join-Path $env:UserProfile ".chef"
    if (Test-Path $chefConfigDir)
    {
        Remove-Item -Path $chefConfigDir -Force -Recurse -ErrorAction Continue
    }
}