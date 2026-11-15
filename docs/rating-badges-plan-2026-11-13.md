# 正式 App 评分展示修改方案

日期：2026-11-13。状态：**已授权实施，代码修改中；独立验证结果另行记录**。代码基线：`codex/r1-home-hero`，`39ab68d`。

## 1. 已确认的展示规则

- **普通影视海报只显示一枚客观评分角标**：按用户启用的来源顺序，取首个真实有效评分；该来源缺分就顺序回退；全部无分则隐藏。
- **首页轮播大海报、详情封面区域可显示多个来源评分**：本次沿用 首页 hero 最多 4 项（用户最新要求）、详情最多 4 项；实际有几项显示几项，无数据不占位。
- **个人评分独立**：不抢占普通海报的客观评分角标，不混入影片外部评分条。
- 复用 Plex/Jellyfin/Emby 已提供的真实 IMDb、TMDB、烂番茄及中性社区/影评分；来源不明时不冒贴品牌。此次不接豆瓣。
- 保留继续观看卡片不显示评分角标的现有例外；保留移动/TV、一起看和现有播放能力。

本包是现有评分展示的小范围调整，不要求新增外部服务、API key、全局网络 Provider 或缓存系统。

## 2. 当前代码事实与本次差异

| 位置 | 现有行为 | 要改成什么 | 验收 |
|---|---|---|---|
| 普通海报 | `lib/widgets/media_rating_badge.dart:33–38` 先取 userRating，再取外部分 | 去掉个人分优先；按现有评分偏好取第一个合法客观分 | 有个人分时海报仍显示客观分；禁用/缺分按顺序回退 |
| 角标实际绘制 | `lib/widgets/media_card.dart:664–675` 左下 `bottom:8,start:6`，共用 MediaCardRatingBadge | 保持一枚、来源标识+数字；仍不独立响应点击，整卡进入详情 | 手机/TV均只有一枚，不挡进度/已看提示，RTL跟随start |
| 角标可读性 | `lib/widgets/media_ratings_strip.dart:108–143` 使用主题浅/深容器色 | 对浅色/深色海报都使用主题命名的半透明深底与清晰前景；复用既有品牌SVG | 亮/暗/纯黑三主题可读，不新增散落颜色常量 |
| 首页轮播大海报 | `lib/widgets/hero_metadata_badges.dart:42–46` 基线渲染最多2项；`fusion_home_hero.dart:151`实际调用 | 保留片名附近多来源分，监听现有排序/启停；不改大海报结构 | 最多4项，品牌和数值可读，首页首屏比例不变 |
| 桌面/TV首页 | `discover_screen.dart:1743`调用HeroMetadataBadges；`tv_spotlight_background.dart:346–350`基线选最多2分 | 在spotlight局部拆出独立评分Wrap；普通元信息继续使用FittedMetadataLine，避免尾部评分被裁掉 | 窄宽窗口/TV不溢出，不新增焦点节点 |
| 详情封面信息区 | `lib/screens/media_detail/presentation.dart:221`已在元数据之后、播放操作之前插入MediaRatingsStrip | 明确呈现为封面信息组内的多来源评分，不移到详情深处；每格“图标+数值 / 来源名” | 进入详情无需滚到简介下方即可辨认评分 |
| TV详情封面信息区 | `lib/screens/media_detail/responsive_layout.dart:161–166`已有评分条+独立个人评分 | 保留位置与fallback；条本身不聚焦、个人评分控件可聚焦 | 焦点到个人分时整组可见，与播放按钮顺序正常 |
| 详情条几何 | `media_ratings_strip.dart:47–90`无分收起，有分按maxRatings预留固定高度 | 按实际有效数量/字体计算行数；1–2项不留空槽；有分先显示 | 0/1/2/4/5来源、200%字体无溢出/多余空白 |
| 加载补全 | 详情已有`_isLoadingMetadata`，评分条没有loading参数 | 不增加loading参数或占位；已有分立即显示，无分始终收起 | Plex列表带1–2分进详情可先显示，补全按实际来源更新，不伪造来源 |
| 设置 | `rating_settings_screen.dart:55–97`已有角标开关、来源启停和上下移 | 复用现有控件；核对说明文案不再说“海报优先显示我的评分” | 排序/启停即时更新角标、轮播、详情；海报开关只影响海报 |

普通手机网格经 `lib/widgets/hub_section.dart:819–841`创建MediaCard；TV经 `lib/widgets/tv_browse_rail.dart:1736–1748`创建同组件。无需分别造两套角标。继续观看、照片/音乐/季、CatalogItem-only卡片保持原范围，不顺带扩展。

## 3. 数据契约与来源规则

复用现有字段，不新增服务端接口或数据库表：

```dart
// lib/media/media_rating.dart
const MediaRatingSource({required this.source, required this.value, this.votes});
// lib/media/media_item.dart
 double? rating;                  // 服务提供的headline
 List<MediaRatingSource>? ratings; // 带来源的客观评分
 double? userRating;              // 用户自己的评分，独立
```

现有显示链：`mediaRatingsFor` → `RatingDisplayPolicy.select` → `preferredMediaRatingsFor`。先取合法具名集合，缺失时可用服务headline回退中性来源；按用户顺序去重、禁用、裁剪。合法值为有限数、`>0 && <=10`，不是合法分则不显示。

| 服务/来源 | 当前读取与显示 |
|---|---|
| Plex | `plex_mappers.dart:970–1008,1112–1123`读取rating/ratingImage、audienceRating/audienceRatingImage、Rating[]；image scheme确定IMDb/TMDB/RT，不认识的来源保留critic/audience |
| Jellyfin/Emby | `jellyfin_mappers.dart:275–276,428–439`读取CommunityRating和CriticRating；CommunityRating保持通用audience，不按ProviderIds猜品牌 |
| IMDb | 内部0–10，显示一位小数 |
| TMDB/RT | 内部归一化0–10，按现有格式显示百分比；RT不解释为平均星级 |
| 无品牌分 | 中性图标/来源名，不能冒用品牌SVG |
| 我的评分 | 只保留独立入口/展示；Plex数字分、JF/Emby收藏能力不控制客观分可见性 |

已有默认来源顺序：RT影评、RT观众、IMDb、TMDB、critic、audience、Simkl、MAL、AniList、Trakt、other；沿用用户已保存的顺序，不强制重置。海报只是从这个顺序取一个；轮播与详情分别取多个。

**数据边界**：服务器未提供某来源分时，UI无法补出该品牌分；无分应隐藏/真实回退。Plex列表通常少于详情来源，不应为每张海报额外请求详情以凑齐品牌。当前不承诺“每部电影都有四个分”。

JF/Emby CriticRating当前被标RT，但旧R02/R05对此存在来源核验分歧；本包不新增或扩大这项品牌断言，也不擅改映射及用户已有排序语义。若真实响应核对发现归属不明，应以单独数据修正任务处理，明确记录，不能把UI验收当成来源验证。

## 4. 最小文件责任与共享文件

### 前端实现代理

优先只改下列现有文件：

1. `lib/widgets/media_rating_badge.dart`：客观海报分选择；抽取/复用来源图标帮助函数，避免重复SVG格式逻辑。
2. `lib/widgets/media_ratings_strip.dart`：封面评分条图标+数值+来源、实际数量自然排版、无分收起、角标可读性。
3. `lib/widgets/media_card.dart`：仅合并角标判断/使用客观分，保持继续观看例外、位置及语义说明与视觉一致。
4. `lib/screens/media_detail/presentation.dart`、`responsive_layout.dart`：保持现有调用和评分在封面信息组的位置；本次无需新增参数。
5. `lib/utils/rating_display_policy.dart`：集中hero4/detail4具名常量和TODO，默认值不散写。
6. 必要的`lib/theme/`命名颜色和 `lib/i18n/*.i18n.json`说明文案；由现有生成命令更新生成文件，不手改。

hero、discover、设置页面本身已接评分：先验收；TV spotlight按上述独立Wrap调整，只有发现本次直接相关问题才改，不能扩大首页重构。`rating_utils.dart`只在复用图标/标签确有需要时局部调整。普通卡片不新增网络状态订阅。

### 后端

本轮默认无后端改动。若验收证明服务器确有具名评分但现有mapper丢失，先记录具体脱敏字段和复现，交原作者做独立最小解析修复；不在UI实现中猜字段或顺便新增API。

### QA与独立审查

另一个代理负责测试/编译/界面验证；审查代理只读本包改动。共享文件 `rating_display_policy.dart`、`rating_utils.dart`、theme、i18n统一由前端作者处理；不并行修改同一文件。修错回原作者，同问题最多两轮。

现有未跟踪 `design/prototype-v2/` 和其他文档不得回退或清理；本次不修改原型、不提交推送。

## 5. 默认值与TODO

| 配置 | 本次默认 | 说明 |
|---|---|---|
| 海报角标数量 | 1 | 用户明确要求，始终只有一个 |
| heroLimit | 4 | 用户最新要求；保留TODO(VELO-P3-01)进行设备验证 |
| detailLimit | 4 | 沿用设计默认，可调整；补TODO(VELO-P3-02) |
| 来源顺序/禁用 | 现有用户配置 | 无数据则按序回退，不重置用户偏好 |
| 海报开关 | 现有showRatingBadges，默认true | 不影响轮播/详情评分显示 |
| 无评分 | 收起 | 不补0、不放假品牌、不占空槽 |
| 无分加载 | 不占位 | 无评分始终收起；不新增骨架或固定空行 |

个人分退出普通角标属于本次明确行为变化；更新说明与测试，不改变个人评分输入、保存或后端权限。

## 6. 验收步骤与证据

### 逻辑/组件测试

- 海报0/1/多来源始终最多1个；有userRating也不占客观角标；首源缺失回退，禁用全部则隐藏。
- hero最多4、详情最多4；5源按配置顺序裁剪；切换来源顺序/启停后同步更新三处。
- 有效范围、0/空/null/NaN/越界过滤、未知品牌中性显示；IMDb小数与TMDB/RT百分比正确。
- 详情0/1/2/4项自然高度；加载中无分也完全收起，有分立即显示；无复制占位分数。
- JF/Emby无数字个人评分能力时客观分仍显示；离线缓存评分可读，不能因不能编辑个人分而隐藏。
- 继续观看无角标；海报开关不误关hero/详情；评分块不新增TV焦点。

基线 `test/widgets/media_ratings_strip_test.dart`仅有hero评分用例；实施新增详情条、数量、偏好、TV实际布局测试，执行结果由独立QA记录。旧R5文档部分测试路径当前不存在，新增有意义的相关测试，不能把不存在的命令记成通过。

### 实际页面验证

1. 选一个已知具名评分的获准服务条目，核对mapper输入→MediaItem.ratings→海报/轮播/详情输出；只记分数字段，不输出服务器地址/token/私人媒体库。
2. 手机320/390宽、200%字体，亮/暗/纯黑三主题；浅/深海报上角标可读；封面区评分不挤播放按钮、不移到深处。
3. TV普通海报只一分；轮播/详情多分；方向键仍聚焦整卡、个人评分和播放，评分来源条本身不吸焦点。
4. 进入/返回详情、来源设置变更后界面一致；无分影片无假占位；继续观看原有进度与无角标行为保持。
5. 对当前无法连接的服务和缺真实样例的来源标“未验证”，mock截图不能冒充服务器联调。

由QA执行本次相关单测、`flutter analyze`、适用平台编译；提交前执行项目要求的 `scripts/run_tests.sh`及规则检查。改slang则生成并执行 `scripts/codegen.sh --check`。通过/失败/未运行分别记录。

## 7. 可选后续与非目标

如果服务器缺少IMDb/TMDB/RT，可后续单列用户自配MDBList API key的补充分任务；官方单片`ratings[]`接口已查到文档，但本轮没有真实key成功联调，**不是本轮依赖或交付条件**。不为当前小改动新增密钥设置、Provider、缓存、限流或ID匹配体系。

不改个人评分交互、不扩音乐/直播/录制、不改播放器与投屏、不扫描用户媒体、不抓取竞品/评分网站、不追求四个来源每片必齐。竞品取数方式另据公开说明回答，不以布局相似推断其内部API。

## 8. 完成报告要求

按“普通海报单角标／轮播多分／详情封面多分／个人分独立／来源设置与例外”逐项报告实现文件与验证。列共享文件、采用默认值、源数据不足和未测环境。真实服务缺分不是加随机数的理由；未实施或未验证不能写“已经加好”。

本次已授权实施正式Flutter评分展示与文案。测试/编译由独立QA执行并报告；数据库、后端和原型不在本包修改范围。未提交或推送。
