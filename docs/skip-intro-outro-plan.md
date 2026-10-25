# 跳过片头片尾完整方案（Emby + 302 反代 115 场景优先）

> 2026-10-24 定稿，同日完成 v1 实施（M1+M2 核心+M3，见 §8 实施记录）。基于本轮逆向取证
> （VidHub 3.0.3）与外部方案逐项实测验证（AniSkip API 现场调用、StrmAssistant wiki 原文、
> Emby IntroTimestamps 端点在 302 反代链路的实证日志）。
> 与《三端融合方案》P1「跳过片头提示+撤销」条目衔接，本文是该条目的展开与扩展。

## 1. 背景与场景约束

用户主场景：**Emby 服务器 + strm/302 反代到 115 网盘直链**。含义：

- 媒体字节只流经客户端，服务器不落盘、不该碰媒体数据。
- 一切依赖服务器读媒体的检测（Emby 官方扫描、Jellyfin Intro Skipper 式全片指纹）都不可行——
  等于让服务器去 115 拉流，架构意义归零。
- 可用的检测只有两类：**行为学习式**（StrmAssistant 播放行为探测，Emby 独有，零媒体流量）与
  **外部数据式**（AniSkip 社区时间戳，客户端直查，与服务器无关）。

VidHub 取证结论（背景知识）：其跳过片头片尾 = 用户自定义秒数 + 服务器标记消费，**无任何客户端
实时计算**。本方案与其同构，但数据源分层更完整。

## 2. 目标与非目标

**目标**

1. Emby 后端接入原生片头标记端点（`IntroTimestamps`），打通 StrmAssistant 行为探测生态。
2. AniSkip 社区时间戳作为服务器无关层（动漫精准覆盖，客户端直查）。
3. VidHub 式自定义片头/片尾秒数兜底（服务器和数据源都没有时）。
4. 自动跳过 toast + 撤销；TV 遥控可达。
5. 三层来源按优先级合并进现有 `MediaMarker` / `SkipMarkerMode` 管线，一次开发全部后端受益。

**非目标**

- 客户端本地指纹检测（chromaprint + 跨集对齐）。法律上无障碍（Plezy 与 Intro Skipper 同为
  GPL-3.0，算法可移植），但在本场景被 S1+S2+S3 完全覆盖，暂无不可替代价值。留待文件源直连
  （WebDAV/SMB 无服务器）落地后评估。
- 不做检测算法自研；不引入任何检测用的服务器流量。

## 3. 总体架构

```
S1 服务器标记（权威）                S2 AniSkip（动漫填充）           S3 自定义秒数（兜底）
Jellyfin /MediaSegments ✅已有      api.aniskip.com（新）            全局 + 按剧覆盖（新）
Plex    marker/chapter ✅已有       身份链复用弹幕匹配               播放器菜单直接改
Emby    /Episode/{id}/IntroTimestamps ⬅ 新增                        每次播放合成合成标记
        （StrmAssistant 行为探测写入）
        └────────────┬────────────────┴───────────────┬─────────────────┘
                     ▼                                ▼
         resolveSkipMarkers() 纯函数合并（新，lib/media/）
         按 type（intro/credits）分组，优先级 server > aniskip > custom
                     ▼
         现有管线：PlaybackExtras.markers → video_controls 的
         SkipMarkerMode(off/button/auto) → SkipMarkerButton / 自动 seek
                     ▼
         player_toast_indicator：自动跳过提示 + 撤销（新交互）
```

## 4. 数据源详细设计

### S1c. Emby `IntroTimestamps`（新增，M1）

- **端点**：`GET /Episode/{itemId}/IntroTimestamps`，标准 MediaBrowser token 认证
  （复用现有 jellyfin_client 的认证头）。Jellyfin/Emby 共享客户端，按 dialect 门控：
  仅 `MediaBrowserDialect.emby` 时请求；Jellyfin 继续.MediaSegments（已接，见
  `media_browser_dialect.dart:116`）。
- **响应**：`{EpisodeId, Valid, IntroStart, IntroEnd, ShowSkipPromptAt, HideSkipPromptAt}`。
- **单位自适应（关键）**：该端点血统里 Jellyfin 老插件返回 .NET ticks（1e7/秒），Emby 系文档为秒。
  统一启发式：`IntroEnd > 100000` 视为 ticks，除以 1e7 转 ms；否则按秒乘 1000。数量级差 5 个零，
  不会误判。单测覆盖两个分支。
- **降级**：404 = 该集无数据 → 返回空，静默；超时/网络错误同 offline 现有处理（log + 空）。
- **落点**：
  - `cached_playback_metadata_service.dart` 的 `_fetchJellyfinPlaybackExtras`：dialect 为 emby 时
    并行请求该端点，与 MediaSegments 同级容错。
  - `jellyfin_api_cache.dart` 加 endpoint 构造 + 缓存条目（跟随现有 ApiCache 模式，TTL 跟
    MediaSegments 一致）。
  - 解析函数 `embyIntroTimestampsToMarkers()` 放 `jellyfin_client/parts/` 旁（或 mappers），
  纯函数 + 单测。
- **片尾（开放问题 A）**：StrmAssistant 行为版同时写片头片尾，但 `IntroTimestamps` 响应是否含
  片尾、或走独立端点/章节，需装好插件后在用户服务器上抓一次包确认，实现时补齐。确认前 credits
  走 S2/S3。
- **离线**：`download_manager_service.dart:860` 的 offline-pin 已调用 `fetchPlaybackExtras`，
  Emby 标记自动进离线缓存，无需额外工作。

### S1 补充：Emby 章节式标记（零成本顺带验证）

StrmAssistant + Chapter API 生态会把片头写成章节。`PlaybackExtras.withChapterFallback`
（`media_source_info.dart:404` 起）已有章节名→标记铸造 + 3 分钟守卫（#2235）。Emby 条目的
Chapters 若带这些名字即自动生效——M1 联调时顺手验证，不单独排期。

### S2. AniSkip（新增，M2）

- **API（已现场验证可用，无 key）**：
  `GET https://api.aniskip.com/v2/skip-times/{malAnimeId}/{episodeNumber}?types[]=op&types[]=ed&episodeLength={秒}`
  → `{found, results: [{interval: {startTime, endTime}, skipType: op|ed|mixed-op|mixed-ed|recap, skipId, episodeLength}]}`
  （实测：葬送的芙莉莲 ep1 返回 OP 34.54–124.54s、ED 1330.58–1421.21s。）
- **类型映射**：`op`/`mixed-op` → `intro`；`ed`/`mixed-ed` → `credits`；`recap` → 新 type
  `recap`（UI 文案「回顾」，交互与 intro 相同）。
- **身份解析（分三级，按序尝试，按 (serverId, seriesId, season) 记忆）**：
  1. **弹幕匹配链复用**：已完成的 dandanplay 匹配选择（剧名+季+集）给出日文原名/罗马字，
     以此查 Jikan（`api.jikan.moe/v4/anime?q=`，免费、3 req/s）或 AniList GraphQL 得 MAL id
     （AniList 响应自带 `idMal`）。
  2. **Emby ProviderIds**：TMDB/TVDB id → 公开映射数据集兜底（anime-offline-database）。
  3. **手动绑定**：以上失败时在播放器菜单弹一次「为该剧绑定动漫（搜索框）」，选择后记忆——
     与弹幕首次添加面板同一交互模式，保证正确性兜底。
- **缓存**：按 (malId, episodeNumber) 缓存响应（skipId 变化即失效）；身份映射按剧缓存。存 Drift
  或 SharedPreferences JSON（量小，prefs 够用）。
- **时序**：不阻塞起播。起播时并行发起，返回后合并刷新标记（按钮可能晚 1–2 秒出现，可接受）。
- **设置开关**：「动漫片头片尾数据（AniSkip）」总开关。**默认值待拍板**（见 §10）。
- **失败**：超时（建议 5s）/未命中 → 静默降级到 S3，不弹错。

### S3. 自定义秒数（新增，M3，即融合方案 P1）

- **数据**：全局 `custom_intro_seconds` / `custom_end_seconds`（默认 0 = 关闭）+ 按剧覆盖
  `custom_skip_overrides: { "serverId:seriesId": {intro, end} }`（prefs JSON）。改一个剧不影响全局。
- **合成标记**：起播时同步生成 `intro: [0, N秒)`、`credits: [duration−M, duration)`，type 与
  服务器标记一致、来源标 `custom`。
- **UI 入口**：播放器设置抽屉（`player_settings_drawer.dart` 已有 skipIntroMode/skipCreditsMode
  行，同处加「自定义片头/片尾秒数」stepper + 「本剧单独设置」）；文案全部走 slang
  （`check_hardcoded_strings.py` 会拦）。
- **与 SkipMarkerMode 关系**：合成标记与服务器标记同管线——mode=off 只隐藏，button 弹按钮，
  auto 自动跳。三层来源只是数据不同，交互统一。

## 5. 合并与交互

### 合并规则（`resolveSkipMarkers()`，纯函数，新文件 `lib/media/skip_marker_resolver.dart`）

- 输入：三组标记 + 媒体时长；输出：按 type 去重后的最终标记列表。
- 同一 type 多来源时取**最高优先级来源**（server > aniskip > custom），不做区间并集（避免
  半精度区间叠加）。
- `MediaMarker` 增加 `source` 字段（`server`/`aniskip`/`custom`，默认 `server` 兼容现有构造），
  供 toast 文案区分「已按服务器标记跳过」/「已按社区数据跳过」/「已跳过自定义片头」。

### 自动跳过 + 撤销

- auto 模式触发 seek 后，`player_toast_indicator.dart`（已有组件）弹「已自动跳过片头 · 撤销」，
  8 秒内可撤销（seek 回触发点）。撤销后本集不再自动跳（防循环），仅显示按钮。
- TV：SkipMarkerButton 已走 focus 封装；确认键激活。热力图 P0 任务的时间轴画布
  （`BufferRangePainter`）会画 skip 区间——本方案的标记列表直接复用为画布输入
  （见 AGENTS.md 当前任务 #2「片头片尾跳过区间也画在这块画布上」）。

## 6. 服务器侧配置指引（随版本说明提供给用户）

1. Emby 装 StrmAssistant（神医助手），开「片头探测-播放行为」。
2. 插件的白名单/客户端名配置里加上 Plezy 上报的 `X-Emby-Client` 名（关键字匹配，不区分大小写）。
3. 无需任何媒体扫描；首次看完一集后标记即生成，`IntroTimestamps` 端点开始返回数据。
4. Jellyfin 用户可选装 TheIntroDB 插件（TVDB id 纯元数据匹配、写 MediaSegments、零媒体流量），
   客户端零改动即生效。

## 7. 测试与验收

单测（新增）：

- 单位自适应：秒/ticks 两分支 + 边界（IntroEnd=0、负值丢弃）。
- Emby 端点：404 → 空标记；响应解析字段齐全。
- AniSkip：响应解析、types 映射（含 recap）、found=false、超时静默、缓存命中与 skipId 失效。
- 合并：三来源同 type 取最高优先级；空输入；custom 秒数边界（N=0 不生成标记；N ≥ 时长钳制）。
- 身份解析：弹幕匹配记忆命中 / 手动绑定覆盖。

验收：

- `flutter analyze` 无新增告警；`scripts/ci_checks.sh` 过（含硬编码字符串检查）。
- 真机（Emby+302+115）：装 StrmAssistant 后，首播出按钮、二次起播 auto 生效；AniSkip 动漫集
  秒级出按钮；两者皆无时自定义秒数生效。
- TV 遥控可达（按钮焦点 + 确认键跳过）。
- 起播不被 S2 网络请求阻塞。

## 8. 分期与工时

| 里程碑 | 内容 | 工时 |
|---|---|---|
| M1 | Emby IntroTimestamps 接入（端点 + 单位自适应 + 缓存 + 单测 + dialect 门控） | 0.5–1 d |
| M2 | AniSkip（身份解析三级链 + 手动绑定 UI + API client + 缓存 + 设置开关 + 单测） | 1–1.5 d |
| M3 | 自定义秒数（全局+按剧、设置 UI、合成标记）+ 自动跳过 toast 撤销 | 1 d |
| M4 | 联调与可选增强：片尾端点补齐（开放问题 A）、Emby 章节式路径验证、时间轴区间渲染并入热力图画布、Jellyfin 老服务器 IntroTimestamps(ticks) 兜底 | 0.5 d+ |

合计约 3–4 人日。M1 独立可交付（对装了 StrmAssistant 的用户立即生效）。

### 8.1 实施记录（2026-10-24 v1）

**已落地**（`flutter analyze` 零告警，新增 28 个单测全绿，相关回归 150 个全绿）：

- M1 全量：`embyIntroTimestampsToMarkers`（`jellyfin_media_info_mapper.dart`，秒/ticks
  数量级判别）、`JellyfinApiCache.embyIntroTimestampsEndpoint`（纳入 deleteForItem /
  pinForOffline）、live 路径与 cache-only 路径按 dialect 分流（`parts/playback.dart`、
  `cached_playback_metadata_service.dart`）。
- M3 全量：`lib/media/skip_marker_resolver.dart`（三源按 type 取最高优先级；自定义秒数合成
  标记，负 id 防碰撞）、`customSkipIntroSeconds`/`customSkipEndSeconds` 设置项 +
  播放设置页两行、离线/无服务器场景也可用。
- M2 核心：`lib/services/aniskip_client.dart`（v2 skip-times、op/ed/recap/mixed 映射、
  会话内缓存、全失败静默）、`lib/services/aniskip_identity.dart`（Jikan 精确匹配 +
  按 seriesGlobalKey 记忆绑定 + 7 天负缓存）、`aniskipEnabled` 开关（默认开，可在设置关闭）。
- 装载器接线：`VideoControlsPlaybackExtrasLoader` 与服务器请求并行取 AniSkip，不阻塞起播。
- i18n：en / zh / zh-Hant 词条。

**基座已有、无需再做**：自动跳过 toast+撤销（`IntroSkipUndo`，5 秒窗口，撤销后本集抑制）、
时间轴 skip 区间渲染（`_timelineSkipRanges`）、SkipMarkerMode off/button/auto 与 TV 焦点。

**v1 未含（后续迭代）**：按剧覆盖的自定义秒数（当前仅全局）；AniSkip 手动绑定 UI（中文
标题在 Jikan 上自动匹配不到的剧，暂时落到自定义秒数兜底）；Emby 片尾端点确认（开放问题 A）。

## 9. 已验证的外部依赖

| 依赖 | 验证方式 | 状态 |
|---|---|---|
| Emby `GET /Episode/{id}/IntroTimestamps` | go-emby2openlist issue #284 实际日志（Emby Web 4.9.1.21 穿 302 反代调用） | ✅ |
| StrmAssistant 行为探测写 Emby 原生标记、零媒体流量 | wiki 原文 | ✅ |
| AniSkip `/v2/skip-times` | 本机 curl 实测返回精确区间 | ✅ |
| TheIntroDB Jellyfin 插件（TVDB id → MediaSegments） | README 原文 | ✅（客户端零改动） |
| Intro Skipper 无 AniSkip 集成（澄清） | wiki Anime 设置页原文 | ✅ 已排除误传 |
| Plezy 许可证 = GPL-3.0 | LICENSE + README:292 | ✅（无 GPL 兼容障碍） |

## 10. 风险与开放问题

| # | 事项 | 处置 |
|---|---|---|
| A | Emby 片尾标记的暴露端点未确证（可能同响应/独立端点/章节） | M1 期间在用户服务器抓包确认，M4 补齐 |
| B | AniSkip 开关默认值 | 与「弹幕源不内置地址」同类决策，**需拍板**：建议默认开（公共数据 API、可关），实现前确认 |
| C | 身份解析冷启动（无弹幕匹配、无 ProviderIds） | 手动绑定兜底，交互成本一次性 |
| D | 自定义秒数与服务器标记同时存在时的体验 | 合并规则保证单来源生效；UI 显示当前生效来源 |
| E | 115 直链与 API 无关（IntroTimestamps 走反代透传） | 已实证，无风险，记录备查 |
