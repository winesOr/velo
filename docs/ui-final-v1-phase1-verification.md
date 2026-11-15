# Velo 最终原型 V1：首批实际 UI 改造与验收

日期：2026-11-13（America/Los_Angeles）。实施基线：`c41732f5c8c9f3e7953516f01eae6d7b82e78239`。

本批仅覆盖详情页、音频／字幕选择和统一浮层／通知。未升级版本、未替换 mpv／ExoPlayer、未更改任何现有媒体服务器接入。最终原型的全部 22 项不是本批全部实现的声明。

## 逐项对照

| 原型条目 | 实际实现及验收 | 范围／差异 |
| --- | --- | --- |
| DETAIL-01／02：海报内评分 | 保留原有 hero 中的位置，主界面仅来源图标＋数值；来源与尺度留在无障碍语义、提示和可点击说明。无评分收起，不补零、不伪造平台。 | `MediaRatingsStrip` 使用真实模型／既有偏好；组件截图与评分既有回归测试验证。 |
| DETAIL-04：连续选集 | 手机／平板／普通桌面使用懒建连续轨道；分组定位不改播放集，滚动同步分组；11／21 集末组、390／844 宽度、27 集常规季、换季重置、尾部分页防重入已覆盖。 | 不为了连续滚动预取整季；显式“查看全部”与指定集定位保留原完整列表。 |
| DETAIL-04：输入方式 | 键盘方向键按焦点集同步；触摸、滚轮、macOS `PointerPanZoom` 接管后按可见内容同步。 | 生产 widget 行为测试；未进行实体遥控器测试。 |
| DETAIL-04：TV 详情 | 保留现有专用 `TvBrowseRail` 连续懒建、季轨道与相关推荐，在前景信息加入焦点集对应的组范围。 | TV 没有引入手机式可点击分组跳转；这是本批明确保留的布局差异。 |
| PLAYER-01：设置面板 | 独立播放器设置／轨道入口居中；宽度上限 420，视口两侧各 16；可用高度扣安全区、键盘与上下各 12，普通上限 560／窄屏 680。 | HUD 白色样式保留；紧凑选择菜单仍锚定，空间不足或旧锚点被键盘遮挡时居中。 |
| PLAYER-02／03：音轨字幕 | 独立与嵌入入口统一双行 `AppSelectField`；busy 防重入、异步错误保留面板和原选择。音轨重复选择去重；主字幕已经关闭而次字幕活跃时，再选关闭仍清理次字幕。 | 保留真实播放器状态和 source/native ID；不引入原型的模拟时序。主次互斥／能力判断沿用真实实现。 |
| SHARED：现代弹窗 | 复用已有半径 24 的居中玻璃弹窗；紧凑菜单半径 18，选中态深浅 Velo 紫色；完整菜单矩形必须处于安全视口内。 | 自带懒列表的弹窗保持有界滚动；纯长文本明确使用 `scrollable: true`，避免统一包裹外层滚动后意外拉尽分页。 |
| SHARED：顶部通知 | root 和 profile 两级 `AppNotificationHost`；顶部 SafeArea、最大宽 520、淡入、队列／替换／关闭／计时销毁，保持旧 helper 函数签名。 | 不抢焦点；root 错误跨导航保留，profile 注销销毁其通知。系统原生权限弹窗不属于 Flutter 样式控制范围。 |

## 与性能方案的对应

- 评分仍走既有主响应和后补探测链，没有为图标增加第三方请求，也没有新增“等评分到齐才可操作”的门槛。此次主要是保留和验证现有非阻塞边界。
- 连续剧集使用固定尺寸的 `ListView.builder`、既有图片尺寸与按需分页；测试验证初始未创建末集、临近尾部请求不重入、错误后显式重试。
- 音轨选择使用真实异步 guard，busy 期间不重复发送请求，音轨同值不切换。字幕“关闭”保留清次字幕的必要副作用。
- 首页逐库发布、缓存快照、NextUp 后置、图片请求合并和线路算法不属于本批；未宣称启动或播放性能已经实测提速。

## 视觉证据

以下六张是**实际 Flutter 生产组件＋受控 fixture 数据**的截图，均已目视，不是 HTML 原型截图、真机照片或用户媒体账号画面。组件布局、图标与文字、选中配色、顶部通知及大字键盘避让按本批目标逐项检查；没有声称整页像素级等同。

| 截图 | 证据 |
| --- | --- |
| [详情评分](ui-final-v1-phase1/phase1-detail-ratings.png) | 图标＋数值，没有平台副标签 |
| [评分说明弹窗](ui-final-v1-phase1/phase1-rating-dialog.png) | 来源／尺度在居中说明中 |
| [11–20 连续剧集](ui-final-v1-phase1/phase1-episodes-11-20.png) | 连续真实组件、紫色活动分组 |
| [音轨选择菜单](ui-final-v1-phase1/phase1-audio-selector.png) | 双行字段、锚定菜单、紫色选中 |
| [顶部通知](ui-final-v1-phase1/phase1-top-notification.png) | 顶部安全区、不替换底部 SnackBar |
| [大字／键盘下的居中弹窗](ui-final-v1-phase1/phase1-centered-dialog-large-text.png) | 可滚内容与可达关闭按钮 |

截图可以通过 `flutter test test/widgets/final_ui_phase1_test.dart --dart-define=CAPTURE_TABLET=true` 重现；输出默认在被忽略的 `docs/fixtures/tablet/`。本报告只保存本批六张验证截图（合计约 104 KiB）。

## 检查记录

| 检查 | 最终结果 | 证据 |
| --- | --- | --- |
| `scripts/run_tests.sh --reporter expanded` | 160 通过、7 跳过、4 个已确认历史 golden 失败；本批新增／相关回归没有失败 | `<local-artifacts>/velo-phase1-all-tests-final.log`；新测试文件 21 项行为测试及播放器新增“主 off 清次”测试通过 |
| `scripts/ci_checks.sh` | 全部通过 | `<local-artifacts>/velo-phase1-ci-final.log`；含 1064 个 Dart 文件格式、codegen freshness、翻译、UI／错误文案、脚本 guard、图标、原生格式、analyzer、unused code/files |
| `scripts/codegen.sh --check` | 由最终 CI 执行，通过 | 本项目检查将未暂存生成文件视为 stale；由主会话先暂存本轮 26 个翻译源／生成文件再执行，无跳过或脚本修改 |
| `flutter analyze --no-pub <repo>/lib <repo>/test` | 通过，最终源码状态无 issues，8.6 秒 | `<local-artifacts>/velo-phase1-analyze-final.log` |
| `flutter build macos --debug --no-pub` | 环境阻断：没有 Xcode.app，仅有 CommandLineTools | `<local-artifacts>/velo-phase1-macos-build.log`；未安装工具或改变全局选择 |
| Android debug 原生编译 | 通过；`assembleDebug`，显式指定 ARM64 Flutter 目标；41 秒，639 个任务（54 执行、585 使用缓存） | `<local-artifacts>/velo-phase1-android-gradle.log`；使用现有 JDK 17、SDK 36、NDK 29 与依赖缓存，无版本增量 |

环境处理：Flutter 默认使用物理中文路径时，首次 analyzer 的 LSP 初始化出现截断 JSON；显式传入 ASCII 工作区路径后成功。首次 Android Flutter 构建也因 Java Properties 把中文 SDK 路径按不同编码读取而失败；验证时只将被忽略的 `android/local.properties` 的 `flutter.sdk` 临时指向已有 ASCII 别名，沿用 Flutter 生成的相同构建配置直接执行 Gradle，结束后恢复原文件并核对字节一致。没有修改已跟踪的 Android／macOS 配置、依赖锁或 `pubspec.yaml`。构建产物不属于本批提交或交付安装包。

### 已确认的历史 golden 差异

`continue_watching_progress_test.dart` 的 phone／phone_light／phone_large／tv 四个 golden 在本机失败。另建干净 HEAD `c41732f5` 临时工作树，使用同一 Flutter SDK、依赖解析、字体和测试命令，四项同样失败；当前与 HEAD 输出图**字节完全相同**，不属于本批引入的差异。没有更新无关 golden。临时工作树已删除，比较记录保留于 `<local-artifacts>/velo-phase1-golden-baseline-comparison.txt`。

| 当前与 HEAD 一致的输出图 | SHA-256 |
| --- | --- |
| phone | `c42e9cf1b6144c1b3f864dd216ab6ec393cbe9b557131196a64d09e5f15bfdd1` |
| phone_light | `adfce51e194a4aa0206570a305f5ff8eae882932ee77a131a837eeec21716d9e` |
| phone_large | `49d8b242b08aa8c507864cf95cc7751a9c9018ad6f2abd94b0162479ec048dba` |
| tv | `11cf0e77a520cdcd5def822609453a8dbbf25301656646131d009f06f552c3e2` |

## 文件归属与共享修改

### C：统一浮层、通知和翻译

- 新增 `lib/widgets/app_notification_host.dart`；修改 `lib/utils/snackbar_helper.dart`，保留公开函数签名与 root messenger 兼容键。
- 共享接入：`lib/main.dart`、`lib/navigation/profile_session_screen.dart`，仅增加通知 host 及必要 import／生命周期包装。
- 修改 `lib/widgets/app_menu.dart`、`lib/widgets/overlay_sheet.dart`、`lib/screens/video_player/parts/casting.dart`。
- `lib/widgets/app_dialog.dart` 最终没有净修改：保留既有 Material 滚动合同，避免额外滚动容器破坏分页。
- 新 key `videoControls.noAudioTracksAvailable`：英文、简体、繁体有文本；其他 19 个 locale 按项目清理规范补空串，由现有 base-locale fallback 回退英文。共 22 个 `.i18n.json` 源文件及 `strings.g.dart`、`strings_en.g.dart`、`strings_zh.g.dart`、`strings_zh_Hant.g.dart`，生成文件仅由脚本生成。

### B：音轨／字幕

- `lib/widgets/app_select_field.dart`
- `lib/widgets/video_controls/player_presentation.dart`
- `lib/widgets/video_controls/parts/mobile_chips.dart`
- `lib/widgets/video_controls/widgets/track_chapter_controls.dart`
- `lib/widgets/video_controls/sheets/player_settings_drawer.dart`
- `lib/widgets/video_controls/sheets/sheet_selection_column.dart`
- `lib/widgets/video_controls/sheets/track_sheet.dart`
- `lib/widgets/video_controls/sheets/video_settings_sheet.dart`
- 删除本轮旧路径移除后无调用的 `lib/widgets/video_controls/helpers/track_selection_helper.dart`，没有 lint 忽略。

### A：详情

- 新增 `lib/widgets/detail_episode_rail.dart`。
- 修改 `lib/widgets/media_ratings_strip.dart`、`lib/screens/media_detail_screen.dart`、`lib/screens/media_detail/presentation.dart`、`lib/screens/media_detail/responsive_layout.dart`。

### QA

- 新增 `test/widgets/final_ui_phase1_test.dart`，覆盖本批实际组件与交互边界。
- `test/widgets/player_migration_test.dart`：新增主字幕关闭清次字幕回归，更新窄屏大字 popover 居中回退合同。
- `test/widgets/settings_migration_test.dart`、`test/widgets/watch_together_migration_test.dart`：fixture 挂载与生产一致的通知 host，继续验证失败提示。
- 本报告与 `docs/ui-final-v1-phase1/` 六张截图。

## 默认值、限制与后续

- 布局尺寸是本轮视觉 token；组大小沿用既有十集分组，不修改服务器分页大小或播放器性能参数。
- 未连接 Android／实体 TV；没有真实服务器音轨解码、远程控制器、网络首屏或播放性能实测。测试中的 fake player／媒体 item 只用于隔离生产组件，不进入应用。
- TV 可点击分组跳转、首页网络性能后续批次、四项已有 golden 基准差异仍是后续事项。
- 不触碰、不提交原有四项 untracked：`design/prototype-v2/`、`design/vidhub-study/`、`docs/player-native-observations-2026-11-13.md`、`docs/ui-refresh-validation-2026-11-10.md`。
