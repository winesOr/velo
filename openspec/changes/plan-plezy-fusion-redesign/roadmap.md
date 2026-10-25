# 改造路线与交付边界

当前 change：`plan-plezy-fusion-redesign`。建议先完成 **P0 可播放闭环**，再推进五页视觉与弹幕深度。以下顺序依据当前代码依赖制定；工作量是工程估算，不是交付日期，外部凭据与真机条件另计。

| 阶段 | 交付内容 | 依赖 | 完成证据 | 粗估投入 |
|---|---|---|---|---|
| P0 | 多源持久化、三步匹配、记忆/偏移、热力、Logo | 现有播放与设置基础 | tasks 1–4；源可用、重启保留、真机/TV 可操作 | 5–8 工程日 |
| P1a | 首页、媒体库、一起看、设置、手机/TV 导航 | P0 可用版本；媒体服务可访问 | tasks 5–7；五页真实数据闭环、视觉和焦点回归 | 7–11 工程日 |
| P1b | 样式、密度、过滤、撤销 | P0 数据管线、P1a 设置入口 | tasks 8–9；高密度播放与全量集成验收 | 3–5 工程日 |
| P1c-A | 播放器投屏、手机辅助配置 | P1a 导航/播放器；实际接收端 | 独立 change，真设备发现/控制/断开 | 先做 1–2 日可行性验证再估算 |
| P1c-B | 文件源基础、WebDAV/SMB、115 | 来源抽象、持久索引、播放资源解析 | 独立 changes，真实目录→刮削→播放闭环 | 基础 5–8 日；115 契约核验后重估 |
| P2-A | 可选 VLC 2.0、ISO/蓝光路径 | 能力适配验证与文件播放链 | 独立 change，格式/内核切换矩阵 | 先做 2–3 日技术验证再估算 |
| P2-B | 梯度快进、增益、豆瓣等 | 稳定播放器、合法数据接口 | 按单项价值提出 change | 分项估算 |

阶段估算包含相应测试与文档，不包含等待账号开通、设备到位或上游接口变化。P1c-A/B 可以按实际需求调整先后，不能将其插入 P0 的依赖链。

## 原型到规格的映射

| 原型 | 当前实现依据 | 本次规格 | 后续事项 |
|---|---|---|---|
| home.html + hero.js | DiscoverScreen、ambient backdrop/取色器 | adaptive-media-shell | 文件源入口在文件源交付时启用 |
| library.html + library.js | LibraryQuery、现有库页和 translator | media-library-browsing | 文件条目进入统一海报墙 |
| together.html + together.js | 现有 watch_together 全链路 | watch-together-experience | 接收端投屏与同步兼容另验收 |
| player.html + proto.js | video_controls、timeline/painter、danmaku | player-hud、danmaku-heatmap/matching/presentation | cast.js 是演示；VLC 是后续能力 |
| settings.html | SettingsService、现有设置页 | danmaku-sources/presentation、adaptive-media-shell | 手机扫码配置、文件源管理 |

## 后续独立 changes 的预定范围

### `add-playback-casting`

先检查 `lib/services/companion_remote/`、现有接收端和播放资源的可访问性，区分“遥控已运行的 Plezy TV”与“把媒体交给通用接收器”。第一批优先复用已具备的 Plezy TV 通道；DLNA 和 Google Cast 按实际协议/平台能力分别接入。

提案必须定义设备发现、连接/断开/重连、播放暂停、seek、音量、认证 URL/headers、媒体续播位置及能力提示。接收端通常不能执行 Flutter 弹幕叠层，必须说明弹幕和字幕能力；一起看同步必须经真机验证才开放组合使用。扫码配置仅走已配对鉴权通道，不向局域网广播源 token。

验收：一台真实 Plezy TV、实际 DLNA/Cast 设备各自独立记录，跨网段不可达、鉴权失败和设备离线均有错误反馈。通过可行性阶段后补齐该 change 的 proposal/specs/design/tasks，再进入实现。

### `add-file-source-library`

先定义 `lib/sources/` 中的来源、文件条目、索引任务和播放资源解析接口。媒体服务器继续通过现有 MediaServerClient；文件源提供目录/文件能力，再通过适配器接入 UI，避免为 SMB 虚构服务器管理接口。

第一批 WebDAV/SMB（含本地目录入口按平台授权能力接入），实现连接测试、分页目录、凭据存储、增量扫描/取消/恢复、TMDB 元数据匹配和人工纠错、来源隔离与去重策略。Drift 索引有 schema 迁移、取消重扫和缓存回收方案。

验收：真实共享目录的电影/多季剧集、重命名、删除、重复文件、断网、带认证的播放资源均可处理；文件播放进度和服务器媒体进度互不覆盖。第三方协议库选择与许可在该提案中核验。

### `add-pan115-source`

依赖文件源接口与索引。核验当前可用的官方授权、应用资格、目录接口、限流、直链有效期和请求头要求；旧方案中“OAuth + 302”只作为待核验假设，不能直接写成已具备的契约。

优先目标为用户 115 资源的授权→列目录→索引→刷新播放地址→续播。验证过期/撤销授权、限流退避、直链过期和跨设备访问。若无开放接口权限，先报告具体限制，并另行评估用户已有网关作为 WebDAV 来源；不得假称已完成原生 115 直连。

### `add-optional-vlc-backend`

保留 mpv/ExoPlayer 原有默认，新增第三后端与能力表；先实测平台 SDK、包体、HDR/DV、ASS、音轨、章节、ISO/蓝光菜单、播放状态和生命周期事件。ISO 文件读取与蓝光交互菜单分别评估，简单 ISO 直读可先用 libarchive 路径。

自动路由只根据验证过的能力触发；切核需保存进度/轨道并允许失败回退。禁止复用参考 APK 的 Lua、HRTF 等资源。验收必须包含原双核无回归、长时间播放、切后台、异常释放和包体差异，不能把某平台能力泛化到全平台。

### 后续播放体验与评分

按剧集记忆视频缩放、字幕缩放/位置：复用 scoped_player_prefs，先核对已支持字段，仅补缺口。梯度快进和音量增益：单独校准手势曲线、可用内核与音量边界。豆瓣评分、在线字幕和其他画质选项：核验合法接口与现有能力后再决定范围。Trakt、Seerr、Anime4K、Trickplay 等已有能力保留并回归，不重复建设。

## OpenSpec 推进方式

本 change 的 proposal → 八个 specs → design → tasks 已形成依赖链。实施时按 tasks 分组推进，完成一项即补证据并勾选；范围或行为变动先更新相关规格。P0 可以形成阶段版本，但当前 change 需 P1a/P1b 全部完成才归档。

```bash
openspec status --change plan-plezy-fusion-redesign
openspec instructions apply --change plan-plezy-fusion-redesign --json
openspec validate plan-plezy-fusion-redesign --strict
```

后续启动当前实现可使用 `$openspec-apply-change plan-plezy-fusion-redesign`。这里只准备计划，不执行 apply 或 archive。后续 changes 在开始前分别形成完整规格，避免用路线图中的高层假设直接驱动编码。
