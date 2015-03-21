$cpuLoad = (Get-Counter '\processor(_total)\% processor time' -SampleInterval 1).CounterSamples.CookedValue

$warnAt = 95
$criticalAt = 90

$processorText = ''
$diskText += "Average load: $([int]([System.Math]::Round($cpuLoad)))%"

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

Write-Output ($text + " - " + $diskText)
exit $exitCode