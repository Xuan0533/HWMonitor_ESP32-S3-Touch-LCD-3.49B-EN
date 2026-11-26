# No param block: all arguments are forwarded to Python.
$ErrorActionPreference='Stop'
# Child process isolation only; no persistent environment changes.
Remove-Item Env:PYTHONHOME,Env:PYTHONPATH -ErrorAction SilentlyContinue
$env:PYTHONNOUSERSITE='1'
try {
    Set-Location -LiteralPath $PSScriptRoot
    . (Join-Path $PSScriptRoot 'runtime.ps1')
    $r=Get-MonitorRuntime
    if ($r.mode -eq 'conda') { & $r.conda_exe run --no-capture-output --prefix $r.prefix $r.python @args }
    else { & $r.python @args }
    exit $LASTEXITCODE
} catch {
    [Console]::Error.WriteLine($_.ToString())
    exit 1
}
