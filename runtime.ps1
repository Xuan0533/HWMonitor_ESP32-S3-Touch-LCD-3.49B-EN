# Shared launcher configuration; local to this installation, not distributed.
$script:RuntimeRoot = $PSScriptRoot
function Save-MonitorRuntime {
    param([string]$Mode, [string]$Python, [string]$CondaExe, [string]$Prefix)
    $record = [ordered]@{ mode=$Mode; python=$Python; conda_exe=$CondaExe; prefix=$Prefix }
    $record | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $script:RuntimeRoot 'runtime.local.json') -Encoding UTF8
}
function Get-MonitorRuntime {
    $file = Join-Path $script:RuntimeRoot 'runtime.local.json'
    if (Test-Path -LiteralPath $file) { $r = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json }
    else {
        # Compatibility with an already installed 1.0.0 venv.
        $r = [pscustomobject]@{mode='venv'; python=(Join-Path $script:RuntimeRoot '.venv\Scripts\python.exe')}
    }
    if ($r.mode -notin @('venv','conda','private') -or !(Test-Path -LiteralPath $r.python -PathType Leaf)) {
        throw 'Python runtime not found. Run Install.cmd again.'
    }
    if ($r.mode -eq 'conda' -and (!(Test-Path -LiteralPath $r.conda_exe -PathType Leaf) -or !(Test-Path -LiteralPath $r.prefix -PathType Container))) {
        throw 'Conda runtime not found. Run Install.cmd again.'
    }
    return $r
}
