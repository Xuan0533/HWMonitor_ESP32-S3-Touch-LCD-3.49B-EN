param([ValidateSet('Auto','Private','Conda','Venv')][string]$Mode='Auto',[switch]$SkipFlash,[switch]$NoStart,[string]$Port,[string]$CondaExe,[string]$PythonExe)
$ErrorActionPreference='Stop'
# Child process isolation only; no persistent environment changes.
Remove-Item Env:PYTHONHOME,Env:PYTHONPATH -ErrorAction SilentlyContinue
$env:PYTHONNOUSERSITE='1'
Set-Location -LiteralPath $PSScriptRoot
. (Join-Path $PSScriptRoot 'runtime.ps1')
. (Join-Path $PSScriptRoot 'tools.ps1')
if (![Environment]::Is64BitOperatingSystem -or $env:PROCESSOR_ARCHITECTURE -ne 'AMD64') {throw 'Windows x64 PowerShell is required.'}
if (Test-Path '.\runtime.local.json') {Write-Host 'Repairing existing local installation.'}
& (Join-Path $PSScriptRoot 'stop.ps1') -Quiet
$env:PIP_CACHE_DIR=Join-Path $script:ToolsRoot 'pip-cache'
$env:PIP_CONFIG_FILE='NUL'
Remove-Item Env:PIP_USER,Env:PIP_TARGET,Env:PIP_PREFIX -ErrorAction SilentlyContinue
function Invoke-Checked { param([string]$Exe,[string[]]$Arguments); & $Exe @Arguments; if ($LASTEXITCODE -ne 0) { throw "Command failed ($LASTEXITCODE): $Exe $($Arguments -join ' ')" } }
function Find-Conda {
    $candidates=@($CondaExe,$env:CONDA_EXE)
    $cmd=Get-Command conda.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) {$candidates += $cmd.Source}
    foreach ($p in @($env:USERPROFILE,$env:LOCALAPPDATA,(Join-Path $env:LOCALAPPDATA 'Programs'),$env:ProgramData,'C:\')) {
        foreach ($n in @('miniconda3','anaconda3','miniforge3','mambaforge')) {if ($p) {$candidates += (Join-Path $p "$n\Scripts\conda.exe")}}
    }
    $candidates | Where-Object {$_ -and (Test-Path -LiteralPath $_ -PathType Leaf)} | Select-Object -First 1
}
if (!(Test-Path '.\pc\agent.py') -or !(Test-Path '.\lhm_bridge\Program.cs')) {throw 'Extract the complete ZIP first.'}
$conda=$null
if ($Mode -eq 'Auto') {if (Test-Path '.\runtime.local.json') {$Mode=(Get-Content '.\runtime.local.json' -Raw | ConvertFrom-Json).mode} else {$Mode='Private'}}
if ($Mode -eq 'Conda') {$conda=Find-Conda}
if ((Test-Path '.\runtime.local.json')) {
    $existing=Get-Content '.\runtime.local.json' -Raw | ConvertFrom-Json
    if ($existing.mode -ine $Mode) {throw 'Existing runtime has a different mode. Uninstall it first or select its mode explicitly.'}
    if ($existing.mode -eq 'conda' -and $existing.prefix -ine (Join-Path $PSScriptRoot '.runtime')) {throw 'Legacy/shared Conda environment detected. Use the legacy uninstall first, then install in a fresh directory.'}
}
Write-Host "[1/5] Private Python runtime ($Mode)"
if ($Mode -eq 'Private') {
    $py=Get-PrivatePython
    Save-MonitorRuntime -Mode private -Python $py
    & $py -m pip --version
    if ($LASTEXITCODE -ne 0) {Invoke-Checked $py @('-m','ensurepip','--upgrade')}
    Invoke-Checked $py @('-m','pip','install','-r',(Join-Path $PSScriptRoot 'pc\requirements.txt'))
} elseif ($Mode -eq 'Conda') {
    if (!$conda) {throw 'Conda not found. Use -CondaExe or install Miniconda first.'}
    $conda=(Resolve-Path -LiteralPath $conda).Path
    $prefix=Join-Path $PSScriptRoot '.runtime'; $py=Join-Path $prefix 'python.exe'
    if ((Test-Path -LiteralPath $prefix) -and ((Get-Item -LiteralPath $prefix -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {throw 'Refusing to use linked .runtime.'}
    if (!(Test-Path -LiteralPath $py)) {
        if ((Test-Path -LiteralPath $prefix) -and !(Test-Path -LiteralPath (Join-Path $prefix 'conda-meta'))) {throw 'Unexpected .runtime directory; inspect it before retrying.'}
        Invoke-Checked $conda @('create','--prefix',$prefix,'python=3.12','pip','-y')
    }
    if (!(Test-Path -LiteralPath (Join-Path $prefix 'conda-meta'))) {throw '.runtime is not a Conda environment.'}
    Save-MonitorRuntime -Mode conda -Python $py -CondaExe $conda -Prefix $prefix
    Invoke-Checked $conda @('run','--no-capture-output','--prefix',$prefix,$py,'-c','import sys; sys.exit(0 if sys.version_info[:2] == (3,12) else 1)')
    Invoke-Checked $conda @('run','--no-capture-output','--prefix',$prefix,$py,'-m','pip','install','-r',(Join-Path $PSScriptRoot 'pc\requirements.txt'))
} else {
    $py=Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
    if ((Test-Path '.venv') -and ((Get-Item '.venv' -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {throw 'Refusing to use linked .venv.'}
    if (!(Test-Path -LiteralPath $py)) {
        if ($PythonExe) {Invoke-Checked $PythonExe @('-m','venv','.venv')}
        elseif (Get-Command py.exe -ErrorAction SilentlyContinue) {Invoke-Checked 'py.exe' @('-3.12','-m','venv','.venv')}
        else {throw 'No Conda or Python 3.12 launcher found. Install one or pass -PythonExe.'}
    }
    if (!(Test-Path '.venv\pyvenv.cfg')) {throw 'Unexpected .venv folder.'}
    Save-MonitorRuntime -Mode venv -Python $py
    Invoke-Checked $py @('-c','import sys; sys.exit(0 if sys.version_info[:2] == (3,12) else 1)')
    Invoke-Checked $py @('-m','pip','install','-r',(Join-Path $PSScriptRoot 'pc\requirements.txt'))
}
& "$PSScriptRoot\python.cmd" -c 'import psutil,serial,pynvml,win32com.client,win32evtlog'
if ($LASTEXITCODE -ne 0) {throw 'Python dependency check failed.'}
Write-Host 'Python dependencies OK'
Write-Host '[2/5] .NET SDK and local bridge'
$dotnet=Get-Dotnet11
$project=Join-Path $PSScriptRoot 'lhm_bridge\PCMonitor.LhmBridge.csproj'
$out=Join-Path $PSScriptRoot 'build_lhm\bridge'
Invoke-Checked $dotnet @('publish',$project,'-c','Release','-f','net10.0','-r','win-x64','--self-contained','true','-p:Platform=x64','-o',$out)
if (!(Test-Path -LiteralPath (Join-Path $out 'PCMonitor.LhmBridge.exe'))) {throw 'Bridge output missing.'}
Write-Host '[3/5] PawnIO driver check'
$driver=Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\PawnIO' -ErrorAction SilentlyContinue
if (!$driver) {$driver=Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\PawnIO' -ErrorAction SilentlyContinue}
if (!$driver) {$driver=Get-CimInstance Win32_SystemDriver | Where-Object {$_.Name -match 'PawnIO' -or $_.DisplayName -match 'PawnIO'} | Select-Object -First 1}
if (!$driver) {
    $installer=Join-Path $PSScriptRoot 'vendor\LibreHardwareMonitor-master\LibreHardwareMonitor.Windows.Forms\Resources\PawnIO_setup.exe'
    $sig=Get-AuthenticodeSignature -LiteralPath $installer
    Write-Host "PawnIO signature: $($sig.Status) / $($sig.SignerCertificate.Subject)"
    if ($sig.Status -eq 'Valid' -and (Read-Host 'Install the bundled signed PawnIO driver? Verify publisher first [y/N]') -match '^(y|yes)$') {
        $p=Start-Process -FilePath $installer -Verb RunAs -Wait -PassThru
        if ($p.ExitCode -notin @(0,3010,1641)) {throw "PawnIO installer exit code $($p.ExitCode)"}
        Set-Content -LiteralPath (Join-Path $PSScriptRoot 'pawnio-installed-by-project.txt') -Value ([DateTime]::Now.ToString('o')) -Encoding ASCII
        if ($p.ExitCode -in @(3010,1641)) {throw 'Restart Windows and run Install.cmd again (installed dependencies are reused).'}
    } else {throw 'PawnIO installation declined or signature invalid. Install the trusted driver, then retry.'}
} else {Write-Host 'Existing PawnIO installation detected; not changed.'}
Write-Host '[4/5] Firmware and USB verification'
if (!$SkipFlash) {
    Write-Host 'Connect ONE Waveshare ESP32-S3-Touch-LCD-3.49 V2 via USB data cable.'
    Write-Host 'Flashing replaces the entire factory application. V1 and other models are NOT supported.'
    $choice=Read-Host 'Type V2 to confirm flashing or SKIP to retain existing firmware'
    if ($choice -notin @('V2','SKIP')) {throw 'Installation interrupted: enter V2 or SKIP explicitly.'}
    if ($choice -ieq 'V2') {
        if (!$Port) {
            & "$PSScriptRoot\python.cmd" (Join-Path $PSScriptRoot 'pc\launcher.py') --configure-required
            if ($LASTEXITCODE -ne 0) {throw 'No screen selected. Enter BOOT mode and retry.'}
            $Port=(Get-Content '.\config.json' -Raw | ConvertFrom-Json).port
        }
        if ($Port -notmatch '^COM[0-9]+$') {throw 'Invalid COM port.'}
        if (!(Test-Path '.\build\PCMonitorV2\PCMonitorV2.ino')) {
            & "$PSScriptRoot\python.cmd" (Join-Path $PSScriptRoot 'prepare_firmware.py')
            if ($LASTEXITCODE -ne 0) {throw 'Firmware staging failed.'}
        }
        & (Join-Path $PSScriptRoot 'flash.ps1') -InstallCore -Upload -Port $Port
        & "$PSScriptRoot\python.cmd" (Join-Path $PSScriptRoot 'pc\probe.py') --port $Port
        if ($LASTEXITCODE -ne 0) {throw 'Upload completed but display did not acknowledge PCM3. Check USB/reset and run TestScreen.cmd.'}
    } else {Write-Host 'Firmware skipped. Existing PCM3 firmware required.'}
}
& "$PSScriptRoot\python.cmd" (Join-Path $PSScriptRoot 'pc\launcher.py') --configure
if ($LASTEXITCODE -ne 0) {throw 'Port configuration failed.'}
Write-Host '[5/5] Installation finished.' -ForegroundColor Green
if (!$NoStart -and (Read-Host 'Start monitoring now? [Y/n]') -notmatch '^(n|no)$') {
    & "$PSScriptRoot\python.cmd" (Join-Path $PSScriptRoot 'pc\launcher.py')
    if ($LASTEXITCODE -ne 0) {throw 'Monitor failed to start; check logs.'}
}
