# Velo 界面改进分批验收报告（代码与本地验收完成）

日期：2026-11-11。初始代码基线：`main@f955f2a`。对应计划：`docs/ui-ratings-selectors-development-plan-2026-11-11.md`。

**P1–P8代码与对应本地验收、C137/137及24图审查、最终规则/格式/machine分析、83产物隔离一致性、当前Android APK核验及约定隔离烟测均完成；专用模拟器已关闭。flutter analyze LSP exit255及machine零诊断替代实证保留；codegen --check历史未暂存exit1仍记录，提交前标准检查已实测exit0。未登录后的真实业务、真机TV/手机与远程服务未验；未提交推送。历史批次不重复累加。**

## P1–P8 当前状态（唯一状态表）

| 任务 | 代码与对应本地验收（已完成） | 最终集成或外部验证范围 |
|---|---|---|
| P1 常亮 | activity保留旧语义，统一意图/phase/visibility/fatal与唯一插件owner、Activity重挂；Dart186/native51通过 | 约定隔离smoke通过；真实手机30分钟/TV长播、缓冲/音频焦点/PiP/息屏未验 |
| P2 选轨 | 播放器稳定ID与详情预选/source-part scope已完成；C137/137含容量、初始focus、rail200完整路径及rail移除通过 | 约定隔离smoke通过；真实切轨媒体及硬件遥控体验未验 |
| P3 评分 | 首批排序/偏好/四外部+个人/角标通过，C完整137/137含评分布局与个人入口；新实图审查通过 | 约定隔离smoke通过；19语言英语fallback未本地化，真实远程评分保存未验 |
| P4 冷启动 | 授权gate/共享2s/渐进内容/24h快照完成；原15文件、delta83/83及定向静态0诊断，授权/scope审查关闭 | 约定隔离smoke通过；真机5次冷启动与实际耗时收益未测 |
| P5 性能 | 下载快照/300ms合并/行重建144通过；Plex附加请求、blur降级、侧栏select及C相关完整回归通过 | 约定隔离smoke通过；无真实设备FPS、内存或时延百分比证据 |
| P6 错误/空态 | Plex96通过；UI35独立用例分批通过，WhatsOn/Guide重跑27/27，定向静态及Guide焦点审查通过 | 约定隔离smoke通过；真实远程媒体服务联机/权限变化未验 |
| P7 视觉 | B实图/滚动review关闭；C10配置20图+4初始focus图共24张真实Flutter图全部查看、独立review通过，与冻结生产源码关联 | 约定隔离smoke通过；截图是本地Flutter fixture，不等同真实手机/TV设备验收 |
| P8 交互 | 按压/减弱动画/选择延迟/pending防重入完成；B导航32/32、滚动1/1与零误触，C完整137/137及实图审查通过 | 约定隔离smoke通过；真实TV遥控/手机触感未验 |

## 本次续作最终通过与冻结证据

`/tmp/velo-validation-20261111/resume-c-final-results.md`记录：square-art单例1/1后，最新C完整4文件 **137/137、exit0、15.575秒、无超时**。完整批137是当前计数，不能再加单例或早前定向项。日志与状态为`resume-c-final-tests.log`、`resume-c-final-tests-status.json`。容量、TV初始自动focus、有rail200严格全路径与rail移除均已通过；没有仍待修复的C源码/本地验收项。

容量根因与契约保持：fixture `fileSize=238_000_000`，source-1080/path S01E01-1080p.mkv；既有`MediaFilePart.fileSizeFormatted`→`ByteFormatter.formatBytes(decimals:2)`用1024²与两位小数得到226.97 MB。生产技术卡为单Text“本地化label: value”；仅修测试匹配真实文件卡的完整行，未改变产品单位、精度或locale行为。TV修正以实际rail遮挡后的可见区域作为guard与揭示目标，初始已可见不额外居中，保留真实严格几何/焦点路径。square-art旧fixture意外采用宽桌面条件；仅明确390×844 Android phone条件，原选择/旋转/宽图fallback断言完整保留，生产与共享图像helper未改。

24张新图见`resume-c-current-images.json`，来自紧邻的上一完整测试进程；最后只改独立square fixture，生产、10配置矩阵和图像helper未变。validation逐张实看，独立review逐张查看，疑点以单张original复核闭环通过；批量显示导致的TV200列疑点经原图核对撤回，无代码/断言修改。`/tmp/velo-review-final-ui-20261111.md`保留过程并追加最终结论。

测试/实图冻结摘要`resume-final-freeze.json`保存2026-11-12 00:47:32 UTC的sourcehash；纯规范化修正后的`resume-build-freeze.json`记录2026-11-12 00:56:50 UTC、freeze ID `1cd00228646a7b35bcd10327a145e3dfe105689fa8462bfb60d34f5b19cb1ea0`。21JSON仅detailPlayback缩进6→4（非排序，added/removed/type_fixed=0），main补if花括号，137测试/24图结论保留；构建source_drift[]。未提交、推送或改用户旧报告。

## 上一轮停止记录（历史，被续作授权与新定位更新）

上一轮最后两例为1过/1败、exit1：TV有rail200路径过，phone-show-cast选中描边、Episode2/12/1、分页及文件路径过，仅裸容量finder未过。当时按两轮上限停止，当前APK未构建；这段记录不删除，也不再当作本次不能继续的指令。容量原因现在已定位为finder/合并标签不符，旧“原因未判断”仅适用于停止时点。

历史证据：`/tmp/velo-validation-20261111/final-blocked-validation-report.md`、`phase3-detail-last-two-tests.log`/status；64文件账本与current-validation-state.json里的blocked_stopped/next_action也是上一轮快照。用户明确续作后的进度以本文件当前状态表和之后validator结果为准。独立review旧关闭项继续保留，新增TV guard须以新图/运行复核。

## 分批验证证据（重叠不累加）

日志均位于 `/tmp/velo-validation-20261111/`，另有明确绝对路径的除外。

| 批次 | 真实结果与范围 | 证据 |
|---|---|---|
| 首批 | 21文件293/293，首批APK及83产物一致性；已被后续文件改动部分覆盖 | `final-validation.md`；本报告后段保留完整历史信息 |
| P1补强 | 11个Dart文件186/186，另4个native类51/51 | `phase2-p1-results.md`、`phase2-p1-dart-tests.log`、`phase2-p1-native-tests.log` |
| P5下载 | 6文件144/144；fixture事件/重建计数，非真机性能 | `phase2-p5-results.md` |
| P4 | 原15文件有通过证据；delta最后83/83覆盖原7失败及新10安全项；最后静态0诊断 | `phase2-p4-delta-r2-results.md`、`phase2-p4-lint-final-results.md` |
| P6 | Plex96/96；UI35个独立用例在保留/最终批次通过，其中WhatsOn/Guide修复后27/27为重跑 | `phase3-p6-plex-results.md`、`phase3-p6-ui-results.md`、`phase3-p6-ui-r1-results.md` |
| B功能/实图 | 容器分流2/2；最后导航/fixture32/32；六张真实字体/图像fixture已查看 | `phase3-f4-functional-r1-results.md`、`phase3-f4-nav-final-results.md` |
| B生产窄屏滚动 | 最后1/1、format/static0；532px生产高度、两轮双向滚动、完整语义/按钮与点击、零误触，三张新图审查关闭 | `phase3-f4-line-metrics-r1-results.md`、`phase3-f4-title-diagnostic-results.md`、`/tmp/velo-review-final-ui-20261111.md` |
| C恢复与较早运行 | 恢复后定向静态0；旧完整批次126/131，后续局部修正不构成完整批次重验；曾取消的矩阵外层exit0不算通过 | `phase3-resume-results.md`、`phase3-detail-final-full-results.md`、`phase3-detail-functional-r2-results.md` |
| C较早实图/矩阵 | 深浅真实图片2/2及4图；后续定向7/9，桌面/narrow200/无rail TV200共6张新图中的旧问题审查关闭 | `phase3-detail-artwork-final-results.md`、`phase3-detail-matrix-r1-results.md`、`phase3-detail-matrix-r1-images.json` |
| C续作前最后两例 | 1/2通过、exit1且未超时中断；TV有rail200路径过，phone仅最后精确容量断言失败 | `phase3-detail-last-two-tests.log`、`phase3-detail-last-two-status.json`；不与旧批次数相加 |
| C本次最终完整回归 | 4文件137/137、exit0；square独立1/1仅作前置，不另累计；24图与冻结生产源码关联且审查通过 | `resume-c-final-results.md`、`resume-c-final-tests-status.json`、`resume-c-current-images.json`、`resume-final-freeze.json` |

## 最终集成检查与原命令例外

| 项目 | 本轮最终状态与限制 |
|---|---|
| 当前全量规则/静态/格式 | ci_guard/hardcoded strings/user-facing errors/icon规则通过；strict translations0，104手写Dart format0，full machine analyzer0且零诊断，diff-check0。两项整理已关闭；见resume-final-checks-status.json与resume-final-recheck-status.json |
| 当前codegen/生成一致性 | 提交前原始bash scripts/codegen.sh --check已exit0/62.78秒，83个生成文件未变化，157项暂存及index SHA前后完全相同；见commit-staged-validation-report.md、commit-codegen-standard-status.json。未暂存阶段exit1与先前隔离83/83字节一致证据仍保留为历史，不混作同一批 |
| 当前Android APK | 当前源码构建exit0/33.96秒，无超时，source_drift[]，local.properties原/后hash相同；当前稳定APK的ZIP CRC与v2签名通过，详细产物见下一节 |
| 隔离模拟器烟测 | 最新APK安装exit0、启动exit0，未登录入口/Jellyfin与Emby添加页/空地址校验/返回，以及真实相机权限拒绝→可恢复Retry→返回均通过；app存活，crash buffer无fatal。专用AVD新PID77431已实际退出，详见下一节 |
| 原命令与环境 | flutter analyze --no-pub仍为LSP JSON/channel解析截断exit255，full machine替代exit0/零诊断；提交前原始codegen --check已实测exit0，不再属于当前失败项。两者各按真实命令/阶段报告，不将替代分析说成flutter analyze通过 |
| 平台与设备 | 未验证登录后的Home/Library/Watch Together/Settings实机导航、真实服务器认证/播放/PiP/TV遥控/房间/投屏、相机授权成功扫码、5次冷启动/帧时/内存profile、Apple工具链；隔离fixture/smoke不能替代这些场景 |

详情源码恢复证明 `/tmp/velo-detail-recovery/recovery-proof.json`：从首批APK debug source精确恢复5300行/218497字节主文件，再重放新改动。旧GlobalKey等后续已修；恢复本身不是业务交付，也不证明当前APK。共享字体helper `test/test_helpers/preview_fonts.dart` 由C所有、B消费，仅读已有字体资源；未提交、推送或改用户旧报告。

## 当前构建产物与可复核证据

当前APK：[velo-resume-debug-arm64.apk](/Volumes/外置SSD/dev/velo/build/validation/velo-resume-debug-arm64.apk)，**338,009,263 bytes**。SHA256：`a2022a998684e1b7fb84e588b3923efcc886cd4e889e3e19e55717b18215f0c9`。ZIP CRC通过、签名工具exit0/v2通过；package `com.wines.velo`，version 2.23.23/code4204。Gradle目标为android-arm64，但依赖另带其他ABI，不称arm64-only。当前构建属于上方build freeze，旧首批APK仅保留作历史与恢复来源。

证据目录 `/tmp/velo-validation-20261111/`：`resume-android-build-status.json`（exit0、33.96秒、source_drift[]、local.properties恢复）、`resume-apk-verification.json`（路径/bytes/hash/ZIP/签名）、`resume-build-freeze.json`。原命令日志：`resume-final-flutter-analyze.log`（exit255）、`resume-final-codegen-standard.log`（历史未暂存exit1）、`commit-codegen-standard.log`/`commit-codegen-standard-status.json`（提交前标准检查exit0、62.78秒）；提交前摘要`commit-staged-validation-report.md`证明83生成物、157项暂存与index SHA均未变化。替代/复验日志：`resume-final-machine-analyzer-r1.log`、`resume-final-codegen-bytecheck.log`，状态见`resume-final-recheck-status.json`；先前隔离阶段真实index未动/暂存0见`resume-codegen-index-proof.json`。当前APK已用于下述隔离smoke，旧首批APK未充当当前交付。

## 隔离烟测与环境关闭

`resume-smoke-result.json`将安装APK SHA256绑定为上方当前产物，记录安装/启动均exit0、应用存活且前台为Velo、crash buffer无fatal。实际检查：未登录入口；Jellyfin添加服务地址页、空地址本地反馈及返回；Emby添加页及返回；真实Android相机权限弹窗选择拒绝后出现可读、可恢复Retry提示，再返回入口。未用真实账户或媒体服务器；这些结果不包含登录后的Home/Library/Watch Together/Settings导航、成功扫码或实际播放。单次debug启动am记录2676ms，仅作烟测事件，不作五次冷启动或性能改善证据。

9张烟测截图与hash列于`resume-smoke-result.json`，从`resume-smoke-02-login.png`到`resume-smoke-10-permission-return.png`。`resume-emulator-stop-proof.json`最终时间为**2026-11-12 01:06:38 UTC**：专用`resume-stop.py` exit0，PID77431不存在、emulator-5586 adb not found/不在列表、其他设备0；临时AVD保留、用户AVD未触碰。01:06:09的退出中观察另存`resume-emulator-stop-first-observation.json`，不作为成功关闭依据。所有当前源码/构建/烟测检查均已结束，无在跑测试；没有提交、推送或改用户旧报告。

## 后续新增默认与共享文件

- `TODO(VELO-P4-01)`：授权后共享2s等待，可注入，不叠加连接与首页两段预算；PIN未完成不能超时放行。
- `TODO(VELO-P4-02)`：首页快照24h，可注入；profile/client cache scope/在线server集合/隐藏库/layout精确隔离，复用ApiCache现表，剔除凭据/播放字段；无新SQL表。
- `TODO(VELO-P5-01)`：普通进度通知300ms，可注入，0关闭；状态/错误/排序字段即时，map供同步读取仍即时。
- `TODO(VELO-P8-01)`：主.97/次.94/卡片.96/导航.90；按下120ms/回弹180ms；选择器选中120ms，旧AppMenu默认0，减弱动画即时。B/C本地测试/实图review、规则/生成/APK及约定隔离smoke已闭合；真实遥控/触感仍未验。
- P1不新增业务时长，沿首批1/2/5s退避和5s重申；opening沿原attempt watchdog。P6沿既有WhatsOn60s/Recordings30s，无新文案或刷新默认。

| 所有者/范围 | 后续共享文件逐项 | 兼容/隔离处理 |
|---|---|---|
| P1模型桥接 | `lib/mpv/player/player_state.dart`、`lib/mpv/player/player_streams.dart`、`lib/mpv/player/player_stream_controllers.dart`、`lib/mpv/player/player_base.dart`、`lib/mpv/player/platform/player_android.dart`、`lib/mpv/mpv.dart` | activity可选、旧流/调用兼容，export只追加 |
| P1页面 | `lib/screens/video_player_screen.dart`、`lib/screens/video_player/parts/playback_services.dart`、`lib/screens/video_player/parts/errors.dart`、`lib/screens/video_player/parts/lifecycle.dart`、`lib/screens/video_player/parts/pip.dart`、`lib/screens/video_player/media_controls_screen_controller.dart` | 同一Dart owner；媒体控制可选策略回调保留旧默认 |
| P1原生 | `android/app/src/main/kotlin/com/edde746/plezy/exoplayer/ExoPlayerCore.kt`、`packages/wakelock_plus/android/src/main/kotlin/dev/fluttercommunity/plus/wakelock/Wakelock.kt`、`packages/wakelock_plus/android/build.gradle` | 不给核心另写FLAG；插件追加JUnit4.13.2/Robolectric4.16.1测试依赖并使用JUnit runner |
| P4 | `lib/main.dart`、`lib/widgets/home_startup_gate.dart`、`lib/providers/discover_provider.dart`、`lib/services/data_aggregation_service.dart`、`lib/services/api_cache.dart`、`lib/profiles/active_profile_provider.dart`、`lib/profiles/active_profile_binder.dart`、`lib/navigation/profile_session_screen.dart`、`lib/screens/main_screen.dart` | 完整bind契约不提前完成；新readiness/progressive/guard为兼容追加，身份隔离必守 |
| P5下载 | `lib/providers/download_provider.dart`、`lib/screens/downloads/downloads_screen.dart`、`lib/widgets/download_tree_view.dart` | 可注入合并、不可变快照、稳定行key，旧静态树调用默认兼容 |
| C详情 | `lib/screens/media_detail_screen.dart`、`lib/screens/media_detail/action_buttons.dart`、`lib/screens/media_detail/playback_tracks_status.dart`、`lib/screens/media_detail/presentation.dart` | 消费既有选轨参数/反馈组件；不改播放器公共接口；Plex提前附加请求，Jellyfin顺序保持 |
| B反馈/首页 | `lib/theme/interaction_tokens.dart`、`lib/widgets/press_feedback.dart`、`lib/widgets/app_select_field.dart`、`lib/widgets/app_menu.dart`、`lib/widgets/media_card.dart`、`lib/navigation/fusion_navigation.dart`、`lib/widgets/mobile_navigation_rail.dart`、`lib/widgets/side_navigation_rail.dart`、`lib/widgets/fusion_home_hero.dart`、`lib/widgets/vidhub_ambient_backdrop.dart`、`lib/screens/discover_screen.dart` | 公共新参数默认兼容；不改Discover数据或main；路由、真实字体/图像、双向滚动已验证且review关闭 |
| P6 | `lib/services/plex_client/parts/live_tv.dart`、`lib/screens/livetv/tabs/whats_on_tab.dart`、`lib/screens/livetv/tabs/guide_tab.dart`、`lib/screens/livetv/tabs/recordings_tab.dart` | 后端签名/count12不变，全部失败保首异常；UI使用安全错误文本与现有文案 |

新增局部实现：`lib/mpv/player/player_playback_activity.dart`、`lib/screens/video_player/screen_awake_policy.dart`、`lib/services/home_snapshot_store.dart`、`lib/services/home_startup_timing.dart`、`lib/providers/download_mutation_collections.dart`、`lib/screens/media_detail/playback_selection.dart`、`lib/screens/media_detail/playback_selectors.dart`、`lib/screens/media_detail/responsive_layout.dart`、`lib/screens/media_detail/action_press.dart`、`lib/screens/livetv/live_tv_load_error.dart`。测试与共享夹具详见各实施交接；本次最终83产物隔离生成一致性与当前APK已核验；当前结果和首批83产物历史证据分别记录，不混作同一批。

C另外在下方首批列出的同22个slang源文件中追加 `detailPlayback.version/unavailable/loadFailed` 三键；en/zh/zh-Hant为对应译文，其余相同19语言继续英语fallback、尚未本地化。保留原首批九键记录，不能将英语回退写成全语言已完成翻译。

## 首批任务卡对应交付（历史快照）


| 任务 | 交付物与行为 | 验收边界 |
|---|---|---|
| A/P1 | `wakelock_controller.dart` 增加可注入退避，首次/周期启用失败恢复、同目标连续错误日志抑制；关闭取消重试，迟到失败后仍释放；`playback_services.dart` 在 EOF 回拖后按有效播放状态恢复常亮 | 未改原生窗口或 ExoPlayer 公共状态语义；缓冲保持、原生 owner 与真机30分钟长播后置 |
| B/P2 | 新 `AppSelectField`；音频/主字幕/副字幕保留主副标题、编码/声道；菜单稳定区分 Off、nativeTrackId、sourceStreamId；异步 pending 排他及失败恢复；TV/键盘当前项聚焦与返回恢复 | 独立旧选轨弹层保持原列表操作；详情页预选未接入；真实服务端切轨/TV 遥控器未验 |
| B/局部P8 | 新 `PressFeedback`、`InteractionTokens`，由原控件 highlight 驱动变换/颜色，取消和滚动释放；减弱动画只变色，低性能关闭暗层动画 | 未新增业务 onTap/触感；未迁移全局海报/导航；未加入菜单120ms延迟关闭 |
| C/P3 | 纯评分策略、独立详情评分条、首页最多两来源；四外部+独立个人入口；个人角标优先，否则按来源排序；继续观看排除；角标开关与来源启用/排序持久化 | 个人角标为明确 `/10`，编辑复用原五颗星协议和后端能力；不抓外部分、不造 votes、不补 Emby 映射 |
| C/P3 接入 | 手机/桌面/TV 详情脱离元数据裁剪预算；MediaCard/FocusableMediaCard/HubSection/TvBrowseRail 接通角标；来源语义随当前 TV 剧集；个人入口最小48px并自适应大字体 | 未执行整体详情布局重排；静态设计六板审阅不等于 Flutter 截图或真机验收 |

相关新测试：`playback_wakelock_lifecycle_test.dart`、`app_select_field_test.dart`、`player_track_selector_test.dart`、`rating_display_policy_test.dart`、`media_ratings_strip_test.dart`、`rating_settings_screen_test.dart`；另调整已有 owner/详情/card/hub/TV rail 回归。最终执行数量以检查日志为准。

## 首批检查证据（历史快照）

独立检查日志目录：`/tmp/velo-validation-20261111/`；完整汇总 `final-validation.md`。下表文件名均相对此目录。检查由 validation 代理执行；实现代理未自行宣称通过。

| 检查 | 当前结果 | 证据 |
|---|---|---|
| 项目 guard、硬编码文案、用户错误、图标规则 | 均退出0 | `guards.log`、`hardcoded-strings-final.log`、`user-facing-errors.log`、`icon-consistency.log` |
| 翻译 strict hygiene | 退出0，0 unused | `translations-retry.log` |
| 本次 Dart 格式 | 34个手写 Dart 文件通过 | `format-final.log`、`changed-handwritten-dart.json` |
| `git diff --check` | 退出0，无输出 | `final-validation.md` 的检查记录 |
| 全仓 machine analyzer | 通过，0 error/warning/info | `analyzer-clean.log`，执行项目 `scripts/checks/check_analyzer.dart` |
| `flutter analyze --no-pub` | 原命令未通过：LSP JSON 截断，退出255 | `flutter-analyze.log`、`flutter-analyze-retry.log`；共两次后停止，未伪称成功 |
| A/B 定向测试 | 11文件去重74项全部通过 | `ab-tests.log` 73通过/1失败；失败所属文件最终 `bc-retry-tests.log` 7/7通过，未增加总数 |
| C 定向测试 | 10文件去重219项全部通过 | `bc-retry-tests.log` 中排除B后34项，`c-final-tests.log` 185项；总计21文件293项，去重算法见 `test-coverage-summary.json` |
| `scripts/codegen.sh` | 退出0 | `codegen-c-retry.log`，使用已安装Python3.11，不手改生成Dart |
| `scripts/codegen.sh --check` | 退出1，报告23份未暂存生成物 stale | `codegen-check.log`；脚本另将未暂存生成物加入stale集合，不将原命令记为通过 |
| 完整工作区隔离重生成 | 退出0，83份产物逐字节零差异 | `codegen-bytecheck.log`、`codegen-bytecheck-result.json`；覆盖tracked改动及untracked非忽略源码，未改Git索引或项目脚本 |
| Android Gradle arm64 debug 构建 | 退出0，成功 | `android-build-escaped-sdk.log`；原 `android-build.log` 为SDK路径编码失败，临时转义并恢复本机配置后重试 |
| APK ZIP CRC / v2签名 | 通过 | `apk-result.json`、`apk-signature.log`；未安装运行 |
| 独立最终审查 | 通过，无需追加修复的问题 | `/tmp/velo-review-final-20261111.md`；静态审查不代替测试与真机 |

环境准备已确认 Flutter 3.47.7 / Dart 3.13.5、Android SDK/NDK 和 JDK17 可用；生成器临时使用已有Python3.11。wakelock_plus包的旧缓存引用通过离线、锁文件约束的pub get恢复，依赖约束与lock未改。完整 Xcode 未安装，macOS/iOS/tvOS 构建没有执行。未运行全仓 `scripts/ci_checks.sh` 聚合命令、全库单测或额外unused-code扫描；已运行上述分项，不冒充全量CI。

开发 APK：`/Users/wines/velo/build/app/outputs/flutter-apk/app-debug.apk`，287,218,219字节（约273.9MiB）；SHA-256：`01ad681a2ac1e070918c4c73c59345a2ef81670037630e4dd10ff8aff848d8e3`。包含arm64 Flutter引擎、Manifest与DEX；依赖附带部分其他ABI原生库，本次作为arm64 debug验证包。仅本机保留、不入库、不作为正式发布包。首次SDK路径错误来自 Java Properties 按 Latin1 解码未转义中文路径；临时转义已恢复，没有扩大项目源码改动。

## 首批审查问题与修正（历史快照）

| 问题 | 原作者修正 | 复核状态 |
|---|---|---|
| 菜单打开后轨道重排会让位置索引指向另一轨 | 改稳定且区分命名空间的值，返回时按当前列表查找；目标删除不误选 | 最终静态复核关闭；回归日志见检查证据 |
| HubSection/TvBrowseRail 默认 false，真实相关推荐仍无角标 | 两个父组件默认允许评分，保留继续观看和全局开关，补真实 wrapper 回归 | 最终静态复核关闭；相关回归通过 |
| 个人评分入口约30px且固定20px内容盒裁大字体 | 独立最小48px、自适应文字高度，同步手机/TV预算；未扩大普通元数据chip | 最终静态复核关闭；相关回归通过 |

检查中另外修正：A 的全局队列跨 FakeAsync 夹具隔离；B 的 const 键集合与菜单动画临界帧；C 的异构偏好测试类型推断、TV个人入口导航及评分来源语义。B 菜单时序问题两轮修正后使用项目动画时长加1ms完成退出，保留 pending 无菜单/无重复请求/失败重试断言，不修改业务锁来迁就测试。

初轮审查依据：`/tmp/velo-review-ab-20261111.md`、`/tmp/velo-review-c-20261111.md`；它们列的是修正前问题，不应当作最终仍未修复结论。

## 首批共享文件变更清单

| 文件 | 本次改动 |
|---|---|
| `lib/screens/video_player/wakelock_controller.dart` | owner共享控制器新增注入退避及错误恢复，保持原队列契约 |
| `lib/screens/video_player/parts/playback_services.dart` | 播放/完成路径共用常亮同步检查，未重复发进度或媒体控制事件 |
| `lib/widgets/app_menu.dart` | 兼容追加 autofocus/wrapLines/minHeight；旧调用默认保持原表现 |
| `lib/widgets/video_controls/sheets/sheet_selection_column.dart` | 兼容追加 embeddedBuilder，复用 pending 独占与失败恢复 |
| `lib/widgets/video_controls/sheets/player_settings_controls.dart` | 短分段标签单行省略 |
| `lib/services/settings_service.dart` | 追加 showRatingBadges/ratingSourceOrder/disabledRatingSources，登记重置与导出 |
| `lib/screens/settings/appearance_settings_screen.dart` | 追加评分设置入口 |
| `lib/widgets/media_rating_badge.dart` | 来源策略/偏好与整组fallback归属、个人角标选择 |
| `lib/widgets/media_card.dart` | 默认角标、来源/个人优先、左下位置与语义、继续观看排除 |
| `lib/widgets/focusable_media_card.dart` | 兼容转发 showRatingBadge，默认 true |
| `lib/widgets/hub_section.dart` | 父层默认允许评分角标 |
| `lib/widgets/tv_browse_rail.dart` | TV父层默认允许评分角标 |
| `lib/widgets/hero_metadata_badges.dart` | 首页来源评分与偏好更新 |
| `lib/widgets/tv_spotlight_background.dart` | 首页两来源上限与偏好更新 |
| `lib/screens/media_detail_screen.dart` | 独立评分、个人入口、TV焦点/语义与布局预算 |
| `lib/screens/media_detail/presentation.dart` | 手机详情评分区域/个人入口接入 |

新增通用文件：`lib/widgets/app_select_field.dart`、`lib/widgets/press_feedback.dart`、`lib/theme/interaction_tokens.dart`、`lib/utils/rating_display_policy.dart`、`lib/widgets/media_ratings_strip.dart`、`lib/screens/settings/rating_settings_screen.dart`。未改 pubspec、原生播放器、既有品牌/浮层 token 或原设计 HTML。

slang 源文件每份追加九个评分设置键：

- 已有对应语言文案：`lib/i18n/en.i18n.json`、`lib/i18n/zh.i18n.json`、`lib/i18n/zh-Hant.i18n.json`。
- **尚未本地化的英语回退**：`lib/i18n/az.i18n.json`、`lib/i18n/bg.i18n.json`、`lib/i18n/da.i18n.json`、`lib/i18n/de.i18n.json`、`lib/i18n/es.i18n.json`、`lib/i18n/fr.i18n.json`、`lib/i18n/hu.i18n.json`、`lib/i18n/it.i18n.json`、`lib/i18n/ja.i18n.json`、`lib/i18n/kk.i18n.json`、`lib/i18n/ko.i18n.json`、`lib/i18n/nb.i18n.json`、`lib/i18n/nl.i18n.json`、`lib/i18n/pl.i18n.json`、`lib/i18n/pt.i18n.json`、`lib/i18n/ru.i18n.json`、`lib/i18n/sv.i18n.json`、`lib/i18n/tr.i18n.json`、`lib/i18n/uz.i18n.json`。
- 生成输出：`lib/i18n/strings.g.dart`、`strings_az.g.dart`、`strings_bg.g.dart`、`strings_da.g.dart`、`strings_de.g.dart`、`strings_en.g.dart`、`strings_es.g.dart`、`strings_fr.g.dart`、`strings_hu.g.dart`、`strings_it.g.dart`、`strings_ja.g.dart`、`strings_kk.g.dart`、`strings_ko.g.dart`、`strings_nb.g.dart`、`strings_nl.g.dart`、`strings_pl.g.dart`、`strings_pt.g.dart`、`strings_ru.g.dart`、`strings_sv.g.dart`、`strings_tr.g.dart`、`strings_uz.g.dart`、`strings_zh.g.dart`、`strings_zh_Hant.g.dart`（均在 `lib/i18n/`，由代码生成更新）。

既有未跟踪 `docs/ui-refresh-validation-2026-11-10.md` 原样保留。本轮报告与计划是新文档，没有提交或推送。

## 首批默认值与材料差异（后续状态见上方）

| 编号 | 已实现默认 | 仍需确认 |
|---|---|---|
| TODO(VELO-P1-01) | retryDelays 1s/2s/5s，之后保持5s；健康刷新5s；均可注入 | 真机调优；释放失败保留显式请求再试，不增加无人持有后台计时器 |
| TODO(VELO-P3-01) | 详情4外部、首页2；RT影评→RT观众→IMDb→TMDB→其他已知→中性未知；角标开、所有来源启用 | 真机密度；来源顺序/禁用可持久化；后端可用数据不由示例决定 |
| TODO(VELO-P8-01) | 局部缩放.97、按下120ms、回弹180ms、easeOutCubic，组件参数可覆盖 | 全局接入与设备手感；菜单延迟关闭未实现 |

与画稿/原方案的有意差异：菜单至少48px命中区替代46px示例；长文无硬两行截断；个人角标明确0–10而非复制4.5星样例；四外部+个人而非五外部；TMDB/IMDb是来源示例而非业务默认；人数缺失即隐藏；保持现有菜单立即关闭语义；没有为追求图稿重排整页。

以上默认与后置范围仅记录首批快照。后续已落盘的P4启动2s/快照24h、P5进度300ms、详情预选、全局反馈与常亮activity/单owner补强，及各自未通过或待验项，统一以上方“P1–P8 当前状态（唯一状态表）”为准；首批APK不能证明这些后续改动。
