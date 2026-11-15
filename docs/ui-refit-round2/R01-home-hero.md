# R01 首页头图只展示影片信息

- 基线提交:`8885b39`(2026-11-12,工作区干净)。本文行号均在此基线上逐文件核对过。
- 核对方式:静态读码,未运行(本环境无 flutter,`flutter analyze` 与测试都没跑过);凡标"待核对"的需在有 flutter 的环境确认。
- 目标:首页轮播(手机/平板/桌面;TV 见下方"重要发现")只展示影片信息,不再有播放、详情、下载、版本/音频类控件,点击统一进入详情页。
- 优先级:高(用户明确要求,第一轮漏做)。
- 规模:中。
- 前置依赖:无。R2-2(`hero_metadata_badges.dart` 死分支)与本包改同一个文件的不同位置,先做 R1 再做 R2-2。
- 不在范围:详情页(见 R10);`tv_spotlight_background.dart` 的简介行数/布局(见 R1-8 待确认);播放器、mpv/ExoPlayer、一起看、Plex/Jellyfin/Emby 数据层;头图文字颜色策略(亮色下"有海报时强制白字"保持现状,见 C5);页码指示点的样式。

## 0. 与第二轮清单不一致的地方(先读)

| # | 清单说法 | 实际代码 | 本卡处理 |
|---|---|---|---|
| D1 | "TV 首页用的是 `discover_screen.dart` 里的头图""TV 焦点节点近似 `:1407`" | `discover_screen.dart:1184` 起 `_buildContent` 在 `PlatformDetector.isTV()` 时直接 `return` 到 `_buildTvContent`(`:1343` 起,用 `TvSpotlightScaffold`),**从不调用 `_buildHeroSection`**。TV 没有轮播、没有页码点,上方"聚光图"随海报行焦点变化(`tv_spotlight_background.dart`),本身已无按钮、评分 ≤2(`:349`)。`_buildHeroItem` 里所有 `isTv` 分支是死代码 | TV 不改点击/按钮;R1-1~R1-7 只对手机/平板/桌面生效;TV 只做 R1-8 的核对。默认决策里"TV 轮播项保持可聚焦,确认键进详情"对 TV 不适用(TV 没有轮播),只对"键盘桌面"适用 |
| D2 | 清单称头图含"下载、版本/音频信息"需删 | 头图里**没有下载按钮**。"版本/音频/画质"来自 `HeroMetadataBadges`:`hero_metadata_badges.dart:34` 的 `...buildMediaQualityLabels(item)`(4K、HDR、DV、音频编码标签) | 删的是这一行(R1-4),不是某个按钮 |
| D3 | 清单称元数据含"年份·时长·类型·分级" | 现有 `HeroMetadataBadges` 的 labels 是 年份、分级、画质/音频、类型,**没有时长** | R1-4 补时长 |
| D4 | 清单 R1-7 称 TV 焦点依赖"`:~1407` 的焦点节点" | `:1406-1408` 是整段头图外面的 `Focus(focusNode: _heroFocusNode, onKeyEvent: _handleHeroKeyEvent)`,不是播放按钮上的节点。键盘选中键已经是进详情(`:598-600` `_openHero(_heroItems[heroIndex])` 不带 `play`) | 删按钮不影响该焦点节点;不需要新增 focusable 包装 |
| D5 | 清单 R1-2 称桌面分支在 `:1773,1829` 调用 `_buildSmartPlayButton` | 实际在 `:1784` 与 `:1830`;`:1784` 的 `if (!alignLeft)` 在该分支内**永远为假**(`:1558` 分支条件已把 `!alignLeft` 的情况提前 return 到 `FusionHomeHero`),是死代码 | 两处一并删除 |

分支划分(`_buildHeroItem`,`discover_screen.dart:1558`):`isLargeScreen = width >= 900`,`alignLeft = isTv || isLargeScreen`。
- 分支 A(`:1568` `if (!alignLeft || MonoPresentation.isTablet(context))`):手机、所有平板(含横屏大宽度)→ `FusionHomeHero`(`lib/widgets/fusion_home_hero.dart`)。`isTablet` 要求移动平台且短边 ≥ 600。
- 分支 B(`:1568` 之后的内联布局,`:1611-1840`):桌面(Windows/macOS/Linux)宽度 ≥ 900,以及移动平台短边 <600 但宽度 ≥ 900 的横屏大屏手机;TV 理论上也进(死代码,见 D1)。

## 1. 涉及文件表

| 文件 | 行号(基线) | 现状 | 动作 |
|---|---|---|---|
| `lib/widgets/fusion_home_hero.dart` | `:21` | `canPlayHomeHeroDirectly`,仅被按钮与 `_openHero` 使用 | 删 |
| 同上 | `:26-37, :40-42` | 构造参数 `onPlay`(必填)、`playButton`、`detailsButton` | 删两个按钮参数;`onPlay` 改名 `onOpen`;新增 `hideSpoiler` |
| 同上 | `:56, :137-155` | 手机/平板已有外文原名(Georgia 9px 大写,`:143` 写死字体名) | 改为用共享组件 `HeroOriginalTitle` |
| 同上 | `:87-91` | `Semantics(label: title, button: true)` 无 hint,`GestureDetector(onTap: onPlay)` | 加 `hint`;回调改 `onOpen` |
| 同上 | `:167-182` | `HeroMetadataBadges` 之后是 `if (playButton != null \|\| detailsButton != null)` 的按钮 Wrap | 删 Wrap,在原位插入简介 |
| 同上 | `:196-303` | `HomeHeroPrimaryButton`(白底黑字写死,含 `home-hero-play-progress` 进度条 key) | 删整个类 |
| `lib/widgets/hero_text_blocks.dart` | 新文件 | 不存在 | 新增:`HeroOriginalTitle`、`HeroSummary` 两个无状态组件 |
| `lib/widgets/hero_metadata_badges.dart` | `:34` | labels 含 `buildMediaQualityLabels(item)` | 删该行,补时长,调整顺序 |
| `lib/screens/discover_screen.dart` | `:1539-1556` | `_openHero(item, {bool play = false})`,`play` 且可直接播放则 `navigateToVideoPlayer` | 删 `play` 参数与该分支 |
| 同上 | `:1568-1609` | 分支 A:传 `onPlay`、`playButton: _buildSmartPlayButton`、`detailsButton: ...`(`:1575-1604`) | 删两个按钮实参;改 `onOpen`;传 `hideSpoiler` |
| 同上 | `:1646-1654` | 分支 B 外层 `Semantics(hint: t.accessibility.tapToPlay)`、`onTap` 调 `_openHero(heroItem, play: true)` | hint 换新 key;去掉 `play: true` |
| 同上 | `:1742-1829`(约) | 分支 B 内容列:Logo/标题 → 元数据 → (死代码按钮 `:1784`) → 简介(`:1786-1822`,TV 3 行/其他 2 行,空串时显示 `noDescriptionAvailable`)→ 按钮(`:1830`) | 顶部补外文原名;简介改共享组件、桌面 3 行;删两处按钮 |
| 同上 | `:1845-1862` | `_buildSmartPlayButton` | 删 |
| 同上 | import `:14,:17,:30,:31,:69` 等 | `focusable_button.dart`、`input_mode_tracker.dart`、`press_feedback.dart`、`interaction_tokens.dart`、`video_player_navigation.dart` 疑似随之无用 | 以 `flutter analyze` 的 `unused_import` 为准逐个删 |
| `lib/i18n/*.i18n.json`(22 个) | `en:727` 等 | `accessibility.tapToPlay` | 新增 `tapToOpenDetails`;最后单独提交删 `tapToPlay` |
| `test/widgets/f4_home_feedback_test.dart` | `:152-177, :186-399` | 引用 `HomeHeroPrimaryButton`、`playButton`、`detailsButton`、`onPlay` | 改(见第 6 节) |
| `test/screens/discover_screen_test.dart` | `:497-526` | 断言 `hero.detailsButton`、`HomeHeroPrimaryButton` | 改 |
| `test/navigation/fusion_navigation_test.dart` | `:204-210, :274-281, :307-312, :349-352` | 引用 `playButton`、`onPlay`、点 `t.common.play`、断言 `4K` 存在 | 改 |
| `test/widgets/home_hero_blend_test.dart` | `:38` | `onPlay: () {}` | 改名为 `onOpen` |

## 2. 逐步修改说明

### R1-1 FusionHomeHero 删除按钮参数与 Wrap
- 现状:`fusion_home_hero.dart:31-32` 构造参数 `playButton`、`detailsButton`;`:41-42` 字段;`:173-182` 在元数据之后渲染 `Wrap(children: [?playButton, ?detailsButton])`。
- 改成:三者全部删除,头图内容不再为按钮留间距(`:174` 的 `SizedBox(height: 12)` 随 Wrap 一起删)。
- 做法:删参数、字段、`:173-182` 整块。头图外层 `Positioned`(`:111-115`)的 `bottom: 28`、`SingleChildScrollView(reverse: true)`、`maxWidth: 560` 不动(大字号下仍靠它滚动)。
- 说明:此步单独编译不过(调用方还在传),与 R1-5、R1-7 放在同一提交。

### R1-2 点击回调改名并补无障碍提示
- 现状:`required this.onPlay`(`:30`)实际是"点头图";`Semantics`(`:87-89`)只有 `label`/`button`,无 hint。
- 改成:`required this.onOpen`(`VoidCallback`);`Semantics` 加 `hint: t.accessibility.tapToOpenDetails`。
- 做法:全仓 `grep -rn "onPlay:" lib test` 找出 `FusionHomeHero` 的调用(基线只有 `discover_screen.dart:1573` 与 4 处测试),只改 `FusionHomeHero(` 的实参;`HomeHeroPrimaryButton.onPlay` 随类删除。

### R1-3 新增共享文本组件,并给手机/平板补简介
新增文件 `lib/widgets/hero_text_blocks.dart`(无状态组件,不读 Provider):
```dart
class HeroOriginalTitle extends StatelessWidget {
  const HeroOriginalTitle({super.key, required this.item, required this.displayTitle,
      required this.color, this.fontSize = 9, this.textAlign = TextAlign.center});
  // originalTitle trim 后为空,或与 displayTitle 忽略大小写相同 -> 返回 SizedBox.shrink()(不占位)
  // 样式沿用 fusion_home_hero.dart:139-153:大写、maxLines 1、ellipsis、fontFamily 'Georgia'、
  // fontFamilyFallback ['Go Noto Current','serif']、height 1.2、letterSpacing 2.5、color.withValues(alpha:.8)
}
class HeroSummary extends StatelessWidget {
  const HeroSummary({super.key, required this.item, required this.hideSpoiler,
      required this.maxLines, required this.fontSize, required this.height,
      required this.color, this.textAlign = TextAlign.center});
  // 取值与分支 B 现有逻辑一致(discover_screen.dart:1786-1822):
  //  - hideSpoiler 为 false 且 summary 非空:RichText,剧集前缀 "S{parentIndex}, E{index}: " 加粗
  //  - hideSpoiler 为 true 且是剧集:只显示 "S?, E?: 标题"(maxLines 2)
  //  - 其余(summary 为 null 或空串):SizedBox.shrink()。**不再显示 t.messages.noDescriptionAvailable**
  // 该 key 改后可能无人使用,保留不删(删它要动 22 个语言文件),在提交说明里注明
}
```
- `FusionHomeHero` 新增 `final bool hideSpoiler`(默认 false)。在 `HeroMetadataBadges` 之后插入:
  `SizedBox(height: 12)` + `HeroSummary(maxLines: 2, fontSize: tablet ? 14 : 13, height: 1.4, color: metadataStyle.color!.withValues(alpha: .8), textAlign: textAlign, ...)`。`HeroSummary` 返回空时连前面的 12 间距也不应出现:调用处用 `if (hasSummaryContent)` 判断(提供一个同文件的顶层函数 `bool heroHasSummary(MediaItem item, bool hideSpoiler)` 供两个分支共用)。
- 手机头图高度:原来按钮占约 60dp,现在换成 2 行简介(约 40dp),总高不增;`touchHeroHeight` 不改。
- `discover_screen.dart` 分支 A 调用处新增 `hideSpoiler: SettingsService.instance.read(SettingsService.hideSpoilers) && heroItem.shouldHideSpoiler`(与 `:1640` 同写法)。

### R1-4 元数据行去掉版本/音频/画质,补时长
- 现状:`hero_metadata_badges.dart:31-36` 的 `labels = {年份, 分级, ...buildMediaQualityLabels(item), ...类型(≤2)}`;**无时长**。
- 改成:`labels = {年份, 时长, ...类型(≤2), 分级}`(顺序即展示顺序,评分仍在最前,最多 `RatingDisplayPolicy.heroLimit` = 2 个,策略不动)。
- 做法:
  - 删 `...buildMediaQualityLabels(item)`;同时删 `import '../utils/media_quality_labels.dart'`(`:8`)。
  - 加 `if (item.durationMs != null && item.durationMs! > 0) formatDurationTextual(item.durationMs!)`(`lib/utils/formatters.dart:56`,已本地化,详情页 `presentation.dart:203` 同用);需 `import '../utils/formatters.dart'`。
  - 分级位置从第二位挪到最后,与"年份·时长·类型·分级"一致。
  - 不改 `lightInk`、★ 分支(`:29`、`:58-60`,归 R2-2)。
- 该组件仅被首页头图与两个测试使用(`grep -rn "HeroMetadataBadges" lib test` 核对:`discover_screen.dart:1777`、`fusion_home_hero.dart:167`,测试 `fusion_navigation_test.dart`、`media_ratings_strip_test.dart:109`),可安全改。

### R1-5 分支 A(手机/平板)调用处
- 现状:`discover_screen.dart:1569-1609` 传 `onPlay`、`playButton`、`detailsButton`(`:1575-1604`,含 `PressFeedbackBuilder`/`FocusableButton`)。
- 改成:只传 `item`、`client`、`compact`、`onOpen: () => _openHero(heroItem)`、`hideSpoiler`、`backdrop`。
- 做法:删 `:1574-1604`;`backdrop: CyclingMediaBackdrop(...)`(`:1605-1618`)不动。

### R1-6 分支 B(桌面/宽屏)内容与点击
现状 → 改成:
1. 外文原名:在内容 `Column` 最前面、Logo/标题 `LayoutBuilder`(`:1750`)之前加 `HeroOriginalTitle(item: heroItem, displayTitle: showName, color: colorScheme.onSurface, fontSize: 10, textAlign: alignLeft ? TextAlign.left : TextAlign.center)` + `SizedBox(height: 8)`(组件为空时不要这 8 的间距,同 R1-3 的判断函数思路)。
2. 元数据:保持 `HeroMetadataBadges`(`:1777-1782`)。
3. 简介:`:1786-1822` 换成 `HeroSummary`,`maxLines: 3`(桌面与 TV 死代码路径统一取 3;原来非 TV 是 2),`fontSize: isTv ? 18 : 14`,`height: isTv ? 1.45 : 1.4`,`color: colorScheme.onSurface.withValues(alpha: .7)`,保持 `hideSpoiler` 语义。
4. 删 `:1784` 的 `if (!alignLeft) ...[... _buildSmartPlayButton]` 与 `:1830` 的 `if (alignLeft) ...[... _buildSmartPlayButton]`。
5. 点击:`:1651-1654` 的 `_openHero(heroItem, play: true)` 改为 `_openHero(heroItem)`;`:1648` 的 `hint: t.accessibility.tapToPlay` 改 `t.accessibility.tapToOpenDetails`。`ClickableCursor` 外壳(鼠标手型)保留。
6. `Positioned.bottom`(`:1711`)按钮没了以后内容整体下沉,**目视核对**桌面 900/1280/1920 宽度下标题区不贴底、不顶到顶栏;必要时 `bottom` 取值(TV 88 / 紧凑 24 / 大屏 80 / 其他 50)微调,调了要写进提交说明。

### R1-7 删除无用代码
- 现状:`HomeHeroPrimaryButton`、`_buildSmartPlayButton`、`canPlayHomeHeroDirectly`、`_openHero` 的 `play` 参数。
- 改成:全部删除。
- 删前验证命令(基线结果:仅 discover_screen、fusion_home_hero 及两个测试文件命中,文档除外):
  ```bash
  grep -rn "HomeHeroPrimaryButton\|canPlayHomeHeroDirectly\|_buildSmartPlayButton" lib test scripts
  grep -rn "navigateToVideoPlayer" lib/screens/discover_screen.dart   # 基线只有 :1546 一处
  grep -rn "home-hero-play-progress" lib test                         # 基线:fusion_home_hero.dart:273、f4_home_feedback_test.dart:307
  ```
  删完后三条 grep 在 `lib`/`test` 下都应为 0 命中。
- `_openHero` 删 `play` 后只剩 `navigateToMediaItemDetails(context, item)`;`_heroNavigationPending` 仍保留(防重复点击),它原来驱动按钮的 busy 转圈,现在只做防抖,无可见反馈,可接受。
- 清理 import:`flutter analyze` 报 `unused_import` 的逐个删。候选(基线 grep 显示仅按钮代码使用):`discover_screen.dart` 的 `focusable_button.dart`、`input_mode_tracker.dart`、`press_feedback.dart`、`interaction_tokens.dart`、`video_player_navigation.dart`;`context.withFreshWatchState` 来自 `provider_extensions.dart`,该文件是否仍有他用以 analyze 为准;`fusion_home_hero.dart` 的 `material_symbols_icons`、`app_icon.dart`、`press_feedback.dart`、`interaction_tokens.dart`、`i18n/strings.g.dart`(新增 hint 后仍用,别删)。

### R1-8 TV 首页核对(默认不改代码)
- `tv_spotlight_background.dart`:`_buildInfo`(`:199-243`)= Logo/标题 → 元数据行(`:332-389`:类型标签、评分 ≤2、分级、时长、年份)→ 简介(`:216-225`,紧凑 3 行/非紧凑 4 行)。无按钮,无外文原名,无页码点(TV 无轮播)。
- 与默认决策的差异(**待产品确认,默认不做**,因为该组件同时被库/探索页使用,改动会波及它们):① TV 聚光图无外文原名;② 简介 4 行 > 默认决策的 3 行。若要做:给 `TvSpotlightBackground` 加参数(如 `showOriginalTitle`、`summaryMaxLines`),只在首页传值。
- 手动核对:TV 上首页焦点停在海报行时聚光图随焦点变化,无任何按钮;`discover_screen.dart:1406` 的 `_heroFocusNode` 在 TV 路径不挂载,不要为它补焦点。

### R1-9 i18n 与无障碍文案
见第 4 节。`tapToPlay` 在 `lib` 下仅 `discover_screen.dart:1648` 一处使用(`grep -rn tapToPlay lib test --include=*.dart` 核对,排除 `strings*.g.dart`);R1-6 改完后无人使用,单独提交删除 22 个语言文件里的该 key,避免 `scripts/checks/clean_translations.py --unused` 报未使用。

### R1-10 其他形态的行为核对(无代码改动)
- 键盘桌面:`_handleHeroKeyEvent`(`:574-601`)左右切页、下进内容、选中键 `_openHero(_heroItems[heroIndex])` 已是进详情,不改。
- 页码指示点:`:1437-1536` 非 TV 才渲染,可点、带自动滚动进度,不改;回归确认仍显示。
- 评分 ≤2:`HeroMetadataBadges` 内 `limit: RatingDisplayPolicy.heroLimit` 不动。

## 3. 默认值(产品可改)

| 项 | 默认 | 备注 |
|---|---|---|
| 点击行为 | 手机/平板/桌面统一进详情;TV 无轮播(见 D1),保持现状 | 默认值,产品可改(C1) |
| 头图内容 | 标题或 Logo、外文原名(与标题相同或空则不显示)、年份·时长·类型·分级、≤2 评分、简介、页码点 | 默认值,产品可改 |
| 简介行数 | 手机/平板 2 行;桌面 3 行 | 默认值,产品可改 |
| 亮色头图文字 | 保持"有海报时强制白字"(`MonoPresentation.artworkTextColors`,`mono_presentation.dart:64-67`) | 默认值,产品可改(C5) |
| 空简介 | 不显示占位文案 | 默认值,产品可改 |

## 4. i18n key 与常量

| key | en | zh | zh-Hant |
|---|---|---|---|
| `accessibility.tapToOpenDetails`(新增,放在 `tapToPlay` 之后) | Tap to open details | 点击查看详情 | 輕觸即可查看詳情 |
| `accessibility.tapToPlay`(最后一个提交删除) | — | — | — |

其余 19 个语言文件:`tapToOpenDetails` 先填英文 `Tap to open details`(默认决策:其余语言英文占位)。

常量/设置项:无新增。

生成命令(改完 `lib/i18n/*.i18n.json` 后):
```bash
dart run slang                         # CONTRIBUTING.md「Adding New Strings」第 2 步的确切命令
python3 scripts/checks/clean_translations.py --check   # 校验各语言文件与 en 的结构/顺序一致
scripts/codegen.sh --check             # AGENTS.md:检查生成文件是否已同步(完整重新生成用 scripts/codegen.sh,会连带跑其它生成器,一般不需要)
```
`lib/i18n/strings*.g.dart` 是提交进仓库的生成文件,只能由 `dart run slang` 产出,**不手改**。

## 5. TV 焦点、三主题、各形态要求

- TV:不改。`_buildTvContent` 路径没有头图、没有按钮;焦点初始落点 `tv_browse_rail`(`discover_screen_test.dart:455` 已断言)必须保持。`flutter analyze` 与测试通过即可,另在真机/模拟器确认首页首屏聚光图无按钮。
- 三主题(亮/暗/纯黑):头图文字沿用 `HomeTypography`/`artworkTextColors` 的白字;原名、简介、元数据不得写死 `Colors.black`/`Colors.white` 以外的新色值。`HeroSummary` 的颜色由调用方传入。目视:亮色主题下彩色海报上白字可读(现状),纯黑主题下无白色蒙层(`home_hero_blend_test.dart` 守护)。
- 手机竖屏/横屏:简介 ≤2 行不溢出,大字号(系统 200%)下 `SingleChildScrollView(reverse: true)` 仍可滚到标题顶部。
- 平板竖/横:`leftAligned` 横屏平板文字左对齐、其余居中,简介对齐方式随之。
- 桌面 900/1280/1920 宽:分支 B,原名 → 标题 → 元数据 → 3 行简介,左对齐,无按钮;鼠标悬停是手型;点击进详情。
- 无障碍:屏幕阅读器读出标题 + "点击查看详情",不再读"播放";页码点 `Semantics` 与自动滚动的自定义动作不变。

## 6. 测试要求

要改的现有测试(因本次改动必然失败):

| 文件 | 用例/位置 | 原因 | 改法 |
|---|---|---|---|
| `test/widgets/f4_home_feedback_test.dart` | `:152-177` `production hero action routes $kind ...`(4 个 kind) | `HomeHeroPrimaryButton` 删除 | 整组删除;由下方新用例取代 |
| 同上 | `:186-399` `${fixture.name} home fixture uses decoded artwork and the production resume action`(6 个 fixture) | 构造传 `playButton`/`detailsButton`/`onPlay`;断言 `home-hero-play-progress`、`resumeLabel`、`viewDetails` 文案点击 | 改名为 `... shows info only`;`onPlay` → `onOpen`;删按钮实参、`plays`/`details` 里的播放计数、`resumeLabel` 与 `viewDetails` 断言(`:238,:307,:375-378,:385-393`);保留标题可见、`decoded-home-artwork`、导航栏 `options` 断言;大字号分支(`scale > 1`)的 `maxScrollExtent > 0`(`:317`)在无按钮后**可能不成立**,给 fixture item 加长简介(`summary: '…'`)或改为 `>= 0`(待核对,需 flutter) |
| `test/screens/discover_screen_test.dart` | `:497-526` `real home hero $kind exposes one details action and no container playback`(show/season) | 断言 `hero.detailsButton`、`HomeHeroPrimaryButton` | 改名 `real home hero $kind has no action buttons and opens details`:断言头图内无 `ButtonStyleButton`、`InkWell`(按钮类)、`IconButton`;点头图后进入详情路由(参照该文件已有的导航断言写法,待核对) |
| `test/navigation/fusion_navigation_test.dart` | `:176-295` 7 个 `... missing-artwork hero, safe area and navigation remain playable` | `playButton: TextButton(...)`、`ensureVisible/tap(t.common.play)`、`expect(plays, 1)` | 改名去掉 `playable`;`onPlay` → `onOpen`,删 `playButton`;点击改为 `tester.tap(find.byType(FusionHomeHero))` 后 `expect(opens, 1)`;`:274-281` 的 ensureVisible 一并换成对头图 |
| 同上 | `:298-326` `hero badges show genres ...` | `onPlay` | 仅改名;另加 `expect(find.text('1h 46m' 之类时长), ...)` 见下 |
| 同上 | `:327-353` `hero labels wrap at large text and show only known quality` | 断言 `find.text('4K')` 存在 | 改名 `hero labels never show quality or audio badges`:`4K` 与 `HDR` 都 `findsNothing` |
| `test/widgets/home_hero_blend_test.dart` | `:38` | `onPlay: () {}` | 改 `onOpen: () {}` |
| `test/widgets/media_ratings_strip_test.dart` | `:109` 起(`HeroMetadataBadges`) | 行为不变,仅核对 | 运行确认通过 |

要新增的测试:

| 文件 | 用例名 | 断言要点 |
|---|---|---|
| `test/widgets/hero_text_blocks_test.dart`(新) | `original title hidden when empty or equal to title` | 空串、全空白、与标题仅大小写不同 → 找不到该 Text;不同 → 找到且为大写 |
| 同上 | `summary respects max lines and spoiler hiding` | 长文本 `maxLines: 2` 时 `RenderParagraph.didExceedMaxLines` 为真;`hideSpoiler: true` 的剧集只显示 "S1, E2: 标题",不含 summary;summary 为 null/空串 → 无 Text |
| `test/widgets/home_hero_info_only_test.dart`(新) | `FusionHomeHero renders info only` | pump `FusionHomeHero`(含 `originalTitle`、`summary`、`durationMs`、`genres`、`year`、`contentRating`、两个以上 `ratings`):找到原名、简介、年份、时长、类型、分级;评分图标/数值只出现 2 个;`find.byType(FilledButton/OutlinedButton/TextButton/IconButton)` 全部 `findsNothing`;`find.text(t.common.play)` 与 `t.mediaMenu.viewDetails`、`4K` 都 `findsNothing` |
| 同上 | `tap and semantics open details` | 点头图 `onOpen` 触发 1 次;`tester.getSemantics(find.byType(FusionHomeHero))` 的 hint 等于 `t.accessibility.tapToOpenDetails`;无 summary、无原名的 item 不留空白(两个相关 Text 都不存在) |
| `test/screens/discover_screen_test.dart` | `wide desktop hero shows original title, 3-line summary and no buttons` | 把 `debugDefaultTargetPlatformOverride` 设为 `TargetPlatform.windows`(用 try/finally 复原)、`isTv: false`、`size: Size(1280, 720)` 进入分支 B(`_pumpDiscoverShell` 当前无平台参数,待核对是否需加);断言原名可见、无按钮类控件、点击后进入详情而不是播放器(fake 客户端上没有播放启动调用) |
| 同上 | `phone hero tap opens details` | `Size(390, 844)` 点头图进入详情 |

## 7. 验收清单

命令:
- [ ] `flutter analyze` 无新增告警,无 `unused_import`/`unused_element`。
- [ ] `scripts/run_tests.sh` 全绿;至少单独跑过:`flutter test test/widgets/f4_home_feedback_test.dart test/widgets/home_hero_blend_test.dart test/widgets/hero_text_blocks_test.dart test/widgets/home_hero_info_only_test.dart test/widgets/media_ratings_strip_test.dart test/navigation/fusion_navigation_test.dart test/screens/discover_screen_test.dart`
- [ ] `dart run slang` 后 `scripts/codegen.sh --check` 通过;`python3 scripts/checks/clean_translations.py --check` 无差异。
- [ ] 三条 grep 在 `lib`、`test` 下为 0 命中:`grep -rn "HomeHeroPrimaryButton\|canPlayHomeHeroDirectly\|_buildSmartPlayButton" lib test`;`grep -rn "detailsButton\|playButton" lib/widgets/fusion_home_hero.dart lib/screens/discover_screen.dart`;`grep -rn "tapToPlay" lib test --include=*.dart`(排除生成文件后)。

手动(各形态 × 亮色/暗色/纯黑):
- [ ] 手机竖屏:头图只有 原名(若有)→ Logo/标题 → 元数据 → ≤2 行简介 → 页码点;无任何按钮;点击进详情;滑动/页码点切换正常。
- [ ] 手机系统字号 200%:内容可滚动,标题顶部可见,不溢出。
- [ ] 平板竖屏/横屏:同上,横屏左对齐。
- [ ] 桌面 1280×720、1920×1080:内容不贴底、不遮顶栏;原名/元数据/3 行简介;点击与键盘选中键都进详情。
- [ ] 无简介、无原名、无时长的影片:对应行不留空白。
- [ ] 元数据行:无 4K/HDR/DV/音频标签;有时长;评分 ≤2;顺序 年份 · 时长 · 类型 · 分级。
- [ ] TV:首页聚光图无按钮;初始焦点在海报行;确认键行为与改前一致。
- [ ] 屏幕阅读器(TalkBack/VoiceOver):读 "标题,按钮,点击查看详情",不出现"播放"。

## 8. 提交拆分

1. `feat(i18n): 新增头图无障碍提示 accessibility.tapToOpenDetails 并重新生成`
2. `feat(首页): 抽出头图外文原名与简介共享组件并补测试`
3. `feat(首页): 头图元数据去掉版本音频画质并补时长`
4. `feat(首页): 手机与平板头图补两行简介`
5. `feat(首页): 桌面头图补外文原名,简介改为三行`
6. `refactor(首页): FusionHomeHero 点击回调更名为 onOpen`
7. `feat(首页): 头图移除播放与详情按钮,点击统一进入详情页`(含删 `HomeHeroPrimaryButton`、`_buildSmartPlayButton`、`play` 参数、无用 import、测试同步)
8. `chore(i18n): 删除不再使用的 accessibility.tapToPlay`
9. `test: 补头图只展示影片信息的结构与点击测试`(若测试已随各提交补齐,此条合并掉)

## 9. 风险、待确认、禁止事项

风险与待确认:
- D1:TV 无轮播,默认决策中"TV 轮播项保持可聚焦"对 TV 不适用;TV 聚光图缺外文原名、简介 4 行,是否按默认决策补齐需产品确认(R1-8)。
- 大字号下 f4 测试的滚动断言可能失效(第 6 节),需在有 flutter 的环境跑。
- `t.messages.noDescriptionAvailable` 可能变成未使用 key,留待 R8 或后续清理。
- 删按钮后 `_heroNavigationPending` 无可见反馈;若产品觉得点击后无反应,可在头图上加轻量加载态(不在本包)。
- 分支 B 的平台条件导致测试需要覆盖 `debugDefaultTargetPlatformOverride`,待核对 `_pumpDiscoverShell` 是否兼容。
- 亮色头图文字策略未定(C5),本包不动。

禁止事项:
- 不直接改 `lib/i18n/strings*.g.dart`;改 `lib/i18n/*.i18n.json` 后运行 `dart run slang`。
- 不删除或削弱 Plex/Jellyfin/Emby、一起看、TV 支持;不动 mpv/ExoPlayer 后端与其选择逻辑。
- 不引入新的硬编码中英文文案;不提交凭据、构建产物、本地参考文件;保留 Plezy 上游署名。
- 不顺手改其它页面的圆角/颜色(归 R10/R8);一个提交只做一件事。
