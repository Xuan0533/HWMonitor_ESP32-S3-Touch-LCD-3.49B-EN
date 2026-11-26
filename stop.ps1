param([switch]$Quiet)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'task_common.ps1')
$logs=Join-Path $PSScriptRoot 'logs'
New-Item -ItemType Directory -Path $logs -Force | Out-Null
foreach ($f in @('stop.request','bridge.stop')) {New-Item -ItemType File -Path (Join-Path $logs $f) -Force | Out-Null}
function Get-ProjectProcesses {
    $bridge=Join-Path $PSScriptRoot 'build_lhm\bridge\PCMonitor.LhmBridge.exe'
    $agent=Join-Path $PSScriptRoot 'pc\agent.py';$launcher=Join-Path $PSScriptRoot 'pc\launcher.py'
    Get-CimInstance Win32_Process | Where-Object {
        ($_.ExecutablePath -and $_.ExecutablePath -ieq $bridge) -or
        ($_.Name -match '^pythonw?\.exe$' -and $_.CommandLine -and ($_.CommandLine -match ('(?i)(?:^|[\s"])(?:'+[regex]::Escape($agent)+'|'+[regex]::Escape($launcher)+')(?=$|[\s"])')))
    }
}
for ($i=0;$i -lt 40;$i++) {
    $task=Get-OwnMonitorTask
    $processes=@(Get-ProjectProcesses)
    if (!$processes.Count -and (!$task -or $task.State -ne 'Running')) {if (!$Quiet) {Write-Host 'Monitor stopped.'};return}
    Start-Sleep -Milliseconds 500
}
throw 'Monitor did not stop within 20 seconds. Close its console or stop its task as administrator before retrying.'
