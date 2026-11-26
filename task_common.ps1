# Deterministic installation-specific name. No cross-version task collisions.
$script:MonitorRoot=$PSScriptRoot
$sha=[Security.Cryptography.SHA256]::Create()
try {$id=[BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($script:MonitorRoot.TrimEnd('\').ToUpperInvariant()))).Replace('-','').Substring(0,16)} finally {$sha.Dispose()}
$script:MonitorTask='HWMonitor_ESP32-'+$id
function Get-OwnMonitorTask {Get-ScheduledTask -TaskName $script:MonitorTask -TaskPath '\' -ErrorAction SilentlyContinue}
