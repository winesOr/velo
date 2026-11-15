> 历史研究摘要，来自本地资料快照 `c350c4a`（2026-11-14 整理）。原始证据未公开；文内观察、推断和未验证边界按原文保留，不能当作本次复测结果。公开副本仅脱敏路径并处理未公开证据链接。

# Emulator window recovery

- User reported not seeing emulator; inspected previous PID91455 and fixture PID92292: both absent, adb devices empty, TCP5554 refused. Previous process was no longer running; do not describe this as user overlooking a hidden window.
- Prior emulator log ended with `ERROR | bad color buffer handle 90`, without an explicit shutdown reason. This is insufficient to attribute cause to GPU crash or session cleanup.
- Restarted only `vidhub_research_20261113` from its preserved AVD data; original plezy_api36 untouched, no wipe/delete/root/security change.
- Used Python subprocess.Popen start_new_session=True with stdin DEVNULL and file log. New emulator PID97449 was independently observed alive with PPID1; no `-no-window` or `-qt-hide-window` launch flag.
- `adb devices -l`: emulator-5554 device; Android property sys.boot_completed=1. Log says Created extended window in107.493ms and Boot completed in19547ms. These are emulator launch facts, not VidHub playback measurements.
- CUA inventory still does not enumerate qemu as an application; no CUA app binding is available. Thus graphical visibility/foreground position is not independently confirmed. Do not tell the user the window has been visually verified.
- The prior fixture server PID92292 is stopped; no media request was made or fresh server started during window recovery. A subsequent playback session must restart the local fixture and restore adb reverse mapping.
- Kept the recovered emulator running for user handoff; log at window-recovery-emulator.log and machine-readable state window-recovery-state.json.
- If the user still cannot see it, next route is launching this same AVD from a user-visible Terminal/Android Studio UI, not deleting original AVD data or pretending the existing GUI can be controlled.

## 可见窗口核查（2026-11-14T04:03:25.209839+00:00）
- 恢复进程 PID 97449 / PPID 1 存活，ADB emulator-5554 online；启动参数没有 -no-window 或 -qt-hide-window。
- 仅再次启动样本包 MainActivity：Status ok，前台 GrantPermissionsActivity，TotalTime 1129 ms / WaitTime 1140 ms；不是首帧或播放性能。
- CUA listApps 仍无 qemu/emulator；Finder 截图只返回访达下载窗口，不能据此断言整个桌面无窗口。真实 Dock bundle com.apple.dock 的 getApp 返回 timeoutReached (-10005)。此前实际 qemu 路径 getApp 返回 Invalid app。
- SDK 未找到可供选择的 .app/Info.plist；Created extended window 日志不证明主窗口可见。
- 只读配置显示主显示 320×640 / 160 dpi；没有 window.x/y，隔离 AVD 的 emulator-user.ini 不存在，未发现可证实的离屏坐标。未改窗口/系统配置。
- 新增可双击启动器：启动隔离VidHub模拟器.command。它检查本次 AVD 实例，已运行时提示；用户明确输入 y 才正常关闭该研究实例并从终端重启，无 wipe，无操作 plezy_api36；日志 manual-window-launch.log。仅语法检查，尚未实际执行。
- 测试 HTTP 服务此前已停止，本轮未重启，也未发起媒体请求；selftest 不计入 VidHub 动态证据。
- 当前结果：后端启动已恢复，桌面可见性仍未验证；缓存值、硬解属性、最快线路实际运行参数仍未知。
