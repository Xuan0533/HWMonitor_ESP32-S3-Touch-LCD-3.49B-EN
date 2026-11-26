param([string]$Port)
$ErrorActionPreference='Stop'
Set-Location -LiteralPath $PSScriptRoot
& .\stop.ps1 -Quiet
if ((Read-Host 'Connect Waveshare 3.49 V2 and type V2 to authorize replacing its firmware') -cne 'V2') {return}
if (!$Port) {
    & .\python.cmd pc\launcher.py --configure-required
    if ($LASTEXITCODE -ne 0) {throw 'No screen selected.'}
    $Port=(Get-Content .\config.json -Raw | ConvertFrom-Json).port
}
if (!(Test-Path '.\build\PCMonitorV2\PCMonitorV2.ino')) {
    & .\python.cmd prepare_firmware.py
    if ($LASTEXITCODE -ne 0) {throw 'Staging failed.'}
}
& .\flash.ps1 -InstallCore -Upload -Port $Port
& .\python.cmd pc\probe.py --port $Port
if ($LASTEXITCODE -ne 0) {throw 'No PCM3 ACK; run TestScreen.cmd after resetting device.'}
