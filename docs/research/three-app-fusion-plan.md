> **历史档案 / 范围已被后续决策替代。** 此文完整保留早期三应用融合策划正文（仅脱敏本机路径），供理解设计来源，不代表当前产品承诺。网盘、文件源聚合、刮削等早期建议不属于当前实施范围；“APK 不在本机”等历史状态也已被后续研究更新。当前继续保留 Plex / Jellyfin / Emby、一起看、移动端 / TV、mpv / ExoPlayer；弹幕网关由用户配置，不内置第三方密钥。资料整理于 2026-11-14，对应本地资料快照 `c350c4a`；本发布分支仅包含文档和原型，没有同时发布该快照前 50 个本地产品提交。

---
title: 三端融合方案 — Plezy 基座 + Yamby 弹幕/热力 + VidHub 视觉
date: 2026-10-22
tags: [Plezy, Yamby, VidHub, 逆向, 播放器, 架构方案]
status: 方案待拍板
---

# 三端融合：以 Plezy 为基座，吸收 Yamby 的弹幕与热力图、VidHub 的界面

## 0. 结论先行

1. **基座不用重做，而且已经动工了。** `<legacy-repo>` 是 GPL-3.0 的 Flutter 三协议客户端（Plex / Jellyfin / Emby），本地 fork 已领先上游 8 个提交：弹幕解析与绘制层、VidHub 同款流光毛玻璃、播放器玻璃 HUD 都已落地（21 个文件、+1334/−345 行，最新自签包 v2.23.6+159）。
2. **真正缺的是三块，不是"重做一个 App"**：
   - ① **弹幕热力图 = 0 行代码**（全仓库无 heatmap 实现）；
   - ② **弹幕工程深度**：当前只有一个搜索框 + 一个自定义 API 基址，缺匹配精度、多源切换、样式体系、按剧集记忆；
   - ③ **VidHub 的"文件源"聚合层**：原版 Plezy 对 WebDAV/SMB/网盘 的支持是 **0 符号**，这是功能性最大缺口（对你尤其致命 —— 你的影视资源全在 115）。
3. **UI 不冲突，是"壳"与"舱"的关系。** VidHub 提供视觉与空间（首页流光、悬浮海报卡、海报墙），Yamby 提供播放器里的信息密度与手感（弹幕面板、亮度音量竖条、梯度快进）。壳已经落地，舱还差。

---

## 1. 证据与边界（先说清楚哪些是实测、哪些是推断）

| 软件 | 本地制品 | 证据级别 | 关键事实 |
|---|---|---|---|
| **Plezy 2.23.0** | `<local-path>`（92.7 MB，sha256 `baed1691…4b35a`） | **A：APK 实测**（REA artifact graph `ev_a662f25a…04f8c`，inventory `ev_8ab6a725…0bf7`） | 476 条目；`libapp.so` 26.74 MB（Dart AOT 业务全在此）、`libmpv.so` 5.70 MB、`libasskt.so` 2.83 MB、FFmpeg 全家桶（avcodec 13.19 MB）、`libdovi_bridge.so` 1.68 MB、`libcronet` 6.50 MB、`libsqlite3` 1.73 MB、sentry；`classes.dex` 仅 5.02 MB（Kotlin 只是壳） |
| **Plezy 本地 fork** | `<legacy-repo>`（HEAD `864bd92`，上游 `edde746/plezy`） | **A：源码实测** | `lib/danmaku/`（5 文件）+ `lib/widgets/vidhub_ambient_backdrop.dart` + `lib/utils/ambient_palette_extractor.dart` + `timeline_slider` 重写 |
| **Yamby**（`com.hush.yamby`） | ❌ 本机无 APK | **B：官方描述 + 官方 TG 更新日志 + 第三方评测** | 详见 §2.2；**弹幕热力图是官方 TG 原文**："support for danmaku heatmaps / 支持弹幕热力图" |
| **VidHub** | ❌ APK 已不在本机（早期 3.0.2 版做过 REA，结论沉淀在 `plezy/docs/vidhub-ui-*.md`） | **B+：早期 APK 逆向结论 + 官方站缓存文档** | 网易易盾 NIS 7.6.0_744 加固，附加区还原 7,838 个业务描述符；`HomeMediaCenterFragment` / `HomeCarouselColorExtractor.kt` / `ViewColorAnimationKt` / `RenderNodeBlurController` / `DimenExtKt.requestHomeBlurUpdate` |

**Plezy 原版 APK 字符串实证（关键判据）**：

| 关键词 | `libapp.so` 命中次数 | 含义 |
|---|---|---|
| `danmaku` / `dandanplay` / `heatmap` | **0 / 0 / 0** | 原版**完全没有**弹幕与热力图 → fork 里的弹幕是 100% 自研 |
| `Anime4K` | 11 | 原版 mpv 已带 Anime4K shader |
| `Trakt` / `Seerr` | 94 / 254 | 发现层与入库请求现成 |
| `skipIntro` | 6 | 跳过片头现成（片尾另算） |
| `WebDAV` / `SMB` | **0 / 0** | **原版没有任何文件源/网络共享能力** |

> 边界：Yamby 与 VidHub 的**算法级细节**（热力图分桶与配色、弹幕匹配打分、VidHub 3.x 新版 UI）目前只有二手证据。要升级到 A 级，把两个 APK 丢进 `~/Downloads` 我用 REA 补测即可（见 §6）。

---

## 2. 三款软件解剖

### 2.1 Plezy（基座）—— 它已经给了什么

**协议与连接层**：Plex / Jellyfin / Emby 三协议统一抽象（`lib/media/media_server_client.dart` + `lib/services/plex_client.dart` / `jellyfin_client/`），多服务器并行（`multi_server_provider.dart`）、跨服搜索、端点竞速与故障切换（`endpoint_race.dart`、`failover_http_client.dart`）、Profile 分身份借用连接。

**播放层（双内核）**：桌面 / Android TV 走 mpv，Android 手机走 ExoPlayer + libass（`libmpv.so`、`libasskt.so`、`libdovi_bridge.so` 三重实证）；HDR/DV、ASS/SSA 完整样式、直连/转码预设、多版本切换、音画同步、倍速、睡眠定时、画中画、章节导航。

**播放器 UI 现成件**：缩略图 scrub（Plex BIF / Jellyfin Trickplay sprite，`scrub_preview_source.dart`）、章节分段轨道（`buffer_range_painter.dart` 已按章节切段 + 缓冲区间绘制）、跳过片头、轨道记忆（`track_selection_service.dart`）。

**发现与生态**：Plex Discover / Trakt / MyAnimeList / AniList / Simkl / Seerr 聚合，Seerr 请求入库；下载与离线同步规则；Live TV + DVR；音乐（gapless/歌词）；一起看 Rooms；Plezy Remote。

**它的三个硬缺口**：
1. 无弹幕（0 符号）；
2. 无热力图（0 符号）；
3. 无文件源（WebDAV/SMB/网盘 0 符号）—— 只有"媒体服务器"这一种数据来源。

### 2.2 Yamby —— 要吸收的不是皮肤，是"弹幕可用性 + 手感"

| 类别 | 具体能力 | 我们的价值 |
|---|---|---|
| 弹幕源 | 弹弹Play（dandanplay）兼容接口；**手搜时可切换服务器**；匹配结果多时优化精度；显示已加载弹幕的详细信息 | ★★★ 直接决定"弹幕能不能用" |
| 弹幕可视化 | **弹幕热力图**（官方 TG 更新日志原文） | ★★★ 你点名要的 |
| 播放器手感 | 手势快进**梯度曲线**、亮度/音量**竖条**、缩略图预览、自动跳过片头**+提示与撤销**、按剧集记忆〔视频缩放/字幕缩放/字幕位置〕、音量增益（播放中可调）、音轨/字幕轨记忆、PGS 多对象字幕（ExoPlayer） | ★★☆ 细节堆出来的"高级感" |
| 画质 | Anime4K 集成（mpv） | ★☆☆ Plezy 原版已有 shader 入口 |
| 系统层 | MD3 + 10 多套主题 + Monet、备用地址切换、管理员面板（扫描/识别/元数据编辑）、Trakt 同步、豆瓣评分、本地文件+本地字幕 | ★☆☆ 皮肤不抄，功能择取 |

**判断**：Yamby 的所谓"特色功能"，本质是三件事 —— 弹幕**能匹配上**、播放器**手感细**、Emby **管理面**。前两件值得搬，第三件（管理员面板）对你不重要。

### 2.3 VidHub —— 要吸收的是"空间景深"与"来源聚合"

**视觉四层管线（已有 REA 沉淀，参数可直接照抄）**：

```
Layer 4  底部多阶梯消退渐变 (45% / 72% / 94% → #121416)
Layer 3  磨砂防过曝暗层 (纯黑 0.22 恒定)
Layer 2  动态主色辐射流光 (中心 0.45,-0.65 · 半径 1.35 · alpha 0.46 · 380ms easeOutCubic)
Layer 1  硬件加速海报虚化底图 (GPU blur sigma 35~38)
```

- **取色**：微缩图 + 步长下采样把采样点压到 ~1024 点（单张 ≤1.8 ms，后台 isolate/协程）；三重去噪（亮度<0.12 丢、饱和度<0.12 丢、饱和度<0.18 且亮度>0.85 丢）；结果 ×0.78 压暗；LRU 128 缓存；极端情况回退 `#16191D`。
- **空间**：双 Pager 解耦（Image Pager 承载悬浮圆角卡 12~14dp，Info Pager 承载文字，淡入淡出不随机位移）+ 全屏贯通背景包裹状态栏。
- **功能层**：文件源聚合（本地目录 / SMB / WebDAV / 阿里 / 百度 / 115 / 123 / 移动 + Emby/Jellyfin/Plex/fnOS）、TMDB 刮削海报墙、2.0 播放核心、磁盘缓存、长按倍速、在线字幕、小窗。

**它的 IA 与 Plezy 根本不同**：VidHub 是"文件源 → 刮削 → 媒体库"（本地优先），Plezy 是"服务器 → 库 → 条目"（服务端优先）。这是本次融合最大的一处结构冲突（见 §4.5）。

---

## 3. 功能整合点矩阵

优先级：P0 = 本轮必做，P1 = 次轮，P2 = 有余力，✕ = 不做（重复或冲突）

| # | 能力 | Plezy/fork 现状 | 目标来源 | 落点（文件） | 工作量 | 优先级 |
|---|---|---|---|---|---|---|
| 1 | **弹幕热力图** | 无 | Yamby | 新建 `lib/danmaku/danmaku_heatmap.dart` + 改造 `buffer_range_painter.dart` / `timeline_slider.dart` | 0.5~1 d | **P0** |
| 2 | 弹幕匹配精度（标题+集号打分、候选列表带条数） | 只有原始列表 | Yamby | `danmaku_api_client.dart` + `danmaku_settings_sheet.dart` | 1 d | **P0** |
| 3 | 弹幕多源切换（自建 / 官方 / 备用） | 单一 baseUrl | Yamby | `danmaku_session.dart`（源列表）+ sheet | 0.5 d | **P0** |
| 4 | 弹幕样式体系（字号/透明度/速度/显示区域/关键词屏蔽/防遮挡） | 仅字号+透明度 | Yamby | `danmaku_overlay.dart` + sheet | 1 d | P1 |
| 5 | 按剧集记忆弹幕与缩放偏好 | 无 | Yamby | 复用 `services/scoped_player_prefs.dart` | 0.5 d | P1 |
| 6 | 跳过片头提示 + **撤销** | 有 skipIntro，无撤销 | Yamby | `player_toast_indicator.dart` | 0.5 d | P1 |
| 7 | 快进梯度曲线 / 音量增益 | 线性快进、无增益 | Yamby | `mobile_edge_adjustment_indicator.dart` + mpv 属性 | 1 d | P2 |
| 8 | **文件源抽象 + WebDAV/SMB** | 无 | VidHub | 新建 `lib/sources/`，挂进 `connection_registry.dart` | 5~8 d | **P1** |
| 9 | **115 网盘直连**（开放平台 OAuth + 直链 302） | 无 | VidHub | `lib/sources/cloud/pan115_source.dart` | 3~5 d | **P1** |
| 10 | 豆瓣评分徽章 | 无（有 TMDB/Emby 评分） | Yamby | `media_detail_screen.dart` 徽章区 | 0.5 d | P2 |
| 11 | Trakt / Seerr / Anime4K / Trickplay / 一起看 | 已有 | — | — | — | ✕ 别重做 |
| 12 | MD3 + Monet 多主题 | 自研 mono_theme + 玻璃 | Yamby | — | — | ✕ 与 VidHub 视觉打架 |
| 13 | Emby 管理员面板 | 部分（元数据编辑） | Yamby | — | — | ✕ 你不缺 |

### 3.1 弹幕热力图的具体设计（本轮唯一 P0 的新组件）

**数据侧**：`DanmakuSession.comments` 已按 `timeMs` 升序（`danmaku_parser.dart` 两个分支都 `sort`），一次 O(n) 分桶即可：

```
bucketMs = max(1000, durationMs ~/ 600)      // 目标 ~600 桶，短剧不碎、长片不糊
counts[bucket] += 1
normalize: v / p95(counts)  → clamp(0,1)     // 用 P95 而不是 max，防止单个"高能点"把整条压平
```

**渲染侧**：**不要**新建一个独立 widget 叠在 slider 上（多一层 `saveLayer`，滚动时掉帧）。正确做法是把热度数组传进现有的 `BufferRangePainter`，在**同一个 canvas** 上先画热度色带、再画章节分段与缓冲条 —— 现有 painter 已经按章节切段，热度条沿用同一套 `segments` 裁剪即可。

**交互侧**：热力峰值区可点跳转；长按显示"此刻 N 条弹幕"；热力开关放 `danmaku_settings_sheet` 内（默认开）。

**两个形态可选**（要你拍板，见 §6）：
- A：主轨 8px 下方加 4px 独立热力条 —— 信息分离清晰，但播放器底部多一条横线；
- B（推荐）：直接给主轨**背景染色**，热度 → 透明度/明度映射 —— 零额外高度，最像 VidHub 的克制感。

### 3.2 当前弹幕实现里两个必须先修的缺陷

1. **弹幕源写死本机地址**：`DanmakuApiClient.defaultBaseUrl = 'http://127.0.0.1:9321'`，`DanmakuSession.apiBaseUrl` 同样默认 `127.0.0.1`。手机上这个地址永远打不通 —— 必须在首次使用弹幕时引导填自建网关地址（如 `http://192.168.1.x:9321`），或内置默认指向你的服务端。
2. **没有 dandanplay 官方签名**：官方开放 API 要求 AppId + AppSecret 生成签名头，当前 client 是裸 GET，只能走**自建 dandanplay 兼容网关**。要做"官方直连"必须先补签名层（这也是 §3 第 3 项"多源"要一起解决的事）。

---

## 4. UI 整合方案

### 4.1 定位：VidHub 是壳，Yamby 是舱

- **壳（VidHub）**：决定"第一眼"——首页流光、悬浮海报卡、海报墙密度、详情页 hero、暗色玻璃 HUD。
- **舱（Yamby）**：决定"沉浸中"——播放器面板的控件排布、亮度音量竖条、弹幕面板、梯度快进。

两者不冲突，因为作用域不重叠：壳管"看之前"，舱管"看之时"。**唯一禁止**的是把 Yamby 的 MD3/Monet 皮肤引进壳层（会直接把 VidHub 的暗色玻璃质感冲掉）。

### 4.2 页面级分层地图

| 页面 | 当前状态 | 本轮/后续要补 |
|---|---|---|
| 首页 Discover | ✅ VidHub 三层解耦已落地（`3884b99`：拔掉死黑渐变，挂 `VidHubAmbientBackdrop` + 低分辨率采样微缩图） | 补"服务器 / 文件源"切换器（VidHub 右上角范式） |
| 海报墙 / 媒体库 | Plezy 原生 grid + 已有 4K/HDR/DV/音轨徽章 | 对齐 VidHub 密度与圆角（12~14dp）、角标位置 |
| 详情页 | ✅ hero + 圆形演员头像已落地 | 豆瓣徽章、来源标记（服务器/网盘） |
| 播放器 | ✅ 玻璃 HUD + slim 动效时间轴 + 弹幕面板已落地 | **热力图叠层（P0）**、亮度/音量竖条、跳过片头撤销 |
| 设置 | Plezy 原生 | 文件源管理页（长按 → 重命名/禁用/单源扫描，VidHub 范式） |

### 4.3 播放器叠层顺序（别打架，这是硬约束）

```
视频帧
 └ 弹幕 overlay        ← IgnorePointer，必须在 HUD 之下（现状正确：video.dart:127 注释已声明）
    └ 时间轴 painter   ← 热度色带 + 章节分段 + 缓冲区间，同一个 canvas（P0 改造点）
       └ 玻璃 HUD 控制栏
          └ Toast / 指示器
```

### 4.4 视觉参数基线（直接沿用已落地常量，别重新发明）

| 参数 | 值 | 出处 |
|---|---|---|
| 背景虚化 sigma | 35.0 ~ 38.0 | VidHub REA |
| 流光中心 / 半径 / alpha | `Alignment(0.45, -0.65)` / 1.35 / 0.46 | 同上 |
| 色彩补间 | 380 ms · `Curves.easeOutCubic` | 同上 |
| 对比盾 | 纯黑 0.22 恒定 | 同上 |
| Fade scrim 阶梯 | 0–45% 透明 / 45–72% 收敛 / 72–94% 过渡 / 94% 闭合 | 同上 |
| 系统底色 | `#121416`（回退 `#16191D`） | 同上 |
| 取色采样上限 | ~1024 点，单张 ≤1.8 ms | `ambient_palette_extractor.dart` |
| 取色阈值 | 亮度<0.12 / 饱和度<0.12 / (饱和<0.18 & 亮度>0.85) 丢弃；结果 ×0.78；LRU 128 | 同上 |
| 卡片圆角 / 悬浮感 | 12~14 dp + 柔和阴影，左右露边 | VidHub REA |

### 4.5 四处冲突与取舍（含我的判断）

1. **IA 冲突：VidHub 的"文件源"首页 vs Plezy 的"服务器"首页。**
   → 不合并数据模型，合并**入口**：顶层沿用 VidHub 的"库"概念，底层按 source 分组（服务器组 / 文件源组），一个首页两种来源分区呈现。**不要**做两套首页切换器，那是把复杂度推给用户。

2. **调性冲突：弹幕是"热闹层"，VidHub 视觉是"克制层"。**
   → 弹幕默认**不自动加载**，只在识别到动漫类目或用户手动搜索到匹配时提示；默认 18sp / 0.85 透明度（现状即此），不做满屏爆炸、不做彩色描边。

3. **轨道争用：热力图 vs 章节标记 vs 缓冲条 vs 缩略图 scrub，全挤在同一条 8px 轨道。**
   → 推荐 B 方案（热度染色主轨背景），零额外高度；若你坚持要独立热力条，则轨道总高从 8px 涨到 14px，并在 TV/大屏上自适应加高。

4. **皮肤冲突：Yamby 的 MD3 + Monet。**
   → 明确不引入。Yamby 只取功能不取皮肤；否则首页流光、玻璃 HUD、取色算法全部白做。

---

## 5. 分期路线（每期结束都要真机验证）

| 阶段 | 内容 | 预计 | 验收 |
|---|---|---|---|
| **P0** | 弹幕热力图（分桶 + painter + 点击跳转 + 开关）+ 修弹幕源写死地址 | 1~2 d | `flutter analyze` + 单测（分桶/P95 归一化/空数据）+ arm64 真机看片验证 |
| **P1** | 弹幕工程补齐：匹配打分、多源、样式体系、按剧集记忆 | 3~5 d | 用真实番剧验证匹配命中率、切源后热力图重建 |
| **P2** | 文件源抽象 + WebDAV/SMB，再单列 115（OAuth + 直链） | 1~2 周 | 挂真实 SMB/115 目录出海报墙、直链起播不转码 |
| **P3** | Yamby 手感：梯度快进、音量增益、跳过片头撤销、缩放记忆 | 2~3 d | 真机手感对比录屏 |
| **P4** | 豆瓣徽章、海报墙密度打磨、文件源管理页 | 2~3 d | 视觉走查 |

每期提交前：`ruff`/`flutter analyze` + `test` 全过 → 逻辑批次 commit → arm64 打包（注意 fork 已有的离线自举：`prebuilt_mpv/` 本地优先探测，别让 Gradle 去 curl `libdovi`）。

---

## 6. 需要你拍板的三件事

1. **热力图形态**：A 独立 4px 热力条 / **B 主轨热度染色（推荐）**。
2. **文件源优先级**：WebDAV/SMB 先（通用、无授权门槛）还是 115 先（你的真实资源所在，但要接开放平台 OAuth）。
3. ~~要不要 A 级证据~~ → **已解决（2026-10-22 已取回两个 APK 并完成 A 级补测，见 §7）。**
   剩下要你拍板的只有：热力图形态、文件源优先级，以及**要不要引入 VLC 内核**（VidHub 3.0.3 实证是 VLC 主核，见 §7.3 —— 我的意见是不要）。

---

## 附：本次实证清单

- Plezy APK：`<local-path>`，sha256 `baed1691b0c8cbd768c51f82aca47b93c758614c36e6e367187132057a84b35a`，476 条目 / 92,735,321 B；REA `inspect_artifact` = `ev_a662f25a0cd0a753dc5b5572531d3f82e3f08f307e79f1e1d2f45ccb2cb04f8c`，inventory = `ev_8ab6a725113d6f4f16af3ce75932d1adc529001c89f2790939b9845ed7790bf7`。
- 字符串判据：`libapp.so` 内 `danmaku`/`dandanplay`/`heatmap` = 0；`Anime4K` 11、`Trakt` 94、`Seerr` 254、`skipIntro` 6、`WebDAV`/`SMB` = 0。
- 本地 fork：HEAD `864bd92`，`origin/main..HEAD` 8 提交，`lib/` 侧 +1334/−345（21 文件）。
- 弹幕实现：`lib/danmaku/{danmaku_api_client,danmaku_parser,danmaku_overlay,danmaku_session,danmaku_comment}.dart`，依赖 `canvas_danmaku ^0.3.3` + `xml ^7.0.1`。
- Yamby 热力图出处：官方 Telegram 频道 `t.me/s/yamby_release` 更新日志「support for danmaku heatmaps / 支持弹幕热力图」。
- VidHub 视觉参数出处：`plezy/docs/vidhub-ui-architecture-analysis.md`、`plezy/docs/vidhub-ui-ambient-glass-architecture.md`（基于 Android 3.0.2 版 REA 逆向）。

---

# 七、A 级证据补测（2026-10-22 取回 APK 后追加）

## 7.0 取回与落盘

| 文件（统一存放于 `plezy/reference/apk/`） | 来源 | 大小 | sha256 |
|---|---|---|---|
| `yamby/yamby-2.1.0.11.xapk` | apkpure 官方直链（`d.apkpure.com` → `data.winudf.com`） | 40.5 MB | `0b36899a…07a6` |
| `yamby/yamby-base.apk` | 从 XAPK 抽出的 base（Play 分发形态） | 24.7 MB | `cdf2fc35…8be2` |
| `yamby/yamby-config-armeabi-v7a.apk` | XAPK 内的 `config.armeabi_v7a.apk`（原生库全在此） | 14.8 MB | `aca28666…3fae` |
| `vidhub/vidhub-3.0.3.xapk` | apkpure XAPK 直链（含 arm64 split） | 120.8 MB | `ed179715…75b7` |
| `vidhub/vidhub-base.apk` | VidHub base | 35.9 MB | `b7041dc8…1414` |
| `vidhub/vidhub-config-arm64-v8a.apk` | VidHub `config.arm64_v8a.apk`（原生库全在此） | 82.6 MB | `233a0997…f505` |
| `plezy/plezy-2.23.0-arm64-v8a.apk` | 上游 release（基座基线） | 92.7 MB | `baed1691…b35a` |

> 版本号以**解码后的 manifest 字符串池**为准：Yamby = `2.1.0.11`（apkpure 文件名里的 `20010012` 不是版本号），VidHub = `3.0.3`。复算：`python3 reference/scripts/apk_triage.py reference/apk/yamby/yamby-base.apk`。

REA 证据：Yamby `inspect_artifact` = `ev_7733e4df0d38675c3e274905ae968162c70b1d8fbf94dd73cba05567f7e570e9`（inventory `ev_587c92b8…47c8`）；VidHub `inspect_artifact` = `ev_05398b5f06cfa4e480e2bd408806856066c4839c8c458d7b736015da0797bab4`（inventory `ev_3812bd36…874a`）。

> ⚠️ 两个 APK 都是 **Play 分发形态的 split 包**：base 里只有代码/资源，`lib/<abi>/*.so` 全在 config split 里。以后做体积对比或引擎判读，**必须连 split 一起看**，只看 base 会得出"没有原生库"的错误结论。

## 7.1 Yamby 2.1.0.11：没有加固壳，但 35% 的类成员表被改写

**代码规模（实测 DEX 表）**：`classes.dex` 11.94 MB + `classes2.dex` 1.68 MB，合计 **11,340 个 class_def / 71,074 个 method / 64,327 条字符串**。业务类名完整保留（`com/hush/yamby/...`），**没有商业加固壳**（无 NIS、无 SecShell、无壳 DEX）。

**但**：`lib/armeabi-v7a/libnmmp.so`（1.02 MB）+ `libnmmvm.so`（0.18 MB）+ 类 `com/nmmedit/protect/NativeUtil` 同时存在。实证后果：**3,483 个类（占 9,942 的 35%）的 field/method 索引表与 DEX 全局表不一致**（累计 diff 溢出 `field_ids` 45,156 / `method_ids` 60,005 的边界），标准 DEX 解析器无法还原这些类的成员；且这批类名全部是字形混淆名（`Lp0/ۥۛۡۘۡۚ;`、`Lۦۤ۬ۡۘ/ۥۖۘۘۖ۫;`），业务类名则完整保留。

> 归因边界：**"成员表不一致"是观测**（可复现，见 `reference/scripts/apk_triage.py`）；**"由 NMMP 虚拟化保护所致"是推断**，依据是 `libnmmp/libnmmvm` + `com/nmmedit/protect/NativeUtil` 三件套同时存在。DEX 字符串池未加密（所以配置面读得出来），但混淆类的实现无法静态还原 —— 热力图渲染正落在这片区域。

**引擎栈（split 实测）**：`libmpv.so` 5.19 MB、`libass.so` 2.12 MB、FFmpeg（avcodec 11.63 / avformat 2.66 / avfilter 3.18 MB）、`libffmpegJNI.so`、`libmmkv.so`（设置存储）、`libnmmp/libnmmvm`（保护）；DEX 内同时存在 `androidx/media3/exoplayer` 全套 → **mpv + ExoPlayer 双核**，与官方描述一致。

**Anime4K**：`assets/a4k/` 下 8 个 glsl（`Anime4K_Restore_CNN_M` / `Upscale_CNN_x2_M` / `Clamp_Highlights` / `FSR` 等）→ 是随包内置的 mpv shader，不是远程下发。

**弹幕实现（关键）**：DEX 字符串里出现 `bilibili/DanmakuFlameMaster` 及其 LICENSE 链接 → Yamby 用的是 **B 站开源 DanmakuFlameMaster（Java/View 引擎）**，不是自研、也不是 canvas 方案。

**弹幕功能面（可完整读出，这是最有价值的部分）**：17 个偏好键 + 1 个设置数据类字段集。

| Yamby 偏好键 | 含义 | canvas_danmaku 对应 |
|---|---|---|
| `danmaku_heat_map` | **弹幕热力图开关** | 需自研（无对应，P0） |
| `danmaku_font_size` | 字号 | `DanmakuOption.fontSize` |
| `danmaku_transparency` | 透明度 | `DanmakuOption.opacity` |
| `danmaku_speed` | 滚动速度 | `DanmakuOption.duration`（反向） |
| `danmaku_count_on_screen` | 同屏条数 | `massiveMode` + `area` 组合 |
| `top_danmaku_max_line` / `top_fixed_danmaku_max_line` / `bottom_danmaku_max_line` | 顶部/顶部固定/底部行数上限 | `area` + `hideTop`/`hideBottom` 近似 |
| `prevent_danmaku_overlapping` | 防遮挡 | 引擎内建（无需开关） |
| `merge_duplicate_danmaku` | 合并重复弹幕 | 解析层去重（需新增） |
| `danmaku_black` | 关键词黑名单 | 解析层过滤（需新增） |
| `danmaku_apis` | **多 API 源列表** | 需新增（P0） |
| `danmaku_with_related` | 关联剧集弹幕 | 需新增 |
| `danmaku_remember_selection` | 记忆匹配选择 | 需新增（P1） |
| `danmaku_sync_refresh_rate` | 跟随刷新率 | Flutter vsync 天然满足 |
| `danmaku_transform` | 弹幕变换（缩放/位移） | `DanmakuOption.lineHeight/area` 近似 |

设置数据类 `DanmakuSettings(scrollMaxLines=…, topFixedMaxLines=…, bottomMaxLines=…, transparency=…, fontSize=…, speed=…, offsetMs=…, heatMap=…, …)`；另有 `SetDanmakuOffset(offsetMs)` → **弹幕时间轴偏移**（和字幕偏移分开调）。

弹幕源与流程：`https://api.dandanplay.net`（官方域名）+ 事件 `ChooseDanmakuEvent(apiHost=…)` / `DanmakuSearchResults(apiHost=…)` / `LoadDanmakuEpisodes(apiHost=…)` → **API host 是运行时可切换的一等参数**（自建/官方可并存）；流程事件完整：`QueryDanmaku → SelectDanmakuAnime → SelectDanmakuEpisode → DanmakuEpisodesChanged → ApplyDanmakuSelection`。

**热力图的边界（必须说清楚）**：`heatMap` 只以「布尔设置项 + 偏好键」形态出现，`libnmmp.so` 与 DEX 中**没有任何** heat/density/bucket/histogram 相关字符串，渲染实现落在 VMP 保护的类里。→ **"Yamby 热力图怎么画"这一点无法静态取证**，只能确认"它是个开关"。任何分桶宽度/配色映射的具体数字都属推断，不要当事实引用。

**另一个硬事实**：这份 XAPK 只有 `config.armeabi_v7a`，**没有 arm64 split** → 该分发渠道给的是 32 位包。Yamby 对 64 位设备的性能（尤其 4K/Anime4K）是受限的，这反过来是我们的机会点。

## 7.2 VidHub 3.0.3：仍是易盾加固，且是 VLC 主核

**加固实证（比 3.0.2 更完整）**：`classes.dex` 仅 **55,356 字节**（纯 wrapper）；`assets/nedata.db` **18.59 MB** + `assets/nedig.properties`；dex 字符串池里直接躺着 **`7.6.0_744`**（NIS 版本号）；所有业务字符串均为 Base64 密文（样本：`AAo3CQAAFgoAEiMOBgsqIAYXDgE=`）；`libnesec.so` 0.93 MB 在 arm64 split。→ 业务 DEX 与字符串被易盾接管，**静态恢复 UI 常量只能走"附加区描述符"那条老路**（上一轮已做，7838 个描述符）。

**播放引擎（这次才看清，很重要）**：

| 库 | 大小 | 说明 |
|---|---|---|
| `libvlc.so` | **43.24 MB** | VLC 主核（含完整 demuxer/decoder） |
| `libmpv.so` | 12.18 MB | mpv 备核（比 Plezy 的 5.70 MB 大得多，说明编进去的 feature 更多） |
| `libavcodec/format/filter` | 12.12 / 2.88 / 4.24 MB | FFmpeg 三件套 |
| `libarchive-jni.so` | 2.41 MB | 压缩包/ISO 直读 |
| `assets/lua/playlist/*.lua` | 55 个 | **VLC 的 Lua 播放列表解析器**（youtube/vimeo/twitch/soundcloud…）→ 铁证 |
| `assets/hrtfs/*.sofa` | 90 KB | 空间音频 HRTF |

**结论修正**：VidHub 所谓"2.0 播放核心"= **VLC**（43 MB 的体量摆在那），mpv 是备选。它支持 ISO 直开、4K DV、格式兼容广，靠的是 VLC + libarchive。**我的判断：不要跟。** Plezy 已有 mpv + ExoPlayer 双核，再加 VLC 等于平白多 43 MB 且引入第二套 demux 行为差异；ISO/压缩包直读可以用 `libarchive` 单点补（2.4 MB）而不是换内核。

**UI 侧新增实证**：`assets/material-colors.json`（19 组 Material 调色板，说明它的主题色选择器基于 Material 色板，不是 Monet）、`assets/language.json`（音轨/字幕语言清单）、`assets/media_server_current.json`（Lottie 动画，"soft halo" 光晕层，60fps/90 帧）、`assets/subfont.ttf` 6.1 MB（内嵌字幕字体）、`purchase_entrance.json` 2.9 MB（购买入口 Lottie）。→ 与上一轮逆向出的"四层渲染管线"不冲突，参数继续有效。

## 7.3 三方引擎对照（决定我们抄什么、不抄什么）

| 维度 | Plezy（基座） | Yamby 2.1.0.11 | VidHub 3.0.3 |
|---|---|---|---|
| 代码形态 | Flutter / Dart AOT（`libapp.so` 26.7 MB） | Kotlin，**3,483 类成员表被改写**（35%） | Kotlin + **易盾 NIS 7.6.0_744** 全量加固 |
| 播放内核 | mpv 5.70 MB + ExoPlayer+libass | mpv 5.19 MB + libass 2.12 + ExoPlayer | **VLC 43.24 MB** + mpv 12.18 |
| 弹幕引擎 | canvas_danmaku（Flutter 自绘） | **DanmakuFlameMaster**（B 站 Java 引擎） | 无 |
| 弹幕配置面 | 字号/透明度 2 项 | **17 项（含热力图、多 API、黑名单、行数上限）** | — |
| 画质增强 | mpv Anime4K shader 入口 | 随包 8 个 Anime4K glsl | VLC 内置 + 未观测到 shader 目录 |
| 文件源 | ✕（仅服务器） | ✕（仅 Emby/Jellyfin） | ✅ SMB/WebDAV/网盘/本地 + 刮削 |
| 64 位 | ✅ arm64 | ❌ 本渠道仅 v7a | ✅ arm64 split |

## 7.4 补测带来的三个方案修正

1. **弹幕 P0/P1 的验收标准从"抄功能"升级为"对齐 17 项配置面"**：其中 5 项必须自研（热力图、多 API 源、黑名单、去重、关联剧集），6 项可直接映射到 `DanmakuOption`，2 项引擎内建不需要开关，1 项（跟随刷新率）在 Flutter 下天然成立。
2. **热力图的"具体画法"确认无法从 Yamby 取证**（VMP）。所以 §3.1 的分桶/P95 归一化是我们的**自主设计**，不是"还原 Yamby"——文档里必须这么写，避免以后自己骗自己。
3. **不引入 VLC**。VidHub 的格式兼容优势可以用 `libarchive` 补 ISO/压缩包直读，不必换 43 MB 的内核；这条同时挡掉"体积失控"的风险。
