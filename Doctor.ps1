$ErrorActionPreference='Continue'
Set-Location -LiteralPath $PSScriptRoot
Write-Host '=== HWMonitor ESP32 diagnostic ==='
Write-Host 'Runtime:'
if (Test-Path '.\runtime.local.json') {Get-Content '.\runtime.local.json'} else {Write-Warning 'Not installed.'}
Write-Host 'PawnIO service:'
Get-CimInstance Win32_SystemDriver | Where-Object {$_.Name -match 'PawnIO' -or $_.DisplayName -match 'PawnIO'} | Format-Table Name,State,StartMode
Write-Host 'Autostart:'
& .\startup.ps1 -Action Status
Write-Host 'USB ports:'
& .\run.cmd --list-ports
Write-Host 'Snapshot and readings (only fresh while bridge runs):'
& .\run.cmd --once
foreach ($file in @('startup.log','bridge.log','agent.log')) {if (Test-Path ".\logs\$file") {Write-Host "=== $file (last 20 lines) ===";Get-Content ".\logs\$file" -Tail 20}}
