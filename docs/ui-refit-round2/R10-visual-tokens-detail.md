# R10 视觉 token 与详情页结构

- 基线提交:`8885b39`(2026-11-12)。行号均在此基线上逐文件核对。
- 核对方式:静态读码,未运行(本环境无 flutter);"待核对"处需在有 flutter 的环境确认。
- 目标:先落地圆角/字阶/分组面三类共享 token,再把详情页对齐第一轮 P7 规格里尚未实现的部分(外文原名、描边元数据、主按钮、进度条、桌面标题字号)。
- 优先级:中(R10-1、R10-3、R10-4),低(R10-2)。
- 规模:中到大。建议拆成"token 一批 + 详情页逐项各一个提交"。
- 前置依赖:R1(头图删除按钮与 `HomeHeroPrimaryButton`)、R2-2(死分支)完成后再做 R10-4 复查;R1-3 新增的 `HeroOriginalTitle`(`lib/widgets/hero_text_blocks.dart`)可被详情页复用。
- 不在范围:详情页的整页亮色映射(见 0 节 F2,待 C5 决策);全仓一次性替换圆角/颜色(R8-4);动效(R11);评分条上限与"我的评分"位置(C2/C3,R5);选择器下拉(已完成);mpv/ExoPlayer。

## 0. 与清单/第一轮方案不一致或新发现

| # | 说明 | 处理 |
|---|---|---|
| F1 | 清单 R10-1 称"`lib/theme` 下无圆角/字阶 token"。实际已有:`MonoTokens`(`mono_tokens.dart:20-33`)`radiusSm 8 / radiusMd 12 / radiusLg 20 / radiusXs 5`,`radiusFull = 100`(`:20`);`OverlayTokens.radius 24`、`compactRadius 18`(`overlay_tokens.dart:4-5`)。数值在 `mono_theme.dart:268-272`。**缺的是 14(卡片)这一级,以及按规格命名的统一入口与字阶** | R10-1 只补缺口并建统一入口,不重复造 |
| F2 | 第一轮方案的亮色对照表要求详情页亮色下"深色字 + 渐隐到 `#F1F0F6`"。实际详情页**刻意**整页白字压图:`media_detail_screen.dart:3243-3258` 用 `MonoPresentation.artworkTextColors`(恒白,`mono_presentation.dart:64-67`)覆盖 `onSurface`,并把 `onSecondaryContainer` 设为 `Colors.white`;现有测试断言该行为(`test/screens/media_detail_screen_test.dart:3280-3300`"bare action ... must stay readable over the dark artwork surface") | 本包**不**把详情页改成亮色深字(与 C5 同源,待产品定);新做的元素一律沿用页面现有前景色(`colorScheme.onSurface`),不写死色值 |
| F3 | 清单称"元数据为纯文本(`presentation.dart:217`)"。属实:`detail_plain_metadata` 是一个 `Text`(`presentation.dart:215-222`),用 ` · ` 连接 年份、分级、时长、集数、类型(≤2)、**画质/音频标签**(`:206`)。规格要求分级用 1px 描边小框,4K/杜比视界/ATMOS 用更淡的描边小框 | R10-3c |
| F4 | 详情页标题已是:手机居中 40、非居中非 TV **48**、TV `64 * scale`,均 w600(`presentation.dart:161-165`)。规格:手机 40、桌面 64 | R10-3a 只改桌面 |
| F5 | 摘要已是 `CollapsibleText`、行高 1.8、可展开(`media_detail_screen.dart:3393-3399`),字号平板 14 / 紧凑 12 / 其它 13,规格 14 | R10-3e 只调字号 |
| F6 | 演职员已是圆形头像(`cast_member_strip.dart:229` `ClipOval`),但尺寸取"跟随海报网格单元宽度",不是规格的 60 | 待产品确认,默认不改(R10-3g) |
| F7 | TV 焦点描边现为 `FocusTheme.focusBorderWidth = 2.5`(`focus_theme.dart:15`),规格 2px 强调色 | 默认不改,待确认 |
| F8 | `Georgia` 只在 `fusion_home_hero.dart:143` 以字体名引用,没有字体文件(`pubspec.yaml:170` 起只有 Go Noto Current/Hangul)。Android 通常没有 Georgia,会落到后备字体链 `['Go Noto Current','serif']`,**实际渲染多半是无衬线的 Go Noto** | C7 未确认前不加字体文件;详情页复用同一后备链,是否要把 `'serif'` 提前到 `Go Noto Current` 之前(CJK 原名会失去衬线以外的字形)待产品看实机 |
| F9 | 清单 R10-4 称 `fusion_home_hero.dart:248-294` 写死深色,R1-3 删除后消失 —— 属实(现位于 `:196-303`,由 R1-7 删除)。R10-4 剩余项:`action_buttons.dart` 的主按钮写死 `0xfff4f5f6`/`0xff202126`(`:175-176`、`:200-201`)、`Colors.white` 焦点色(`:134-135`)、`presentation.dart` 里 `Colors.white`(`:86、:356、:374、:386、:418-424`) | R10-4 |
| F10 | R1-3 删掉 `discover_screen.dart:1579/1597` 的 `circular(24)`,清单 R10-1 举的"discover_screen 24"例子随之消失 | 例子改为 `press_feedback.dart:20` 的 14 |

## 1. 涉及文件表

| 文件 | 行号 | 现状 | 动作 |
|---|---|---|---|
| `lib/theme/radius_tokens.dart` | 新文件 | 无 | 新增 `RadiusTokens`(12/14/18/24/100) |
| `lib/theme/type_scale.dart` | 新文件 | 无 | 新增 `TypeScale`(11/12/13/15/18/22 与详情标题 40/64) |
| `lib/theme/velo_brand.dart` | `:5-14` | 有 `accent`、`foreground()`、`selection()`,无分组面 | 增 `groupSurface(Brightness)` |
| `lib/theme/settings_presentation.dart` | `:84` | 写死 `Color(0xff14151c)`(暗色页面底);`:85` 亮色 `0xffeeeff2`;`:90` 辉光 `0xff2b283c`/`0xfff4efff` | `:84` 改引用 token,其余不动 |
| `lib/widgets/press_feedback.dart` | `:20` | 默认圆角写死 14 | 改引用 `RadiusTokens.card`(作为首个"顺手替换"样例) |
| `lib/screens/media_detail/presentation.dart` | `:154-193` | `_buildNaturalDetailTitle`,桌面 48 | 改:桌面 64;加原名 |
| 同上 | `:195-226` | `_buildCompactDetailHeader`:纯文本元数据含画质标签 | 改:描边元数据行 |
| `lib/screens/media_detail/responsive_layout.dart` | `:129-146`(TV 标题区) | TV 无外文原名 | 改:TV 标题上方加原名 |
| `lib/screens/media_detail/action_buttons.dart` | `:174-177, :196-206` | 主按钮写死浅底深字;最小高度 `max(48, actionSize)`(`:187`);`actionSize` = TV `46*tvScale` / 其它 48(`:26`) | 改:主题化颜色、高度 52/56 |
| 同上 | `:227-241` | 续播进度条 2px,在按钮背景内,`primary.withValues(alpha:.65)`,key `detail-play-progress` | 改:3px、强调色、位于按钮下方 |
| `lib/screens/media_detail_screen.dart` | `:3393-3399` | 摘要字号 14(平板)/12(紧凑)/13 | 改:统一 14 |
| `lib/screens/media_detail_screen.dart` | `:143-147` | `_heroSideInset`、`_tvDetailActionSize = 46` 等常量 | 视 R10-3d 调整 |
| `test/theme/` | 新文件 `design_tokens_test.dart` | 仅有 `mono_theme_test.dart` | 新增 |
| `test/screens/media_detail_screen_test.dart` | `:3280-3300, :3640-3650, :3725-3760` 等 | 依赖 `detail_plain_metadata`(`:3738`)、`detail-play-progress`(`:3646`) | 改 |

## 2. 逐步修改说明

### R10-1 圆角与字阶 token(只落地 token,不全仓替换)
新增 `lib/theme/radius_tokens.dart`:
```dart
abstract final class RadiusTokens {
  static const double poster = 12;                       // = MonoTokens.radiusMd 的数值
  static const double card = 14;
  static const double menu = OverlayTokens.compactRadius; // 18
  static const double dialog = OverlayTokens.radius;      // 24
  static const double pill = MonoTokens.radiusFull;       // 100
  static BorderRadius circular(double r) => BorderRadius.all(Radius.circular(r));
}
```
新增 `lib/theme/type_scale.dart`(规格字阶 11 / 12 / 13 / 15 / 18 / 22,另详情标题 40 / 64):
```dart
abstract final class TypeScale {
  static const double caption = 11, small = 12, meta = 13, body = 15, title = 18, headline = 22;
  static const double detailTitlePhone = 40, detailTitleDesktop = 64;
}
```
注意:现有 `textTheme` 里有 14(`bodyMedium`、`titleSmall`、`labelLarge`,`mono_theme.dart:42-48`),不在规格字阶里。本包**不改**现有 `textTheme`(会影响全仓),`TypeScale` 只给新代码用;14 是否并入字阶待产品确认。
做法:
1. 两个文件均为纯常量,不读 Provider,不改 `MonoTokens` 构造(`MonoTokens(` 在 `mono_theme.dart:268`、`test/test_helpers/theme.dart:8,28` 共三处构造,加字段会连带改测试)。
2. 首个替换样例:`press_feedback.dart:20` `Radius.circular(14)` → `RadiusTokens.card`(数值不变)。其余 8 处 14(`grep -rn "circular(14)" lib` 基线 9 处命中)只在各包碰到该文件时顺手替换,本包不做。
3. 在两个文件头部注释写明:新代码只用 token,不再写字面数值。

### R10-2 分组面 token
- 现状:`settings_presentation.dart:84` 暗色页面底 `Color(0xff14151c)` 写死;OLED 走黑(`:80-83`);亮色 `0xffeeeff2`(`:85`)。
- 改成:`velo_brand.dart` 新增
  ```dart
  static Color groupSurface(Brightness b) => b == Brightness.dark ? const Color(0xff14151c) : const Color(0xffffffff);
  ```
  (暗 `#14151C`、亮 `#FFFFFF`,取自第一轮规格亮色对照表"分组面/卡片"一行。)
- 做法:`settings_presentation.dart:84` 改为 `VeloBrand.groupSurface(Brightness.dark)`。亮色 `0xffeeeff2` 是设置页**页面底**而非分组面,**不改**,否则设置页外观会变。OLED 的 `0xff0a0a0a`(`mono_theme.dart:58`)保持。
- "卡片类分组面共用":先 `grep -rn "surfaceContainerLow\|surfaceContainer" lib/widgets/settings_section.dart lib/screens/settings` 找出设置页分组卡片现用的色(待核对),只有确认与 `#14151C` 同值才替换;不同值的不动。验收是设置页像素不变。

### R10-3 详情页结构(按第一轮 P7"详情页"小节逐项)
规格原文(详情页手机自上而下)与现状对照,逐项一个子任务:

| 规格 | 现状 | 子任务 |
|---|---|---|
| 1 全幅头图,底部长渐隐到背景色 | 已有(`MonoPresentation.artworkBlend`,`media_detail_screen.dart:4430`) | 不动 |
| 2 标题区居中:外文原名(Georgia 10,字距 3,全大写,可选)→ Clear Logo 或文字标题;标题手机 40、桌面 64,w600 | 标题已有;**无外文原名**;桌面 48 | R10-3a、R10-3b |
| 3 元数据一行纯文字,点号分隔:年份 · 时长 · 类型;分级 1px 描边小框;4K/杜比视界/ATMOS 更淡描边小框 | 纯文本一行含画质标签 | R10-3c |
| 4 评分条 | 已有 `MediaRatingsStrip` | 不动 |
| 5 主按钮高 52、胶囊、浅色底深色字("继续播放 · 剩余 X 分");右侧圆形次要按钮;"我的评分"按钮;主按钮下方 3px 强调色进度条 | 主按钮高 48、写死浅底深字、文案 `播放 · 37%`(`action_buttons.dart:261`);进度条 2px 在按钮内 | R10-3d |
| 6 版本/音频/字幕下拉 | 已有 | 不动 |
| 7 简介(14,行高 1.8,可展开)→ 演职员(60 圆形头像)→ 相关推荐 | 简介字号 12/13/14;头像尺寸随网格 | R10-3e、R10-3g |
| 桌面/TV:左侧 600 宽信息区(标题 64、元数据、评分条、简介、操作行高 56、三个下拉并排),底部一行相关推荐海报 150×225;TV 控件 2px 强调色焦点描边 | TV 已有独立布局(`_buildTvDetailScreen`,`:3642`);桌面走紧凑头图,`maxWidth: 720`(`responsive_layout.dart:75`) | R10-3a/d;焦点见 R10-3f |

#### R10-3a 桌面标题 64
- 现状:`presentation.dart:161-165` `fontSize = tv ? 64*scale : centered ? 40.0 : 48.0`。
- 改成:`tv ? 64*scale : centered ? 40.0 : (桌面平台 ? 64.0 : 48.0)`。"桌面平台"= `!PlatformDetector.isMobile(context)`(`platform_detector.dart:263`);平板横屏(`centered == false` 且是移动平台)保持 48(默认值,产品可改)。
- 注意:标题无高度预算会换行(`:170` 注释),桌面 64 + `maxWidth: 720` 下长标题 2-3 行,目视核对 `FittedBox`(`:188`)只用于 logo 回退,不要让 64 的文字被缩小。

#### R10-3b 外文原名
- 现状:详情页(`media_detail_screen.dart`、`media_detail/*.dart`)没有 `originalTitle`,没有 Georgia(`grep -rn "originalTitle\|Georgia" lib/screens/media_detail*` 基线为 0 命中)。
- 改成:在标题(Logo 或文字)**上方**显示原名:全大写、1 行省略、字号 10、字距 3、`fontFamily: 'Georgia'`、后备 `['Go Noto Current', 'serif']`、颜色 `onSurface` 的 .8 透明度、与标题间距 8。与标题相同或为空则不显示、不占位。
- 做法:复用 R1-3 的 `HeroOriginalTitle`(参数 `fontSize: 10`),需把其字距参数化(R1 版固定 2.5 → 加 `letterSpacing` 参数,默认 2.5,详情传 3)。放在 `_buildCompactDetailHeader`(`presentation.dart:195`)的 `Column` 第一项(`_buildNaturalDetailTitle` 之前),居中/左对齐随 `centered`;TV 放在 `responsive_layout.dart:129` 的 `_buildNaturalDetailTitle` 之前(TV 缩放 `scale` 乘到字号上)。
- 字体:不加字体文件(C7 默认);F8 的后备链问题在提交说明里写明。
- 剧集详情用 `grandparentTitle` 对比,和头图一致(`title = isEpisode ? grandparentTitle ?? displayTitle : displayTitle`)。

#### R10-3c 描边元数据行
- 现状:`presentation.dart:200-222` 把 年份、分级、时长、集数、类型、画质标签 `join(' · ')` 成一个 `Text`(key `detail_plain_metadata`)。
- 改成:一行 `Wrap`(居中/左对齐随 `centered`,`spacing: 8, runSpacing: 6, crossAxisAlignment: center`):
  - 文本段:`年份 · 时长 · 集数(仅剧集)· 类型(≤2)`,仍是纯文字、点号分隔、保留 key `detail_plain_metadata`(该 key 现有测试在 `:3738`、`:3760` 读 `Text.data`,保留它能让断言继续成立,但见第 5 节);
  - 分级:1px 描边小框(`border: Border.all(color: onSurface.withValues(alpha: .4), width: 1)`,圆角 `RadiusTokens.poster` 的一半即 5~6,内边距 6×2,字号 `TypeScale.small`);
  - 画质/音频标签(4K、HDR、DV、Atmos 等,来自 `buildMediaQualityLabels(target ?? metadata)`,`:206`):更淡的描边框(alpha .22),字号 `TypeScale.caption`;
  - 颜色一律由 `Theme.of(context).colorScheme.onSurface` 派生(详情页已把它设为白,见 F2),不写死。
- 抽成一个小组件放 `lib/screens/media_detail/` 下新文件(如 `detail_metadata_row.dart`,`part of` 方式或独立 widget 均可,先看 `presentation.dart` 的 `part of '../media_detail_screen.dart'` 约束),入参 `labels`、`rating`、`qualityLabels`、`centered`,便于单测。
- 紧凑手机 320 宽 / 200% 字号下可换行,不得横向溢出(现有 `media_detail_screen_test.dart:3725-3770` 的宽度循环覆盖)。

#### R10-3d 主按钮与进度条
- 现状:`action_buttons.dart:174-177` `whitePlayStyle`(`#F4F5F6` 底、`#202126` 字,所有主题相同);`:196-206` 紧凑模式再写一遍;高度 `ConstrainedBox(minHeight: max(48, actionSize))`(`:187`);进度条 `LinearProgressIndicator(minHeight: 2, valueColor: primary.alpha(.65))` 在按钮背景里(`:227-241`)。
- 改成(默认值,产品可改):
  1. 主按钮高度:手机/平板 52,桌面 56,TV 沿用 `_tvDetailActionSize * tvScale`(46×)不变(TV 规格 56 与现有 46 差别大,**待产品确认**,默认不改 TV)。做法:`:26` 的 `actionSize` 拆出 `primaryHeight`:`isTv ? actionSize : (compactPresentation ? 52 : 56)`,`:187` 改用 `primaryHeight`;次要圆形按钮仍 48(`actionSize`)。
  2. 颜色:不再写死两个色值。亮底深字的现状与"详情页整页暗色压图"(F2)一致,**默认保持浅底深字,但把两个字面值收进一处**:在 `velo_brand.dart` 增 `static const detailPrimaryBackground = Color(0xfff4f5f6)`、`detailPrimaryForeground = Color(0xff202126)`,`:175-176`、`:200-201` 引用。亮色主题下改成"深底 #2D2E40 + 白字"属于 C5 决策,**本包不做**,在代码注释写 `TODO(VELO-R10-01)`。
  3. 进度条:从按钮背景里挪到主按钮**下方**,高 3px,颜色 `colorScheme.primary`(或 `VeloBrand.foreground(brightness)`,二选一,以详情页目视为准),保留 key `detail-play-progress`,`value: resumeProgress`;无进度时不渲染(现有测试 `:3674` 断言无进度时 `findsNothing`,保持)。按钮内部背景的 `primary.alpha(.12)` 填充条(`:216-222`)一并去掉,避免双进度。
  4. 文案:现为 `播放 · 37%`(`:261`)。规格是"继续播放 · 剩余 X 分钟"。可用已有 key `t.discover.minutesLeft(minutes: n)`(R1 的旧按钮在用,`fusion_home_hero.dart` 原 `:223`)。改法:`progressPercent == null ? label : '$playVerb · ${t.discover.minutesLeft(...)}'`;剩余分钟 = `((durationMs - viewOffsetMs) / 60000).round()`。**这是文案变化,现有测试 `media_detail_screen_test.dart:3647` 断言 `find.textContaining('37%')`,需同步改**;默认值,产品可改(不改则保留百分比)。
- 影响面:TV 的 `_tvDetailActionRailGap`、`:507` 的 `detail_primary_play` 宽度估算(`playButtonWidthEstimate`,`:428-440`)按文案宽度算布局,文案变长要复测"操作行不溢出"的现有用例(`media_detail_screen_test.dart:2854、2912、3039、3088`)。

#### R10-3e 摘要字号
- 现状:`media_detail_screen.dart:3398` `fontSize: isTablet ? 14 : (compact ? 12 : 13)`,行高 1.8 已满足。
- 改成:统一 14(`TypeScale.body` 是 15,不用它;规格明确写 14,直接写 14 并注释出处)。紧凑手机 `maxLines` 现为 2(`:3396`),保持。
- 注意:12→14 会让手机摘要折叠区变高,检查头图下首屏不把"选择器/剧集"挤出;现有布局测试若依赖像素高度需更新(待核对)。

#### R10-3f TV 焦点(默认不改)
- 现状:`FocusTheme.focusBorderWidth = 2.5`(`focus_theme.dart:15`),详情页各控件用 `FocusableWrapper`/`useBackgroundFocus`。规格"2px 强调色描边"。
- 默认:不改(全局常量,改了影响所有 TV 控件);作为待确认项 Q1 提给产品。本包只保证**新增**的元素(原名不可聚焦;分级/画质框不可聚焦)不进入焦点链,不新增焦点节点。

#### R10-3g 演职员头像 60(默认不改)
- 现状:头像尺寸随库网格密度(`cast_member_strip.dart:60-65` `responsiveCardWidth`)。规格 60 圆形。
- 默认:不改,待产品确认(Q2);若要改,给 `CastMemberStrip` 加固定尺寸参数,仅详情页传 60,TV 不传。

### R10-4 亮色硬编码复查(R1/R2 完成后)
逐项:
| 位置 | 现状 | 处理 |
|---|---|---|
| `fusion_home_hero.dart` `HomeHeroPrimaryButton` | 写死白底黑字 | R1-7 已删,复查 grep 为 0 |
| `hero_metadata_badges.dart:58-60` | 写死色值 | R2-2 已删,复查 |
| `hero_metadata_badges.dart:15` 默认前景 `Colors.white` | 仅测试用默认 | 保持(C5) |
| `mono_presentation.dart:64-67` `artworkTextColors` | 恒返回白 | **不改**(C5 默认保持白字压图) |
| `action_buttons.dart:134-135` 焦点 `Colors.white` | 紧凑模式图标按钮焦点色 | 页面前景是白(F2),保持;注释说明 |
| `presentation.dart:86, :356, :374, :386, :418-424` | 季标签、剧集标题、分页芯片写死 `Colors.white` | 同上保持,但改成 `colorScheme.onSurface`(详情页已把它覆盖为白,数值不变,以后 C5 变更时自动跟随)。逐处目视确认亮色主题外观不变 |
验收:亮色主题下首页头图、详情页文字对比度 ≥ 4.5:1(白字压彩色海报以实机为准,海报偏亮时记录为 C5 风险,不在本包修)。

## 3. i18n key 与常量/设置项

i18n:默认无新增(R10-3d 第 4 条若采用"剩余 X 分钟"复用 `discover.minutesLeft`)。如需新增,先 `grep -n '"minutesLeft"' lib/i18n/en.i18n.json` 确认可复用。改 `lib/i18n/*.i18n.json` 后运行 `dart run slang`(CONTRIBUTING.md 指定),再 `scripts/codegen.sh --check`。

常量:

| 名称 | 值 | TODO 编号 |
|---|---|---|
| `RadiusTokens.poster/card/menu/dialog/pill` | 12 / 14 / 18 / 24 / 100 | — |
| `TypeScale.*` | 11 / 12 / 13 / 15 / 18 / 22;详情标题 40 / 64 | — |
| `VeloBrand.groupSurface` | 暗 `#14151C` / 亮 `#FFFFFF` | — |
| 详情主按钮高度 | 手机/平板 52,桌面 56,TV 不变 | `TODO(VELO-R10-02)` |
| 详情进度条高度 | 3 | `TODO(VELO-R10-02)` |
| 详情主按钮颜色(亮色改深底) | 保持浅底深字 | `TODO(VELO-R10-01)`(依赖 C5) |
| 外文原名字距/字号 | 3 / 10 | — |

## 4. TV 焦点、三主题、各形态要求

- TV:详情页 `_buildTvDetailScreen` 的焦点顺序与"初始焦点在播放按钮"不得变(`media_detail_screen_test.dart` 现有 TV 用例守护);原名是 `ExcludeSemantics` 内的装饰文本,不聚焦,但要并入 `_tvDetailInformationSemanticLabel`(`responsive_layout.dart:107`)的语义标签(可选);主按钮高度不变。
- 三主题(亮/暗/纯黑):新增元素只用 `colorScheme` 派生色;分级/画质描边在三主题下对比度可见(alpha .4/.22 在亮色海报上若太淡,以目视为准调到 .5/.3 并记录);纯黑主题无新增白色蒙层。
- 手机:竖屏居中,原名在标题上方居中;320 宽、200% 字号下元数据行换行、主按钮文案不溢出。
- 平板:竖屏居中;横屏左对齐(`centered == false`),标题 48。
- 桌面:标题 64、左对齐、`maxWidth 720` 内;主按钮高 56。
- TV:标题 64 沿用,原名在标题上方,其余不变。

## 5. 测试要求

要改的现有测试(`test/screens/media_detail_screen_test.dart`,5031 行,以下行号为基线):
- `:3725-3770`(元数据宽度循环):按 R10-3c 重写——文本段仍可读 `detail_plain_metadata`,但 `'1080p'`、`PG-13` 不再在这个 `Text.data` 里(它们变成描边框),断言改为 `find.text('PG-13')`、`find.text('1080p')` 存在;`:3753` 起的 `contains('PG-13 · 1h 46min')` 断言失效,改为 `contains('1h 46min')`。
- `:3640-3660`(`detail-play-progress` 与 `find.textContaining('37%')`):进度条仍存在、`value == .37`;若采用"剩余分钟"文案则 `37%` 断言改为 `t.discover.minutesLeft(...)`。
- 桌面标题字号相关用例(`detail_natural_title`,`:2426、:2449、:2630、:2719、:2736、:3299、:3342、:3787`):凡断言桌面宽度下字号为 48 的改 64(待核对:先 `grep -n "fontSize" test/screens/media_detail_screen_test.dart`)。
- `:2854、:2912、:3039、:3088`(`detail_primary_play` 宽高/溢出):主按钮高度 48→52/56,若断言高度等于 48 需改。
- `:3150-3162`(chip 尺寸)与 R2-3 联动,保持通过。
- `test/widgets/home_hero_blend_test.dart`、`f4_home_feedback_test.dart`:由 R1 处理,本包不再改。

要新增的测试:

| 文件 | 用例名 | 断言要点 |
|---|---|---|
| `test/theme/design_tokens_test.dart`(新) | `radius tokens match the visual spec` | `RadiusTokens.poster==12, card==14, menu==18, dialog==24, pill==100`;`menu == OverlayTokens.compactRadius`,`dialog == OverlayTokens.radius`,`poster == monoTheme(dark:true).extension<MonoTokens>()!.radiusMd` |
| 同上 | `type scale and group surface values` | `TypeScale` 六个值;`VeloBrand.groupSurface(Brightness.dark) == Color(0xff14151c)`,亮色为白 |
| `test/screens/settings/settings_appearance_test.dart`(新或并入现有设置测试,待核对已有文件) | `dark settings page background still uses the group surface` | 暗色(非 OLED)`SettingsAppearance` 背景色等于 `VeloBrand.groupSurface(Brightness.dark)`;OLED 为黑;亮色为 `0xffeeeff2` |
| `test/screens/media_detail_screen_test.dart` | `detail shows original title above the title only when different` | 原名与标题不同 → 找到全大写原名且 y 坐标在标题之上;相同/空 → 找不到 |
| 同上 | `desktop detail title is 64 and tablet landscape stays 48` | 桌面平台宽度 1280:`detail_natural_title` 的 `style.fontSize == 64`;平板横屏 48;手机 40 |
| 同上 | `certification and quality render as outlined chips` | `PG-13` 的祖先含 `Border.all(width: 1)` 的 `DecoratedBox`;`4K` 的框颜色 alpha 小于分级框 |
| 同上 | `resume progress bar is 3px under the primary button` | `detail-play-progress` 的 `minHeight == 3`,其 y 坐标不小于 `detail_primary_play` 的 bottom |
| `test/widgets/detail_metadata_row_test.dart`(新,若抽成独立组件) | `wraps at 320 width and 200 percent text without overflow` | `tester.takeException()` 为 null;全部标签可见 |

## 6. 验收清单

命令:
- [ ] `flutter analyze` 无新增告警。
- [ ] `scripts/run_tests.sh` 全绿;单独跑:`flutter test test/theme test/screens/media_detail_screen_test.dart test/widgets/detail_metadata_row_test.dart`
- [ ] 若改了 i18n:`dart run slang`、`scripts/codegen.sh --check`、`python3 scripts/checks/clean_translations.py --check` 通过。
- [ ] `grep -rn "0xff14151c" lib` 只剩 `velo_brand.dart` 一处。
- [ ] `grep -n "Color(0xfff4f5f6)\|Color(0xff202126)" lib/screens/media_detail/action_buttons.dart` 为 0(已收进 token)。

手动(手机 / 平板竖横 / 桌面 / TV × 亮 / 暗 / 纯黑):
- [ ] 设置页暗色与纯黑、亮色外观与改前像素一致。
- [ ] 详情页:原名(有则在标题上方,全大写,Georgia 或后备字体)→ Logo/标题 → 描边元数据行 → 评分条 → 操作行(主按钮 52/56)→ 3px 进度条(有续播时)→ 下拉 → 摘要(14,可展开)。
- [ ] 桌面标题 64 不被缩小、不遮挡;平板横屏 48。
- [ ] 有续播与无续播的影片各看一遍;主按钮文案不溢出;TV 初始焦点仍在播放按钮。
- [ ] 亮色主题下详情页文字可读(沿用白字压图现状,不比改前差)。

## 7. 提交拆分

1. `feat(主题): 新增圆角与字阶 token 并补测试`
2. `refactor(主题): 分组面色值提为 VeloBrand.groupSurface,设置页引用`
3. `refactor(组件): PressFeedback 默认圆角改用 RadiusTokens.card`
4. `feat(详情): 桌面标题字号改为 64`
5. `feat(详情): 标题上方显示外文原名`
6. `feat(详情): 元数据行改为描边分级与画质标签`
7. `feat(详情): 主按钮高度 52/56,续播进度条改为按钮下方 3px`
8. `fix(详情): 摘要字号统一为 14`
9. `refactor(详情): 详情页写死的白色改用 colorScheme.onSurface`(R10-4)
10. `test(详情): 补外文原名、标题字号、描边元数据与进度条测试`(若已随各提交补齐则合并)

## 8. 风险、待确认、禁止事项

待确认(给产品):
- Q1 TV 焦点描边 2px 还是现有 2.5(F7);TV 主按钮高 56 还是现有 46(R10-3d)。
- Q2 演职员头像固定 60 还是随密度(F6)。
- Q3 `Georgia` 实际落到 Go Noto(F8)是否可接受,或要加系统衬线优先(C7)。
- Q4 详情页亮色整页深字(F2、C5)—— 决定后 R10-3d 的主按钮亮色规格(深底白字)才能做。
- Q5 续播文案用"剩余 X 分钟"还是保留百分比。
- Q6 14 是否并入字阶(R10-1)。

风险:
- 详情页测试文件很大(5031 行),改动面集中在元数据与主按钮,务必在有 flutter 的环境先跑一遍基线再改。
- 主按钮高度与文案变化会影响 TV 操作行宽度估算(`action_buttons.dart:428-442`),需复测。
- 摘要 12→14 增高手机首屏占用。

禁止事项:
- 不直接改 `lib/i18n/strings*.g.dart` 等生成文件;改 `lib/i18n/*.i18n.json` 后运行 `dart run slang`。
- 不加字体文件、不改 `pubspec.yaml` 的 fonts(C7 未确认)。
- 不改现有 `textTheme` 与 `MonoTokens` 构造签名;不做全仓圆角/颜色一次性替换。
- 不动 `artworkTextColors`(C5)、不改评分条上限与"我的评分"位置(C2/C3)。
- 不删 Plex/Jellyfin/Emby/一起看/TV 支持;不动 mpv/ExoPlayer 后端;一个提交只做一件事;不提交凭据、构建产物、本地参考文件;保留 Plezy 上游署名。
