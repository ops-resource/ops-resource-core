<#
    .SYNOPSIS

    Copies a file to the given remote path on the machine that the session is connected to.


    .DESCRIPTION

    The Copy-ItemToRemoteMachine function copies a local file to the given remote path on the machine that the session is connected to.


    .PARAMETER localPath

    The full path of the file that should be copied.


    .PARAMETER remotePath

    The full file path to which the local file should be copied


    .PARAMETER session

    The PSSession that provides the connection between the local machine and the remote machine.


    .EXAMPLE

    Copy-ItemToRemoteMachine -localPath 'c:\temp\myfile.txt' -remotePath 'c:\remote\myfile.txt' -session $session
#>
function Copy-ItemToRemoteMachine
{
    [CmdletBinding()]
    param(
        [string] $localPath,
        [string] $remotePath,
        [System.Management.Automation.Runspaces.PSSession] $session
    )

    # Use .NET file handling for speed
    $content = [Io.File]::ReadAllBytes( $localPath )
    $contentsizeMB = $content.Count / 1MB + 1MB

    Write-Output "Copying $fileName from $localPath to $remotePath on $($session.Name) ..."

    # Open local file
    try
    {
        [IO.FileStream]$filestream = [IO.File]::OpenRead( $localPath )
        Write-Output "Opened local file for reading"
    }
    catch
    {
        Write-Error "Could not open local file $localPath because: $($_.Exception.ToString())"
        Return $false
    }

    # Open remote file
    try
    {
        Invoke-Command `
            -Session $Session `
            -ScriptBlock {
                param(
                    $remFile
                )

                $dir = Split-Path -Parent $remFile
                if (-not (Test-Path $dir))
                {
                    New-Item -Path $dir -ItemType Directory
                }

                [IO.FileStream]$filestream = [IO.File]::OpenWrite( $remFile )
            } `
            -ArgumentList $remotePath
        Write-Output "Opened remote file for writing"
    }
    catch
    {
        Write-Error "Could not open remote file $remotePath because: $($_.Exception.ToString())"
        Return $false
    }

    # Copy file in chunks
    $chunksize = 1MB
    [byte[]]$contentchunk = New-Object byte[] $chunksize
    $bytesread = 0
    while (($bytesread = $filestream.Read( $contentchunk, 0, $chunksize )) -ne 0)
    {
        try
        {
            $percent = $filestream.Position / $filestream.Length
            Write-Output ("Copying {0}, {1:P2} complete, sending {2} bytes" -f $fileName, $percent, $bytesread)
            Invoke-Command -Session $Session -ScriptBlock {
                Param($data, $bytes)
                $filestream.Write( $data, 0, $bytes )
            } -ArgumentList $contentchunk,$bytesread
        }
        catch
        {
            Write-Error "Could not copy $fileName to $($Connection.Name) because: $($_.Exception.ToString())"
            return $false
        }
        finally
        {
        }
    }

    # Close remote file
    try
    {
        Invoke-Command -Session $Session -ScriptBlock {
            $filestream.Close()
        }
        Write-Output "Closed remote file, copy complete"
    }
    catch
    {
        Write-Error "Could not close remote file $remotePath because: $($_.Exception.ToString())"
        Return $false
    }

    # Close local file
    try
    {
        $filestream.Close()
        Write-Output "Closed local file, copy complete"
    }
    catch
    {
        Write-Error "Could not close local file $localPath because: $($_.Exception.ToString())"
        Return $false
    }
}

function Read-FromRemoteStream
{
    param(
        [System.Management.Automation.Runspaces.PSSession] $session,
        [int] $chunkSize
    )

    try
    {
        $data = Invoke-Command `
            -Session $Session `
            -ScriptBlock {
                Param(
                    $size
                )

                [byte[]]$contentchunk = New-Object byte[] $size
                $bytesread = $filestream.Read( $contentchunk, 0, $size )

                $result = New-Object PSObject
                Add-Member -InputObject $result -MemberType NoteProperty -Name BytesRead -Value $BytesRead
                Add-Member -InputObject $result -MemberType NoteProperty -Name Chunk -Value $contentchunk

                return $result
            } `
            -ArgumentList $chunkSize

        return $data
    }
    catch
    {
        Write-Error "Could not copy $fileName to $($Connection.Name) because: $($_.Exception.ToString())"
        return -1
    }
    finally
    {

    }
}

<#
    .SYNOPSIS

    Copies a file from the given remote path on the machine that the session is connected to.


    .DESCRIPTION

    The Copy-ItemFromRemoteMachine function copies a remote file to the given local path on the machine that the session is connected to.


    .PARAMETER remotePath

    The full file path from which the local file should be copied


    .PARAMETER localPath

    The full path of the file to which the file should be copied.


    .PARAMETER session

    The PSSession that provides the connection between the local machine and the remote machine.


    .EXAMPLE

    Copy-ItemFromRemoteMachine -remotePath 'c:\remote\myfile.txt' -localPath 'c:\temp\myfile.txt' -session $session
#>
function Copy-ItemFromRemoteMachine
{
    [CmdletBinding()]
    param(
        [string] $remotePath,
        [string] $localPath,
        [System.Management.Automation.Runspaces.PSSession] $session
    )

    Write-Output "Copying $fileName from $localPath to $remotePath on $($session.Name) ..."

    # Open local file
    try
    {
        $localDir = Split-Path -Parent $localPath
        if (-not (Test-Path $localDir))
        {
            New-Item -Path $localDir -ItemType Directory | Out-Null
        }

        [IO.FileStream]$filestream = [IO.File]::OpenWrite( $localPath )
        Write-Output "Opened local file for writing"
    }
    catch
    {
        Write-Error "Could not open local file $localPath because: $($_.Exception.ToString())"
        Return $false
    }

    # Open remote file
    try
    {
        Invoke-Command -Session $Session -ScriptBlock {
            Param($remFile)
            [IO.FileStream]$filestream = [IO.File]::OpenRead( $remFile )
        } -ArgumentList $remotePath
        Write-Output "Opened remote file for reading"
    }
    catch
    {
        Write-Error "Could not open remote file $remotePath because: $($_.Exception.ToString())"
        Return $false
    }

    # Copy file in chunks
    $chunksize = 1MB
    $data = $null
    while (($data = Read-FromRemoteStream $session $chunksize ).BytesRead -ne 0)
    {
        try
        {
            Write-Output ("Copying {0}, receiving {1} bytes" -f $fileName, $data.BytesRead)
            $fileStream.Write( $data.Chunk, 0, $data.BytesRead)
        }
        catch
        {
            Write-Error "Could not copy $fileName from $($Connection.Name) because: $($_.Exception.ToString())"
            return $false
        }
        finally
        {
        }
    }

    # Close local file
    try
    {
        $filestream.Close()
        Write-Output "Closed local file, copy complete"
    }
    catch
    {
        Write-Error "Could not close local file $localPath because: $($_.Exception.ToString())"
        Return $false
    }

    # Close remote file
    try
    {
        Invoke-Command -Session $Session -ScriptBlock {
            $filestream.Close()
        }
        Write-Output "Closed remote file, copy complete"
    }
    catch
    {
        Write-Error "Could not close remote file $remotePath because: $($_.Exception.ToString())"
        Return $false
    }
}

<#
    .SYNOPSIS

    Copies a set of files to a remote directory on a given remote machine.


    .DESCRIPTION

    The Copy-FilesToRemoteMachine function copies a set of files to a remote directory on a given remote machine.


    .PARAMETER session

    The PSSession that provides the connection between the local machine and the remote machine.


    .PARAMETER remoteDirectory

    The full path to the remote directory into which the files should be copied. Defaults to 'c:\installers'


    .PARAMETER filesToCopy

    The collection of local files that should be copied.


    .EXAMPLE

    Copy-FilesToRemoteMachine -session $session -remoteDirectory 'c:\temp' -filesToCopy (Get-ChildItem c:\temp -recurse)
#>
function Copy-FilesToRemoteMachine
{
    [CmdletBinding()]
    param(
        [System.Management.Automation.Runspaces.PSSession] $session,
        [string] $remoteDirectory = "c:\installers",
        [string] $localDirectory
    )

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    $filesToCopy = Get-ChildItem -Path $localDirectory -Recurse -Force @commonParameterSwitches |
        Where-Object { -not $_.PsIsContainer } |
        Select-Object -ExpandProperty FullName

    # Push binaries to the new VM
    Write-Verbose "Copying files to virtual machine: $filesToCopy"
    foreach($fileToCopy in $filesToCopy)
    {
        $relativePath = $fileToCopy.SubString($localDirectory.Length)
        $remotePath = Join-Path $remoteDirectory $relativePath

        Write-Verbose "Copying $fileToCopy to $remotePath"
        Copy-ItemToRemoteMachine -localPath $fileToCopy -remotePath $remotePath -session $session @commonParameterSwitches
    }
}

<#
    .SYNOPSIS

    Copies a set of files from a remote directory on a given remote machine.


    .DESCRIPTION

    The Copy-FilesFromRemoteMachine function copies a set of files from a remote directory on a given remote machine.


    .PARAMETER session

    The PSSession that provides the connection between the local machine and the remote machine.


    .PARAMETER remoteDirectory

    The full path to the remote directory from which the files should be copied. Defaults to 'c:\logs'


    .PARAMETER localDirectory

    The full path to the local directory into which the files should be copied.


    .EXAMPLE

    Copy-FilesFromRemoteMachine -session $session -remoteDirectory 'c:\temp' -localDirectory 'c:\temp'
#>
function Copy-FilesFromRemoteMachine
{
    [CmdletBinding()]
    param(
        [System.Management.Automation.Runspaces.PSSession] $session,
        [string] $remoteDirectory = "c:\logs",
        [string] $localDirectory
    )

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    # Create the directory on the local machine
    if (-not (Test-Path $localDirectory))
    {
        New-Item -Path $localDirectory -ItemType Directory
    }

    # Create the installer directory on the virtual machine
    $remoteFiles = Invoke-Command `
        -Session $session `
        -ArgumentList @( $remoteDirectory ) `
        -ScriptBlock {
            param(
                [string] $dir
            )

            return Get-ChildItem -Recurse -Path $dir
        } `
         @commonParameterSwitches

    # Push binaries to the new VM
    Write-Verbose "Copying files from the virtual machine"
    foreach($fileToCopy in $remoteFiles)
    {
        $file = $fileToCopy.FullName
        $localPath = Join-Path $localDirectory (Split-Path -Leaf $file)

        Write-Verbose "Copying $fileToCopy to $localPath"
        Copy-ItemFromRemoteMachine -localPath $localPath -remotePath $file -Session $session @commonParameterSwitches
    }
}

<#
    .SYNOPSIS

    Removes a directory on the given remote machine.


    .DESCRIPTION

    The Remove-FilesFromRemoteMachine function removes a directory on the given remote machine.


    .PARAMETER session

    The PSSession that provides the connection between the local machine and the remote machine.


    .PARAMETER remoteDirectory

    The full path to the remote directory that should be removed


    .EXAMPLE

    Remove-FilesFromRemoteMachine -session $session -remoteDirectory 'c:\temp'
#>
function Remove-FilesFromRemoteMachine
{
    [CmdletBinding()]
    param(
        [System.Management.Automation.Runspaces.PSSession] $session,
        [string] $remoteDirectory = "c:\logs"
    )

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    # Create the installer directory on the virtual machine
    Invoke-Command `
        -Session $session `
        -ArgumentList @( $remoteDirectory ) `
        -ScriptBlock {
            param(
                [string] $dir
            )

            if (Test-Path $dir)
            {
                Remove-Item -Path $dir -Force -Recurse
            }
        } `
         @commonParameterSwitches
}