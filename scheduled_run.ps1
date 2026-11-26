$ErrorActionPreference='Stop'
Set-Location -LiteralPath $PSScriptRoot
New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot 'logs') -Force | Out-Null
try {
    & (Join-Path $PSScriptRoot 'run_python.ps1') (Join-Path $PSScriptRoot 'pc\launcher.py') --startup
    exit $LASTEXITCODE
} catch {Add-Content -LiteralPath (Join-Path $PSScriptRoot 'logs\startup.log') -Value "$(Get-Date -Format o) $_";exit 1}
