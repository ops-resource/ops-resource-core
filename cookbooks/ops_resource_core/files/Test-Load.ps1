$sampleTime = 10

$wmiProcessor = Get-WmiObject win32_processor
$loadPercentage = $wmiProcessor | Select-Object LoadPercentage
$cpuLoad = $loadPercentage.LoadPercentage

$warnAt = 95
$criticalAt = 90

$loadText = "Average load: $cpuLoad%"

$hasWarning = ($cpuLoad -gt $warnAt)
$hasError = ($cpuLoad -gt $criticalAt)

$exitCode = 0
$text = "LOAD OK"
if ($hasWarning)
{
    $exitCode = 1
    $text = "WARNING: Load"
}

if ($hasError)
{
    $exitCode = 2
    $text = "CRITICAL: Load"
}

Write-Output ($text + " - " + $loadText)
exit $exitCode