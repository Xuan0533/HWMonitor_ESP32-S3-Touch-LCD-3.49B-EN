# v1.5.0 audit / release checklist

Scope: first-party integration files (PowerShell/CMD, Python collector/supervisor/stager, C# bridge and C++ UI/serial protocol), vendor byte integrity. No full third-party source audit. No Windows execution in this container.

| Finding in v1.4 | v1.5 action |
|---|---|
| Fresh install stopped without Python or Conda | Official NuGet x64 Python local bootstrap; explicit alternate Conda/venv modes |
| SDK and Arduino global installs/path dependencies | Local SDK fallback, local Arduino CLI/core/data/cache; process-only environment |
| Installer did not flash | Explicit V2 confirmation, validated VID/PID and COM, official driver staging, upload, PCM3 ACK probe |
| Existing firmware could be overwritten unexpectedly | Separate Install_PC_only.cmd, SKIP option |
| No unified automatic logon | Dedicated path-hashed task and separate enable/disable/status; no SYSTEM service |
| Port selection guessed wrong or reconnect used old COM | USB VID/PID validation and stored serial number for reconnect and noninteractive startup |
| Staging failure left a partially created build folder | Stage in sibling temporary dir and rename only after validation |
| Serial Connected did not prove valid packet parsed | New firmware responds to explicit PCM3? only after valid PCM3 frame; old firmware still receives normal data |
| Manually edited 4096 RX buffer could disappear | Stager patches it; flash checks it before compilation |
| NVML hard-coded 5090 | fallback for exactly one other NVIDIA GPU; no claim of broad support |
| Old cleanup missed new local tools/tasks | path-specific task removal, local generated directories, exact project process paths; preserve shared drivers/logs |
| Fresh startup could prompt with no screen | noninteractive startup waits for selected/unique device; no stdin prompt |

Executed checks: Python compileall and 19 unit tests; exact C++ parser extracted from shipped firmware compiled with host g++ and tested with a Python-generated PCM3 packet, null, invalid count, invalid prefix and NaN; 363-row actual sensor capture, all 29 configured IDs non-null; vendor original ZIP 484 files all byte-identical. ZIP integrity verified after packaging. These are not Windows/ESP32 integration tests.

Pending acceptance on fresh Windows 11 x64:
1. Run Install.cmd without Python/Conda/.NET/Arduino. Verify private CPython imports, .NET local publish, valid signed PawnIO installation; restart if requested.
2. Connect blank V2, confirm V2, verify tool downloads, actual ESP32 compilation, upload and ACK. Check all 4 pages/touch.
3. Start with real data, verify sample timestamp and health log; unplug/reconnect and change COM number. Stop and confirm processes gone.
4. Enable autostart, sign out/in and reboot, test without USB then attach; inspect task result. Disable and ensure task no longer runs at logon.
5. Uninstall, verify task and private runtime/tools gone, prior PATH and other runtimes unchanged, screen still bootable. Driver retained unless user separately removes it.

Residual risks: untested Windows-specific PowerShell, scheduled task permissions, UAC, native DLL imports and .NET dependencies; online downloads and upstream examples may change; actual USB/board revision cannot be determined by VID/PID alone; multiple installations can compete for the same serial port. Elevated logon mode runs both components with current admin user privileges, so keep project/runtime in a trusted directory. No guarantee of all-hardware compatibility. No Windows security controls are disabled.
