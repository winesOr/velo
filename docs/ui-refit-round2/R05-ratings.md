# R5 评分收尾 任务卡

- 基线提交:`8885b39`(`git rev-parse --short HEAD`)。本卡所有行号以此为准,动手前先 `git rev-parse --short HEAD` 对一下,不一致就按符号名重新定位。
- 核对方式:静态读码,未运行(本环境无 flutter)。凡标"待核对"的,开发时要先查再改。
- 目标:详情页评分条补来源图标、手机分隔线和桌面/TV 大号变体,卡片角标改为深色半透明底,清掉评分相关的重复计算、占位空白、缺失译文和测试缺口。
- 优先级:中(R5-1/3/5/6/7),低(R5-2/8/9/10)。
- 规模:中。
- 前置依赖:无硬依赖。与 R2-3(个人评分 /10 与星数不一致,待确认 C4)在 `media_detail_screen.dart` 个人评分 chip 上有交集,本卡不动该 chip。与 R8-4(硬编码颜色)有交集:本卡新增的角标颜色走 theme 目录的命名常量,不要在 widget 里新写十六进制。
- 不在范围:豆瓣(无数据源,第一轮已定不做);首页头图评分(`hero_metadata_badges.dart`,属 R1);Plex `Rating[]` 映射;任何需要新凭据的第三方评分源;"我的评分"并入评分条(默认不做,见 R5-4);评分设置页的交互改版。

## 已定默认决策(默认值,产品可改)

| 项 | 默认值 | 产品可改点 |
|---|---|---|
| 详情评分条上限 | 4,做成具名常量,加 `TODO(VELO-P3-02)` | C2:改 5 只改常量 + 测试 |
| "我的评分" | 保持独立 chip,不并入评分条 | C3 |
| 卡片角标(压在海报上) | 亮/暗/纯黑三种主题都用半透明深底白字 | - |
| 评分条只有 1-2 个评分 | 不预留空高度,高度按实际行数 | - |

## 涉及文件表

| 文件 | 行号(8885b39) | 现状 | 动作 |
|---|---|---|---|
| `lib/widgets/media_ratings_strip.dart` | `MediaRatingsStrip` 17-105;`columnsFor` 35-36;`heightFor` 38-41;`build` 43-104(固定高 `:59`,单元格 `:64-66`,数字 `:75-83`,来源名 `:85-91`);`MediaCardRatingBadge` 108-143(底色 `:123`,个人 `:129-132`,非个人 `:134-138`) | 单元格无图标;`Wrap` 等宽无分隔线;高度按 `maxRatings` 槽位预留;角标用 `surfaceContainerHighest` .94 + `onSurface` | 改 |
| `lib/widgets/media_rating_badge.dart` | `mediaRatingsFor` 17;`mediaCardRatingFor` 33-39;`mediaRatingLabel` 43-44;`InlineRatingBadges` 101-156;`_buildContent`(图标渲染参考)159-187 | 图标渲染逻辑在 `_buildContent` 内,条单元格没复用 | 少量改(抽出图标小部件供条复用) |
| `lib/utils/rating_utils.dart` | `ratingInfoForSource` 28-42;`ratingSourceLabel` 44-62;资源常量 64-69;宽高比 71-77 | 6 个 svg 的来源→资源映射已齐;`critic`/`audience`/`simkl`/`mal`/`anilist`/`trakt` 返回 null | 不改(只读引用) |
| `lib/utils/rating_display_policy.dart` | `TODO(VELO-P3-01)` `:5`;`defaultSourceOrder` 6-18;`detailLimit = 4` `:19`;`heroLimit = 2` `:20` | `detailLimit` 无注释、无独立 TODO | 改(加注释和 TODO) |
| `lib/widgets/media_card.dart` | 刷新偏好列表 462-473;`_buildContent` 内第一处条件 483-488;`_buildPosterStack` 639;第二处 662-675(`mediaCardRatingFor` 在 `:662` 无条件调用) | 同一条件写了两遍,且第二处先算分再判开关 | 改(抽 `_cardBadgeRating`) |
| `lib/screens/media_detail/presentation.dart` | `_buildCompactDetailHeader` 195;`centered` 196-198;条调用 `:221`;个人评分 chip 调用 `:222-224` | 条无变体参数,不知道加载状态 | 改(传 `large`/`loading`) |
| `lib/screens/media_detail/responsive_layout.dart` | `_buildHeroHeader` 56(`centered` 57-59,720 上限 `:75`);`_buildTvDetailForeground` 83;条调用 161-165;个人评分 chip `:166` | TV 用同一个条,无大号变体 | 改(传 `large: true`) |
| `lib/screens/media_detail_screen.dart` | `_isLoadingMetadata` 354;`_buildUserRatingChip` 1142-1236;`_userRatingChipLabel` 1133-1137;TV 评分语义 `limit: detailLimit` `:3833` | 个人评分 chip 独立于条 | R5-4 默认不改;`:3833` 随常量改名同步 |
| `lib/screens/settings/rating_settings_screen.dart` | 构建 43-110;开关 55-60;来源列表 67-104;上下移按钮 112-133 | 用 `t.settings.*` 的 9 个 key,19 个语言为英文占位 | 不改代码,只补译文 |
| `lib/services/jellyfin_mappers.dart` | `_ratingSources` 428-441(注释 415-427);`ratings:` 调用 `:276` | 只映射 `CommunityRating`→`audience`、`CriticRating`→`rottenTomatoesCritic` | 加注释(R5-7 结论),不改逻辑 |
| `assets/rating_icons/` | `imdb.svg rt_fresh.svg rt_rotten.svg rt_spilled.svg rt_upright.svg tmdb.svg`(6 个);`pubspec.yaml:167` 整目录已登记 | 够用 | 不新增 |
| `lib/theme/`(新增 `poster_overlay_colors.dart`) | - | 无"压在海报上"的命名色 | 新增 |
| `lib/i18n/*.i18n.json`(19 个非 en/zh/zh-Hant 文件) | 见 R5-8 | 12 个 key 为英文占位 | 改 |
| `test/widgets/media_ratings_strip_test.dart` | 用例 `:60`(循环 0/1/2/5)、`:69`(预留高度)、`:76`、`:85`、`:99`、`:108` | `:69` 的"高度不变"用例与 R5-6 冲突 | 改 + 新增 |
| `test/widgets/media_card_full_card_test.dart` | `:128` `poster score defaults on, honors preferences, and excludes Continue Watching`(含个人评分 `9.0/10`) | 已覆盖开关/继续观看/个人评分的存在性,不覆盖样式 | 新增样式用例 |
| `test/utils/rating_display_policy_test.dart` | `:17` | 只测 5 个输入取 4 | 新增边界用例 |
| `test/screens/media_detail_screen_test.dart` | `:344,383,478,1334,2246-2247,2631-2632,2720,2737-2752,3158` | 依赖条的几何位置和个人评分 target key | 回归必跑 |
| `test/services/jellyfin_mappers_test.dart` | `:70-72,122-131,134-142,145` | 已覆盖 audience + RT critic | 视 R5-7 结论决定是否加用例 |

## 逐步修改说明

### R5-1 评分条单元格加来源图标

- 现状:`media_ratings_strip.dart:75-91` 每格只有数字 + 来源名文字。`rating_utils.dart:28` 的 `ratingInfoForSource(source, value)` 已能返回 svg 路径、格式化数值和宽高比;`media_rating_badge.dart:159-187`(`_buildContent`)已有"按宽高比定宽的 `SvgPicture.asset`"写法,条没复用。
- 改成:每格 = 第 1 行"图标 + 数字"(同一行,间距 6),第 2 行来源名。有 svg 的来源(IMDb、TMDB、RT 影评、RT 观众,共 4 种来源键,6 个资源)显示图标;`critic/audience/simkl/mal/anilist/trakt/unknown` 没有 svg,**不画图标、不新增自绘**,只留数字 + 来源名,但图标行高度保持一致(用同高 `SizedBox`),保证同一行各格数字基线对齐。
- 做法:
  1. 在 `media_rating_badge.dart` 抽出 `Widget ratingSourceIcon(MediaRatingSource rating, {required double size})`(返回 `SizedBox(width: size * info.iconAspect, height: size, child: SvgPicture.asset(info.assetPath))`;`info == null` 返回 null)。`_buildContent` 改为调用它,行为不变。
  2. 条单元格用 `Row(mainAxisSize: min, children: [icon?, SizedBox(width: 6), Text(number)])`。数字样式保持现有:`fontSize 18, w600, FontFeature.tabularFigures`(大号变体见 R5-2)。
  3. 来源名保持 11、`foreground.withValues(alpha: .78)`、居中、`maxLines` 从 3 改为 2。
  4. 语义不变:单元格仍是 `Semantics(label: ratingsSemanticLabel([rating]), excludeSemantics: true)`。
- 图标尺寸:第一轮规格没给图标尺寸。本卡默认手机 16、桌面/TV 20(默认值,设计可改)。imdb 宽高比约 1.98,16 高时宽约 32,加间距 6 加 "8.1" 数字约 25,总宽约 63,小于手机列宽 76 减左右内边距 6,放得下;动手后用 320px、200% 字号再测一次。
- 不要给 svg 加 `colorFilter`:这些是品牌色图标,亮/暗主题都保持原色(合理保留的硬编码色)。

### R5-2 手机分隔线 + 桌面/TV 大号变体

- 现状:`media_ratings_strip.dart:44-56` `Wrap` 等宽单元格(`columnsFor` 按 `76 × textScale` 算列数),无分隔线,无桌面变体。
- 规格(第一轮 P3,原样抄):
  - 手机:等分列,列之间细线分隔,最多 4 列外部评分;数字 18 / w600 / 等宽数字;来源名 11-12。
  - 桌面/TV:横排,单元格间距 28;数字 22 / w600 / 等宽数字。
  - 分隔线颜色:正文色 8%-10% 透明度(第一轮 P7"分隔线与描边:正文色 8%-10%",亮暗相同);代码里用 `tokens(context).outline`(`mono_tokens.dart:44`,亮色是黑 10%)或 `foreground.withValues(alpha: .1)`,二选一并保持亮暗一致。
- 改成:
  - 新增枚举 `enum RatingsStripSize { compact, large }` 与参数 `size`(默认 `compact`)。`compact`:数字 18、图标 16、来源名 11、等分列 + 竖线。`large`:数字 22、图标 20、来源名 12、`Wrap(spacing: 28, runSpacing: 12)`、无竖线、按 `alignment` 对齐。
  - 调用点:`presentation.dart:221` 传 `size: centered ? compact : large`(`centered` 是 `:196` 现成变量;≥720 宽的桌面/横屏平板左对齐时用 large);`responsive_layout.dart:161` 传 `large`(TV)。
- 做法(compact):
  1. 保留 `columnsFor`,但第三个参数改为**实际评分个数**而不是 `maxRatings`;最少 1 列。
  2. 把评分按 `columns` 个一行切块;每行 `IntrinsicHeight(Row)`,单元格 `Expanded`,相邻单元格之间插 `VerticalDivider(width: 1, thickness: 1)`;行末不加线;不足一行时用 `Expanded` 空白补齐(保持等分列宽,避免 2 个评分被拉成两个超宽格)。**待确认点见风险 1**。
  3. 删除 `heightFor` 与固定 `SizedBox(height: ...)`、固定 `height: 78 * scale` 的单元格(R5-6)。
  4. 评分超过一行(大字号或上限改 5)时按块换行,不横滑、不压缩列宽。5 个评分在 320px(4 列)下会是 4+1,建议改成按行数均分(3+2),均分算法:`perRow = ceil(n / ceil(n / columns))`。
- 不要改 `alignment` 参数的含义(`Wrap` 对齐);`compact` 变体下它只影响最后一行不满时的补位,默认居中补位即可。

### R5-3 详情上限做成具名常量

- 现状:`rating_display_policy.dart:19` `static const detailLimit = 4;`,只有 `:5` 一条笼统的 `TODO(VELO-P3-01)`(来源优先级与槽位)。方案原文是 5,手机 4 列;现有测试 `media_ratings_strip_test.dart:60` 的用例名即写"stable maximum of four"。
- 改成:保持值 4,加专属注释与编号:
  ```
  // TODO(VELO-P3-02): 详情评分条上限。默认 4(手机 4 列);方案为 5,待产品确认(清单 C2)。
  static const detailLimit = 4;
  ```
  `defaultSourceOrder` 保持不变(顺序:`rottenTomatoesCritic, rottenTomatoesAudience, imdb, tmdb, critic, audience, simkl, mal, anilist, trakt, other`),与方案"烂番茄影评、烂番茄观众、IMDb、TMDB、其余"一致。
- 不新增设置页开关(清单写"常量/配置项",默认走常量,最小改动)。若产品要用户可调,另起任务。
- 同步:`media_detail_screen.dart:3833` 与 `media_ratings_strip.dart:24` 继续引用 `detailLimit`,名字不变就无需改。
- 定 5 时的改法:常量改 5;确认 R5-2 的分行逻辑在 320px 下为 3+2;更新测试 R5-10。

### R5-4 "我的评分"保持独立 chip(默认不改)

- 现状:`_buildUserRatingChip`(`media_detail_screen.dart:1142-1236`)独立于条;手机/平板在 `presentation.dart:222-224` 紧挨条下方且仅在非紧凑 hero 时显示,TV 在 `responsive_layout.dart:166`;chip 标签用 `userRating / 2` 的星数(`:1136`),与卡片角标 `x/10` 不同(这是 R2-3/C4 的问题,本卡不处理)。
- 做法:**不改代码**。只需保证 R5-2 重构后:
  - 条与 chip 的相对位置不变(`presentation.dart:221-224`、`responsive_layout.dart:161-166`),TV 的 `_tvDetailRatingsGroupKey` 仍包住"条 + chip"(chip 聚焦时按整组滚动可见,见 `media_detail_screen.dart:1171-1177` 的注释)。
  - `detail_personal_rating_target` key、点击打开 `RatingBottomSheet`、方向键上下行为不变。
- 若产品确认并入(C3):另开任务,方案规格为"条末强调色单元,与外部评分用竖线分开,点击打开 `rating_bottom_sheet.dart`;手机放在操作按钮行"。

### R5-5 卡片角标改深色半透明底 + 白字

- 现状:`MediaCardRatingBadge`(`media_ratings_strip.dart:108-143`)底色 `colorScheme.surfaceContainerHighest.withValues(alpha: .94)`(`:123`),文字 `colorScheme.onSurface`(`:132,137`)。在本项目主题里 `surfaceContainerHighest == c.surface`(`mono_theme.dart:126`),亮色主题下是白底深字,压在深色海报上不一致;位置左下(`media_card.dart:670-671` `bottom: 8, start: 6`)、圆角 6(`:124`),这两项符合第一轮规格,不动。
- 规格(第一轮 P3/P7,原样抄):压在海报上的评分角标两种主题都用半透明深底白字;位置左下、半透明暗底、圆角 6;用户打过分时显示强调色"我的评分";继续观看卡不显示。"我的评分"角标随主题换选中底:选中底 暗 `#36324E` / 亮 `#E9E5F6`;强调 暗 `#B4AAFF` / 亮 `#6256C8`。
- 改成:
  - 非个人角标:底色 `PosterOverlayColors.scrim`,文字/图标 `PosterOverlayColors.onScrim`。亮/暗/纯黑三主题完全相同。
  - 个人角标:底色 `colorScheme.primaryContainer`(= `VeloBrand.selection`,`mono_theme.dart:122`)、人形图标和文字 `colorScheme.onPrimaryContainer`(= 强调色,`:123`);不透明,亮暗各自取值。亮色下 `6256C8` 压在 `E9E5F6` 上对比度约 5:1,过 4.5:1。
- 做法:
  1. 新增 `lib/theme/poster_overlay_colors.dart`:`abstract final class PosterOverlayColors { static const scrim = Color(0x9E000000); static const onScrim = Colors.white; }`。`scrim` 的 alpha(.62)是本卡默认值,放 theme 目录即不计入 R8-4 的统计,真机看亮色海报时可调。
  2. `MediaCardRatingBadge.build` 里按 `personal` 分支取色;`InlineRatingBadges` 传 `textStyle` 与 `foregroundColor` 为 `onScrim`(其内部非品牌图标用 `foregroundColor`)。
  3. 不改尺寸:`padding horizontal 6 / vertical 4`、字号 11、图标 11/12 不变。
- 品牌图标(IMDb 黄、RT 红绿等)在深色底上可读,不加描边。

### R5-6 评分条高度按实际数量 + 加载占位

- 现状:`media_ratings_strip.dart:59` `SizedBox(height: heightFor(width, scaler, slots: maxRatings))`,只有 1 个评分也占满 4 个槽位的高度;大字号下空白更明显(audit N4)。加载中(`_isLoadingMetadata`,`media_detail_screen.dart:354`)条为空则整条 `SizedBox.shrink()`(`:48`),没有占位,Plex 列表项进详情后补全评分会推动下方内容跳动。
- 改成:
  - 有评分:高度由内容决定(R5-2 已删固定高),1-2 个评分只占一行的自然高度,**不预留空高度**。
  - 新增参数 `bool loading = false`:当 `loading && ratings.isEmpty` 时返回一个高度等于"一行单元格自然高度"的空 `SizedBox`(占位,不画骨架动画);`loading` 结束后若仍无评分则收为 0 高度(这一次跳动无法避免,接受)。
  - 已有评分(列表接口带来的 1-2 项)时即使 `loading` 也直接显示,补全后行数不变则不跳动。
- 调用点:`presentation.dart:221` 与 `responsive_layout.dart:161` 传 `loading: _isLoadingMetadata`。占位高度可用 `kRatingsStripPlaceholderHeight` 静态方法按 `size` 与 `textScaler` 算:图标/数字行 `numberSize * 1.2` + 2 + 来源名 `nameSize * 1.2` + 上下内边距各 4,大致 compact 约 52、large 约 62(未量,动手后以实测为准,待核对)。
- 要删/改的现有测试:`media_ratings_strip_test.dart:69` "filling additional sources does not change the reserved region height"(见 R5-10)。

### R5-7 Jellyfin / Emby 评分字段:结论"不做",仅加注释

- 现状:`jellyfin_mappers.dart:428-441` 只读 `CommunityRating`(→`audience`,0-10)和 `CriticRating`(→`rottenTomatoesCritic`,0-100 除以 10)。Emby 复用同一 mapper(`jellyfin_client_emby_dialect_test.dart` 走同一方言路径)。
- 核对结论:
  - 代码内另有字段 `ProviderIds` 被读取(`jellyfin_client/parts/browse.dart:286-289`、`playback.dart:1115-1117`,经 `ExternalIds.fromJellyfinProviderIds`),但只用来取 Tmdb/Imdb/Tvdb **ID**(给 Trakt、外部 ID 匹配用),值是 `"tt0111161"`、`"278"` 这类标识,不是分值。
  - 据 Jellyfin/Emby 公开 `BaseItemDto` 字段:评分相关只有 `CommunityRating`、`CriticRating`(以及 `UserData` 里的个人评分),没有 per-source 评分数组;现有代码注释(`jellyfin_mappers.dart:417-419`)也是同样的判断。**此结论来自代码与公开字段,未用真实服务器响应抽样,标"待核对"**:核对方法是对一台 Jellyfin 和一台 Emby 请求 `GET /Items/{id}?Fields=ProviderIds,CommunityRating,CriticRating`(不要贴出服务器地址/令牌),确认响应里没有 IMDb/TMDB 分值字段。
  - 想拿 IMDb/TMDB 分值只能拿 ID 再去 OMDb/TMDB 等外部服务查,需要新凭据与第三方依赖,违反禁止事项。
- 结论:**不做**。动作只有一个:在 `jellyfin_mappers.dart:428` `_ratingSources` 的文档注释末尾补两行,写明"服务端只提供 CommunityRating/CriticRating;ProviderIds 仅含外部 ID 无分值,IMDb/TMDB 分值不由服务端提供,故不映射,也不从外部抓取"。不改逻辑、不加测试。
- 顺带记录(audit N9,不处理):Jellyfin 的 `CriticRating` 被标为 `rottenTomatoesCritic`,即使服务端实际数据并非 RT;属既有取舍,不动。
- 把"做/不做 + 依据 + 是否已抽样核对"写进该提交说明。

### R5-8 19 个语言补译 12 个英文占位 key

- 现状:`lib/i18n/` 下 22 个语言文件。`en`、`zh`、`zh-Hant` 有译文;其余 19 个文件(已逐个核对,12 个 key 的值全部等于英文原文)是占位:
  `az bg da de es fr hu it ja kk ko nb nl pl pt ru sv tr uz`(文件名均为 `<code>.i18n.json`)。
- key 表(英文与中文原文逐字抄自 `en.i18n.json` / `zh.i18n.json`):

| 位置 | key | en | zh |
|---|---|---|---|
| `settings` | `ratings` | Ratings | 评分展示 |
| `settings` | `showRatingBadges` | Show ratings on posters | 显示海报评分 |
| `settings` | `showRatingBadgesDescription` | Show your score first, or the first available enabled source. Continue Watching stays score-free. | 优先显示你的评分，否则显示首个可用的已启用来源。继续观看不显示评分。 |
| `settings` | `ratingSources` | Rating sources | 评分来源 |
| `settings` | `ratingSourcesDescription` | Enable sources and move them up or down to set their display order. Only scores supplied by your media service are shown. | 启用来源，并上移或下移调整展示顺序。仅展示媒体服务已提供的评分。 |
| `settings` | `otherRatingSources` | Other ratings | 其他评分 |
| `settings` | `moveRatingUp` | Move up | 上移 |
| `settings` | `moveRatingDown` | Move down | 下移 |
| `settings` | `ratingSettingsSaveFailed` | Could not save rating preferences. Try again. | 无法保存评分偏好，请重试。 |
| `detailPlayback` | `version` | Version | 版本 |
| `detailPlayback` | `unavailable` | Not available | 暂无可用选项 |
| `detailPlayback` | `loadFailed` | Could not load playback options | 播放选项加载失败 |

- 做法:
  1. 按语言分批,**一个提交一个语言(或一组相近语言,如 `nb` + `da` + `sv`)**,只改该语言文件里这 12 个 key 的值,键名与顺序不动(`clean_translations.py` 会按 `en` 的结构规范化)。
  2. 参考已有译文的措辞:同一文件里 `settings` 与 `detailPlayback` 下相邻 key 的用语(如"版本"在该语言里别处怎么说)。`version` 在 `da/de/fr/nb/nl/sv` 等语言里可能确实与英文拼写相同,写原词即可,这属于正确译文不是漏翻。
  3. 保留占位符与标点规则;这 12 个 key 都没有 `${}` 参数。
  4. 改完运行:`dart run slang`(CONTRIBUTING.md 的 i18n 一节;全量再生成用 `scripts/codegen.sh`,内部也会执行 `dart run slang`)。不手改 `lib/i18n/strings*.g.dart`。
  5. 机器翻译质量待人工/母语复核:提交说明写明"机翻,待母语复核"。
- 自查脚本(在仓库根执行,只读;输出每个语言仍等于英文的 key 数):
  `python3 -c "import json,glob;e=json.load(open('lib/i18n/en.i18n.json'));ks=[('settings',k) for k in 'ratings showRatingBadges showRatingBadgesDescription ratingSources ratingSourcesDescription otherRatingSources moveRatingUp moveRatingDown ratingSettingsSaveFailed'.split()]+[('detailPlayback',k) for k in 'version unavailable loadFailed'.split()];[print(f,sum(j[s][k]==e[s][k] for s,k in ks)) for f in sorted(glob.glob('lib/i18n/*.i18n.json')) for j in [json.load(open(f))]]"`
  完成后 19 个语言应为 0(或仅 `version` 等确属同形词的 1-2 个,在提交说明里列出)。

### R5-9 卡片角标重复计算

- 现状:`media_card.dart:483-488` 在 `_buildContent` 里写了一遍条件(`showRatingBadge && !isInContinueWatching && showRatingBadges 设置 && item is MediaItem && (movie||show||episode)`)再调 `mediaCardRatingFor`;`:662` 在 `_buildPosterStack` 里**先无条件**调 `mediaCardRatingFor(item)`,`:664-669` 再把同一组条件写第二遍。角标关闭或继续观看卡也每次 build 都算一次(要读设置、选择排序)。
- 改成:抽一个私有方法 `MediaRatingSource? _cardBadgeRating(Object item)`:内部先判全部条件,任一不满足直接返回 `null`,满足才调 `mediaCardRatingFor(item)`。`:483` 与 `:662-669` 都改为调用它,`:664-669` 的条件块缩成 `if (badgeRating != null)`。
- 行为不变:语义标签 `:489-492` 仍包含评分;关闭设置后角标消失;继续观看卡无角标。不改 `_buildPosterStack` 的签名(它有两处调用 `:610`、`:712`,把 `badgeRating` 当参数传需要同时改,收益不大,本卡不做)。

### R5-10 测试(详见"测试要求")

## i18n key 与常量表

| 名称 | 类型 | 默认值 | TODO 编号 | 说明 |
|---|---|---|---|---|
| 新增 i18n key | - | 无 | - | 本包不新增 key;R5-8 只补译已有 12 个 key |
| `RatingDisplayPolicy.detailLimit` | 常量(已有) | 4 | 新增 `TODO(VELO-P3-02)`(C2) | 默认值,产品可改为 5 |
| `RatingDisplayPolicy.heroLimit` | 常量(已有) | 2 | 沿用 `VELO-P3-01` | 不动 |
| `RatingsStripSize.compact/large` | 枚举(新增) | `compact` | - | 手机/竖屏平板用 compact;≥720 宽桌面与 TV 用 large |
| compact 尺寸 | 常量 | 数字 18 / 图标 16 / 来源名 11 / 竖线 1px | - | 数字与来源名为第一轮规格;图标 16 为本卡默认值 |
| large 尺寸 | 常量 | 数字 22 / 图标 20 / 来源名 12 / 间距 28 | - | 数字 22、间距 28 为第一轮规格;图标 20 为本卡默认值 |
| `PosterOverlayColors.scrim` | 颜色常量(新增) | `Color(0x9E000000)`(黑 62%) | - | 默认值,产品可改 |
| `PosterOverlayColors.onScrim` | 颜色常量(新增) | `Colors.white` | - | - |
| 设置项 | - | 无新增 | - | `showRatingBadges`(默认开)、`ratingSourceOrder`、`disabledRatingSources` 沿用 |

第一轮 P7 的"评分图形(自绘替代图形时)"颜色,仅在以后确需自绘评分图形时使用,本卡不用(全部复用现有 svg):

| 语义 | 亮色 | 暗色 |
|---|---|---|
| 红 | `#D93A26` | `#F0503C` |
| 琥珀 | `#C98A12` | `#F2B33D` |
| 青 | `#1F9C88` | `#5BC8B5` |

## TV 焦点与三主题、四形态要求

- TV 焦点:条本身不可聚焦(纯展示,保持现状);其语义已由 TV 详情信息块合并朗读(`media_detail_screen.dart:3833` 附近)。个人评分 chip 保持 `FocusableWrapper`,方向键下→播放按钮、上→信息块/返回键、左右被消费(`:1181-1197`),本卡不得改变。条的高度变化后,TV 上聚焦 chip 时 `_revealTvDetailForeground(_tvDetailRatingsGroupKey)` 仍要把"条 + chip"整组滚到可见,需在 TV 形态下目视确认。
- 三主题:
  - 亮色/暗色/纯黑下,详情条的数字用 `onSurface`(TV 用 `_tvDetailForegroundColor`),来源名 78% 透明;分隔线亮暗同为 8%-10% 正文色。
  - 卡片角标三主题完全一致(深色半透明底 + 白字);个人角标亮/暗各取 `primaryContainer`/`onPrimaryContainer`。纯黑主题下 `primaryContainer` 沿用暗色值(`mono_theme.dart` 对 oled 只换表面 `0A0A0A`),待目视确认。
  - 品牌 svg 三主题不变色。
- 手机:compact,等分列 + 竖线,4 列;320px / 200% 字号下按行数换行,无溢出。个人 chip 在非紧凑 hero 时在条下方(`presentation.dart:222-224`)。
- 平板:竖屏平板 `centered` 为真,用 compact;横屏平板(≥720 且 `isLandscapeTablet`)左对齐,用 large。
- 桌面:窗口 ≥720 宽走 large,左对齐;<720 走 compact 居中。内容最大宽 720(`responsive_layout.dart:75`)。
- TV:large,`foregroundColor` 由 TV 前景色传入;条无焦点。

## 测试要求

修改现有测试:
1. `test/widgets/media_ratings_strip_test.dart:69` `filling additional sources does not change the reserved region height`:该语义被 R5-6 取代。改名为 `height follows the number of rows, not the slot limit`,断言:320px/1.0 缩放下 4 个评分正好 1 行,所以 1 个与 4 个评分高度相等;1 个评分时用 `maxRatings: 4` 与 `maxRatings: 8` 两次构建,高度相等;再加 320px/2.0 缩放下 4 个评分(2 行)高度大于 1 个评分(1 行)。
2. `:60` 循环用例名里的 "stable maximum of four" 保留;补 `count == 4`(循环改 `[0, 1, 2, 4, 5]`),断言 4 个都出现、第 5 个(`simkl` 8.2)不出现。
3. `:76` `320px at 200% text...`:加断言 `tester.takeException()` 为空(已有),并确认两个主题下 `92%`、`79%` 仍可见。
4. `test/screens/media_detail_screen_test.dart`:不预期要改,但这些位置依赖条几何,必须回归:`:478`(个人 chip 高度)、`:2246-2247`、`:2631-2632`、`:2737-2752`(条与 chip 的相对位置)。若失败,按新的自然高度修正期望,不得放宽到失去检查意义。

新增测试:
- `test/widgets/media_ratings_strip_test.dart`
  - `each branded source shows its icon`:对 `imdb/tmdb/rottenTomatoesCritic/rottenTomatoesAudience` 各一次,`find.byType(SvgPicture)` 数量等于有图标的评分数;
  - `sources without an svg fall back to text only`:`simkl` 或 `audience`,无 `SvgPicture`,数字与来源名文字仍在;
  - `compact variant draws dividers between cells, large variant does not`:2 个评分 compact 下 `find.byType(VerticalDivider)` 为 1,large 为 0;
  - `large variant uses 22pt numbers`:`tester.widget<Text>(find.text('92%')).style?.fontSize == 22`,compact 为 18;
  - `loading with no ratings reserves one row, then collapses`:`loading: true` 时高度 > 0,换成 `loading: false` 且无评分高度为 0;`loading: true` 且已有评分时不显示占位;
  - `five ratings wrap evenly instead of squeezing`(若 C2 定 5 或把 `maxRatings` 设 5):320px 下行数为 2、每行不超过 3 个。
- `test/widgets/media_card_full_card_test.dart`(在 `:128` 用例旁)
  - `poster badge is dark translucent with white text in light and dark themes`:`ThemeData(brightness: light)` 与 dark 各 pump,取 `MediaCardRatingBadge` 内 `Container` 的 `BoxDecoration.color == PosterOverlayColors.scrim`,文字颜色 `== PosterOverlayColors.onScrim`;
  - `personal rating badge uses the selection container color`:`userRating: 9` 时底色 `== colorScheme.primaryContainer`,文字 `9.0/10` 颜色 `== onPrimaryContainer`;
  - `badge rating is not computed when disabled`:关闭 `showRatingBadges` 后卡片不渲染角标(行为断言;计算次数无法直接断言,不强求)。
- `test/utils/rating_display_policy_test.dart`:`detail limit trims 0/1/2/4/5 ratings in default order`,用 `RatingDisplayPolicy.detailLimit` 取值,不写死 4;另 `detailLimit is 4 by default`(便于改 5 时有意识地改测试)。
- `test/services/jellyfin_mappers_test.dart`:R5-7 不做,不新增;若抽样核对发现服务端带 IMDb/TMDB 分值,则改为按"做"补映射与单测并更新结论。

## 验收清单

- [ ] `flutter analyze` 无新增告警
- [ ] `scripts/run_tests.sh test/widgets/media_ratings_strip_test.dart test/widgets/media_card_full_card_test.dart test/utils/rating_display_policy_test.dart test/screens/settings/rating_settings_screen_test.dart test/widgets/hub_section_test.dart test/widgets/tv_browse_rail_test.dart`
- [ ] `scripts/run_tests.sh test/screens/media_detail_screen_test.dart test/screens/discover_screen_test.dart test/services/jellyfin_mappers_test.dart`
- [ ] `scripts/run_tests.sh` 全量通过
- [ ] `scripts/codegen.sh --check` 通过(R5-8 之后)
- [ ] `python3 scripts/checks/clean_translations.py --check --strict` 通过
- [ ] 手动:详情页有 IMDb/TMDB/RT 评分的片子,每格有图标 + 数字 + 来源名;Jellyfin 条目(只有 `audience`)显示数字 + 来源名,无图标且数字不错位
- [ ] 手动:手机 320px/390px,2 个与 4 个评分,竖线只在格间,等分;系统字体 200% 无溢出
- [ ] 手动:桌面窗口 ≥720 宽,左对齐,间距 28,数字 22;<720 回到居中等分
- [ ] 手动:只有 1 个评分时条下方无多余空白;Plex 列表进入详情,评分补全时下方内容不跳动
- [ ] 手动:亮/暗/纯黑下,在浅色和深色海报上,卡片角标都可读;个人评分角标显示强调色且亮色下可读
- [ ] 手动(TV):方向键从信息块 → 个人评分 chip → 播放按钮,聚焦 chip 时条与 chip 整组可见
- [ ] 手动:设置 → 评分,开关/排序后详情条与卡片角标即时更新
- [ ] 手动:把语言切到 de、ja、ru(任选 3 个已补译语言),评分设置页和详情页版本选择器文案为该语言
- [ ] `git grep -n 'TODO(VELO-P3-02)' lib` 命中 1 处

## 提交拆分

1. `refactor(评分): 抽出评分来源图标小部件供评分条复用`
2. `feat(评分): 详情评分条单元格加来源图标`
3. `feat(评分): 评分条手机分隔线与桌面/TV 大号变体`
4. `fix(评分): 评分条高度按实际数量并加加载占位`
5. `docs(评分): 详情评分上限改为具名常量并加 TODO(VELO-P3-02)`
6. `feat(评分): 卡片角标改深色半透明底白字,个人评分用选中底`
7. `refactor(评分): 合并卡片角标重复条件,关闭时跳过评分计算`
8. `docs(评分): 注明 Jellyfin/Emby 服务端不提供 IMDb/TMDB 分值`
9. `feat(i18n): 评分与播放选项文案补译 <语言>`(每个语言或每组相近语言一个提交,共 19 个语言)
10. `test: 评分条图标/变体/占位与卡片角标样式用例`(也可把每个测试并入对应功能提交;现有测试的修改必须与改动同一提交,保证每个提交测试都绿)

## 风险与待确认

1. 等分列补位:只有 2 个评分时,"等分补空列"会让两格偏左占一半宽度。备选是 2 个评分时居中、列宽取内容宽。默认按等分补位,与第一轮"手机等分列"一致;目视不满意时再改,不影响结构。
2. 图标尺寸 16/20、`scrim` 62% 是本卡默认值,第一轮规格未给,需设计过目。
3. C2(上限 4/5)、C3(个人评分并入)待产品;默认值已写死。
4. R5-7 结论未用真实服务器响应核对(待核对,方法见 R5-7)。
5. 纯黑主题下个人角标的 `primaryContainer` 取值待目视。
6. 19 个语言机翻质量需母语复核。
7. 占位高度具体数值未量(R5-6),以实测为准。

## 禁止事项

- 不直接改生成的 Dart 文件(`lib/i18n/strings*.g.dart` 等);改 `lib/i18n/*.i18n.json` 后运行 `dart run slang`,全量生成用 `scripts/codegen.sh`,检查用 `scripts/codegen.sh --check`。
- 不删除 Plex/Jellyfin/Emby、一起看、TV 支持;不改 mpv/ExoPlayer。
- 不引入需要新凭据的第三方评分数据源(OMDb、TMDB API 等),不从 `ProviderIds` 反查外部评分。
- 不新增自绘评分图形,图标只用 `assets/rating_icons/` 现有 6 个 svg。
- 不在 widget 里新写十六进制颜色;角标色放 `lib/theme/`。
- 不动个人评分 chip 的交互与 key(R5-4 默认);不动 `hero_metadata_badges.dart`(R1)。
- 不提交凭据、构建产物、本地参考文件;保留 Plezy 上游署名。
