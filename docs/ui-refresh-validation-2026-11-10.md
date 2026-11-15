# Velo 界面与通知浮层改造验收（2026-11-10）

结论：本轮 UI 改造与已发现的显示回归已完成；64/64 个页面类都有组件执行证据。最终 Flutter 分析、共享组件回归、授权/TV 回归及新增页面渲染通过。整库验证并未全部通过：保留 7 项原始 HEAD 即存在的金标差异、并发 Android 更新任务的 3 项失败/4 个过期翻译生成文件；本机缺少 Xcode，macOS 原生构建未完成。

## 任务对应与交付

| 用户要求 | 交付与验证方法 |
| --- | --- |
| 检查所有通知弹窗 | 按最终渲染器去重覆盖通知、普通/根级对话框、菜单、锚定面板、OverlaySheet host/fallback；系统原生授权窗口由 OS 管理 |
| 高级感与磨砂玻璃 | 统一主题色磨砂、细边框、柔和阴影、状态图标、动作层级；高对比/减少动效/低性能回退实色 |
| 各页面显示 BUG 检查 | 以下 64 类页面逐项映射本轮执行的生产组件 fixture；不等于 64 页所有数据与状态组合或手机/TV 真机验收 |
| 界面样式优化 | 统一按钮触控尺寸、输入焦点、错误对比度、设置页宽度；保留现有焦点与业务行为 |
| 参考主流浏览器 | 官方资料核验 Safari/Apple、Edge/Microsoft、Chrome；只借鉴材质、层级和无障碍，不引入浏览器业务功能 |

## 页面覆盖矩阵

“fixture”表示生产 Widget 配合隔离数据/平台mock；“设置家族”复用实际 TV 分类循环。列表中的测试文件必须在本轮执行日志出现后才记为执行。

| 页面与位置 | 本轮实际测试入口 | 结果 | 范围与限制 |
| --- | --- | --- | --- |
| `SetupScreen` `lib/main.dart:2006` | `test/screens/setup_database_recovery_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `ProfileSessionScreen` `lib/navigation/profile_session_screen.dart:72` | `test/navigation/profile_session_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `ActorMediaScreen` `lib/screens/actor_media_screen.dart:25` | `test/screens/actor_media_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `AuthScreen` `lib/screens/auth_screen.dart:41` | `test/screens/auth_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `CatalogItemDetailScreen` `lib/screens/catalog_item_detail_screen.dart:64` | `test/screens/catalog_item_detail_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `CatalogSearchScreen` `lib/screens/catalog_search_screen.dart:22` | `test/screens/catalog_search_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `CollectionDetailScreen` `lib/screens/collection_detail_screen.dart:47` | `test/screens/collection_detail_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `MobileRemoteScreen` `lib/screens/companion_remote/mobile_remote_screen.dart:23` | `test/widgets/companion_remote_discovery_view_test.dart` | 通过（组件/fixture） | 整页发现/失败重试fixture；未操作真实远程设备 |
| `DiscoverScreen` `lib/screens/discover_screen.dart:80` | `test/screens/discover_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `DownloadsScreen` `lib/screens/downloads/downloads_screen.dart:41` | `test/screens/downloads/downloads_screen_focus_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `SyncRulesScreen` `lib/screens/downloads/sync_rules_screen.dart:21` | `test/screens/downloads/sync_rules_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `ExploreScreen` `lib/screens/explore_screen.dart:50` | `test/screens/explore_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `HubDetailScreen` `lib/screens/hub_detail_screen.dart:38` | `test/screens/hub_detail_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `FilterNumberPage` `lib/screens/libraries/filters/filter_range_page.dart:20` | `test/screens/libraries/filters_bottom_sheet_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `FilterDatePage` `lib/screens/libraries/filters/filter_range_page.dart:142` | `test/screens/libraries/filters_bottom_sheet_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `FilterTextPage` `lib/screens/libraries/filters/filter_text_page.dart:17` | `test/screens/libraries/filters_bottom_sheet_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `FilterValuePage` `lib/screens/libraries/filters/filter_value_page.dart:22` | `test/screens/libraries/filters_bottom_sheet_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `LibrariesScreen` `lib/screens/libraries/libraries_screen.dart:48` | `test/screens/libraries/libraries_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `LiveTvScreen` `lib/screens/livetv/live_tv_screen.dart:43` | `test/screens/livetv/live_tv_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `LiveTvShowScheduleScreen` `lib/screens/livetv/live_tv_show_schedule_screen.dart:26` | `test/screens/livetv/live_tv_show_schedule_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `MainScreen` `lib/screens/main_screen.dart:376` | `test/screens/main_screen_layout_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `MediaDetailScreen` `lib/screens/media_detail_screen.dart:290` | `test/screens/media_detail_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `MetadataEditScreen` `lib/screens/metadata_edit_screen.dart:32` | `test/screens/metadata_edit_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `AlbumDetailScreen` `lib/screens/music/album_detail_screen.dart:44` | `test/screens/music/album_detail_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `ArtistDetailScreen` `lib/screens/music/artist_detail_screen.dart:34` | `test/screens/music/artist_detail_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `NowPlayingScreen` `lib/screens/music/now_playing_screen.dart:59` | `test/screens/music/now_playing_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `PlaylistDetailScreen` `lib/screens/playlist/playlist_detail_screen.dart:39` | `test/screens/playlist_detail_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `PlexMatchScreen` `lib/screens/plex_match_screen.dart:29` | `test/screens/ui_secondary_screens_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `AddLocalProfileScreen` `lib/screens/profile/add_local_profile_screen.dart:25` | `test/screens/profile/add_local_profile_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `BorrowConnectionScreen` `lib/screens/profile/borrow_connection_screen.dart:43` | `test/screens/profile/borrow_connection_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `ProfileDetailScreen` `lib/screens/profile/profile_detail_screen.dart:43` | `test/screens/profile/profile_detail_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `ProfileSwitchScreen` `lib/screens/profile/profile_switch_screen.dart:38` | `test/screens/profile/profile_switch_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `SearchScreen` `lib/screens/search_screen.dart:40` | `test/screens/search_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `AboutScreen` `lib/screens/settings/about_screen.dart:11` | `test/screens/settings/settings_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `AccountPreferencesDetailScreen` `lib/screens/settings/account_preferences_detail_screen.dart:51` | `test/screens/settings/settings_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `AccountPreferencesScreen` `lib/screens/settings/account_preferences_screen.dart:21` | `test/screens/settings/account_preferences_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `AddConnectionScreen` `lib/screens/settings/add_connection_screen.dart:27` | `test/screens/settings/add_connection_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `AddJellyfinScreen` `lib/screens/settings/add_jellyfin_screen.dart:87` | `test/screens/settings/add_jellyfin_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `AddPlexAccountScreen` `lib/screens/settings/add_plex_account_screen.dart:37` | `test/screens/ui_secondary_screens_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `AppearanceSettingsScreen` `lib/screens/settings/appearance_settings_screen.dart:22` | `test/screens/settings/appearance_settings_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `EditJellyfinConnectionScreen` `lib/screens/settings/edit_jellyfin_connection_screen.dart:19` | `test/screens/ui_secondary_screens_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `ExternalPlayerScreen` `lib/screens/settings/external_player_screen.dart:22` | `test/screens/settings/external_player_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `GeneralSettingsScreen` `lib/screens/settings/general_settings_screen.dart:22` | `test/screens/settings/general_settings_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `KeyboardShortcutsScreen` `lib/screens/settings/keyboard_shortcuts_screen.dart:18` | `test/screens/settings/keyboard_shortcuts_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `LicensesScreen` `lib/screens/settings/licenses_screen.dart:17` | `test/screens/ui_secondary_screens_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `_LicenseDetailScreen` `lib/screens/settings/licenses_screen.dart:100` | `test/screens/ui_secondary_screens_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `LogsScreen` `lib/screens/settings/logs_screen.dart:99` | `test/screens/settings/logs_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `MpvConfigScreen` `lib/screens/settings/mpv_config_screen.dart:29` | `test/screens/settings/mpv_config_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `PlaybackSettingsScreen` `lib/screens/settings/playback_settings_screen.dart:28` | `test/screens/settings/playback_settings_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `SeerrConnectScreen` `lib/screens/settings/seerr_connect_screen.dart:36` | `test/screens/settings/seerr_connect_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `SeerrSettingsScreen` `lib/screens/settings/seerr_settings_screen.dart:18` | `test/screens/settings/settings_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `ServicesSettingsScreen` `lib/screens/settings/services_settings_screen.dart:25` | `test/screens/settings/settings_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `SettingsScreen` `lib/screens/settings/settings_screen.dart:82` | `test/screens/settings/settings_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `SubtitleStylingScreen` `lib/screens/settings/subtitle_styling_screen.dart:13` | `test/screens/settings/settings_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `TrackerLibraryFilterScreen` `lib/screens/settings/tracker_library_filter_screen.dart:20` | `test/screens/settings/settings_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `TrackerSettingsScreen` `lib/screens/settings/tracker_settings_screen.dart:162` | `test/screens/settings/settings_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `TraktSettingsScreen` `lib/screens/settings/trakt_settings_screen.dart:30` | `test/screens/settings/settings_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `SyncReceiveScreen` `lib/screens/sync/sync_receive_screen.dart:33` | `test/screens/sync_receive_screen_layout_test.dart` | 通过（组件/fixture） | TV启动错误态；IOOverrides阻止真实端口绑定，未验证配对成功/导入 |
| `SyncScanScreen` `lib/screens/sync/sync_scan_screen.dart:28` | `test/screens/ui_secondary_screens_test.dart` | 通过（组件/fixture） | TV无相机降级态；未验证手机摄像头/扫码 |
| `VideoPlayerScreen` `lib/screens/video_player_screen.dart:481` | `test/screens/video_player/player_startup_chrome_test.dart、test/screens/video_player/player_prompt_overlays_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `WatchTogetherScreen` `lib/watch_together/screens/watch_together_screen.dart:42` | `test/watch_together/watch_together_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `SettingsPage` `lib/widgets/settings_page.dart:21` | `test/screens/settings/settings_screen_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `DanmakuSettingsPage` `lib/widgets/video_controls/sheets/danmaku_settings_sheet.dart:39` | `test/widgets/danmaku_settings_sheet_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |
| `_FileInfoPage` `lib/widgets/video_controls/sheets/video_settings_sheet.dart:1706` | `test/widgets/video_settings_sheet_test.dart` | 通过（组件/fixture） | fixture；未连真实服务器/未跑手机或TV真机 |

额外子区：LiveTV WhatsOnTab/GuideTab/RecordingsTab 与 Libraries browse/collections/playlists/music/grouped/filters 随相应测试执行。播放器音轨、字幕、播放设置、弹幕、投屏等面板通过共享浮层和既有各自测试覆盖；真实播放/投屏/远程服务不在本机 fixture 的证明范围内。

## 回归与视觉审查

- 新增窄屏 320/360、横屏 844×390、桌面、Full HD TV，深浅色及 200% 字号；长通知、确认取消、菜单返回值、辅助页面滚动和原生焦点路径。
- 检查真实 BackdropFilter 且裁剪到面板；高对比、disableAnimations、低性能模式回退不透明。
- 审查发现首版 560 最大宽误限 TV 键盘/授权 QR、透明黑被改 alpha 后成为黑底；原作者第 1 轮修复，独立审查通过，授权激活码纵向溢出经第 2 轮修复；修复后授权/TV 定向 26 项全部通过，没有进行第 3 轮修复。
- 设置 5 张金标已逐张查看，主要为本轮预期的表面/控件变化。媒体库/继续观看旧金标的文字和图标边缘差异单独记录，不自动当作布局错误或盲目更新。

## 检查命令与证据

最终隔离快照：`/var/folders/h6/9snpwbc14ps1k18tpbvwkthh0000gn/T/velo-ui-validation-rsevwsvt/checkout`。基线 HEAD：`3f2697fc7aa7d7f949b88294f34801664f1b4266`。最终验证前逐项 SHA256 比较 37 个本轮生产文件，全部与主工作区一致；第 2 轮仅同步 `pending_auth_dialog.dart`。未覆盖并发源改动，未提交/推送。

| 检查 | 实际结果 | 日志 |
| --- | --- | --- |
| `scripts/run_tests.sh --no-pub --reporter expanded`（共享工作区首轮） | 8536 项通过、7 跳过、31 失败后，截图测试等待图片解码；仅余 1 个 tester 且日志停滞超过 90 秒，人工 SIGINT 终止。此运行 **未完成，不能视为全库通过** | `<local-artifacts>/velo-ui-full-tests.log` |
| 新增/授权/TV/远控/搜索等 11 个文件的隔离定向验证 | 首次 100 通过、2 个激活码纵向溢出失败；原作者第 2 轮修复后相关 4 个文件 26/26 通过，原有其余 98 项无需重复。包含此前未覆盖的配对错误态与匹配页 | `<local-artifacts>/velo-ui-focused-tests.log`、`<local-artifacts>/velo-ui-auth-final-tests.log` |
| 共享主题、dialogs、host/fallback sheet、menu、TV按钮 6 文件 | 修复后新 runner 60/60 通过 | `<local-artifacts>/velo-ui-core-final-tests.log` |
| 设置家族 2 文件 | 38/38 通过；使用 `--update-goldens` 更新人工确认的 5 张预期样式金标 | `<local-artifacts>/velo-ui-settings-final-tests.log` |
| 旧媒体库/继续观看 7 个金标 | 定向复跑 7 失败；原始 HEAD 隔离基线也 7 失败，**7 张 actual PNG 的 SHA256 与本轮逐张完全相同**；不是本轮改动，未更新这些金标 | `<local-artifacts>/velo-ui-existing-goldens-recheck.log`、`<local-artifacts>/velo-ui-original-goldens.log` |
| `flutter analyze --no-pub` | 最终隔离快照 exit 0，No issues found，46秒 | `<local-artifacts>/velo-ui-analyze-final.log` |
| `scripts/ci_checks.sh` | exit 1；1717 文件格式、翻译卫生、文案、错误文本、规则脚本、985 文件图标、analyzer、unused code/files 均通过；失败为 4 个并发翻译生成文件与原生格式初次 PATH 无 JDK | `<local-artifacts>/velo-ui-ci.log` |
| `scripts/format_native.sh --check` | 使用本机现有 `<local-path>` 补跑后 exit 0；未安装工具，未改原生代码 | `<local-artifacts>/velo-ui-native-format.log` |
| `scripts/codegen.sh --check` | 共享工作区独立检查失败；后续最终隔离 CI 再检查仍是同 4 个翻译生成文件过期，未由本任务覆盖生成 | `<local-artifacts>/velo-ui-codegen.log`、`<local-artifacts>/velo-ui-ci.log` |
| `flutter build macos --debug` | exit 1：依赖解析成功后明确提示 Xcode not installed；没有生成可验收 macOS 构建 | `<local-artifacts>/velo-ui-macos-build.log` |

首次共享 `.dart_tool/hooks_runner/objective_c` 曾出现 `Invalid SDK hash`。只清除精确失效 dill 后缓存元数据仍引用旧产物，因此停止触碰共享缓存，转到隔离工作副本验证。截图测试改为预解码本地资源且每步有 5 秒超时，1 轮修复后深浅两案例均通过；没有将卡住的旧 runner 计为通过。

### 首轮 31 个失败的归类与最终处置

| 类别 | 数量 | 处置 |
| --- | ---: | --- |
| 授权 QR/DeviceCode 与 Full HD TV 键盘布局：Tracker 4、OAuth 3、DeviceCode 2、新布局回归 4 | 13 | 原作者在 2 轮内修复；最终定向通过 |
| 本任务测试适配：PlexMatch 缺内存缓存初始化 2、搜索页面错误图标与通知图标重复匹配 1 | 3 | 仅修测试 setup 与 finder；定向通过，未放宽行为断言 |
| 设置/弹幕设置 5 张预期样式金标 | 5 | 逐张查看后更新；38 项设置测试通过 |
| 媒体库 3 + 继续观看 4 的旧金标 | 7 | 原始 HEAD 可同样复现且实际图逐张 SHA256 相同；保留金标，不归为本轮显示 BUG |
| 并发 Android 更新任务 | 3 | `android_app_update_service_test.dart` 的 disposed startup caller、losing foreground during native APK validation 两项，以及 `android_update_dialog_test.dart:211` 缺 `t.update.preparingInstall` 导致加载失败；未修改其代码，未把旧快照失败冒充该并发任务当前状态 |

未完成的首轮截图案例已在隔离新 runner 完成；64 页矩阵逐项核验全部有本轮日志入口，不以测试文件存在代替执行。真实配对成功、摄像头、远控、媒体服务以及手机/TV 真机仍未覆盖。


## 默认值与共享文件

视觉默认：blur sigma 22；普通弹窗/面板圆角 24、菜单/通知 18；深/浅表面 alpha 0.90/0.94、降级 1；普通弹窗 max560、宽授权窗 max720、通知 max520；外距16；过渡180ms/降级0ms；按钮最小48×48；桌面设置 max900。TV键盘使用自身已有尺寸，PIN max320。

| 文件 | 变化 |
| --- | --- |
| lib/theme/overlay_tokens.dart | 新增统一浮层视觉默认值 |
| lib/widgets/app_glass_surface.dart | 新增单层磨砂/边框/阴影与可读性回退 |
| lib/widgets/app_dialog.dart | 新增保留 Material alert 布局的玻璃 Dialog 容器 |
| lib/theme/mono_theme.dart | 全局主题、按钮、输入焦点、错误色和 tooltip 层次 |
| lib/utils/snackbar_helper.dart | 通知统一表面、状态图标、有界滚动文本，生命周期不变 |
| lib/utils/dialogs.dart | 通用弹窗构造迁移；确认弹窗标题和正文可滚动 |
| lib/widgets/overlay_sheet.dart | host/fallback 统一表面与可选 style/blurSigma 参数 |
| lib/widgets/app_menu.dart | 两类菜单表面与减少动效规则 |
| lib/widgets/dialog_action_button.dart | 多行操作文本居中，保留 FocusableButton |
| lib/widgets/settings_page.dart | 桌面设置内容限宽，TV 原布局保留 |
| lib/widgets/video_controls/sheets/danmaku_settings_sheet.dart | 唯一直接 SnackBar 迁移到统一 helper |

以下是初始构造迁移完整清单；除 utils/dialogs.dart、pending_auth_dialog.dart、tv_virtual_keyboard.dart、pin_entry_dialog.dart 外，仅新增 app_dialog import 并替换构造名：
- lib/main.dart
- lib/utils/dialogs.dart
- lib/utils/update_dialog.dart
- lib/utils/smart_deletion_handler.dart
- lib/screens/metadata_edit_screen.dart
- lib/screens/auth_screen.dart
- lib/screens/settings/settings_utils.dart
- lib/screens/settings/settings_screen.dart
- lib/screens/settings/external_player_screen.dart
- lib/screens/settings/hotkey_recorder_widget.dart
- lib/screens/settings/logs_screen.dart
- lib/screens/libraries/grouped_library_browse.dart
- lib/screens/profile/pin_entry_dialog.dart
- lib/watch_together/screens/watch_together_screen.dart
- lib/watch_together/widgets/local_media_match_dialog.dart
- lib/watch_together/widgets/join_session_dialog.dart
- lib/services/media_list_playback_launcher.dart
- lib/widgets/tag_edit_dialog.dart
- lib/widgets/deletion_progress_dialog.dart
- lib/widgets/startup_failure_view.dart
- lib/widgets/pending_auth_dialog.dart
- lib/widgets/collection_picker_dialog.dart
- lib/widgets/tv_virtual_keyboard.dart
- lib/widgets/library_management_sheet.dart
- lib/widgets/background_download_warning_banner.dart
- lib/widgets/companion_remote/remote_session_dialog.dart
- lib/widgets/video_controls/sheets/danmaku_sources_sheet.dart

测试共享文件：`test/test_helpers/tablet_screenshots.dart` 补对话框字体，使截图可读；18 个既有测试的 AlertDialog finder 从精确类型改为子类型识别，行为断言不变；远控测试改挂生产整页，搜索错误图标限定到页面状态区域。新增 4 个测试文件：`ui_surface_accessibility_test.dart`、`app_glass_surface_test.dart`、`ui_secondary_screens_test.dart`、`sync_receive_screen_layout_test.dart`。仅更新 5 个设置金标，不更新 7 个既有差异金标。


## 材料差异与遗留限制

- 调查最初约63页，最终枚举64个Screen/Page类（含通用/内部子页）；551为调用/定义字符串计数，不是551个独立弹窗。
- Flutter磨砂不是原生Liquid Glass；浏览器资料仅作为设计原则。没有将候选长文本风险冒充已复现BUG。
- 本机仅macOS运行设备；组件fixture不证明真实媒体服务器、OAuth完成、摄像头、TV硬件或投屏成功。系统原生授权弹窗不受Flutter主题控制。
- 并发Android应用更新任务的改动被保留。本次仅按构造迁移更新重叠UI文件，没有接管其服务/原生实现。
- 没有新增业务默认值或业务TODO；没有提交、推送或创建PR。

## 官方参考

- [Apple Materials](https://developer.apple.com/design/human-interface-guidelines/materials)、[Apple Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)、[Safari](https://www.apple.com/safari/)
- [Microsoft Acrylic](https://learn.microsoft.com/en-us/windows/apps/design/style/acrylic)、[Edge 功能](https://explore.microsoft.com/en-us/edge/features?form=MT0160)
- [Chrome 工具与无障碍](https://www.google.com/chrome/browser-tools/)、[Chrome 2023 Material You 改版背景](https://blog.google/products-and-platforms/products/chrome/google-chrome-new-features-redesign-2023/)（仅历史背景）


## 可查看的截图与证据

以下为真实生产弹窗/通知组件加本地测试卡片背景；不是带真实账号的端到端截图。深浅色、内容层次、边界和可读性均人工检查。

- 暗色弹窗（历史本地资料未公开：`<local-path>`）、浅色弹窗（历史本地资料未公开：`<local-path>`）
- 暗色通知（历史本地资料未公开：`<local-path>`）、浅色通知（历史本地资料未公开：`<local-path>`）
- 实际设置页深色 fixture（历史本地资料未公开：`<local-path>`）、浅色 fixture（历史本地资料未公开：`<local-path>`）
- 7 张金标原始 HEAD 对照 SHA256（历史本地资料未公开：`<local-path>`）、37 个生产文件主工作区/验证快照 SHA256（历史本地资料未公开：`<local-path>`）

## 既有测试/金标逐文件改动

以下18个文件仅作AlertDialog子类型finder兼容（个别行由dart format换行）：

- `test/utils/dialogs_test.dart`
- `test/utils/smart_deletion_handler_test.dart`
- `test/screens/playlist_detail_screen_test.dart`
- `test/screens/metadata_edit_screen_test.dart`
- `test/screens/settings/logs_screen_test.dart`
- `test/screens/settings/mpv_config_screen_test.dart`
- `test/screens/settings/keyboard_shortcuts_screen_test.dart`
- `test/screens/settings/settings_utils_test.dart`
- `test/screens/settings/settings_screen_test.dart`
- `test/screens/video_player/playback_reload_failure_test.dart`
- `test/watch_together/watch_together_overlay_test.dart`
- `test/services/play_queue_launcher_test.dart`
- `test/widgets/oauth_proxy_dialog_test.dart`
- `test/widgets/player_core_selection_test.dart`
- `test/widgets/library_management_sheet_test.dart`
- `test/widgets/video_settings_sheet_test.dart`
- `test/widgets/background_download_warning_banner_test.dart`
- `test/widgets/media_context_menu_test.dart`

其他既有测试共享改动：

- `test/test_helpers/tablet_screenshots.dart`：对话框截图字体。
- `test/widgets/companion_remote_discovery_view_test.dart`：窄屏实际远控页壳。
- `test/screens/search_screen_test.dart`：错误图标finder限定页面状态区域。

更新的5个预期样式金标：

- `test/screens/settings/goldens/settings_phone_dark.png`
- `test/screens/settings/goldens/settings_phone_light.png`
- `test/screens/settings/goldens/settings_phone_narrow_large.png`
- `test/screens/settings/goldens/fusion_settings_tv.png`
- `test/screens/settings/goldens/danmaku_settings_phone.png`
