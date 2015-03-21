$disks = Get-WmiObject Win32_LogicalDisk -ComputerName .

$warnAt = 10
$criticalAt = 5

$hasError = $false
$hasWarning = $false
$diskText = ''
foreach($disk in $disks)
{
    if (($disk.ProviderName -eq $null) -or ($disk.ProviderName -eq ''))
    {
        [double]$freeSpace = $disk.FreeSpace
        [double]$size = $disk.Size

        $freeInMb = [int]([System.Math]::Truncate($freeSpace / (1024 * 1024)))
        $ratio = [int]([System.Math]::Round(($freeSpace / $size) * 100.0))

        $text = "DISK OK"
        if ($ratio -lt $warnAt)
        {
            $hasWarning = $true
            $text = "WARNING: Disk space"
        }

        if ($ratio -lt $criticalAt)
        {
            $hasError = $true
            $text = "CRITICAL: Disk space"
        }

        Write-Output ($text + " - [$($disk.DeviceID)] free space: $freeInMb Mb ($ratio%); ")
    }
}

$exitCode = 0
if ($hasWarning)
{
    $exitCode = 1
}

if ($hasError)
{
    $exitCode = 2
}
exit $exitCode