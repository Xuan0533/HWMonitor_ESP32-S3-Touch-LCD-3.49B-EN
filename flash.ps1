param([string]$Port, [switch]$InstallCore, [switch]$Upload)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
. (Join-Path $PSScriptRoot 'tools.ps1')
$cli = Get-ArduinoCli
function Invoke-Cli { & $cli @args; if ($LASTEXITCODE -ne 0) { throw 'Arduino CLI command failed' } }
if ($InstallCore) {
    $url='https://espressif.github.io/arduino-esp32/package_esp32_index.json'
    Invoke-Cli core update-index --additional-urls $url
    Invoke-Cli core install 'esp32:esp32@3.3.0' --additional-urls $url
}
if (!(Test-Path 'build\PCMonitorV2\PCMonitorV2.ino')) { throw 'Run prepare_firmware.py first' }
if (!(Test-Path 'build\PCMonitorV2\monitor_ui.cpp') -or ((Get-FileHash 'build\PCMonitorV2\monitor_ui.cpp').Hash -ne (Get-FileHash 'firmware\monitor_ui.cpp').Hash)) { throw 'Staged UI differs from release. Back up the staged file, then copy firmware\monitor_ui.cpp to build\PCMonitorV2\monitor_ui.cpp or restage official V2 sources.' }
if ((Get-Content 'build\PCMonitorV2\PCMonitorV2.ino' -Raw) -notmatch 'Serial\.setRxBufferSize\(4096\)') {throw 'Staged firmware lacks the required USB RX buffer patch. Rename build, then run prepare_firmware.py.'}
if (!(Test-Path 'build\libraries\lvgl\library.properties')) { throw 'Official LVGL 9.3 library is missing; see README' }
$fqbn='esp32:esp32:esp32s3:USBMode=hwcdc,CDCOnBoot=cdc,FlashSize=16M,PSRAM=opi,PartitionScheme=app3M_fat9M_16MB,UploadSpeed=115200'
$sketch=Join-Path $PSScriptRoot 'build\PCMonitorV2'
$lib=Join-Path $PSScriptRoot 'build\libraries'
$out=Join-Path $PSScriptRoot 'build\compiled'
Invoke-Cli compile --fqbn $fqbn --libraries $lib --output-dir $out $sketch
if ($Upload) {
    if ($Port -notmatch '^COM[0-9]+$') { throw 'Specify your ESP32 port explicitly: -Upload -Port COM5' }
    & (Join-Path $PSScriptRoot 'python.cmd') (Join-Path $PSScriptRoot 'pc\probe.py') --port $Port --identify
    if ($LASTEXITCODE -ne 0) {throw 'Refusing to flash non-Espressif USB Serial/JTAG port.'}
    Write-Host "Uploading custom firmware to $Port. This replaces factory firmware."
    Invoke-Cli upload --fqbn $fqbn --port $Port --input-dir $out $sketch
}
