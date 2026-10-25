# 弹幕 P0 后端

## 配置与使用

- 初始弹幕源为空。用户可添加 HTTP(S) 服务、启用/禁用、调整顺序和测试连接；取消添加不影响视频播放，本地 XML/JSON 导入仍可用。
- 地址可写成 `https://gateway.example/private/token` 或同地址的 `/api/v2` 形式。客户端保留完整路径前缀，去掉尾斜杠，拒绝 query、fragment 和 URL 内的账号密码。
- 自动搜索按启用顺序尝试源；超时、HTTP 失败和无候选会继续下一源。手动选源后只查询所选源。连接测试只证明搜索接口当次可用，不保证所有剧集均有弹幕，也不保存过期延迟。
- 默认搜索词是“剧名 第N季”。作品不唯一时需手动选择作品，再选择分集；特别篇、非整数集号和重复集号不会静默匹配。集号偏移独立于时间偏移，例如服务器第 1 集对应源第 2 集时设置集号偏移 +1。
- 候选的条数字段缺失时保持未知；所有作品与分集 ID 都携带源 ID，切源后重新查询。

## 数据与生命周期

`DanmakuSession.initialize()` 加载设置；UI 应 await 保存方法，失败时保留输入。源、样式、凭据与匹配记忆保存为带版本的 `danmaku_settings_v1` 资源，经现有 `CredentialVault` 加密后由 `SettingsService` 保存，普通设置导出不包含此资源。该 vault 继承仓库的静态加密限制，不是操作系统安全存储。损坏数据读取为空配置并显示错误，直到用户保存前保留原始存储。

播放器调用 `setMediaContext(DanmakuMatchContext(...))`，保存返回的 owner token，用 `ownsContext(token)` 检查异步恢复与片长回调，退出时调用 `clear(ownerGeneration: token)`，防止旧页面清掉新页面数据。同一个条目打开新页面也会获得不同 token。换片、换用户和换源使请求 generation 失效。匹配记忆键包含 profile、服务器、剧集和季；无剧集标识的单片使用自身 itemId。删除源或更改地址会删除该源记忆和对应凭据。源间切换时重置该源关联的时间与集号偏移；尚未匹配的新源不会修改旧源记忆。

`comments` 是唯一有效数据列表：解析排序后应用时间偏移，并剔除负时间和 `timeMs >= durationMs`。正偏移表示延后，原 10000ms 在 +1500ms 后成为 11500ms。原始列表保留，负偏移/片长变化可重新计算；片长未知时只剔除负值。overlay 直接使用有效列表，热力图也使用同一列表且不得再次加偏移。`dataVersion` 只随数据/源/偏移/片长变化，不随播放位置和纯样式变化。

overlay 用播放器的 position / playing / buffering / rate 驱动时钟，在两次原生 position 更新之间逐帧插值；弹幕仅在实际到达其时间戳时入画，不再提前 400ms 批量发射。原生时钟停止更新时最多外推 1 秒。暂停和缓冲会同时停住时钟与画布，恢复时继续 cursor；seek 清空画布并从目标时间重新定位，普通时钟抖动不重复入队。

滚动行数限制的是画面顶部的可用轨道，不是同时存活的条数。前一条尾部进入画面并留出安全间距后，同一轨道即可继续接入；更长、移动更快的后续弹幕还需通过追尾检查。同屏上限仍单独控制总密度，顶部/底部固定弹幕保持独立上限，并预留底部字幕空间。这些显示限制不修改 session 的弹幕统计或热力图。

播放器弹幕抽屉将在线搜索、显示区域、速度/密度/屏蔽与来源管理分别作为直接入口。在线搜索的输入和结果在单独页面，选集成功后返回常用设置；显示区域可选顶部 4/8/12 行，也可逐行调整滚动、顶部固定和底部固定弹幕。

## 协议与签名依据

2026-10-23 核验以下官方来源：

- [接入与签名指南](https://doc.dandanplay.com/open/)，第 5 节：`base64(sha256(AppId + Timestamp + Path + AppSecret))`。Timestamp 为 Unix 秒，Path 以 `/` 开头且不含 query。
- [官方 OpenAPI](https://api.dandanplay.net/swagger/v2/swagger.json)：`search/anime?keyword=...` → `bangumi/{bangumiId}` → `comment/{episodeId}?withRelated=...&chConvert=...`。`chConvert` 的 0/1/2 分别为不转换/简体/繁体。分集 `episodeNumber` 可为 SP 等非整数，`commentCount` 不保证存在。评论可能 302 跳转至加速站点。

仅精确 HTTPS origin `https://api.dandanplay.net` 使用用户输入的自有 AppId/AppSecret 签名；缺失凭据直接返回 `credentials_required`，不发送请求。网关只收到应用 User-Agent。客户端手动处理重定向；跨 origin 去掉所有签名头，并拒绝 HTTPS 降级。每次同 origin 路径变化重新签名。HTTP 404/405/501 才回退 `search/episodes`；401/403、空结果、超时或错误 JSON 不触发旧路由。

固定测试样本使用公开占位文本而非真实凭据：AppId=`your_app_id`，AppSecret=`your_app_secret`，Timestamp=`1735660800`，Path=`/api/v2/comment/123450001`，期望签名=`MNBT8iOsIplI/GSkJEAH3V1AlpTyH1aMPJ1nedenEsw=`。该值由独立 Python hashlib 计算并与 Dart 实现比对。

所有错误只暴露本地错误码和数字 HTTP 状态；不返回服务端错误正文、完整请求 URL、路径 token 或密钥。官方凭据端到端验收和真机性能需要实际环境，mock 测试不代表已完成这两项。

## 针对性验证

```sh
flutter test test/danmaku/danmaku_api_client_test.dart test/danmaku/danmaku_session_test.dart test/danmaku/danmaku_overlay_test.dart
```

测试覆盖端点与编码 token 路径、v2/旧路由分支、鉴权/超时/解析错误、签名样本、同域重新签名、跨域头隔离和 HTTPS 降级拒绝、多源完整流程重试、CRUD 和重启恢复、写入失败、敏感导出、作用域记忆、同条目页面所有权、排队写入及网络请求竞态、有效偏移和片长边界。overlay widget 测试驱动播放器的 position/playing/playheadJump streams 并观察真实 canvas 控制器契约，验证正负偏移、seek、初始暂停和暂停恢复不重复入队。P1 的过滤、去重、密度和更多样式不在本后端批次中。

## 时间轴热力图

### 分桶、归一化与计数

`DanmakuHeatmap` 使用 session 的有效弹幕列表，调用时保持 `offsetMs: 0`，避免再次应用时间偏移。片长未知、非正数或直播时不生成热力图；其余时间只统计 `[0, durationMs)` 内的弹幕。桶宽固定为 `max(1000, durationMs ~/ 600)` 毫秒，桶数向上取整，末桶可短于桶宽。

`counts` 保留各桶原始条数，长按显示的“此刻 N 条”就是手指所在桶的条数，不是平滑值、每秒平均值或屏幕当前显示条数。显示曲线先取当前桶前后各四桶的均值（边缘缩短窗口），再除以原始桶计数的 P95 并截到 `[0, 1]`。P95 将全部桶计数（含零桶）排序后取 `floor((桶数 - 1) × 0.95)`，分母至少为 1，因此空数据和单桶均可安全处理。

`DanmakuHeatmapCache` 按媒体标识、`dataVersion`、片长、过滤参数、偏移和直播状态缓存结果。播放位置不参与缓存键；播放进度更新只重绘，不重新分桶或排序。正式接线传入已偏移的 session 数据，所以缓存中的额外偏移保持零。

### 绘制与操作

曲线、章节、缓冲条和片头片尾跳过区间由同一个 `BufferRangePainter` 绘制。轨道是连续的一整条，章节边界画成 1dp 暗色刻度，不再断开。时间轴保持闲置 3dp、交互 8dp 的轨道；曲线显示时增加 24dp 交互区域。弹幕设置中的热力图开关关闭后，曲线及其交互区域隐藏，原有进度拖动与缩略图预览继续可用。

- 点击曲线：以点击桶为固定中心搜索前后各六桶。只有点击桶的显示热度严格大于 0.6 时才吸附到窗口内最高热度桶的中心；并列先取离点击桶更近的，再取较早的。低于或等于阈值时按点击时间跳转。
- 长按曲线：显示“此刻 N 条”，松手关闭提示，不触发跳转。
- TV 遥控器：时间轴获得焦点后，左右键沿用时间轴调时操作；按住确认键跳到离当前播放位置最近的正热度局部峰值。平顶峰取中间偏早的桶，等距峰取较早的；一次按住只跳一次，并消费后续重复键和松键。没有正热度峰时显示本地化提示，不改变播放位置；短按确认保留原有行为。

热力图针对性验证：

```sh
flutter test test/danmaku/danmaku_heatmap_test.dart test/widgets/danmaku_timeline_test.dart
flutter test test/widgets/video_controls_test.dart --plain-name TimelineSlider
```

测试覆盖分桶与片长边界、P95 与九桶平滑、空数据/单桶、偏移、缓存失效、点击与长按、TV 确认键、拖动与预览回归，以及章节刻度不打断轨道。真机播放帧率与实体遥控器操作仍需实际设备验收。

## P1b 呈现与过滤（2026-10-23）

全局设置与播放器复用同一个 `DanmakuSettingsSheet` / `DanmakuSession`。
速度范围 0.25–3 倍，滚动持续时间为 `8 / speed` 秒；静态弹幕仍用引擎默认持续时间。
同屏上限 1–200，滚动、顶部与底部各自的行数上限 0–30，0 表示隐藏该类型。
旧 v1 设置没有这些字段时使用默认值，不清空已有源与匹配记忆。

`canvas_danmaku 0.3.3` 没有分类行数参数，因此 overlay 采用保守的逐条准入：每类同时在场的条数不超过其行数配额，总数不超过同屏上限。
开启防重叠时按实际字高分配互斥纵向位置，包含滚动与固定类型之间的冲突检查，并保留底部字幕空间；不通过不精确的 area 比例冒充行数限制。
调整布局参数会清掉当前画面中的旧弹幕，新弹幕使用新配额；seek 和暂停继续沿用播放器时钟。

关键词按非正则子串匹配；每行一个，保存时去除两端空白和重复词，上限100词、每词200字符。
去重键为 `(mode, text.trim())`，连续相邻重复间隔不超过1000ms时只保留首次，超过窗口重新显示。
过滤始终从保留的原始数据重建，再偏移并剔除越界数据；关闭过滤可恢复原始条目。
热力图与 overlay 共享该有效列表，密度准入只影响画面，不改变热力计数或触发热力重算。

自动化证据：`test/danmaku/danmaku_presentation_test.dart` 验证迁移、边界、写入失败、持久化和过滤可逆性；
`test/danmaku/danmaku_overlay_test.dart` 验证高密度分类/总量上限、跨类型不重叠、速度、seek及暂停。
这些测试不是实机高密度性能证明，真实网关/TV/FrameTiming仍须独立验收。
