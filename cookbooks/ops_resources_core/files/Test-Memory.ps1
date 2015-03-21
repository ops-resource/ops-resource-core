$os = Get-WmiObject Win32_OperatingSystem -ComputerName .

$warnAt = 10
$criticalAt = 5

$hasError = $false
$hasWarning = $false

[double]$freeSpace = $disk.FreeSpace
[double]$size = $disk.Size

$freeVirtualInMb = [int]([System.Math]::Truncate($os.FreeVirtualMemory / 1024))
$freePhysicalInMb = [int]([System.Math]::Truncate($os.FreePhysicalMemory / 1024))

$ratioVirtual = [int]([System.Math]::Round(($os.FreeVirtualMemory / $os.TotalVirtualMemorySize) * 100.0))
$ratioPhysical = [int]([System.Math]::Round(($os.FreePhysicalMemory / $os.TotalVisibleMemorySize) * 100.0))

$memoryText = "free virtual space: $freeVirtualInMb Mb ($ratioVirtual%); free physical space: $freePhysicalInMb Mb ($ratioPhysical%)"
$hasWarning = $hasWarning -or ($ratioVirtual -lt $warnAt) -or ($ratioPhysical -lt $warnAt)
$hasError = $hasError -or ($ratioVirtual -lt $criticalAt) -or ($ratioPhysical -lt $criticalAt)


$exitCode = 0
$text = "MEMORY OK"
if ($hasWarning)
{
    $exitCode = 1
    $text = "WARNING: Memory space"
}

if ($hasError)
{
    $exitCode = 2
    $text = "CRITICAL: Memory space"
}

Write-Output ($text + " - " + $memoryText)
exit $exitCode