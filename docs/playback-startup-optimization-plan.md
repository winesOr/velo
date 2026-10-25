# 播放器起播性能瓶颈剖析与优化方案

> 更新：2026-10-24。第一阶段三项已实现；自动化验证见下文，arm64 真机/TV 性能验收待完成。
> 调研来源：REA 静态逆向、Hermes 起播链路审查与当前仓库代码复核。
> 实施变更：`openspec/changes/optimize-playback-startup/`。

## 一、证据边界与瓶颈复核

### VidHub 的结论如何使用

- **静态观察**：VidHub 3.0.3 同时打包约 43 MB 的 `libvlc.so` 与 mpv；`settings_player_core_vlc_desc` 将「2.0 播放核心」文案与 VLC 联系起来。Java 业务层受 NIS 保护，无法据此确认默认核心、自动切核规则和真实起播时序。
- **探测函数实证**：REA 对 `libplayer.so` 的 DV/HDR 探测路径分析发现 FFmpeg `probesize=262144`、`analyzeduration=1000000`（微秒，即 1 秒）和 `fflags=nobuffer`，扫描循环有 32 视频包、128 总包、4 MiB、150 ms 的退出条件。**这是独立探测函数，不能直接称为实际播放器的秒开配置**。150 ms 在 I/O 调用之间检查，也不是整个网络探测的硬超时。
- **字符串证据**：VLC 中有 DV P7 回退、HDR、直通、`vlc-prefetch.XXXXXX` 和 BD-J 限制相关字符串。它们说明存在相关实现或诊断路径，不能证明磁盘缓存默认开启、所有 P7 都降级，或某核心实测画质更好。旧文档 `docs/vidhub-player-core-2.0-analysis.md` 中的强比较结论应按此边界理解。
- 本轮沿用 mpv/ExoPlayer，不引入 VLC，也不复制 VidHub 库、资源或运行参数。

### Plezy 当前执行链路

| 环节 | 代码证据与本轮判断 | 耗时结论 |
|---|---|---|
| 属性准备 | `video_player_screen.dart` 中原有大量串行属性调用；其中字幕外观等独立偏好适合合批。音频、DV/HDR 与用户配置有状态和覆盖顺序，不能全部无差别并行。 | 请求数可减少；原先 300–800 ms 是估计，尚无设备计时支持。 |
| PlaybackInfo | 在线 `_playbackDataFuture` **已经与内核初始化并行**，但 `open` 仍须等其结果。详情页原先只探测元数据/轨道，未提前完成原画协商。 | 预解析命中可以移走点击后的协商请求；原先 150–600 ms 不是实测。 |
| 显示匹配 | Android mpv 按解码结果采样并匹配显示模式，切换后还有约 2 秒基础稳定等待及用户延迟。原生首帧与画面可见是不同阶段。 | TV 开启匹配时仍可能主导等待；本阶段保持现有策略。 |
| 远程字幕 | 与 `loadfile` 一起交给内核的网络字幕可能阻塞打开，原守卫约 10 秒后尝试回退。只把 URL 移到后置 `sub-add` 仍可能阻塞 mpv 命令队列。 | 应先后台下载成本地文件，再挂载。 |

### Android 手机场景补充（用户反馈复核）

用户确认：Android 手机点击播放后转圈数秒，随后可以正常出画面。该反馈应按首帧延迟排查，不能直接认定为播放器死锁或持续失败。

- `SettingsService.useExoPlayer` 默认关闭，即默认 mpv；帧率匹配、分辨率匹配也默认关闭。未主动开启匹配时，不会进入 Android mpv 的显示协商起播门；前述约 2 秒切屏等待不是这个默认场景的首要解释。
- 优先分段计时：播放信息协商与内核准备（两者已并行）→ 打开视频 HTTP 流、格式/轨道发现和解码器创建 → 原生首帧 → 视觉效果完成并释放 UI 转圈。现有转圈统一覆盖这些阶段，单凭转圈时长无法判断哪段最慢。
- 若手机改用 ExoPlayer，当前首次播放门槛是 `LoadControlPolicy.BUFFER_FOR_PLAYBACK_MS=1000`，指 **1 秒媒体数据**，不是固定等待 1 秒墙钟时间；30–60 秒等预读上限也不代表起播必须先填满。
- 第一阶段的属性合批、详情页准备、远程字幕移出打开路径适用于该场景；具体收益仍须在已安装这些改动的新包上复测。当前无 ADB 设备连接，尚不能判断手机实际选中的核心、是否转码以及各阶段耗时。

## 二、第一阶段实施结果

### 任务 1：属性批量注入

- `Player` 增加 `Future<void> setProperties(Map<String, String>)`。Android mpv 使用 `setProperties`，Android ExoPlayer 使用 `setMpvProperties`，一批只需一次通道请求。其他平台及带 Dart 状态副作用的特殊属性沿用逐项设置。
- 原生先校验整批输入，再**依次调用已有异步 setter**，等每项回调完成后处理下一项；不在 UI 线程直接循环调用 JNI。单项失败不跳过后续属性，批次完成后返回逐项错误；中途实例失效会拒绝剩余写入。
- 起播字幕外观偏好合批，字体路径/名称合批；核心属性观察流水注册，全部注册结束后才视为就绪。
- DV/HDR、音频配置与用户 mpv.conf 保持既有顺序，因此不宣称原先近 30 次调用已全部变成一次。

相关实现：`lib/mpv/player/player_base.dart`、`player_native.dart`、`platform/player_android.dart`，以及 Android `shared/PlayerPropertyBatch.kt` 和两个播放器插件。

### 任务 2：详情页预解析串流

- 复用详情页已有 350 ms 防抖目标探测，在元数据和保存版本选择就绪后，后台调用可选的 `PlaybackPreparationSupport`。
- 当前只由 **Jellyfin/Emby 在线、原画、电影/剧集点播**实现。预解析发 `PlaybackInfo` 时设置 `AutoOpenLiveStream=false`，不打开媒体流，不发送播放开始事件。需要打开的动态来源、无限流、无可用协商结果及失败结果不保留。
- `PlaybackPreparationCache` 每个客户端独立，最多 4 项、TTL 30 秒；按认证会话、当前端点、媒体 ID、版本、音轨/字幕意图和起播位置匹配。一次消费，允许点击播放时复用仍在进行的请求。预解析失败时，播放走正常初始化重试。
- `PlaybackSourceResolver` 仍先检查下载优先规则；缓存只在确定需要服务端初始化时消费。不同质量或版本不复用。客户端关闭和优雅关闭都清空缓存。
- Plex 的准备路径可能带服务端转码状态，不做详情页投机协商；保留原有元数据缓存。详情页停留超过 30 秒或直接从其他入口播放时，可能没有可消费的准备结果。

相关实现：`lib/services/playback_preparation_cache.dart`、`jellyfin_client/parts/playback.dart`、`lib/screens/media_detail/playback_tracks_status.dart`。

### 任务 3：远程字幕后台加载

- HTTP(S) 外挂字幕在 Dart 后台下载，视频 `open` 只接收本地字幕。下载在 `open` 前开始，但不被起播等待；选中字幕优先，同一播放的下载串行且按 URI 去重。
- 每次下载先给 **1.5 秒预算**，失败后台重试一次，重试预算 20 秒。每个文件最多 32 MiB，拒绝空文件、超限与失败响应。文件以计数器命名写入私有临时目录，不将签名 URL 写入文件名或失败日志。
- 等视频首帧且画面可见后才挂载已完成的本地文件。原始 URI、来源轨道 ID 和元数据继续用于 `TrackManager` 匹配，后台任务只增加轨道；实际选择仍由现有选择策略决定，保留用户晚近选择。
- mpv 使用本地 `sub-add ... cached`。ExoPlayer 普通字幕先进入可选目录，只有选中尚未准备的字幕才重新准备媒体，保留 `currentPosition` 和 `playWhenReady`；多轨字幕容器需合并进媒体源，挂载后可能产生一次重新缓冲。ExoPlayer 回退 mpv 时也携带已下载字幕目录。
- 打开边界的尝试检查、活动下载器、片源代际及原生实例/片源检查共同隔离迟到任务。重载前等待已下发的挂载操作，重载进行中暂停新增挂载；预解析失败并保留旧视频时，旧字幕任务仍可继续。退出取消下载，原生释放后清理文件；换片保留旧文件到后继画面可见，避免释放仍被内核读取的文件。
- 本地与离线字幕保留原打开路径。字幕可能晚于画面出现，特别是服务端提取或大体积位图字幕；不能承诺画面首帧时所有字幕已就绪。

相关实现：`lib/services/remote_subtitle_loader.dart`、`lib/screens/video_player/parts/playback_open.dart`、播放器桥接与 Android `ExoPlayerCore.kt`。

## 三、第二阶段保留研究，不随本轮启用

1. **探测参数**：先证明实际 demux 阶段占比，再对协议、容器和字幕样本做对照。FFmpeg AVOption 与 mpv 公开属性的名称/单位不能混用；`nobuffer` 和缩小探测预算可能损害轨道发现、时间戳与弱网稳定性。ExoPlayer 的提取器参数也不是 mpv/FFmpeg 参数。
2. **磁盘缓存**：作为可选实验评估容量、清理、寻址与实际收益，使用平台缓存目录，不写死包名路径。VLC 临时缓存文件名不足以证明将 mpv `cache-on-disk` 默认打开就能缩短首帧。
3. **显示模式等待**：单独验证切屏通知、黑屏稳定性与设备差异，再决定是否替换固定等待。当前开启匹配的 TV 仍保留该等待。

## 四、验证与验收

### 自动化覆盖

- 批次顺序、部分失败后继续、回调完成时机、输入校验和过期实例；播放器原有桥接、音频与起播配置回归。
- 缓存容量/TTL、一次消费、进行中共享、失败重试、Jellyfin/Emby 请求次数、版本/音轨/质量隔离、账号/客户端/端点隔离、动态来源拒绝、下载优先规则。
- 字幕慢请求重试、取消后迟到响应、空/超限文件、私有临时文件清理、临时存储失败；字幕未到时先出首帧、换源拒绝迟到挂载。
- ExoPlayer 缓存字幕不立即重开，选中后进度和暂停意图保留，后选字幕不会被旧默认标记覆盖。

最终源码验证结果：

| 检查 | 结果 |
|---|---|
| `flutter analyze` | 无告警或错误。 |
| 最终相关 Flutter 回归 | **847 项通过**，包含全部 `test/mpv/`、`test/screens/video_player/`、详情页、音乐播放器兼容与相关服务测试。 |
| Android 原生测试 | **98 项通过**：批次 4、字幕异步挂载 1、mpv 插件 65、ExoPlayer 插件 28。 |
| Dart/原生格式、差异空白、OpenSpec 严格校验 | 通过。 |
| `scripts/ci_checks.sh` | **未全绿**：当前工作区 23 份 i18n 生成文件过期；本轮未修改翻译源或生成文件。配置 Python 3.12 后，其余 CI 项（脚本守卫、翻译检查、硬编码字符串、图标、格式、analyzer、未使用代码/文件）通过。系统默认 Python 3.9 不满足现有生成脚本的语法/API 要求。 |
| 全仓 Flutter 运行 | 在实施尚有修改时启动的一轮为 8185 通过、6 跳过、2 失败：新增字幕存储失败用例和 TrackManager 测试使用了先前的编译快照。两文件的最终源码及相关范围已在上述 847 项中重跑通过；**最终版全仓全量未再次运行**。 |

测试不能证明具体毫秒收益或真实设备 DV/直通表现。i18n 生成物过期是现有工作区问题，本批次不混入其大范围生成变更。

复现命令（Flutter/Dart、JDK 17+、Python 3.10+ 需已在环境中配置）：

```bash
flutter analyze
scripts/run_tests.sh
scripts/ci_checks.sh
cd android
./gradlew :app:testDebugUnitTest \
  --tests com.edde746.plezy.shared.PlayerPropertyBatchTest \
  --tests com.edde746.plezy.exoplayer.AsyncSubtitleAttachmentTest \
  --tests com.edde746.plezy.mpv.MpvPlayerPluginTest \
  --tests com.edde746.plezy.exoplayer.ExoPlayerPluginTest \
  -x :app:compileFlutterBuildDebug
```

最后一条单独验证 Android 桥接与原生代码，Dart 部分由前面的 analyzer/Flutter 测试覆盖。

### 真机性能验收待办

当前 ADB 没有连接设备，**未测得实际提速，未验证 300–500 ms 目标**。该数值仅适合作为内网、准备命中、无需显示切换的常规片源探索目标，不是所有片源和设备的承诺。

1. 同一设备、同一服务端与同一文件，分别测试 mpv/ExoPlayer、冷/热启动、详情页准备命中/未命中、显示匹配开/关；每组至少 20 次，记录 P50/P95。
2. 分开记录点击到准备结果、属性就绪、原生首帧、画面可见、字幕可用的时间，避免把原生首帧当成用户已看到画面。
3. 故意延迟或拒绝字幕请求，确认视频继续起播；测试选字幕、关闭字幕、切版本、下一集、失败重载和退出。
4. arm64 真机/TV 复核 P7→P8.1、HDR/SDR、TrueHD/DTS-HD 直通、ASS/PGS/多轨容器与双字幕、弹幕滚动和遥控器操作。检查退出后临时字幕文件清理。
