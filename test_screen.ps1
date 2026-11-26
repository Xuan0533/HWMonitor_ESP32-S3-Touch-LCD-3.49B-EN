param([string]$Port)
$ErrorActionPreference='Stop'
Set-Location -LiteralPath $PSScriptRoot
& .\stop.ps1 -Quiet
if (!$Port) {& .\python.cmd pc\launcher.py --configure-required; if ($LASTEXITCODE -ne 0) {throw 'No screen selected.'};$Port=(Get-Content .\config.json -Raw | ConvertFrom-Json).port}
& .\python.cmd pc\probe.py --port $Port
exit $LASTEXITCODE
