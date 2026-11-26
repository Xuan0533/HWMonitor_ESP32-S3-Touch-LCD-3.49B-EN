param([switch]$Build,[switch]$Start,[switch]$RegisterStartup,[switch]$Status,[switch]$Stop,[switch]$Remove)
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$name='PCMonitorV2-LHM'
$out=Join-Path $root 'build_lhm\bridge'
$exe=Join-Path $out 'PCMonitor.LhmBridge.exe'
$snapshot=Join-Path $root 'logs\lhm_snapshot.json'
if (@(@($Build,$Start,$RegisterStartup,$Status,$Stop,$Remove)|Where-Object {$_}).Count -ne 1) {throw 'Specify one: -Build, -Start, -RegisterStartup, -Status, -Stop, -Remove'}
if ($Build) {
    . (Join-Path $root 'tools.ps1')
    $dotnet=Get-Dotnet11
    $project=Join-Path $root 'lhm_bridge\PCMonitor.LhmBridge.csproj'
    & $dotnet --list-sdks
    & $dotnet publish $project -c Release -f net10.0 -r win-x64 --self-contained true -p:Platform=x64 -o $out
    if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $exe)) {throw 'Bridge build failed; see dotnet output above.'}
    Write-Host "Built: $exe"; return
}
$task=Get-ScheduledTask -TaskName $name -TaskPath '\' -ErrorAction SilentlyContinue
if ($Status) {
    if ($task) { $task | Select-Object TaskName,State; Get-ScheduledTaskInfo -TaskName $name -TaskPath '\' | Select-Object LastRunTime,LastTaskResult } else { Write-Host 'Bridge task not registered.' }
    if (Test-Path -LiteralPath $snapshot) { Get-Item -LiteralPath $snapshot | Select-Object FullName,LastWriteTime } else { Write-Host 'No bridge snapshot.' }
    return
}
if ($Stop -or $Remove) {
    if ($task) { if ($task.State -eq 'Running') { Stop-ScheduledTask -TaskName $name -TaskPath '\' }; if ($Remove) { Unregister-ScheduledTask -TaskName $name -TaskPath '\' -Confirm:$false } }
    Write-Host 'Scheduled bridge stopped/removed. A manually launched bridge must be stopped with Ctrl+C in its own console.'; return
}
if (!(Test-Path -LiteralPath $exe)) {throw 'Run lhm.ps1 -Build first.'}
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
$admin=([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($Start) {
    if ($task -and $task.State -eq 'Running') {throw 'Scheduled bridge already running.'}
    if (!$admin) {Write-Warning 'Some sensors may require administrator privileges. Use an elevated PowerShell if needed.'}
    & $exe $snapshot
    if ($LASTEXITCODE -ne 0) {throw "Bridge exit code $LASTEXITCODE"}; return
}
if (!$admin) {throw 'RegisterStartup requires an elevated PowerShell. This is an optional elevated logon task.'}
if ($task -and $task.State -eq 'Running') {throw 'Stop the existing bridge task before registering it again.'}
$user=$identity.Name
$action=New-ScheduledTaskAction -Execute $exe -Argument ('"'+$snapshot+'"') -WorkingDirectory $out
$trigger=New-ScheduledTaskTrigger -AtLogOn -User $user
$principal=New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
$settings=New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName $name -TaskPath '\' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
Write-Host 'Bridge logon task registered. Start it using Task Scheduler or sign out and back in. Do not run a second manual bridge.'
