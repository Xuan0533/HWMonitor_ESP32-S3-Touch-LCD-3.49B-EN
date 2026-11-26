param([ValidateSet('Enable','Disable','Status')][string]$Action='Status',[string]$ExpectedSid)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'task_common.ps1')
$id=[Security.Principal.WindowsIdentity]::GetCurrent()
if ($ExpectedSid -and $id.User.Value -ne $ExpectedSid) {throw 'Use the same administrator-capable Windows account; different elevation accounts are not supported.'}
$admin=([Security.Principal.WindowsPrincipal]::new($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($Action -ne 'Status' -and !$admin) {
    $a='-NoProfile -ExecutionPolicy Bypass -File "'+$PSCommandPath+'" -Action '+$Action+' -ExpectedSid '+$id.User.Value
    $p=Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList $a -Verb RunAs -Wait -PassThru
    exit $p.ExitCode
}
$task=Get-OwnMonitorTask
if ($Action -eq 'Status') {if ($task) {$task | Select-Object TaskName,State; $task | Get-ScheduledTaskInfo | Select-Object LastRunTime,LastTaskResult,NextRunTime} else {Write-Host 'Autostart not registered.'};return}
if ($Action -eq 'Disable') {
    if ($task) {Disable-ScheduledTask -InputObject $task | Out-Null; & (Join-Path $PSScriptRoot 'stop.ps1') -Quiet; Unregister-ScheduledTask -TaskName $script:MonitorTask -TaskPath '\' -Confirm:$false}
    Write-Host 'Autostart removed.';return
}
if (!(Test-Path (Join-Path $PSScriptRoot 'runtime.local.json')) -or !(Test-Path (Join-Path $PSScriptRoot 'build_lhm\bridge\PCMonitor.LhmBridge.exe'))) {throw 'Run Install.cmd first.'}
if ($PSScriptRoot.StartsWith('\\') -or (Get-Item -LiteralPath $PSScriptRoot -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {throw 'Use a trusted local, non-linked directory.'}
Write-Host 'This registers an elevated task under YOUR account at Windows sign-in. Both bridge and agent will be elevated in this mode.'
Write-Host 'Do not use shared writable folders. Do not let other users modify this release or its runtime.'
if ((Read-Host 'Register this task? [y/N]') -notmatch '^(y|yes)$') {return}
& (Join-Path $PSScriptRoot 'stop.ps1') -Quiet
$user=$id.Name
$ps=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$arg='-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+(Join-Path $PSScriptRoot 'scheduled_run.ps1')+'"'
$act=New-ScheduledTaskAction -Execute $ps -Argument $arg -WorkingDirectory $PSScriptRoot
$trigger=New-ScheduledTaskTrigger -AtLogOn -User $user
$principal=New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
$settings=New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) -StartWhenAvailable
Register-ScheduledTask -TaskName $script:MonitorTask -TaskPath '\' -Action $act -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Start-ScheduledTask -TaskName $script:MonitorTask -TaskPath '\'
Write-Host 'Autostart registered and started. Use Startup_status.cmd to inspect.'
