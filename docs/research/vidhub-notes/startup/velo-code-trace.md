> 历史研究摘要，来自本地资料快照 `c350c4a`（2026-11-14 整理）。原始证据未公开；文内观察、推断和未验证边界按原文保留，不能当作本次复测结果。公开副本仅脱敏路径并处理未公开证据链接。

# Velo 启动资源链路：当前代码证据

检查日期：2026-11-13。代码：`<repo>`，HEAD `c41732f`。只读源码审阅，无 Velo 动态测量、无产品修改、无编译或测试运行。检查时 tracked 文件没有修改；存在未跟踪 `design/prototype-v2/`、`design/vidhub-study/` 和两份 docs，不能据此推断用户正在修改启动代码。以下耗时常量是预算/上限，均不是实测耗时。行号以本次检查为准。

## 结论

当前 Velo 已做服务器并行连接、按服务器渐进发布首页、继续观看和推荐并行、授权后有界首页门、磁盘首页快照及图片连接复用。不能将差异解释为“所有服务器全部完成才显示”或“下载完整海报才放行”。最值得验证的是 **单服务器内部的全库返回门、继续观看装饰/排序补全门、可用在线身份之前不可读取快照**。这些是代码路径证据，尚非本设备比 VidHub 慢的测量归因。

## 共同关键路径和界面门槛

1. `lib/main.dart:264` `Future<_StartupDependencies> _initializeApplication()`：读取 Settings；条件性 Sentry 初始化；进入 `:925 _initializeStartup(SettingsService settings)`。设备能力并行获取，存储、数据库 open/recovery、图片缓存预算等局部阶段有 await；Android 用户证书加载提前发起、客户端创建前 await。非必要初始化 `:1008` 附近延后到首帧后，不能统称为首屏串行阻塞。
2. `lib/main.dart:2148` 起 Setup 创建 ConnectionBootstrap 并 `await bootstrap.run()`，清理孤立连接、reload profile；`:2197` 取连接列表；`:2259` 再 await profile hydration；`:2276` `binder.start(...)`。`lib/connection/connection_bootstrap.dart:46 Future<void> run()` 依次执行幂等种子/迁移；它不是每次启动完整远端同步的证据。
3. `lib/profiles/active_profile_binder.dart:287 _runRebindOnce`：读取连接/关联快照；`:398` Plex Home 与 join rows 并行；`:656 _bindJoinRows(...)` 再用 Future.wait 并行各连接。授权集先完成时可发布已在线客户端；Jellyfin 本地身份不等待所有网络连接。敏感身份/PIN权限不可为性能直接跳过。
4. `lib/main.dart:1263 Future<bool> awaitStartupContentReady({required ActiveProfileProvider profile, required MultiServerProvider servers, required bool hasNetwork, Duration connectionBudget = const Duration(seconds: 2)})` 先等待身份授权，再等待首个 online 或剩余预算。网络存在时身份阶段没有这个 2 秒 content deadline；无网络用 `awaitStartupBindSettle` 的 2 秒限额。连接预算与后续 HomeStartupGate 按 `startupContentWaitElapsed` **共享**，不是两次固定 2 秒。
5. `lib/navigation/profile_session_screen.dart:249` 给 Discover 的门是 `activeProfile.isBinding && !activeProfile.isStartupIdentityReady`，给 Libraries 的门是 `isBinding`（`:234`）；`:424` 仅在线、无需 profile prompt、启动 Discover 时启用 HomeStartupGate。
6. `lib/widgets/home_startup_gate.dart:47 _prepare()` await `discover.ensureLoaded()`；build 在身份 ready 后、有内容/失败/预算耗尽/两加载完成任一条件进入 MainScreen。有内容就提前退出，**不等待海报像素**。
7. `lib/providers/discover_provider.dart:163 _homeClients()` 只取 online clients；`:167 _restoreHomeSnapshot()` 在上述身份门通过且至少一个客户端 online 后，从 Settings、隐藏库配置及客户端认证 scope 构建读取请求。`:189` 读磁盘快照并立即发布。`lib/services/home_snapshot_store.dart:64` 默认 maxAge 24h，`:69 read(...)` 经 ApiCache.getIfFresh 按客户端 scope 并行读 DB，认证 epoch/配置变化使旧结果失效。`lib/services/api_cache.dart:134` 确认是 DB cachedAt 新鲜度校验及 isolate JSON decode。它是授权后的缓存首屏，不是启动前无需网络的直接快照。
8. `lib/providers/discover_provider.dart:390 Future<void> ensureLoaded()` 复用 inflight/已覆盖 online 的结果；`:438 _loadOnce()` 先尝试快照，随后同时启动继续观看 `:559 getOnDeckProgressively` 与 hubs `:571 getHubsProgressively(includePlaybackHubs:false)`。后面的先 await A 再 await B 不代表网络串行。
9. `lib/services/data_aggregation_service.dart:160 _homeProgressively<R>` 对多服务器各自 fetch 并将已完成服务器合并发布；单服务器走 `fetch(serverIds)`，没有中途回调。`:788 _fetchLibraryHubsForClient(...)` 库级滑窗并发 3，`:849` await 所有 workers 才返回整服 hubs，因此单服一库慢可推迟该服所有 Latest 行出现。
10. `lib/screens/discover_screen.dart:1186` 初始全页 skeleton 只在继续观看 loading 且 onDeck/hubs 都空；有任一数据就不再盖住 hero。hubs 仍空时保留分区 skeleton。2 秒门退出不等于内容已到，也不等于图已显示。
11. `lib/screens/main_screen.dart:726 _primeOnlineServices(...)` 在 libraries 加载后才 prime 已挂载 tabs；`:2065 _primeContentTabs()` 不挂载未访问标签。Discover 已由上面的 Gate 发起，不应把这个库加载门说成 Discover 唯一入口。

## 后端具体资源请求与附加门

| 后端 | 连接/身份就绪 | 继续观看 | 首页其它行 |
|---|---|---|---|
| Jellyfin / Emby | `multi_server_manager.dart:802 addJellyfinConnection`：多 baseUrls 时 endpoint race，然后 `JellyfinClient.create`（客户端身份/headers，非全库扫描），`:887` checkHealth 成功才 online；`jellyfin_client.dart:574` 请求 dialect `paths.currentUser`，更新权限或头像变化时还 await 持久化回调 | Jellyfin 同发 Resume 与 `/Shows/NextUp`，再 await `_attachSeriesLastPlayed` 才 merge；Emby 使用一个 hide-aware Resume window，拆分 resume/nextup，不能改成 Jellyfin API 拼接丢失隐藏条目语义 | `data_aggregation_service.dart:664` 先 await fetchLibraries；J/E `<local-path>` (`browse.dart:340`)，再每可见库 `<local-path>`，并发 3 且等全库结果 |
| Plex | `PlexClient.create:509` await `_initMediaProviders:766`，获取 `/media/providers` 再注册客户端；endpoint/身份授权独立处理 | `_getContinueWatching:1636` 使用 provider continue key 或 `/hubs?identifier=home.continue,home.ondeck&count=...&includeGuids=1`；`:1677` 还 await missing clearLogo owner 合并 metadata 请求 | fetchLibraries 通常复用 `_providerLibraries`（`:1109`）；缺失时 `/library/sections`。global 使用 promoted/home key 或 `/hubs` (`:2513`)，音乐库 `/hubs/sections/{id}` 与 global 并发，但最终整服合并等待两支 |

本节路径行号未带前缀者分别属于 `lib/services/plex_client.dart`、`lib/services/jellyfin_client/parts/browse.dart`。没有记录实际服务器地址、用户 ID 或鉴权值。

### 实际可疑串行工作

- J/E 库列表：`browse.dart:323 fetchLibraries()` 仅 **in-flight single-flight**；成功时存 `_loadedLibraryViews`，后续 fetchLibraries 调用仍重新请求 Views，不是持久 TTL cache 命中。LibrariesProvider 和 Discover 同时请求可合并，错开后则会重发。`data_aggregation_service.dart:661` 的缓存注释不能代替实现事实。隐藏库分支 `browse.dart:1758` 在 `_loadedLibraryViews == null` 时直调 `_fetchLibraries()`，绕过 single-flight；可能与首页 hubs 的 Views 重叠，须运行记录确认。
- J/E Latest：`_fetchLibraryHubsForClient:788` 使用滑窗 3 而非逐库串行，但 await 全部 workers 的服务器级发布门仍存在。默认每行 20 (`lib/media/media_server_client.dart:31`)；首页 `includePlaybackHubs:false`，`browse.dart:1948` 在 Latest 后直接 return，因此当前首页每库**不会重复**请求 Resume/NextUp。
- Jellyfin Continue：`browse.dart:1807` Resume/NextUp Future.wait 后，`:1824` await `_attachSeriesLastPlayed:2305`。最多 24 series，batch concurrency=4 (`:204`)，每 request 3 秒 (`:222` 附近)，全 pass 4 秒 (`:232` 附近)；`_fetchSeriesLastPlayed:2609` 请求 `/Items`，ParentId=series、Episode、SortBy=DatePlayed、Limit=1、Fields=UserData、EnableImages=false、EnableTotalRecordCount=false。已有有界/精简优化，但这些补全仍在首排数据返回之前。隐藏库时 `:1766` 的每 3 库 Future.wait batch 还有批次屏障。
- Emby Continue：`browse.dart:244` Resume window limit 300；不是给首页返回 300 张卡，而是服务器混合已开始/下一集语义的有界窗口，首页再切成 20+1 probe (`discover_provider.dart:81`)。不能只改 count=20 宣称等价提速；需验证隐藏、排序、下一集完整性。
- 跨副本去重：`data_aggregation_service.dart:443 _deduplicateContinueWatching` 仅有重复 title bucket 才进；`:469` await identity lookups；`:575` 使用 `fetchExternalIds(targetId)`，每 target 一次合并。不能称每张卡都请求完整详情；但命中重复标题时确有额外请求门。
- Plex 装饰 logo：`plex_client.dart:1689 _backfillMissingLogos` 对缺失 clearLogo 的 episode/season owner 发一次合并 `/library/metadata/{comma-separated-owner-ids}`，`:1705` await 完才返回。不是每条卡 N 请求；这一请求没有首页 retry deadline 参数。可优先考虑数据先显示、logo 后补（保留同 profile epoch/行身份 guards）。
- Plex global fetch 包装 `:4447` 接受 includePlaybackHubs 但未转发该参数，global response 是否含继续观看取决于 provider key；不能断言绝不重叠。需记录 key/response 类型而不是 token/实际条目。

## 图片与缓存不是同一类门

`lib/widgets/optimized_media_image.dart:300 _buildCachedImage` 用实际 slot×artworkPixelRatio 形成服务器尺寸 URL、受限 decode provider。内存图同步命中立即绘制（`:583`），其他图显示 placeholder 并异步 fade；没有把图片 Future join 到 HomeStartupGate。`lib/utils/media_image_helper.dart:335 getMemCacheDimensions` 采用 bucket，poster 上限基线 720×1080、thumb 960×540、art 1920×1080，full tier 随 displayBudgetFactor 缩放，reduced art 用更小预算，不是所有手机永远请求这些上限。

`lib/services/image_cache_service.dart:20` artwork 全局并发 reduced=3/full=6，`:18` 共享 HTTP client/连接池；`:51` 磁盘 stalePeriod 14d、max 3000 objects；`:89 getImageFile` 绕过二次磁盘 PNG resize；`:140 send` 排队许可，响应/流无进展 30 秒断开。`lib/services/jellyfin_client/parts/images_downloads.dart:8 thumbnailUrl` 传 maxWidth/maxHeight，外部 URL 原样使用（`:25`）。可见内容 ready 与首张/首屏所有海报 ready 必须分别测量。缓存键去凭证策略不在报告中暴露真实 URL。

## 超时、重试和取消

- `lib/utils/media_server_timeouts.dart:8/14/17` 基础 connect 10s / response headers 30s / body 120s；`:29` home hub 总 15s、`:36` library hub 总20s、`:60` library list 单服 deadline15s。以上不是启动一定等待的时长。
- `lib/utils/media_server_retry.dart:42 retryTransientMediaServerCall<T>` 默认 `maxConnectionRetries=2`，仅 connectionError 重试；timeout 不重试；外层统一 deadline，超时 abort 当前请求。首页 hub retry 禁 endpoint failover，避免把慢查询当线路失败；不能把其 budget 与一般 receive timeout相加。
- `lib/services/data_aggregation_service.dart:312 _withinServerDeadline` 区分取消/失败并限制单服；Discover 请求代际与 snapshot scope 检查避免切号迟到污染。候选渐进化必须保留这些 guards。

## 与 VidHub 本会话运行证据如何对照

由主会话提供本次 VidHub 运行摘要（本文件未独立复采）：HomeStartupPerf `loading_hidden=133ms` / `all_enabled_sections_ready=135ms` 对应 itemCount 全0，不能作为资源完成时间；getMediaViews 约1120ms，随后 getResumeItems约272ms；5个 getLatestItems 方法在3ms内发起，五个成功集中返回，距 home_load_started 最后成功约2168ms。它支持“本次 VidHub 快速调度五个 Latest 方法”，尚不等同五条 HTTP 在同一时刻出站；不能与不同服务器/缓存/设备条件下的 Velo 静态并发3推算加速倍率。

## 候选改进排序（需下一任务实施及测量）

1. **单服按库发布 Latest**：保留并发3先移除全库展示屏障；首库成功就发布，余库补齐、失败不清旧行。预期影响最贴合“资源开始出现”；风险为排序跳动/跨代迟到/完整性语义，不必先放大全局并发。
2. **继续观看先显示、装饰后补**：Plex clearLogo 低风险独立补齐；Jellyfin LastPlayed 与跨副本 identity 影响排序/去重，需采用稳定占位/有界二阶段 reconciliation，风险较高。不能牺牲观看进度、隐藏条目和去重正确性。
3. **Views 共享已完成结果**：明确作用域与短生命周期/主动失效，统一隐藏库分支走 single-flight；匹配服务端库新增刷新和账号切换。先验证错开重复 Views 是否实际发生。
4. **授权身份下的离线快照首显**：目前 online 才读；可探索 durable profile+connection+auth generation snapshot，后台验证后替换。此项有账号权限风险，不能直接删 online/authorization 条件或混用另一 profile cache。
5. **提高 Latest 并发是可选实验**：配置3/5/6做同机对照，观察服务端负载、TTFB、首行与全部行；VidHub 5路方法发起不足以证明6一定更快。
6. **首屏图片优先级**：现有图片有共享队列和3/6 cap，可测首屏图是否排在折叠区图后，再加可见区优先/取消。当前代码不支持“图片 await 阻塞首页”的判断。

## 动态验收清单（此文件未执行）

- 同机同网络同服务器同账号/隐藏库/排序配置；区分进程冷启动+warm磁盘、清缓存冷启动、后台恢复；每类至少5次，用 median/p90，不比较截图状态栏网速。
- 时钟：process start、Dart HomeStartupTiming.start (`main.dart:147`)、identity-ready、first-online、snapshot-hit/miss、Views start/end、Resume/NextUp/Latest method+HTTP start/end、首非空模型、首非空布局、第一张图、首屏图齐；明确 loading_hidden 和 empty ready 不算资源就绪。
- 使用已有 `lib/services/home_startup_timing.dart:15 markContentVisible(fromSnapshot:...)` 的 `Startup home content visible` 记录，但它仅首个可显示模型之后一帧，不是 OS process 起点或图片完成；补充外部 screen timing 才可闭环。
- 首先测一台5库 J/E：人为延迟第1或第5个 Latest，观察 Velo 当前整服门；对照三并发滑窗发起顺序、所有返回后一次发布。隔离模拟器/测试服务注入，不修改真实媒体条目。
- 测隐藏库开/关，Views并发与错开；测多个NextUp无LastPlayed、同名多副本；Plex 缺logo；Emby HideFromResume 和300窗口；多服一快一慢；切profile/PIN失效/注销/离线快照必须不串账号。
- 未来代码修改需 flutter analyze、scripts/run_tests.sh 和相关 startup/provider/aggregation tests；当前源码审阅未跑任何测试，不能标为性能通过。

## 交接签名、权限与未决项

接口摘录：`Future<List<MediaItem>> fetchContinueWatching({int? count = 20, Set<String> excludedLibraryIds = const {}})`；`Future<List<MediaLibrary>> fetchLibraries()`；`Future<List<MediaHub>> fetchLibraryHubs(String libraryId, {required String libraryName, int limit = defaultHubPreviewLimit, bool includePlaybackHubs = true, MediaKind? libraryKind, HubFetchDiagnostics? diagnostics})`；`Future<HomeSnapshot?> read(HomeSnapshotScope scope, {required bool Function() isCurrent})`。身份字段/权限门：`isStartupIdentityReady`、`committedIdentityGeneration`、`authenticationSessionId`、`cacheServerId`、`hiddenLibraryKeys`；J/E健康刷新 `Policy.IsAdministrator`。本任务不修改 schema/权限字典，缓存依赖现有 apiCache 的 `cacheKey/data/cachedAt`。

待确认：Velo安装包是否等于当前 HEAD；VidHub账号与 Velo 的资源/库数是否同配置；当前 snapshot 命中率；Plex provider hub key 及 logo缺失率；真实 request headers/body级时序及缓存层命中来源。没有动态测量支持具体倍数、最慢函数或服务器归因。与旧材料冲突时采用上述当前源码，尤其已存在 parallel/progressive/bounded loading/snapshot 的事实。
