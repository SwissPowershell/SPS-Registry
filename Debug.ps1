Remove-Module SPS-Registry -ErrorAction Ignore
Import-Module "$($PSScriptRoot)\SPS-Registry.psd1" -Force
# Set the most constrained mode
Set-StrictMode -Version Latest
# Set the error preference
$ErrorActionPreference = 'Stop'
# Set the verbose preference in order to get some insights
$VerbosePreference = 'Continue'

# change the verbose color so it's not the same color than the warnings
if (Get-Variable -Name PSStyle -ErrorAction SilentlyContinue) {
    $PSStyle.Formatting.Verbose = $PSStyle.Foreground.Cyan
}else{
    $Host.PrivateData.VerboseForegroundColor = [System.ConsoleColor]::Cyan
}
# $Path = 'HKLM:\Software\Microsoft\Windows'
$TempFile = New-TemporaryFile
reg export HKLM\Software\Microsoft $TempFile.FullName /y 2>&1 | Out-Null
$StopwatchNative = [System.Diagnostics.Stopwatch]::new()
$StopwatchNative.Start()
$Registry = Get-SPSRegistry -File $TempFile.FullName
$Registry | out-null
$StopwatchNative.Stop()

Write-Host "The module command took: $($StopwatchNative.Elapsed.TotalMilliseconds)ms"
$TempFile | Remove-Item -Force

#### Seems quicker to run an Reg Export then to read the output file than to try to objectify the registry Key by Key
# reg export HKLM\Software\Microsoft MS.reg /y 2>&1 | Out-Null