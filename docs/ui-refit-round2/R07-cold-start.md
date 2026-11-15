# R07 冷启动二期 任务卡

- 基线提交:`8885b39`(静态读码,未运行;本环境无 flutter,所有耗时数字均未测量)
- 目标:缩短"进程启动 → 首页首个内容可见"的时间,并让首页缓存快照不再依赖在线 client;先测基线,再改,改后在同一台真机上对比。
- 优先级:R7-8 基线测量最高(先做);R7-3 高;R7-1、R7-2、R7-4 中;R7-5 低;R7-6、R7-7 不动。
- 规模:大
- 前置依赖:R7-8 的"改前"测量必须在任何 R7 代码提交之前完成(改造前版本 = 本卡基线 `8885b39`;清单里提到的 `fe12755` 是第一轮合并点,也可作为对照,二选一并在表中写明)。
- 不在范围:2 秒内容预算与 24 小时快照寿命做成设置项(保持 `TODO(VELO-P4-01)`、`TODO(VELO-P4-02)` 注入参数,不做设置);`AppDatabase.open` 迁移放后台 isolate(R7-7,无测量数据前不动);首页头图改版(R1)。

## 与清单/材料不一致及新发现(已核实)

1. R7-1:清单说"`connectionRegistry.list` 可并行"。**不成立**:`list()`(`main.dart:2198`)读的是 `bootstrap.run()`(`:2157`)迁移写入、`pruneUnreferencedJellyfinConnections()`(`:2163`)裁剪之后的连接表,必须排在这两步之后。只有 `ConnectivityProbe.check()`(`:2182`)与迁移/prune/`reloadFromStorage` 无数据依赖,可提前发起。
2. `reloadFromStorage` 在 `SetupScreen` 里被调用两次:`:2171`(迁移后,try 块内)与 `:2259`(绑定前)。第二次是否冗余**待核对**(第一次在 try 内,迁移抛错时被跳过,第二次兜底;不要直接删,先看 `ActiveProfileProvider.reloadFromStorage` 是否幂等且便宜)。
3. R7-2:`applyImageCacheBudget` 在 `_startNonessentialInitialization` 里**已有第二次调用**(`main.dart:1070`,注释说明首次可能早于引擎 metrics)。门控里的 `:991` 那次是同步、几乎零成本的调用,"后移"收益很小,列为可选的最后一个提交。
4. R7-2:`AppDatabase.open`(`lib/database/app_database.dart:85`)读的是 `BaseSharedPreferencesService.sharedCache()`(`:109`),不依赖 `StorageService.getInstance()`;`StorageService.onInit` 只做日志脱敏登记与 `user_plex-home-*` 键迁移(`lib/services/storage_service.dart:46-54`),与数据库恢复读取的键(`active_app_profile_id`、`profile_migration_v1_done`、`credential_vault_key_v1`,`app_database.dart:138-140`)不相交。因此 storage 与 database 可并行,但失败时要关闭已打开的数据库(见 R7-2)。
5. R7-3:"全离线冷启动拿不到缓存"的真实成因不只是 key 依赖在线 client:`SetupScreen` 在 `awaitStartupContentReady` 之后若 `shouldEnterOfflineModeAfterStartupBind`(`main.dart:2303-2308`)为真(绑定失败且无在线服务器)会直接进入**离线模式(下载页)**,根本不会挂载首页,`DiscoverProvider` 不存在。所以 R7-3 的受益场景是"弱网/服务器连接超过 2 秒"(首页壳 + 骨架先出,`HomeStartupGate` 预算到期后进入),不是"完全离线"。完全离线时是否改为显示缓存首页是产品决策,见待确认 C-R7-1。
6. R7-4:`refreshMetadataFromCache` 共有 **5 个调用点**,清单只提到 `main.dart:2324`:`download_provider.dart:233`(每次切换 profile 的 `_reloadProfileScopedStateForActiveProfile`)、`main.dart:1599`(`_autoDeleteAndSync`)、`main.dart:2324`(首页后 postFrame)、`screens/main_screen.dart:736`(`_primeOnlineServices`,服务器上线后)、`main_screen.dart:1869`(切换 profile 后)。另外 `fetchOnMiss: true` 只对"缓存里没有元数据"的下载项发请求(`download_provider.dart:567-577`),已有缓存的项不联网,影响面小于清单描述。
7. R7-8:`scripts/perf/launch.sh` 使用 `PKG=com.edde746.plezy` 且 adb 路径写死 macOS,**对 Velo 不可直接用**;Velo 的 `applicationId` 是 `com.wines.velo`(`android/app/build.gradle:260`),Activity 类仍是 `com.edde746.plezy.MainActivity`(`android/app/src/main/kotlin/com/edde746/plezy/MainActivity.kt`),启动组件为 `com.wines.velo/com.edde746.plezy.MainActivity`。
8. `HomeStartupTiming.start()` 在 Dart `main()` 开头(`main.dart:147`),**不含**引擎初始化与原生 `onCreate` 阶段;要含全程需叠加 `am start -W` 的 `TotalTime`(见 R7-8)。
9. 另有现成的分段日志:`AndroidExitDiagnostics.markStartupPhase` 输出 `Startup phase: phase=<id> elapsedMs=<n>`(info 级,release 可见,`lib/utils/android_exit_diagnostics.dart:9-19、85-105`),`kProfileMode` 下 `_initializeStartup` 另输出 `Startup phase <name>: Nms (total Nms)`(`main.dart:928-933`)。

## 当前串行启动链与依赖

门控阶段(`_initializeApplication` `main.dart:264-312` → `_initializeStartup` `:925-1003`),**全部串行 await**:

```
main():147 HomeStartupTiming.start()
 └ runApp(StartupBootstrap) ── 先出一帧加载页(并行:_resolveStartupTheme :290-300)
    └ _initializeApplication
       1 SettingsService.getInstance            (:265)  ← 后面所有步骤都读 settings
       2 Sentry.init(可选, 最长10s)             (:280)
       3 StartupDiagnosticsStore.holdForFlush   (:307, 不 await)
       └ _initializeStartup(settings)
          0 CertificateTrust.loadUserAuthorities()  (:939, 仅 Android, 已提前发起, 不 await)
          4 locale: LocaleSettings.setLocale        (:943-946)   依赖: settings
          5 windowManager(仅桌面)                   (:954-957)   依赖: 无
          6 deviceCapabilities (Tv/Perf/Decode 三者已 .wait) (:963-969) 依赖: settings
          7 certificateTrust await                  (:971-973)   依赖: 步骤0
          8 StorageService.getInstance              (:975)       依赖: SharedPreferences(已由1初始化)
          9 AppDatabase.open + 下载恢复             (:979-989)   依赖: SharedPreferences 缓存; 与8无数据依赖
         10 applyImageCacheBudget                   (:991)       依赖: 6(isReduced/TV 判定)
```

`SetupScreen._loadSavedCredentials`(首帧后,`main.dart:2109-2330`)串行:

```
A ConnectionBootstrap.run (迁移旧 prefs → ConnectionRegistry/ProfileRegistry)   :2157   依赖: 8、9
B pruneUnreferencedJellyfinConnections                                           :2163   依赖: A 的结果
C activeProfiles.reloadFromStorage                                               :2171   依赖: A(迁移出的 profile)
D ConnectivityProbe.check (最长 3s)                                               :2182   依赖: 无    ← 可前移
E connectionRegistry.list                                                        :2198   依赖: A、B
F activeProfile.reloadFromStorage (第二次)                                       :2259   依赖: A、C
G binder.start(allowInitialPinPrompt: hasNetwork)                                :2276   依赖: D(hasNetwork)、F
H awaitStartupContentReady (身份/PIN 不限时, 之后 2s 连接预算)                   :2297   依赖: G
I 导航 ProfileSessionScreen → postFrame refreshMetadataFromCache                :2316-2328
```

结论:D 是唯一可与 A-C 并行的步骤(最长 3 秒的纯等待);E 必须在 A、B 之后;G 需要 D 的结果,所以 D 必须在 G 之前完成,但不必在 A 之前开始。

## 涉及文件表

| 文件 | 行号 | 现状 | 动作 |
|---|---|---|---|
| lib/main.dart | 925-1003 | 门控阶段串行 | 改(R7-2) |
| lib/main.dart | 2157-2198、2259 | `SetupScreen` 串行;`ConnectivityProbe.check` 排在迁移后 | 改(R7-1) |
| lib/main.dart | 1263-1310、2324 | `awaitStartupContentReady`(2s 预算 `TODO(VELO-P4-01)`);postFrame 刷新元数据 | R7-4 改调用参数;预算不动 |
| lib/main.dart | 1599 | `_autoDeleteAndSync` 内 `refreshMetadataFromCache()` | R7-4 评估 |
| lib/screens/main_screen.dart | 736、1869 | 服务器上线/切 profile 后 `refreshMetadataFromCache()` | R7-4 改 |
| lib/providers/download_provider.dart | 227-239、2330-2386、548-588 | `refreshMetadataFromCache` 无参数,内部 `fetchOnMiss: true` 逐项串行 await | 改(R7-4) |
| lib/services/home_snapshot_store.dart | 25-60、64-113、115-155 | key 与 scope 由在线 client 捕获;`read` 逐服务器 try/catch 跳过损坏行 | 改/新增(R7-3、R7-5) |
| lib/services/api_cache.dart | 121-139、170-172 | 只有 `get/getIfFresh/put/deleteForServer`,**没有按单 key 删除** | 新增 `delete(ServerId, endpoint)`(R7-5) |
| lib/providers/discover_provider.dart | 149-165、167-201、453 | `_restoreHomeSnapshot` 要求 `_homeClients()` 非空;在 `_loadOnce` 开头调用 | 改(R7-3) |
| lib/navigation/profile_session_screen.dart | 245-250、137 | `DiscoverProvider` 的 `isProfileBinding = binding && !identityReady`;切 profile 时 `ApiCache.clearRegisteredVolatile()` | 只读,R7-3 依赖其语义 |
| lib/widgets/home_startup_gate.dart | 34-98 | 预算 `initialContentBudget`(`TODO(VELO-P4-01)`);`markContentVisible` 在 `:94` | 不改 |
| lib/services/home_startup_timing.dart | 全文 | `start()`/`markContentVisible(fromSnapshot)`,输出 `Startup home content visible` + `{elapsedMs, source}` | 不改(测量用) |
| lib/profiles/active_profile_provider.dart | 106-143 | `isStartupIdentityReady`/`awaitStartupIdentityReady` | 只读 |
| scripts/perf/launch.sh | 7-9 | 包名/adb 路径对 Velo 不适用 | 不改,文档说明;如需可另提 |
| test/startup_bootstrap_test.dart | 535-680 | `openAppDatabaseWithDownloadRecovery` 三个用例 | 保持通过 |
| test/screens/startup_content_ready_test.dart | 64、91 | `awaitStartupContentReady` 用例 | 保持通过 |
| test/services/home_snapshot_store_test.dart | 56-120 | 5 个用例(隔离、失效、过期) | 保持通过并扩充 |
| test/providers/discover_startup_test.dart | 138-259 | 快照/绑定/delta 用例 | 保持通过并扩充 |
| test/providers/download_provider_test.dart | 2092-3828 | 约 20 处 `refreshMetadataFromCache()` 用例 | 默认参数保持旧行为,保持通过 |

## 逐步修改说明

### R7-8 基线测量(最先做,不改代码)

对象:同一台真机、同一账号、同一网络;版本 A = 改造前(`8885b39` 构建),版本 B = 改造后。**不得用模拟器**(`am start` 2676ms 不是冷启动证据)。

操作步骤(Android,`adb` 已连接设备;`PKG=com.wines.velo`,`ACT=com.edde746.plezy.MainActivity`):

1. 安装对应版本的 release 或 profile 包(同一构建类型,A、B 一致);首次启动并登录,进入首页等 30 秒让快照落盘,之后**不清数据**。
2. 每次测量前:`adb shell input keyevent 224`(亮屏)、`adb shell am force-stop $PKG`、`adb logcat -c`,等待 3 秒。
3. 启动并取系统侧耗时:`adb shell am start -W -n $PKG/$ACT`,记录 `TotalTime`、`WaitTime`(含引擎与原生启动,Dart 日志不含这段)。
4. 等首页内容出现(约 15 秒),取 Dart 侧日志:
   `adb logcat -d | grep -E "Startup home content visible|Startup phase:"`
   记录:`Startup home content visible` 行里的 `elapsedMs` 与 `source`(`authorized-cache` 表示来自快照,`network` 表示来自网络),以及 `Startup phase: phase=first_frame/database_ready/credentials_loaded/binding_started/binding_settled/main_screen` 各 `elapsedMs`。
5. 重复 5 次,每次 force-stop;表格每个版本 5 个原始值,取中位数。
6. 另测一组"弱网/飞行模式"冷启动 5 次(飞行模式:`adb shell cmd connectivity airplane-mode enable`,测完 `disable`;弱网可用路由器限速或把服务器地址指向不可达地址以模拟连接超时),同样记录 `source` 与是否进入离线模式。
7. 结果写入表格:版本 × 5 次原始值 × 中位数 × `source` 分布。用 `profile` 构建时可额外看 `Startup phase <name>: Nms` 分段(`kProfileMode` 才输出)。
8. 判据:改造后中位数不劣于改造前;弱网组 `source=authorized-cache` 的比例上升或 `elapsedMs` 下降。每个 R7 改动提交后至少复测一轮(5 次)以便归因。

桌面/iOS 无 adb 时:用同样日志关键字(桌面从控制台或应用内日志页导出,`MemoryLogOutput`)。

### R7-1 `ConnectivityProbe.check` 提前发起(中)

- 现状:`:2157` → `:2163` → `:2171` → `:2182` → `:2198` 串行,探测最长 3 秒才开始计时。
- 改成:在 `_loadSavedCredentials` 的 `shouldBypassSetupForDatabaseRecovery` 判断之后、`_setStatus(checkingNetwork)` 处,先 `final connectivity = ConnectivityProbe.check();`(Future,不 await),保持 Sentry 面包屑文案;原 `:2182` 处改为 `final hasNetwork = !(await connectivity).contains(ConnectivityResult.none);`。
- 保持:`list()` 仍在 A、B 之后(依赖);`hasNetwork` 仍用于 `binder.start(allowInitialPinPrompt: hasNetwork)`(`:2276`)与 `awaitStartupContentReady(hasNetwork: ...)`(`:2297`),授权 gate 语义不变;迁移失败的 catch(`:2172-2174`)行为不变;`ConnectivityProbe.check` 内部已 `runZonedGuarded` 且永不抛(返回 `[other]`),提前发起不会产生未处理异常。
- 不做:不把 `list()` 与迁移并行;不删第二次 `reloadFromStorage`(待核对)。

### R7-2 门控阶段并行(中)

- 现状:locale(`:943`)→ windowManager(`:954`)→ deviceCapabilities(`:963`)→ certificateTrust(`:971`)→ storage(`:975`)→ database(`:979`)→ imageCache(`:991`)。
- 改成(分两个提交,先 R7-2a 再 R7-2b):
  - R7-2a:storage 与 database 并行。数据库 future 先启动:`final dbFuture = _gatePhase(StartupPhase.database, ...)`,`final storageFuture = _gatePhase(StartupPhase.storage, StorageService.getInstance)`;用 `(storageFuture, dbFuture).wait`(与 `:964-968` 现有 `(a,b,c).wait` 同风格,保留各自 `_gatePhase` 以便按阶段归因,见 `#1732` 注释 `:219-225`)。**失败处理**:任一失败时若数据库已成功打开必须 `close()`:捕获后 `await dbFuture.then((r) => r.database.close(), onError: (_) {})` 再 rethrow;`openedDatabase` 的赋值要覆盖并行路径,保证 `catch (_) { await openedDatabase?.close(); rethrow; }`(`:997-1000`)不漏关。`AndroidExitDiagnostics.markStartupPhase(databaseOpenStarted/databaseReady)`(`:978`、`:990`)位置保持语义:started 在发起处,ready 在 db future 完成回调里。
  - R7-2b:locale、windowManager(桌面)、deviceCapabilities 三者并行(都只依赖已就绪的 `settings`),再进入 R7-2a 的并行块;`deviceCapabilities` 必须在 `imageCache` 之前完成(`applyImageCacheBudget` 读 `isReduced`/`isTV`)。证书信任 `await userAuthorities` 可与上述并行,最迟在门控结束前完成(注释 `:936-938` 要求"任何 client 创建之前")。每个步骤仍用各自 `_optionalGatePhase`/`_gatePhase` 包装,保留 10 秒超时与阶段名。
  - 可选 R7-2c:删除 `:991` 的同步 `applyImageCacheBudget` 阶段(`:1070` 已有第二次)。需确认首帧到 `onCommitted` 之间用 Flutter 默认图片缓存(1000 张/100MB)无内存风险;低端 TV 有风险则不做。
- 不能并行的:`SettingsService.getInstance`(其余全依赖);Sentry(可选,独立,已在其后);`deviceCapabilities` → `imageCache`;数据库打开 → 任何 `AppDatabase` 使用者。
- 注意:数据库在后台 isolate 运行,storage/设备能力走平台线程,理论上能真并行;收益量级**待 R7-8 数据**确认,没有收益则回滚该提交。

### R7-3 首页快照不依赖在线 client(高)

- 现状:
  - `HomeSnapshotScope.capture`(`home_snapshot_store.dart:32-47`)只遍历传入的在线 `clients`,key = `velo/home-snapshot/v1/` + `sha256(jsonEncode([1, profileId, sorted("serverId:scope"), sorted(hiddenKeys), useGlobalHubs]))`。scope 由 `resolveActiveClientScopeId(serverId, client.cacheServerId)` 得到(Plex 为 `…/~plex-profile/<profileId>`,Jellyfin/Emby 为 `machineId/userId`),读行时还要 `client.backend` 选 `ApiCache`、`client.authenticationSessionId` 做授权代际校验。**key 含在线服务器集合**:只有 {A,B} 同时在线才读得到 {A,B} 写下的快照。
  - `_restoreHomeSnapshot`(`discover_provider.dart:167-201`)开头 `final clients = _homeClients(); if (clients.isEmpty) return;`,且在 `_loadOnce` 开头(`:453`)执行,所以必须等首台服务器在线。
- 改成(分层,各层可独立提交):
  1. **清单(manifest)持久化**:新增 `HomeSnapshotManifest`(类名可调):`{version:1, profileId, servers:[{serverId, backend(name), scope, serverName}], hiddenLibraryKeys, useGlobalHubs, endpointKey}`。`write(...)` 成功后同时写 manifest。存储位置:同一张 `api_cache` 表的一行(经 `ApiCache.forBackend(null)`,命名空间用保留 `ServerId('velo-home-manifest')`,endpoint `v1/<profileId>`),这样 `ApiCache.clearRegisteredVolatile()`(切 profile/退出登录/同步导入,`profile_session_screen.dart:137`、`main_screen.dart:1854`、`profile_teardown.dart:395`)会一并清掉,不会比快照寿命更长。`forBackend(null)` 回退到 Plex 实例,已在 `main.dart:1389-1390` 注册两个后端**待核对**生产路径一定先注册。
  2. **离线读取入口**:`HomeSnapshotStore.readFromManifest(manifest, {required bool Function() isCurrent})`:按 manifest 的 `servers` 逐个 `ApiCache.forBackend(backend).getIfFresh(ServerId(scope), endpointKey, maxAge: maxAge)`,解析逻辑复用现有 `read`(抽成私有方法);不要求 client 存在,**不做**身份认证代际(`authenticationSessionId`)比较——改由下一条的授权门代替。
  3. **授权门(隔离关键)**:仅当同时满足才读:`profileId == 当前 activeId`、`profile.isStartupIdentityReady`(PIN/身份已通过,即 `DiscoverProvider.isProfileBinding()==false`,`profile_session_screen.dart:249`)、manifest 内每个 server 仍在当前 profile 的连接集合里(来源:`MultiServerManager.serverIds` 在 binder 启动后何时填充**待核对**;不行则用 `ConnectionRegistry.list()` + `ProfileConnectionRegistry` 过滤)。任一不满足整体放弃,不展示。快照行内容已去 token(`_displayJson`,`:158-190`),仍不得写入凭据。
  4. **`DiscoverProvider._restoreHomeSnapshot`** 改为:`clients.isNotEmpty` 走原路径(保持 `scope.isCurrent`/auth 校验);`clients.isEmpty` 时走 manifest 路径。读到后 `_applyOnDeck/_replaceHubs`、`_restoredHomeSnapshot = true`,新增只读 getter `restoredFromStaleManifest`(区别于在线客户端读取)。**不阻塞**后续刷新:`_loadOnce` 随后的网络路径不变;网络结果到来后按现有逻辑替换;`hasDisplayableContent` 已有的保护(`:186`)保持。`_snapshotRestoreAttempted` 需改为区分两条路径各尝试一次(否则在线后无法再走校验路径刷新标记)。
  5. 标注"缓存,可能过期":先只做 provider 状态,**不加可见文案**;是否展示 UI 提示见待确认 C-R7-2(若要展示,新增 i18n key,见下表)。
- 保持不变:key 的构成(profileId/scope/隐藏库/useGlobalHubs)、Plex profile scope 校验(`capture` `:41-44`)、`authenticationSessionId` 校验(在线路径)、登出清缓存、写入需 `fullyLoaded`、24 小时寿命(`maxAge`,`TODO(VELO-P4-02)`)。
- 局限(必须写进提交说明):首页只有在 `SetupScreen` 导航到 `ProfileSessionScreen` 之后才存在(见"不一致"第 5 条),本项主要改善"服务器连接 >2 秒"场景;完全离线仍进离线模式。

### R7-4 `refreshMetadataFromCache` 启动期不联网(中)

- 现状:`download_provider.dart:2330` 无参数,`:2358` 固定 `_hydrateDownloadMetadata(..., fetchOnMiss: true)`;对缓存缺失项逐个串行 `fetchAndPinMetadata`(`:567-577`),与首页首批请求争带宽。
- 改成:签名改为 `Future<void> refreshMetadataFromCache({bool fetchOnMiss = true})`(默认保持旧行为,现有 ~20 个测试不改);`:2358` 传入该参数。新增 `Future<void> fillMissingMetadataFromNetwork()`(内部即 `refreshMetadataFromCache(fetchOnMiss: true)`,带"进行中则复用"的 `Future? _fillInFlight`,避免重复)。
- 调用点调整:
  - 启动期改为 `fetchOnMiss: false`:`download_provider.dart:233`(profile 重载,含冷启动)、`main.dart:2324`(首页后 postFrame)、`main_screen.dart:736`(服务器上线后)。
  - 补齐时机:进入下载页(`downloads_screen.dart` 首次 build/initState 后)调用 `fillMissingMetadataFromNetwork()`;以及首页内容可见后延迟 `kDownloadMetadataFillDelay`(默认 10 秒,`TODO(VELO-R7-01)`)一次(用 `Timer`,`dispose`/profile 变更时取消,沿用 `isStale()` 代际保护)。
  - 保持旧行为:`main.dart:1599` `_autoDeleteAndSync`(同步/自动删除需要完整元数据)与 `main_screen.dart:1869`(用户主动切 profile)暂保持 `fetchOnMiss: true`,待 R7-8 数据决定是否也推迟。
- 验证点:`_loadDownloadCollections`、`_applyOfflineWatchOverlay` 仍执行;`updatedCount > 0` 才通知的逻辑不变。

### R7-5 损坏缓存行读一次后删除(低)

- 现状:`HomeSnapshotStore.read` 每台服务器 try/catch(`:93-95`)只 `appLogger.d` 跳过,行留在库里,每次启动重复解析失败直到被新写覆盖。注意解析失败有两类:`ApiCache.getIfFresh` 内 `jsonDecode`(`api_cache.dart:138`,`tryIsolateRun`)抛错,与 `MediaItem.fromJson`/`MediaHub` 构造抛错(`_items`、`:73-88`)。
- 改成:`ApiCache` 新增 `Future<void> delete(ServerId serverId, String endpoint)`(`delete ... where cacheKey.equals('$serverId:$endpoint') & pinned=false`;pinned 行不得删);`read` 的 catch 内对该 server 的快照 key 调用 `delete`(再 try/catch 吞掉删除失败)。`version != 1` 的行也一并删除(旧版本格式)。过期行(超过 `maxAge`)是否删除:**不做**(留给 `clearVolatile`)。
- 注意不要因 `!isCurrent()` 提前返回的情形误删好行。

### R7-6、R7-7 不动

- R7-6:2 秒预算(`main.dart:1263-1267` 的 `connectionBudget`、`home_startup_gate.dart:25-27`)与 24 小时快照(`home_snapshot_store.dart:62-64`)保持注入参数与 TODO,等真机数据。
- R7-7:`AppDatabase.open` 迁移放后台——无测量数据前不动;若 R7-2a 之后 `database` 阶段仍是门控最长阶段,在提交说明里写评估结论。

## i18n key 与设置项/常量

| 名称 | 默认值 | 位置 | TODO |
|---|---|---|---|
| `kDownloadMetadataFillDelay` | 10 秒 | download_provider.dart 或 main_screen.dart 常量,可注入 | TODO(VELO-R7-01) |
| `HomeSnapshotStore.maxAge`(沿用) | 24 小时 | home_snapshot_store.dart:62 | TODO(VELO-P4-02) 已有 |
| `connectionBudget`(沿用) | 2 秒 | main.dart:1267 | TODO(VELO-P4-01) 已有 |
| i18n key(仅当 C-R7-2 决定展示提示) | 建议 `discover.cachedContentHint`("缓存内容,可能已过期"/en/其余语言按 slang 流程补全) | lib/i18n/*.i18n.json | 默认不新增 |
| 设置项 | 无(2s 预算与 24h 寿命明确不做设置) | | |

## TV 焦点、主题、形态要求

- TV:首页快照渲染后焦点行为与在线路径一致(首个可聚焦项获得初始焦点,不因快照→网络替换而丢焦点;现有 `discover_startup_test.dart:138` 的"先缓存、再刷新一次"用例保持);启动期不弹新的对话框。
- 若 C-R7-2 决定展示提示:提示不得可聚焦,不抢焦点。
- 三主题:快照路径渲染与在线路径使用同一组件,无新增颜色;如加提示文本用 `tokens(context).textMuted`。
- 手机/平板/桌面/TV:启动并行(R7-2)对桌面含 `windowManager`、对 Android 含证书信任,各形态逐一冷启动无崩溃、无空白闪屏时间变长;弱网场景各形态分别验证。

## 测试要求

保持通过:`test/startup_bootstrap_test.dart`(`:535-680` 三个数据库恢复用例)、`test/screens/startup_content_ready_test.dart`、`test/services/home_snapshot_store_test.dart`(5 个)、`test/providers/discover_startup_test.dart`、`test/providers/download_provider_test.dart`(默认参数保持旧行为)。

新增:
- `test/startup_parallel_gate_test.dart`:把并行块抽成可注入函数后测试——`storage 失败时已打开的数据库被关闭`、`database 失败时 storage 阶段名不被吞(StartupPhaseException.phase == database)`、`deviceCapabilities 超时不阻塞门控(沿用 _optionalGatePhase 行为)`。
- `test/screens/setup_connectivity_order_test.dart`(或并入现有 setup 测试):`ConnectivityProbe.check 在 bootstrap.run 完成前已被调用`、`list() 在 prune 之后调用`、`hasNetwork 仍传入 binder.start`。
- `test/services/home_snapshot_store_test.dart` 增加:`manifest 往返`、`无 client 时 readFromManifest 返回快照`、`换 profile 后旧 manifest 不可读(profileId 不符)`、`清除 volatile 后 manifest 同时消失`、`manifest 中服务器已不在当前连接集合则放弃`、`损坏行读一次后被删除且 pinned 行不被删除`、`version != 1 的行被删除`。
- `test/providers/discover_startup_test.dart` 增加:`无任何在线 client 且身份已就绪时展示快照,restoredFromStaleManifest 为真`、`绑定未就绪(isProfileBinding)时不读`、`快照展示后服务器上线,网络结果替换且不闪空`、`切换 profile/登出不串数据`。
- `test/providers/download_provider_test.dart` 增加:`fetchOnMiss:false 时对缓存缺失项不调用 fetchAndPinMetadata`、`fillMissingMetadataFromNetwork 补齐缺失项`、`fill 进行中重复调用只执行一次`、`profile 变更后延迟补齐被取消`。
- `test/services/api_cache_test.dart`(若不存在则新建):`delete 只删指定 key、不删 pinned`。

## 验收清单

- [ ] `flutter analyze` 无新增告警
- [ ] `scripts/run_tests.sh` 通过,并单独跑上面"保持通过"的文件
- [ ] R7-8 表格已填:改前/改后各 5 次冷启动原始值 + 中位数(含 `source` 与 `am start -W TotalTime`),改后中位数不劣于改前
- [ ] 弱网/飞行模式组 5 次:记录 `source`、是否进离线模式;弱网(服务器连接 >2s)场景 `source=authorized-cache` 且 `elapsedMs` 低于改前中位数
- [ ] 日志验证:首页内容可见后的前 5 秒内,抓包/日志中没有下载元数据补齐请求(`fetchAndPinMetadata`);进入下载页后缺失元数据被补齐
- [ ] 手动:一台服务器离线时首页不被卡住;缓存与刷新结果不一致时平滑替换(无整页闪烁)
- [ ] 手动:登出、切换 profile、删除服务器后冷启动,首页不出现上一个用户/服务器的内容
- [ ] 手动:数据库打开失败(模拟存储已满)路径仍走下载恢复,且无数据库句柄泄漏
- [ ] 三主题、手机/平板/桌面/TV 各冷启动一次无异常

## 提交拆分

1. `docs(冷启动): 记录改造前冷启动基线测量表`(不含代码,仅数据与方法)
2. `perf(启动): 联网探测与迁移并行发起`
3. `perf(启动): 存储与数据库并行初始化`
4. `perf(启动): 语言、设备能力与窗口初始化并行`
5. `perf(启动): 移除门控内重复的图片缓存预算调用`(可选,有风险则放弃)
6. `feat(首页): 持久化首页快照清单`
7. `feat(首页): 无在线服务器时按清单读取首页快照`
8. `test(首页): 快照清单隔离与离线读取用例`
9. `perf(下载): 启动期元数据刷新只读缓存`
10. `perf(下载): 下载页与空闲时补齐缺失元数据`
11. `fix(缓存): 损坏的首页快照行读取后删除`
12. `docs(冷启动): 记录改造后冷启动对比与结论`

## 风险与待确认

- C-R7-1(产品):全部服务器离线时,是否仍进离线模式(现状),还是展示缓存首页?默认保持离线模式。
- C-R7-2(产品):快照展示时是否给用户可见的"缓存,可能过期"提示?默认只做状态不展示。
- 待核对:第二次 `reloadFromStorage`(`main.dart:2259`)是否可去;`MultiServerManager.serverIds` 的填充时机;`ApiCache.forBackend(null)` 生产注册顺序;`ConnectivityProbe` 提前发起后 Sentry 面包屑的顺序是否有测试依赖。
- 风险:并行初始化的失败归因与资源释放(R7-2a);manifest 若写在会被误清的位置会导致冷启动无快照(只影响速度,不影响正确性);manifest 若绕过授权门会造成跨用户泄露,**这是本包最高风险**,必须有"换 profile/登出不串数据"测试。
- 禁止事项:不直接改生成的 Dart 文件;不删 Plex/Jellyfin/Emby/一起看/TV 支持;保留 mpv 与 ExoPlayer;不改播放器帧时序相关时长;缓存必须按用户/服务器隔离,不得跨用户泄露;快照/manifest 中不得出现 token 或密码;不改授权 gate(身份/PIN 阶段不设上限)语义。
