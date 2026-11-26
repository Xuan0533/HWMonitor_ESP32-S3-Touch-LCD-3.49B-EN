# PCMonitor V2 1.2.0

- Bundles the exact uploaded LibreHardwareMonitor master source tree and original licenses (source version property: 0.9.6).
- Adds local .NET 10 x64 sensor bridge referencing bundled library; no HTTP listener or hardware control calls. Python checks timestamp/schema and rejects stale snapshots. Legacy WMI is opt-in.
- Adds lhm.ps1 build/start/status and optional elevated logon task registration/removal. No automatic driver installation.
- Firmware and PCM2 protocol unchanged. Source and SDK/NuGet dependencies are not equivalent to a prebuilt executable; Windows build and hardware validation remain outstanding.

# PCMonitor V2 1.1.0

- Windows Miniconda support: dedicated Python 3.12 environment, automatic discovery, explicit path override, import checks, no base installation.
- Existing venv installation remains supported. Both environments share `run.cmd` and `python.cmd` via a locally recorded runtime configuration.
- Logon startup with hidden launcher, status/start/stop/remove actions, failure retry and graceful stop request. Windows file lock prevents multiple continuous collectors in the same installation.
- Configurable daily CSV retention (new config: 30 days; existing config without field: disabled; 0 disables). Only strictly matching dated telemetry/demo CSV names are removed.
- Added `--version`, retention unit tests and revised Chinese setup/upgrade instructions.
- No firmware or PCM2 protocol changes. An already functioning 1.0.0 ESP32 does not need to be reflashed.

Validation: four Python unit tests, Python compilation and demo one-shot passed; firmware source identical to 1.0.0. Windows runtime, scheduled task, USB hardware and actual firmware compilation remain untested in this Linux environment.

## 1.3.0
- Four GPU/CPU/BOARD RAM/HEALTH pages; PCM3, 44 fields, new GPU voltage and clocks, dual DIMMs, motherboard rails, 10 fan channels, 60-second load history, timestamp/age and offline status.
- Exact sensor IDs derived from the user's 363-row snapshot. Preserve zero RPM and effective clock; no nominal CPU frequency fallback. Separate v3 CSV filenames; new installation retention defaults to 0.
- --once waits up to 3 seconds for event counts. Flash script checks staged UI hash. Bridge and vendor sources unchanged. Actual firmware compilation/physical UI testing pending.

## 1.4.0
- Local prefix runtime, Install/Start/Stop/Uninstall and legacy uninstall entrypoints.
- Scoped uninstall with explicit confirmation; retains shared dependencies and user logs.
- Single foreground supervisor with elevated bridge only, parent lifecycle and stop markers.
- Keep PCM3 protocol; integrate latest CPU utilization and eight-fan UI.
- Stage USB CDC RX buffer 4096 bytes before Serial.begin; no automatic flashing.
- No default persistent autostart tasks.

## v1.5.0 — HWMonitor_ESP32
- Versioned directory, private Python bootstrap and local development tools.
- Full Install includes optional firmware flash and ACK test; PC-only install preserves existing firmware.
- Per-installation automatic logon task with enable/disable/status, unified stop and uninstall.
- USB serial identity / reconnect, transactional staging, firmware ACK, 19 Python tests and native parser test.
- Windows end-to-end acceptance remains pending; see AUDIT.md.
