param([string]$Target=$PSScriptRoot,[switch]$Interactive,[string]$ExpectedSid)
$ErrorActionPreference='Stop'
trap { Write-Host ($_.ToString()) -ForegroundColor Red; if ($Interactive) { [void](Read-Host 'Press Enter to close') }; exit 1 }
$root=(Resolve-Path -LiteralPath $Target).Path.TrimEnd('\')
if ((Get-Item -LiteralPath $root -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {throw 'Refusing linked project root.'}
if (!(Test-Path -LiteralPath (Join-Path $root 'pc\agent.py')) -or !(Test-Path -LiteralPath (Join-Path $root 'config.json'))) {throw "Not a PCMonitor installation: $root"}
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
if ($ExpectedSid -and $identity.User.Value -ne $ExpectedSid) {throw 'Elevation used a different Windows account. Run from the original installation account.'}
$admin=([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (!$admin) {
    $argsLine='-NoProfile -ExecutionPolicy Bypass -File "'+$PSCommandPath+'" -Target "'+$root+'" -Interactive -ExpectedSid '+$identity.User.Value
    $p=Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') -ArgumentList $argsLine -Verb RunAs -Wait -PassThru
    exit $p.ExitCode
}
Set-Location -LiteralPath $env:TEMP
function Under([string]$path,[string]$parent) {
    if (!$path -or !$parent) {return $false}
    try {$a=[IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($path.Trim().Trim('"'))).TrimEnd('\'); $b=[IO.Path]::GetFullPath($parent).TrimEnd('\'); return ($a -ieq $b -or $a.StartsWith($b+'\',[StringComparison]::OrdinalIgnoreCase))} catch {return $false}
}
function Refers([string]$line,[string]$path) {
    if (!$line -or !$path) {return $false}
    return [regex]::IsMatch($line,'(?i)(?:^|[\s"])(?:'+[regex]::Escape($path)+')(?=$|[\s"])')
}
$runtimePath=Join-Path $root 'runtime.local.json'; $r=$null
if (Test-Path -LiteralPath $runtimePath) {$r=Get-Content -LiteralPath $runtimePath -Raw | ConvertFrom-Json}
$prefix=$null; $conda=$null
if ($r -and $r.mode -eq 'conda') {
    $prefix=$r.prefix; $conda=$r.conda_exe
    if (!$prefix -or !$conda -or !(Test-Path -LiteralPath $conda -PathType Leaf)) {throw 'Invalid recorded Conda runtime; no environment removed.'}
    $prefix=[IO.Path]::GetFullPath($prefix).TrimEnd('\')
    $baseOutput=& $conda info --base
    if ($LASTEXITCODE -ne 0) {throw 'Cannot verify Conda base; no environment removed.'}
    $base=[IO.Path]::GetFullPath(($baseOutput -join "`n").Trim()).TrimEnd('\')
    if ($prefix -ieq $base -or (Under $base $prefix)) {throw 'Refusing to remove Conda base or its parent.'}
    if ($prefix -ine (Join-Path $root '.runtime') -and (Split-Path $prefix -Leaf) -ine 'pcmonitor') {throw "Nonstandard Conda environment '$prefix'. Remove manually after checking it is not shared."}
    if ((Test-Path -LiteralPath $prefix) -and !(Test-Path -LiteralPath (Join-Path $prefix 'conda-meta'))) {throw 'Recorded directory is not a Conda environment.'}
    if (Test-Path -LiteralPath $prefix) {
        if ((Get-Item -LiteralPath $prefix -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {throw 'Refusing to remove linked Conda environment.'}
        $raw=& $conda env list --json
        if ($LASTEXITCODE -ne 0) {throw 'Cannot verify environment list.'}
        $known=@((($raw -join "`n") | ConvertFrom-Json).envs | Where-Object {$_ -and ([IO.Path]::GetFullPath($_).TrimEnd('\') -ieq $prefix)})
        if ($known.Count -ne 1) {throw 'Recorded environment not uniquely registered; no environment removed.'}
    }
    if ($env:CONDA_PREFIX -and ([IO.Path]::GetFullPath($env:CONDA_PREFIX).TrimEnd('\') -ieq $prefix)) {throw 'Deactivate the PCMonitor Conda environment, close its terminals, and rerun.'}
}
$venv=Join-Path $root '.venv'
if ((Test-Path -LiteralPath $venv) -and !(Test-Path -LiteralPath (Join-Path $venv 'pyvenv.cfg'))) {throw 'Unexpected .venv directory; inspect it manually.'}
Write-Host "Installation: $root"
if ($prefix) {Write-Host "Conda environment to remove: $prefix"}
if (Test-Path -LiteralPath $venv) {Write-Host "Local venv to remove: $venv"}
Write-Host 'Will stop this installation, remove its tasks/runtime, and retain logs, config, source and firmware. Shared software/drivers are retained.'
if ((Read-Host 'Continue? [y/N]') -notmatch '^(y|yes)$') {Write-Host 'Cancelled.'; if ($Interactive) {[void](Read-Host 'Press Enter to close')}; return}
# Remove new path-specific task before deleting anything. Also handle legacy tasks below.
$sha=[Security.Cryptography.SHA256]::Create()
try {$taskId=[BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($root.ToUpperInvariant()))).Replace('-','').Substring(0,16)} finally {$sha.Dispose()}
$newName='HWMonitor_ESP32-'+$taskId
$newTask=Get-ScheduledTask -TaskName $newName -TaskPath '\' -ErrorAction SilentlyContinue
if ($newTask) {
    if (!(@($newTask.Actions | Where-Object { (Under $_.WorkingDirectory $root) -and (Refers $_.Arguments (Join-Path $root 'scheduled_run.ps1')) }).Count)) {throw 'Task action does not match this installation; inspect manually.'}
    Disable-ScheduledTask -InputObject $newTask | Out-Null
}
$logs=Join-Path $root 'logs'; New-Item -ItemType Directory -Path $logs -Force | Out-Null
foreach ($f in @('stop.request','bridge.stop')) {New-Item -ItemType File -Path (Join-Path $logs $f) -Force | Out-Null}
# Scope legacy task removal by name AND action path, not name alone.
foreach ($name in @('PCMonitorV2','PCMonitorV2-LHM')) {
    $task=Get-ScheduledTask -TaskName $name -TaskPath '\' -ErrorAction SilentlyContinue
    if (!$task) {continue}
    $ours=@($task.Actions | Where-Object { (Under $_.WorkingDirectory $root) -or (Under $_.Execute $root) -or (Refers $_.Arguments (Join-Path $root 'launch_hidden.vbs')) }).Count -gt 0
    if (!$ours) {Write-Warning "Task $name refers to another installation; not touched.";continue}
    if ($task.State -eq 'Running') {Stop-ScheduledTask -TaskName $name -TaskPath '\'}
    Unregister-ScheduledTask -TaskName $name -TaskPath '\' -Confirm:$false
    Write-Host "Removed task $name"
}
Start-Sleep -Seconds 4
if ($newTask) {
    for ($i=0;$i -lt 20;$i++) {
        if ((Get-ScheduledTask -TaskName $newName -TaskPath '\').State -ne 'Running') {break}
        Start-Sleep -Milliseconds 500
    }
    if ((Get-ScheduledTask -TaskName $newName -TaskPath '\').State -eq 'Running') {Stop-ScheduledTask -TaskName $newName -TaskPath '\'}
    Unregister-ScheduledTask -TaskName $newName -TaskPath '\' -Confirm:$false
}
$agent=Join-Path $root 'pc\agent.py'; $launcher=Join-Path $root 'pc\launcher.py'; $bridge=Join-Path $root 'build_lhm\bridge\PCMonitor.LhmBridge.exe'
# Graceful stop markers first; old manually launched bridge has no stop-file support.
# Only stop exact project processes; never stop every python/conda process.
$procs=@(Get-CimInstance Win32_Process | Where-Object {
    ($_.ExecutablePath -and $_.ExecutablePath -ieq $bridge) -or
    ($_.Name -match '^pythonw?\.exe$' -and ((Refers $_.CommandLine $agent) -or (Refers $_.CommandLine $launcher)))
})
foreach ($p in $procs) {Write-Host "Stopping remaining project process $($p.Name) ($($p.ProcessId))"; Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue}
Start-Sleep -Seconds 2
# Do not remove a runtime with unrelated processes still executing from it.
foreach ($p in (Get-CimInstance Win32_Process)) {
    if (($prefix -and (Under $p.ExecutablePath $prefix)) -or (Under $p.ExecutablePath $venv) -or (Under $p.ExecutablePath (Join-Path $root '.tools'))) {throw "Runtime still in use by $($p.Name) PID $($p.ProcessId). Close it and rerun."}
}
if ($prefix -and (Test-Path -LiteralPath $prefix)) {
    & $conda env remove --prefix $prefix --yes
    if ($LASTEXITCODE -ne 0) {throw 'Conda environment removal failed; runtime metadata retained.'}
    if (Test-Path -LiteralPath (Join-Path $prefix 'conda-meta')) {throw 'Conda metadata remains; inspect removal output.'}
}
if (Test-Path -LiteralPath $venv) {
    if ((Get-Item -LiteralPath $venv -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {throw 'Refusing to recursively delete linked .venv.'}
    Remove-Item -LiteralPath $venv -Recurse -Force
}
# Old setup scripts never edited PATH. Offer to remove only orphaned references
# to the removed environments if a user had added them independently.
$targets=@($prefix,$venv,(Join-Path $root '.tools\python')) | Where-Object {$_}
foreach ($scope in @('User','Machine')) {
    $key=if ($scope -eq 'User') {[Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment',$true)} else {[Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment',$true)}
    if (!$key) {continue}
    try {
        foreach ($name in @('Path','PYTHONPATH','PYTHONHOME')) {
            $raw=$key.GetValue($name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            if ($raw -isnot [string]) {continue}
            $parts=if ($name -eq 'PYTHONHOME') {@($raw)} else {$raw.Split(';')}
            $remove=@($parts | Where-Object {$part=$_; @($targets | Where-Object {Under $part $_}).Count -gt 0})
            if (!$remove.Count) {continue}
            Write-Host "$scope $name contains orphaned project environment paths: $($remove -join '; ')"
            if ((Read-Host 'Remove only these references? [y/N]') -match '^(y|yes)$') {
                $left=@($parts | Where-Object {$_ -notin $remove})
                if ($name -eq 'PYTHONHOME' -or ($name -eq 'PYTHONPATH' -and !$left.Count)) {$key.DeleteValue($name,$false)}
                else {$key.SetValue($name,($left -join ';'),$key.GetValueKind($name))}
            }
        }
    } finally {$key.Close()}
}
if (Test-Path -LiteralPath (Join-Path $root 'tools.ps1')) {
    foreach ($rel in @('.tools','build','build_lhm','lhm_bridge\bin','lhm_bridge\obj','vendor\LibreHardwareMonitor-master\bin','vendor\LibreHardwareMonitor-master\obj','vendor\LibreHardwareMonitor-master\LibreHardwareMonitorLib\bin','vendor\LibreHardwareMonitor-master\LibreHardwareMonitorLib\obj')) {
        $dir=Join-Path $root $rel
        if (!(Test-Path -LiteralPath $dir)) {continue}
        # Do not recursively traverse reparse points. Check each ancestor and child directory.
        $cur=$dir
        while ($cur -ine $root) {
            if ((Get-Item -LiteralPath $cur -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {throw "Refusing linked generated directory: $cur"}
            $cur=Split-Path -Parent $cur
        }
        $pending=New-Object 'System.Collections.Generic.Stack[string]';$pending.Push($dir)
        while ($pending.Count) {
            $next=$pending.Pop()
            foreach ($entry in (Get-ChildItem -LiteralPath $next -Force)) {
                if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) {throw "Refusing linked generated entry: $($entry.FullName)"}
                if ($entry.PSIsContainer) {$pending.Push($entry.FullName)}
            }
        }
        Remove-Item -LiteralPath $dir -Recurse -Force
    }
}
if (Test-Path -LiteralPath $runtimePath) {Remove-Item -LiteralPath $runtimePath -Force}
foreach ($f in @('lhm_snapshot.json','lhm_snapshot.json.tmp')) {$p=Join-Path $logs $f;if (Test-Path -LiteralPath $p) {Remove-Item -LiteralPath $p -Force}}
Write-Host 'Uninstall complete. No flash operation. Logs and source retained; you may archive/delete the project folder yourself.' -ForegroundColor Green
if (Test-Path -LiteralPath (Join-Path $root 'pawnio-installed-by-project.txt')) {Write-Host 'PawnIO was installed by this release. If no other software uses it, uninstall PawnIO separately in Windows Settings > Apps > Installed apps.'}
Write-Host 'Open a fresh terminal (sign out/in if you changed persistent environment variables). Base Python, other environments, SDK, Arduino and PawnIO remain installed.'

if ($Interactive) { [void](Read-Host 'Press Enter to close') }
