# R06 运行时性能 任务卡

- 基线提交:`8885b39`(静态读码,未运行;本环境无 flutter,analyze/测试均未执行)
- 目标:去掉播放器 HUD 的无条件实时模糊、压低下载进度与首页渐进回调带来的无谓重建,并按实际代码收窄清单中不成立的条目。
- 优先级:R6-1 高;R6-2/3/5/6 中;R6-4 低;R6-7、R6-8 结论为不动。
- 规模:中
- 前置依赖:无。R6-3 依赖 `downloadsStructureRevision` 语义(已存在,不需改)。
- 不在范围:详情页 Plex 预渲染(R6-8,无实测不动);直播节目单改造(核对后无需改);图片解码尺寸(已完成);任何视觉改版。

## 与清单/材料不一致(已核实,以本卡为准)

1. R6-6:`about_screen.dart:14` 已是 `static final _packageInfoFuture`,`:20` 使用它,不是 build 内新建 future,**不改**。`external_player_screen.dart:55-56` 的 `KnownPlayers.getForCurrentPlatform()` 内部已 `_installedPlayers ??=` 记忆化(`lib/models/external_player_models.dart:357-358`),重建不会重复探测,只剩"新 State 首帧 snapshot 为 waiting"的一帧空白,**不属于性能缺陷,默认不改**。真正每次 build 重新发起平台调用的只有 `settings_screen.dart:711-712` 与 `1040-1041`(`getCurrentDownloadPathDisplay` → `getDownloadsDirectory`,`lib/services/download_storage_service.dart:124-130`)。
2. R6-7:文件实际路径是 `lib/screens/livetv/tabs/guide_tab.dart`(清单写成 `livetv/guide_tab.dart`)。核对结论:`:1246` 的 `Column` 只是"时间导航 + 表头 + 网格"的布局外壳;频道列与节目网格都用 `SliverVariedExtentList.builder`(`:1283`、`:1321`)懒构建;节目块按水平可视范围裁剪(`_buildProgramRow` `:1737-1757`,只构建可视区前后各约 1 槽);时间表头最多 12 槽(窗口 6 小时、每槽 30 分钟,`:121`、`:271`)。`:1680` 的 `Column` 是频道名回退(2 个子项)。**结论:不是长列表整体构建,不改。**
3. R6-2:`_invalidateDownloadsSnapshot`(`download_provider.dart:675`)只把 `_downloadsSnapshot` 置空,**重建是惰性的**,只在下一次读 `downloads` getter(`:707-708`)时发生,不是每个进度事件都全量重建。真实成本是:每 300ms 通知后,凡读 `downloads` 的订阅者(如 `downloads_screen.dart:231` 的 `provider.downloads.values.any(...)`)触发一次 O(n) 拷贝。清单"每个进度事件都重建"偏重,验收按"每个通知周期最多重建一次快照"写。
4. R6-3:`smart_deletion_handler.dart:49` 的 `Consumer` 关心的是删除进度而不是下载进度;`action_buttons.dart:803` 位于 `lib/screens/media_detail/action_buttons.dart`(目录已核实,清单标"待核对")。
5. R6-5:侧栏除 `:884-885` 外,`:1303` 的 `_buildLibrariesSection` 还有一处 `context.watch<LibrariesProvider>()`(只用 `isLoading`),清单未列,一并处理。
6. R6-1:`reduceEffects` 同时包含 高对比度 与 系统"减弱动画"(`app_glass_surface.dart:29-30`),HUD 在这两种情况下也会降级为不透明底色,属预期。

## 涉及文件表

| 文件 | 行号 | 现状 | 动作 |
|---|---|---|---|
| lib/widgets/video_controls/widgets/player_hud_surface.dart | 14-27 | `PlayerHudSurface` 无条件 `BackdropFilter(sigma 10)`,底色 `Colors.black 0.42`;被 `video_controls.dart:1459`、`player_toast_indicator.dart:35`、`mobile_edge_adjustment_indicator.dart:36` 使用 | 改:接入 `AppGlassSurface.reduceEffects` |
| lib/widgets/app_glass_surface.dart | 29-30 | `static bool reduceEffects(BuildContext)` = `DevicePerformance.isReduced \|\| highContrast \|\| disableAnimations` | 不改,仅引用 |
| lib/navigation/fusion_navigation.dart | 59、99-101 | 参照做法:`reduced ? navigationBody : BackdropFilter(...)`,降级时底色 alpha=1 | 不改,照此接入 |
| lib/providers/download_provider.dart | 80-93、625-672、675、707-708 | `_DownloadMutationMap(_invalidateDownloadsSnapshot)`;`numericProgressOnly` 判定(`:653-662`);300ms 共享 Timer(`:663-669`);`downloads` 惰性快照 | 改(R6-2) |
| lib/providers/download_mutation_collections.dart | 5-47 | `_DownloadMutationMap.operator []=` 每次写入都回调 `_onChanged` | 改(增加不失效写入口) |
| lib/screens/media_detail/action_buttons.dart | 803-819、826-960 | `Consumer<DownloadProvider>` 内调 `_downloadButtonSpec` | 改(R6-3) |
| lib/screens/music/album_detail_screen.dart | 209-250 | `Consumer<DownloadProvider>` 读 `getProgress`/`isQueueing` | 改(R6-3) |
| lib/screens/downloads/sync_rules_screen.dart | 39-72、116 | `Consumer<DownloadProvider>` 读 `syncRules`、`metadata`;`_SyncRuleTile` 只用 provider 调 `updateSyncRuleOptions`(`:273`、`:278`) | 改(R6-3) |
| lib/utils/smart_deletion_handler.dart | 49-65 | 删除进度对话框 `Consumer<DownloadProvider>` 读 `getDeletionProgress` | 改(R6-3) |
| lib/providers/discover_provider.dart | 562-567、573-580 | 两个 `onProgress` 每次回调 `safeNotifyListeners()` | 改(R6-4) |
| lib/services/data_aggregation_service.dart | 160-190、437-441 | `_homeProgressively` 链式 `merge(snapshot)`(`snapshot` 在入队时取),每台服务器完成一次全量 `mergeContinueWatching` | 改(R6-4) |
| lib/widgets/side_navigation_rail.dart | 884-885、1303 | `context.watch<LibrariesProvider>()` / `<HiddenLibrariesProvider>`;`_buildLibrariesSection` 再 watch 一次 | 改(R6-5) |
| lib/screens/settings/settings_screen.dart | 165、703-725、1026-1050、1109-1111、1126-1128 | 两处 `FutureBuilder(future: storageService.getCurrentDownloadPathDisplay())`,future 在 build/对话框 builder 内新建 | 改(R6-6) |
| lib/screens/settings/external_player_screen.dart | 24、55-56 | `StatelessWidget`;future 已记忆化 | 默认不改 |
| lib/screens/settings/about_screen.dart | 14-20 | 已是 static future | 不改 |
| lib/screens/livetv/tabs/guide_tab.dart | 1246、1283、1321、1680 | 已懒构建 | 不改 |
| test/widgets/player_ui_refinement_test.dart | 179、201 | 现有 HUD 尺寸/位置用例 | 保持通过 |
| test/widgets/app_glass_surface_test.dart | 13-36 | 四种模式(full/contrast/motion/reduced)矩阵写法 | 参考其写法 |
| test/providers/download_provider_progress_test.dart | 62-185 | 7 个节流/快照用例 | 保持通过并扩充 |

## 逐步修改说明

### R6-1 播放器 HUD 模糊降级(高)

- 现状:`PlayerHudSurface.build` 直接 `ClipRRect > BackdropFilter(blur 10) > DecoratedBox`,叠在视频上做实时模糊,低端 TV/手机代价最大。
- 改成:`final reduced = AppGlassSurface.reduceEffects(context);`。为真时不创建 `BackdropFilter`,保留 `ClipRRect` 与描边;底色改不透明。
- 做法:
  - 文件内私有常量:`_glassAlpha = 0.42`(现值)、`_reducedAlpha = 0.88`(降级底色 alpha;黑底白字可读),`TODO(VELO-R6-01)` 真机调。
  - 降级时 `color: Colors.black.withValues(alpha: _reducedAlpha)`;边框保持 `white 0.14`,高对比度下边框 alpha 提到 0.35(与 `app_glass_surface.dart` 降级描边一致)。
  - 对外签名 `PlayerHudSurface({required child, radius = 22})` 不变,三个调用点不改。
  - 不改任何时长/帧时序。

### R6-2 下载快照:纯进度更新不使快照失效(中)

- 现状:`_onProgressUpdate` 对每个事件 `_downloads[key] = current`(`:652`),`_DownloadMutationMap.[]=` 立即 `_invalidateDownloadsSnapshot()`;`downloads` getter 下次被读时 `Map.fromEntries(...where(_ownsProgressEntry))` 重建。
- 改成:纯数值进度(与现有 `numericProgressOnly` 同一判定)不使结构快照失效,在 300ms 定时器触发时一次性把最新值合入快照。
- 做法(先做 A):
  - A:`_DownloadMutationMap` 增加 `void putNumeric(K key, V value)`,只写 `_values` 不调 `_onChanged`;`_onProgressUpdate` 在"归属当前 profile 且 numericProgressOnly"时用它(判定变量要在写入前计算,现代码在写入后才算 `numericProgressOnly`,需把判定前移,只依赖 `previous` 与 `current`),并把 key 记入 `_pendingNumericKeys`。定时器回调(`:665-668`)里:若 `_downloadsSnapshot != null`,生成**新**快照(`Map.of(旧快照)` 覆盖待刷新 key,再包 `UnmodifiableMapView`),否则不做事。旧快照对象必须保持不可变(现有用例 `download_provider_progress_test.dart:79` 依赖)。
  - B:若 A 的 rebuild 计数收益不可测,保持现状并在提交说明记录"惰性重建,不改"。
- 不变量:状态变化、增删、所有权变化仍走 `_onChanged` 立即失效;`_downloadsStructureRevision` 在纯进度时不增加(用例 `:84`、`:85` 已断言)。
- 参数沿用 `progressNotifyInterval`(默认 300ms,`TODO(VELO-P5-01)`,`:80-81`),不新增常量。

### R6-3 `Consumer<DownloadProvider>` 改 `Selector`(中)

选择器返回 record(值相等)。`downloadsStructureRevision`(`:88`)在纯进度脉冲时不变,可用来覆盖结构变化。

| 位置 | 应选字段 | 说明 |
|---|---|---|
| `action_buttons.dart:803` `_buildDownloadButton` | `(progress?.status, progress?.progressPercent, progress?.currentFile, provider.isQueueing(globalKey), provider.downloadsStructureRevision)`,`progress = provider.getProgress(metadata.globalKey)` | `_downloadButtonSpec` 还读 `isDownloaded`、`hasSyncRule`、`getSyncRule`,这些变化伴随结构通知,由 revision 覆盖。builder 内用 `context.read<DownloadProvider>()` 调 spec。容器(show/season)的 `getProgress` 为聚合值,体现在 `progressPercent` |
| `album_detail_screen.dart:209` | `(status, progressPercent, isQueueing)`,取自 `getProgress(widget.album.globalKey)`/`isQueueing` | 与 `lib/widgets/music/track_row.dart:315-319` 现有 Selector 同形 |
| `sync_rules_screen.dart:39` | `provider.downloadsStructureRevision` | 该页不展示下载进度;`syncRules` getter 每次返回新 `Map.unmodifiable`(`download_provider.dart:2451`),不能直接当 selector 值 |
| `smart_deletion_handler.dart:49` | `provider.getDeletionProgress(globalKey)`(`DeletionProgress` 为 freezed,值相等,`lib/models/download_models.dart:47`) | 删除进度走 `safeNotifyListeners`(`:2285-2294`) |

- `episode_card.dart:242`、`track_row.dart:315`、`download_tree_view.dart:378` 已是 Selector,不改。
- 行为不变:按钮图标/tooltip/可点击性与改前一致。

### R6-4 首页渐进回调合帧与 merge 去重(低)

- 现状:`_homeProgressively`(`data_aggregation_service.dart:160-190`)每台服务器返回后 `publications.then(merge(snapshot); onProgress(combined))`,`snapshot` 入队时取;多台同时完成各跑一次全量 `mergeContinueWatching`(`:437`,排序+去重,去重可能触发外部 id 加载)。`discover_provider.dart:562-567`、`573-580` 每次回调都 `safeNotifyListeners()`,N 台 = onDeck N 次 + hubs N 次。
- 改成:
  1. 聚合层:`snapshot` 改为在 `publications.then` 回调**执行时**取(此时 `completed` 已含后到结果);若 `completed.length` 与上次已发布数量相同则跳过。最终 `latest` 语义不变(最后一次包含全部)。
  2. Provider 层:新增私有 `_notifyHomeProgress()`,用 `bool _homeNotifyScheduled` + `SchedulerBinding.instance.scheduleFrameCallback` 把同一帧内多次通知合并为一次 `safeNotifyListeners()`,回调内再判 `isDisposed`;仅替换 `:566`、`:579` 两处,其余保持同步。
  3. 无帧的单测环境需显式 pump 一帧;`discover_startup_test.dart` 若因此失败,修测试(先 pump),不放宽断言。
- `_applyOnDeck`/`_replaceHubs`/`expectedCommitRevision` 仍同步执行,只延迟通知。

### R6-5 侧栏 watch 改 Selector(中)

- 现状:`side_navigation_rail.dart:884-885` watch 两个 provider;`:1303` 再 watch `LibrariesProvider` 只取 `isLoading`。`libraries`/`hiddenLibraryKeys` getter 每次返回新的 `List.unmodifiable`/`Set.unmodifiable`(`libraries_provider.dart:68`、`hidden_libraries_provider.dart:27`),不能用身份比较。
- 改成:`:884-885` 用 `Selector` + `shouldRebuild`(`listEquals`/`setEquals`);`MediaLibrary`(`lib/media/media_library.dart:8`)是否定义 `==` **待核对**(`grep -n 'operator ==' lib/media/media_library.dart`);没有时比较 `globalKey` 加展示字段(title、serverId、type)组成的 record 列表。`:1303` 改 `context.select<LibrariesProvider, bool>((p) => p.isLoading)`。
- 库分组、隐藏库、焦点记忆(`_focusTracker.pruneExcept`)行为不变。

### R6-6 build 内新建 future(中,范围收窄)

- 只改 `settings_screen.dart`:
  - 增加字段 `late Future<String> _downloadPathDisplay`,在 `initState`(`:165`)赋值 `DownloadStorageService.instance.getCurrentDownloadPathDisplay()`。
  - `:711-712` 的 `FutureBuilder.future` 改用该字段。
  - 路径变化处重新赋值:`:1109-1111`(选新路径后的 `setState`)与 `:1126-1128`(`_resetDownloadLocation` 的 `setState`),在 `setState` 内重新取 future,否则页面不更新。
  - `:1040-1041` 对话框内的 `FutureBuilder`:在 `_showDownloadLocationDialog`(`:1026`)里先创建局部 future 再传入 builder。
- `external_player_screen.dart`、`about_screen.dart` 不改。

### R6-7 / R6-8

- R6-7:无代码改动,在提交说明记录核对结论。可选在 `test/screens/livetv/guide_tab_test.dart`(已有虚拟化用例 `:354`)加 500 频道用例,断言可视范围外的行未构建。
- R6-8:无实测数据前不动。

## i18n key 与设置项/常量

| 名称 | 默认值 | 位置 | TODO |
|---|---|---|---|
| `_glassAlpha` / `_reducedAlpha`(HUD 底色) | 0.42 / 0.88 | player_hud_surface.dart 私有常量 | TODO(VELO-R6-01) |
| `progressNotifyInterval`(沿用) | 300ms | download_provider.dart:80 | TODO(VELO-P5-01) 已有 |
| i18n key | 无 | | |
| 设置项 | 无 | | |

## TV 焦点、主题、形态要求

- TV/低端机:HUD 无 `BackdropFilter`,目视黑底不过重、文字可读。
- TV 焦点:R6-3/R6-5 不得改变 `FocusableAction`/`FocusNode` 的创建位置与数量;`album_detail_screen.dart:209` 外层 `FocusableAction.builder` 保持,Selector 放在其内;侧栏 `_focusTracker` 行为不变。
- 三主题(亮/暗/纯黑):HUD 恒黑底白字,三主题一致;下载按钮图标颜色与改前一致。
- 手机/平板/桌面:HUD 均走 `reduceEffects`;桌面开启系统"减弱动画"后应降级。

## 测试要求

修改现有:
- `test/widgets/player_ui_refinement_test.dart:179`、`:201` 保持通过。
- `test/providers/download_provider_progress_test.dart` 7 个用例保持通过。

新增:
- `test/widgets/player_hud_surface_test.dart`:`full 含一个 BackdropFilter`、`contrast/motion/reduced 为 findsNothing`(参照 `app_glass_surface_test.dart:13-36` 与 `DevicePerformance.debugReset(autoReduced: true)`、`tearDown(DevicePerformance.debugReset)`);降级时底色 alpha ≥ 0.85。
- `download_provider_progress_test.dart` 增加:`纯进度更新 300ms 内 identical(provider.downloads, provider.downloads)`、`300ms 后读到最新进度且旧快照值不变`、`状态变化立即得到新快照`。
- `test/widgets/download_consumers_rebuild_test.dart`(新):build 计数,100 次纯进度事件后,下载按钮/同步规则页/专辑下载按钮 build 次数 ≤ 1 + 结构变化次数;状态变 paused/completed 时图标变化。
- `test/screens/downloads/sync_rules_screen_test.dart` 现有 9 个用例(`:210-398`)保持通过。
- `test/services/home_progressive_aggregation_test.dart`:新增"两台同时完成只 merge 一次,最终结果与逐次 merge 一致";现有 3 个用例保持通过。
- `test/providers/discover_startup_test.dart`:新增"同一帧内两台回调只通知一次"。
- `test/widgets/side_navigation_rail_test.dart`:新增"库列表内容不变时重复通知,侧栏 build 次数不增加"。
- (可选)`test/screens/settings/settings_download_path_test.dart`:多次 build 只调用一次 `getCurrentDownloadPathDisplay`;改路径后刷新。

## 验收清单

- [ ] `flutter analyze` 无新增告警
- [ ] `scripts/run_tests.sh` 通过;重点 `test/providers/download_provider_progress_test.dart`、`test/widgets/download_tree_progress_test.dart`、`test/screens/downloads/sync_rules_screen_test.dart`、`test/widgets/player_ui_refinement_test.dart`、`test/providers/discover_startup_test.dart`、`test/services/home_progressive_aggregation_test.dart`
- [ ] 新增 HUD 测试:降级模式树内无 `BackdropFilter`
- [ ] 手动:低端 TV 或 设置视觉效果=reduced 时,播放中边缘亮度/音量 HUD、长按倍速 toast 无模糊且可读
- [ ] 量化:开始 2 个以上下载,详情页停留 30 秒,DevTools "Track widget rebuilds"(或测试计数)记录下载按钮 build 次数,目标每 300ms 至多 1 次且不高于改前;`sync_rules_screen` 纯进度期间 build 次数为 0
- [ ] 量化:两台以上服务器冷启动,首页 `DiscoverProvider` 通知次数 ≤ 帧数,最终内容与改前一致
- [ ] 手动:设置页反复重建下载路径不闪;更改/重置下载位置后文本更新
- [ ] 三主题各看一次 HUD 与下载按钮

## 提交拆分

1. `perf(播放器): HUD 模糊接入 reduceEffects 降级`
2. `test(播放器): 新增 HUD 降级用例`
3. `perf(下载): 纯进度更新不使快照失效`
4. `test(下载): 补充快照复用与进度可见性用例`
5. `perf(下载): 媒体详情下载按钮改用 Selector`
6. `perf(下载): 专辑下载按钮与同步规则页改用 Selector`
7. `perf(下载): 删除进度对话框改用 Selector`
8. `perf(首页): 渐进聚合只对最新结果 merge`
9. `perf(首页): 渐进回调按帧合并通知`
10. `perf(侧栏): 库列表改用 Selector`
11. `perf(设置): 缓存下载路径显示 future`
12. `docs: 记录节目单与关于页核对结论`

## 风险与待确认

- R6-2 方案 A 易破坏"旧快照不可变",测试先行;收益不可测则走 B。
- R6-4 帧合并使首页通知晚一帧,个别测试需显式 pump。
- `MediaLibrary` 是否值相等待核对(见 R6-5)。
- HUD 降级 alpha 0.88 为估值,需真机调(VELO-R6-01)。
- 待确认:`disableAnimations`/高对比度也触发 HUD 降级(与 `AppGlassSurface` 一致,默认接受)。
- 禁止事项:不直接改生成的 Dart 文件;不删 Plex/Jellyfin/Emby/一起看/TV 支持;保留 mpv 与 ExoPlayer;不改播放器帧时序相关时长;缓存必须按用户/服务器隔离,不得跨用户泄露(本包不触碰缓存键)。
