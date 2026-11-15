# B5 播放器视觉迁移独立验证（2026-11-13）

结论：本批定向验证通过。最终 17 项测试、格式、规则检查、Flutter analyze、debug Dart bundle、diff-check 通过；随后 9 个核心相关测试文件组合回归 92 项全部通过。包含真实 PlexVideoControls 宿主输入事件与 5 张生产组件截图；player、系统 channel、数据库和网络依赖使用测试替身，不是实际解码/设备播放验证。

## 执行证据

Flutter PATH 为 `<local-path>`；规则使用已有 Python 3.12。未安装工具或修改全局环境。

| 检查 | 结果 | 日志 |
| --- | --- | --- |
| `scripts/run_tests.sh test/widgets/player_migration_test.dart --dart-define=CAPTURE_TABLET=true --dart-define=CAPTURE_TV=true` | exit 0，17 项 | `<local-artifacts>/velo-b5-tests-final.log` |
| `dart format --output=none --set-exit-if-changed`，最终 15 个本批 Dart 文件 | exit 0，0 changed | `<local-artifacts>/velo-b5-format-final.log` |
| `bash scripts/ci_guard_checks.sh` | exit 0 | `<local-artifacts>/velo-b5-guard.log` |
| `python3 scripts/checks/check_hardcoded_strings.py` | exit 0 | `<local-artifacts>/velo-b5-hardcoded.log` |
| `python3 scripts/checks/check_user_facing_errors.py` | exit 0 | `<local-artifacts>/velo-b5-errors.log` |
| `dart run scripts/checks/check_icon_consistency.dart` | exit 0，1012 个非生成文件 | `<local-artifacts>/velo-b5-icons.log` |
| `flutter analyze --no-pub <local-artifacts>/velo-analysis-project` | exit 0，No issues found | `<local-artifacts>/velo-b5-analyze-final.log` |
| `flutter build bundle --debug` | exit 0；Dart bundle，不是 APK | `<local-artifacts>/velo-b5-build-bundle.log`（成功无输出） |
| `git diff --check` | exit 0 | 工具执行记录 |

ASCII 分析路径指向同一工作树，沿用既有 Unicode 工作目录 LSP 协议问题绕行；没有更改 Flutter SDK。无翻译或生成输入变化，未重复 codegen；未运行全仓测试。规则检查在首轮执行，最终生产/测试修复后重跑相关测试、格式、分析和编译。

主会话追加的小型跨批组合回归：

`scripts/run_tests.sh test/widgets/cinema_migration_test.dart test/widgets/catalog_migration_test.dart test/widgets/settings_migration_test.dart test/widgets/watch_together_migration_test.dart test/widgets/player_migration_test.dart test/screens/libraries/library_browse_tab_test.dart test/navigation/fusion_navigation_test.dart test/widgets/home_hero_info_only_test.dart test/screens/discover_screen_test.dart`

结果 exit 0，92 项全部通过，日志 `<local-artifacts>/velo-core-migration-combined.log`。未启用 capture 标志、不重复生成截图；保留库现有正常 golden 比较。此次覆盖 5 批新增迁移测试，以及真实库 fixture、共享导航、首页 hero 与 discover 页面集成，未发现跨批状态/样式回归。

## 任务逐项对应

- HUD：320×740、390×844、844×390、640×320，200% 字号下无布局异常；底部单行工具条可横向拖动、滚动到选集并点击，截图/PiP 回调各实际调用一次，播放入口位于下半部。
- 输入隔离：完整 PlexVideoControls，640×320、200% 字号，使用 tester pointer 的实际事件分发。拖动 HUD、按住 chip 650 ms、移动并 cancel 后，fake player 没有 seek/rate 命令，音量保持 100，mock channel 没有亮度/音量调用；chip 仍可点击打开真实抽屉并 Escape 关闭。
- 非 HUD 正向对照：同一宿主 HUD cancel 后，在画面区域横拖确有 seek 命令，证明排除 HUD 没有把后续画面手势锁死。这里是模拟触摸事件，不是物理触屏。
- 权限/系统能力：缺失截图/PiP 回调时入口隐藏；guest 的播放 callback 和倍速 onTapWithRect 为 null。该项是 UI 禁用状态验证，不等同真实网络权限攻防测试。
- 抽屉：真实四 tab 切换、selected 状态及空轨输入下无异常；主字幕选择 English 后，副字幕不能再选 English，改选 Japanese 更新实际 fake player track state。
- 倍速：实际 OverlaySheetController 弹层中选择 1.5 后 rate 更新、弹层关闭、触发 chip 仍可命中。完整宿主另从实际倍速 chip 打开弹层，断言弹层底边在真实时间轴顶边之上。
- DLNA：注入 empty discovery 显示无设备，点击 Refresh 后扫描次数从 1 到 2，注入失败显示发现失败。没有设备发送或真实交接。
- TV：Tab/Enter 可激活 PlayerDrawerChoice；选中状态保留。chrome hold/release 的现有控制器状态测试通过；没有将其称为完整自动隐藏计时测试。
- disabled：switch/checkbox 保持 checked=true，disabled 配色与 enabled 配色不同。

## 缺陷与修复轮次

初轮测试 6 过 / 9 失败，HUD fixture 缺 WatchTogetherProvider 和 intl 日期初始化，继发 ErrorWidget 导致巨量溢出。原作者补真实 provider/日期环境后恢复正常；原始日志 `<local-artifacts>/velo-b5-tests.log`。

独立审查提出新增 HUD 横滚可能被根 raw pointer 同时识别为 seek，以及 disabled 配色反馈不足。原作者按实际 header/toolbar/utility RenderBox 范围排除该 pointer，保持到 up/cancel，并对长按入口作同样排除。没有改 native backend 或 seek/edge 算法。

首轮合并复验 15 过 / 2 失败：320 宽 200% 的时间轴 Row 右溢 23 px；checkbox 的 disabled resolver 遗漏。最后修复保留全部时间信息与字号，将窄屏时间文本改 Wrap；补齐 checkbox disabled fill/check/border。checkbox 为第 2/最后修复轮，最终通过。日志 `<local-artifacts>/velo-b5-tests-round1.log` 与最终日志均保留。测试中 `_loadPlaybackExtras` 无 server/cache scope 警告来自无服务器 fixture，不是实际服务失败。

## 图像证据与边界

真实字体和 MaterialSymbols 由现有 helper 加载。黑背景表示没有解码测试视频，不是正在播放的影片；字幕/时长等取受控 fake playback 状态。

- `docs/fixtures/tablet/b5-player-landscape.png`：844×390，生产 MobileVideoControls 常态。
- `docs/fixtures/tablet/b5-player-drawer.png`：844×390，生产 HUD 叠真实四 tab Drawer。
- `docs/fixtures/tablet/b5-player-popover.png`：844×390，测试固定位置展示真实 SpeedPopover；此图本身不证明实际 chip 锚定。
- `docs/fixtures/tv/b5-player-tv.png`：1280×720，生产组件的 TV 分栏/抽屉呈现；不是完整 TV 应用设备截图。
- `docs/fixtures/tablet/b5-player-actual-popover.png`：640×320、200% 字号，完整 PlexVideoControls 中实际点倍速 chip 打开，弹层底边避开时间轴；受空间限制仅首两行在视口，其余为滚动内容。

前四张逐张审阅文字、选中、面板结构，无观察到的溢出；最终真实 popover 图确认空间受限时仍避开时间轴。没有覆盖完整锁屏、弹幕轨迹、系统旋转及全部 popover 状态。截图属于 `.gitignore` 的 `/docs/fixtures/` 可重生成本地产物，未 stage；没有盲更新旧金标，也不宣称 golden 比较通过。

## 精确本批可提交文件

生产 UI 及输入区域隔离（14）：

1. `lib/widgets/video_controls/player_presentation.dart`（新增）
2. `lib/widgets/video_controls/video_controls.dart`
3. `lib/widgets/video_controls/video_control_button.dart`
4. `lib/widgets/video_controls/mobile_video_controls.dart`
5. `lib/widgets/video_controls/parts/mobile_chips.dart`
6. `lib/widgets/video_controls/parts/playback_input.dart`
7. `lib/widgets/video_controls/widgets/player_hud_surface.dart`
8. `lib/widgets/video_controls/widgets/player_track_summary.dart`
9. `lib/widgets/video_controls/widgets/video_timeline_bar.dart`
10. `lib/widgets/video_controls/sheets/player_settings_controls.dart`
11. `lib/widgets/video_controls/sheets/base_video_control_sheet.dart`
12. `lib/widgets/video_controls/sheets/player_settings_drawer.dart`
13. `lib/widgets/video_controls/sheets/player_popovers.dart`
14. `lib/widgets/video_controls/sheets/dlna_cast_sheet.dart`

新增测试 `test/widgets/player_migration_test.dart`、本报告 `docs/flutter-migration-b5-validation-2026-11-13.md`；共 16 个可提交文件，另有上述 5 张忽略的截图。QA 未改实现/测试源码；修复全部由原作者完成。未改 native、会话协议、服务、数据模型、翻译或全局主题，未提交推送。

默认值集中于 PlayerPresentation：panelInset=12、panelBlur=12、drawerWidth=332/tablet=420、drawerHeight=560/tablet=680、radius=14、rowHeight=44、chipHeight=36、feedbackDuration=160 ms；保留 `TODO(VELO-UI-05)`。160 ms 是配置值，不是实测原生动效时长。新增的时间轴换行与实际工具区域排除，是修复本批布局/输入回归的必要局部共享修改。

既有未跟踪 `design/prototype-v2/`、`docs/player-native-observations-2026-11-13.md`、`docs/ui-refresh-validation-2026-11-10.md` 保留，不属于本批。

## 未测与遗留边界

没有实体手机/TV、真实 mpv/ExoPlayer 解码、真实音轨/字幕解码、DLNA 发包交接、截图/PiP/旋转系统调用、触屏亮度音量、真实服务器或多人同步联调。AppDatabase 使用内存，系统 channel 使用 mock，播放使用 FakeSyncPlayer/empty streams。未完整验证旧锁屏/所有手势/所有 subtitle/danmaku 偏好保存、不同平台系统等宽字体、全部字号语言/主题矩阵；四 tab 测试只验证选择与空轨兼容，不将其扩述成所有设置已保存。现无未修复的本批定向失败；上述核心组合回归已完成，APK 打包另行验证。
