# HWMonitor_ESP32 / v1.5.0

Windows 11 x64 + Waveshare ESP32-S3-Touch-LCD-3.49 **V2**. PCM3 (44 numeric fields), four pages, 4096-byte USB RX buffer. Existing working v1.3/v1.4 PCM3 firmware is compatible; new firmware adds optional diagnostic ACK. Not compatible with V1 hardware or PCM2 firmware.

## 1. 安装：第一次使用 / 空白屏幕

完整解压（不要在 ZIP 内直接运行），建议 `C:\HWMonitor_ESP32\v1.5.0`，固定在可信本地目录，不要放在多人可写的共享目录。不要让其他用户修改源码、配置或运行环境。需要 Windows 11 x64、支持管理员提权的当前用户、可联网访问 NuGet/PyPI/GitHub/微软/Arduino/Espressif、足够的磁盘空间（完整首次下载建议至少留 10 GB）、USB 数据线。显卡应已安装正常的厂商驱动；本项目不安装 GPU 驱动。

1. 连接唯一一块微雪 3.49 V2 屏幕。先停止旧版本监控程序和取消旧任务，防止串口/底层传感器冲突。
2. 双击 **Install.cmd**。默认下载项目私有 Python 3.13.17（NuGet python x64），无需预装 Python/Conda，不修改系统 PATH 或文件关联。复用已有 .NET SDK 11；没有时下载本地 11.0.100 SDK。编译随包提供的 LibreHardwareMonitorLib 和 C# bridge。
3. 如果需要 PawnIO，检查显示的数字签名和发布者后同意安装；UAC 是正常现象。如需重启，重启后再次双击 Install.cmd。不要关闭内存完整性、安全启动等系统安全功能来安装驱动。
4. 输入 `V2` 明确授权烧录（必须核对外壳/板子的 V2 标识，USB VID/PID 只能识别 Espressif 设备，不能识别 LCD 具体型号）。默认选唯一的 ESP32 USB Serial/JTAG，多个设备时手动选择。安装器下载官方 V2 示例、LVGL 9.3、Arduino CLI 1.6.0 与 ESP32 core 3.3.0，编译后烧录；不会使用 V1 驱动。烧录替换出厂应用，先保留官方出厂恢复固件备用。
5. 安装器发送 PCM3 DEMO 数据并查询 PCM3-ACK。只有收到 ACK 才报告新的固件通信验证成功。ACK 不证明 LCD/触摸正确，仍要肉眼检查四个页面。安装结束后选择立即运行；只需要一个前台窗口，C# bridge 隐藏运行。

若空白 ESP32 无法自动识别：使用数据线，按住 BOOT，短按 RESET（如外壳有可访问的按钮），松开 BOOT；重新连接后运行 Install.cmd 或 Flash.cmd。查看设备管理器及 `run.cmd --list-ports`。不要对不确定型号的设备烧录。若烧录后 COM 号变化，重新运行 TestScreen.cmd 或 Start.cmd。自动下载失败后检查网络再运行；若 `build` 已存在且损坏/旧版本，先重命名该目录再重试；不需删除 vendor。

## 2. 已经烧录并成功显示的屏幕（你的当前情况）

双击 **Install_PC_only.cmd**，或者 `Install.cmd` 并输入 `SKIP`，不写入 ESP32，不下载 Arduino 工具链。旧版固件仍可显示实时 PCM3，但不支持新加入的 ACK，因此旧版运行正常而 TestScreen.cmd 无 ACK 并不是故障。

如果你希望继续使用现有 Miniconda：在项目目录打开普通 PowerShell 或 CMD，运行 `./Install_PC_only.cmd -Mode Conda`（CMD 使用 `Install_PC_only.cmd -Mode Conda`），安装完整流程则运行 `Install.cmd -Mode Conda`。环境创建在该版本目录的 `.runtime`，不创建全局命名环境、不改 base。普通 Python 3.12 可选 `-Mode Venv`，或指定 `-PythonExe`；默认 Private 模式不需要这两项。不同模式切换前先卸载旧环境。

## 3. 日常使用

| 文件 | 功能 |
|---|---|
| Install.cmd | 全新安装，询问是否烧录、是否启动 |
| Install_PC_only.cmd | 安装电脑端，保留屏幕固件 |
| Start.cmd | 一键启动；手动模式只提升 C# bridge 权限 |
| Stop.cmd | 请求停止两个程序（不取消下次自启动） |
| Enable_autostart.cmd | 注册当前 Windows 用户登录后的自启动任务，并立即启动 |
| Disable_autostart.cmd | 停止并注销本版本的自启动任务 |
| Startup_status.cmd | 查询任务状态 |
| Flash.cmd | 单独下载/编译/烧录（需要先安装） |
| TestScreen.cmd | 停止监控后验证新版 PCM3 ACK |
| Doctor.cmd | 查询 Python 环境、驱动、串口、任务和采样日志 |
| SelfTest.cmd | 运行 Python 单元测试（不代替实机验证） |
| Uninstall.cmd | 卸载本版本，保留日志、源码、配置和屏幕固件 |
| Uninstall_old.cmd | 清理旧版，默认 C:\PCMonitor，可传入实际旧目录 |

开机自启动使用当前管理员用户的 Windows Task Scheduler 任务，登录后运行，不是在登录界面之前的 SYSTEM 服务。注册时需要管理员权限，自动运行时无需每次手动批准 UAC。**自启动模式的 bridge 和 Python supervisor/agent 均以当前用户的最高权限运行**，不要在共享可写目录注册；不建议无管理员权限的标准用户使用此模式。任务名包含目录哈希，每个版本独立。不要同时启用多个版本。未连接屏幕时后台等待；保存 USB 序列号后优先绑定原设备，串口号变化时自动重新查找。同一目录重复运行由锁防护。启用任务后不能直接移动项目目录，先取消自启再移动（Python/Conda 的绝对路径也可能需要重新安装）。停止后如需立即运行，双击 Start.cmd 或从任务计划程序启动已注册任务。

## 4. 卸载 / 旧版迁移

- 当前正在使用旧版时，先停止两个程序。可双击本包 `Uninstall_old.cmd`（默认 `C:\PCMonitor`）；如果旧目录不同，在 CMD 运行 `Uninstall_old.cmd "C:\PCMonitor_1.4"`。务必检查提示的真实目录与环境，确认后继续。保留旧版源码和 CSV，可归档旧目录。
- 新版双击 `Uninstall.cmd`，确认 UAC 及目标路径。注销属于该目录的任务，停止项目进程，移除项目私有 Python/Conda/venv、私有 Arduino/.NET 缓存、生成固件工程和 C# 构建产物、运行时配置。保留 logs/（删除临时快照）、源码及 config.json。之后可以自行删除整个版本目录。
- 安装时未修改 Windows 全局 PATH、Python 文件关联、应用执行别名、PowerShell Profile；卸载仅检测专用环境的残留 PATH/PYTHONPATH/PYTHONHOME 引用，询问是否清理。不要重置整个 PATH。已有的 Miniconda、系统 Python、SDK、Arduino CLI 保留；如果使用了 Conda 模式，Conda 自身共享包缓存保留。
- PawnIO 是系统共享内核驱动，**不会自动删除**。如果本程序安装了驱动，会记录 `pawnio-installed-by-project.txt`；确认没有其他工具需要它后，可在 Windows 设置 > 应用 > 已安装的应用卸载 PawnIO。不会卸载显卡驱动或修改安全配置。
- **任何卸载入口均不执行烧录或擦除 ESP32。** 屏幕会在无数据时显示 OFFLINE。

## 5. 传感器及界面

保持原四页：GPU（核心温度、显存温度、功耗、电压、核心/显存频率、显存占用、GPU load）；CPU（封装温度/功耗、Vcore、SoC、CCD1/CCD2、平均核心频率、总使用率）；主板（VRM/System/Chipset 温度、双 DIMM、CPU/Pump/SYS1–6 风扇转速、三组供电）；Health（WHEA、Kernel-Power 41、60 秒 CPU/GPU load、连接与采样时间）。保留 PCM3 44 字段，日志仍记录未显示的字段。

config.json 默认保留已经验证的 9950X + MSI X870E Tomahawk + RTX 5090 的 29 个精确映射。其他电脑可将 `sensor_ids` 设为空对象，再根据 `run.cmd --sensors` 返回的真实 ID 逐项配置。并非所有主板/CPU/GPU 都有相同的传感器；其他硬件可能显示 `--`，不可将缺失数据当作故障。NVML 支持单张其他 NVIDIA GPU 的回退，但没有承诺多 GPU、Intel CPU 或 AMD GPU 的完整映射。实时采样 1 Hz，日志默认不自动删除。

## 6. 验证边界与排错

本发行版是联网安装的源码包，不是离线 MSI。开发环境无 Windows PowerShell、Windows .NET SDK/Arduino CLI 及实体屏幕：不能保证新电脑一次安装必然成功。未在本次实际执行 PowerShell、驱动安装、计划任务、C# 发布、Arduino 完整编译、烧录或卸载。上游 Waveshare main 下载依赖官方目录布局（V2 GPIO42/旋转/LVGL 版本检查，不符合就停止），没有将其完整仓库离线打包。软件依赖下载仍受网络、上游变化、Windows 策略及硬件限制。

若 Windows 端无法运行：双击 Doctor.cmd，提供 logs/agent.log、logs/bridge.log、logs/startup.log（如存在）和安装终端的完整报错。若 PowerShell/计划任务失败，不能通过关闭安全设置规避。新固件 ACK 失败时先确认没有另一个程序占用 COM、重插屏幕，运行 TestScreen.cmd；旧固件无 ACK 不代表坏了。

详细开发审核与验证记录见 `AUDIT.md` 和 `TEST_RESULTS.txt`。第三方 LibreHardwareMonitor 源码原样保存，遵循其原许可证；仅审查本项目的集成与调用，不宣称第三方全部 484 个文件都无 bug。
