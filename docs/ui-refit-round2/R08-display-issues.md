# R8 其他显示问题 任务卡

- 基线提交:`8885b39`(`git rev-parse --short HEAD`)。行号以此为准,不一致就按符号名重新定位。
- 核对方式:静态读码,未运行(本环境无 flutter)。标"待核对"的要先查再改。
- 目标:消除长文字溢出和固定宽度截断,把两处 `SimpleDialog` 换成磨砂 `AppDialog`,分批收敛非播放器页面的硬编码颜色,把散落的断点魔数收成命名常量(不改布局效果),并修正 zh 的 Quick Connect 文案。
- 优先级:中(R8-1/2/3/4),低(R8-5/6)。
- 规模:大(R8-4 工作量最大,可分多个迭代;R8-1/2/3/5/6 各为小)。
- 前置依赖:无硬依赖。R8-4 里 `fusion_home_hero.dart` 与 `hero_metadata_badges.dart` 属 R1 范围,先等 R1;`media_detail/action_buttons.dart` 与 R9 的按下反馈同文件,合并时注意冲突。
- 不在范围:播放器控制层(始终深色)、压在海报上的角标/头图文字(待 C5)、品牌色图标;直播节目表错误态(P6-1,不属本卡);全仓一次性替换颜色;改变任何断点的实际阈值。

## 已定默认决策(默认值,产品可改)

| 项 | 默认值 |
|---|---|
| 断点 | 新增命名常量,保持现有阈值与比较符(`>` / `>=`),不归并到 600/900/1200(C12) |
| zh `auth.quickConnect` | 改为"快速连接（Quick Connect）",与 zh-Hant 写法一致(C9,可选) |
| 压在图片上的白字/黑渐变 | 保留,集中为命名常量(C5 待产品) |
| `discover.playEpisode` | 不改(zh 与 en 相同为有意保留) |

## 涉及文件表

| 文件 | 行号(8885b39) | 现状 | 动作 |
|---|---|---|---|
| `lib/screens/settings/add_jellyfin_screen.dart` | 724-730(已连接服务器行:serverName、`productName version` 两个 `Text` 无 maxLines);931-935(`_buildServerCard`:同样两个 `Text` 无 maxLines);两处都已在 `Expanded` 内 | 超长服务器名/版本串会无限折行,撑高卡片 | 改 |
| `lib/widgets/server_activities_button.dart` | 324-332(`Row` 内 `Text(result.serverName.toUpperCase())`,后面跟数量徽标 `:333-343`) | 无 `Flexible`,长名挤出数量徽标并溢出 | 改 |
| `lib/widgets/hub_section.dart` | 559-572(标题行 `Row`:`Flexible` 标题 `:543-546`、`totalResults`、`•`、`Text(widget.hub.serverName!)` `:568-573`、"全部"/chevron) | serverName 无 `Flexible`/省略,和标题抢宽度时溢出 | 改 |
| `lib/screens/profile/borrow_connection_screen.dart` | 411(标题 `Text`,有 `overflow` 无 `maxLines`);415-423(`Row` 内 `Text(borrowFromProfile)` + 锁图标);428-431(`connectionAs` `Text`,在 `Column` 内不是 `Row`) | 只有 `:415` 的 `Row` 真会溢出;`:411`、`:428` 只会多行折行 | 改 |
| `lib/screens/discover_screen.dart` | 1090(`participantCount` 数字徽标) | 仅数字,基本无风险 | 不改 |
| `lib/screens/catalog_item_detail_screen.dart` | `_buildFactRow` 903-919(`SizedBox(width: 140)` `:910`);列数断点 954-958(1100/700) | 标签固定 140 宽,长语言/大字号被折成多行或截断 | 改 |
| `lib/screens/media_detail_screen.dart` | `_buildInfoRow` 4574-4590(`SizedBox(width: 120)` `:4581`) | 同上(第一轮文档写 `:5200` 已过期) | 改 |
| `lib/utils/dialogs.dart` | `_OptionPickerDialogState.build` 612-686(`SimpleDialog` `:623`,`ScrollInkBoundary` 注释 `:632`) | 非磨砂弹窗 | 改 |
| `lib/watch_together/widgets/local_media_match_dialog.dart` | 126-143(版本选择 `showScopedDialog` 内 `SimpleDialog` `:128`) | 同上 | 改 |
| `lib/widgets/app_dialog.dart` | `AppDialog` 8-39;`AppAlertDialog` 42 起 | 目标组件(磨砂、约束 280-560) | 只读 |
| `test/widgets/option_picker_dialog_test.dart` | `:64`、`:71`(`find.byType(SimpleDialog)`) | 断言旧组件 | 改 |
| `lib/utils/layout_constants.dart` | `ScreenBreakpoints` 6-27(`mobile 600`、`wideTablet 900`、`desktop 1200`、`largeDesktop 1600`、`tablet`=mobile 别名、`isMobile` `<600` 等) | 无 700/720/680/1100/1180/390 | 改(新增常量) |
| 断点散落点 | 见 R8-5 表 | 魔数 | 改 |
| `lib/i18n/zh.i18n.json` | `auth.quickConnect` 第 38 行 | `"Quick Connect"` | 改(可选) |
| 硬编码颜色文件 | 见 R8-4 排行 | - | 分批改 |
| `lib/theme/`(新增 `status_colors.dart`、`poster_overlay_colors.dart` 若 R5 未建) | - | 无状态色/压图色命名常量 | 新增 |

## 逐步修改说明

### R8-1 长文字溢出

统一写法:Row 内可变文本包 `Flexible`(或已有 `Expanded` 就不再包),加 `maxLines: 1` 与 `overflow: TextOverflow.ellipsis`;Column 内可多行的文本给 `maxLines: 2`。

1. `add_jellyfin_screen.dart:724-730`:`Text(_serverInfo!.serverName)` 加 `maxLines: 1, overflow: ellipsis`;`'${productName} ${version}'` 同样 `maxLines: 1`。`Expanded` 已在外层,不要再加。
2. `add_jellyfin_screen.dart:931-935`:同上两个 `Text`。
3. `server_activities_button.dart:324`:`Text(result.serverName.toUpperCase())` 外包 `Flexible(child: ..., )`,`maxLines: 1, overflow: ellipsis`;`SizedBox(width: 6)` 和数量徽标保持不缩。
4. `hub_section.dart:568-573`:serverName 外包 `Flexible(fit: FlexFit.loose, child: Text(..., maxLines: 1, overflow: ellipsis))`。标题 `Flexible`(`:543`,非 TV 为 `tight`)保持不动;两个 `Flexible` 同权重时长标题会被压缩,可接受(标题自身已 ellipsis)。TV 下 `Row.mainAxisSize: min`,`loose` 不会撑满。
5. `borrow_connection_screen.dart:415-423`:`Text(borrowFromProfile)` 外包 `Flexible`,加 `maxLines: 1, overflow: ellipsis`,锁图标不缩。`:411` 补 `maxLines: 1`。`:428` 补 `maxLines: 2, overflow: ellipsis`。
6. `discover_screen.dart:1090` 不改。

### R8-2 固定宽度标签

- 现状:`catalog_item_detail_screen.dart:910` `SizedBox(width: 140)`;`media_detail_screen.dart:4581` `SizedBox(width: 120)`。标签文字超过该宽度只能折行,大字号下被拉高。
- 改成:标签用 `ConstrainedBox(constraints: BoxConstraints(minWidth: W, maxWidth: <行宽的 45%>))`,值保持 `Expanded`。只设 `minWidth` 不设上限会让长标签吃掉整行,所以必须有上限。
- 做法:行外包 `LayoutBuilder`,`maxWidth: constraints.maxWidth * 0.45`;`minWidth` 取 `W * min(textScale, 1.5)`(`MediaQuery.textScalerOf(context).scale(1)`),默认 `W` 仍是 140 / 120,常规字号下视觉不变。标签 `Text` 不加 `maxLines`(允许折 2-3 行,不截断)。
- 同一行高度由 `crossAxisAlignment: start` 保持顶对齐,不变。

### R8-3 两处 SimpleDialog 换 AppDialog

- 现状:`dialogs.dart:623` 与 `local_media_match_dialog.dart:128`。`AppDialog`(`lib/widgets/app_dialog.dart:8`)是 `Dialog` 子类,约束默认 `minWidth 280 / maxWidth 560`(`OverlayTokens.dialogMaxWidth`),内部包 `AppGlassSurface`;它**不带标题和滚动**,`SimpleDialog` 的标题、内边距、滚动要自己补。
- 做法(两处相同):
  ```
  AppDialog(
    child: Column(mainAxisSize: min, crossAxisAlignment: stretch, children: [
      Padding(title ...),            // SimpleDialog 的 titlePadding 24/24/24/0,文字样式 titleLarge
      Flexible(child: SingleChildScrollView(child: <原 children 包成 Column>)),
    ]),
  )
  ```
  - `dialogs.dart`:保留 `insetPadding: horizontal 8 / vertical 24` 与 `constraints minWidth 304` 的原值(传给 `AppDialog`);保留 `ScrollInkBoundary`(现在包在新的 `SingleChildScrollView` 内部);行项 `FocusableListTile`、`_initialFocusNode`、`focusFirstItem`、`onBeforeClose` 逻辑不动,这是 TV 焦点的来源。
  - `local_media_match_dialog.dart:128`:标题 `t.watchTogether.localMatch`;每个版本是 `FocusableButton + TextButton`,原样放进 `Column`;**第一个版本按钮要能拿到初始焦点**:`SimpleDialog` 原本不给初始焦点,但该对话框在 `showScopedDialog` 内,先看 `showScopedDialog`(`dialogs.dart:26`)是否已处理初始焦点,若无就给第一个按钮 `autofocus`(待核对,行为以 TV 实测为准)。
  - 窄屏/大字号下内容必须可滚动不溢出(`local_media_match_dialog_test.dart:212` 已有同类用例)。
- 样式要求:两个对话框外观一致(同一磨砂面、同一圆角,由 `AppGlassSurface` 提供),标题 `titleLarge`,内容区左右内边距 16-24。

### R8-4 硬编码颜色分批收敛

#### 统计口径(提交说明必须用同一条命令写前后数)

在仓库根执行(排除 `lib/theme`、生成文件):
```
grep -rEo 'Color\(0x' lib --include=*.dart --exclude-dir=theme --exclude='*.g.dart' | wc -l      # 基线 67
grep -rEo 'Colors\.[a-zA-Z]+' lib --include=*.dart --exclude-dir=theme --exclude='*.g.dart' | wc -l  # 基线 441
grep -rEo 'Colors\.transparent' lib --include=*.dart --exclude-dir=theme --exclude='*.g.dart' | wc -l # 基线 97
```
基线:合计 508,去 transparent 后 411(与第一轮"约 413"基本持平)。注意 441 里含 13 处 `GlassSheetColors.of(...)` 被误匹配(`Colors.of`),真实 `Colors.xxx` 约 428,去 transparent 约 398 处硬编码;排行按"排除 transparent 与 `Colors.of`"统计,命令:
```
grep -rEo 'Color\(0x|Colors\.[a-zA-Z]+' lib --include=*.dart --exclude-dir=theme --exclude='*.g.dart' | grep -v 'Colors\.transparent\|Colors\.of$' | cut -d: -f1 | sort | uniq -c | sort -rn | head -20
```

#### 前 20 个文件排行(基线 8885b39,静态统计)

| # | 文件 | 数量 | 处置 |
|---|---|---|---|
| 1 | `lib/screens/video_player/widgets/player_prompt_overlays.dart` | 24 | 保留(播放器浮层,始终深色) |
| 2 | `lib/screens/auth_screen.dart` | 18 | 改(第 2 批):整页是固定深色渐变登录页(`:361` `262a32→08090b`),见下"auth_screen 处理" |
| 3 | `lib/watch_together/widgets/watch_together_overlay.dart` | 15 | 保留(`Colors.black54` 底的悬浮指示器,叠在播放画面上);`Colors.amber` 房主色改状态常量(低优先) |
| 4 | `lib/screens/media_detail/action_buttons.dart` | 13 | 改(第 1 批) |
| 5 | `lib/widgets/video_controls/sheets/player_settings_controls.dart` | 12 | 保留(播放器) |
| 6 | `lib/widgets/video_controls/desktop_video_controls.dart` | 12 | 保留(播放器) |
| 7 | `lib/widgets/fusion_home_hero.dart` | 10 | 暂缓(R1 与 C5);`HomeHeroPrimaryButton` 随 R1 删除 |
| 8 | `lib/widgets/watched_indicator.dart` | 9 | 保留(压在海报上),集中为命名常量 |
| 9 | `lib/widgets/video_controls/widgets/content_strip.dart` | 9 | 保留(播放器) |
| 10 | `lib/widgets/video_controls/video_controls.dart` | 9 | 保留(播放器) |
| 11 | `lib/utils/initials_palette.dart` | 9 | 保留(头像调色板,注释已写明"深到白字恒达标") |
| 12 | `lib/navigation/fusion_navigation.dart` | 9 | 改(第 4 批):已按 `dark ?` 分亮暗,迁到 `MonoPresentation` 的导航色 |
| 13 | `lib/widgets/video_controls/widgets/timeline_slider.dart` | 8 | 保留(播放器) |
| 14 | `lib/widgets/video_controls/mobile_video_controls.dart` | 8 | 保留(播放器) |
| 15 | `lib/widgets/download_status_icon.dart` | 8 | 改(第 3 批):状态色 → 状态常量 |
| 16 | `lib/screens/settings/logs_screen.dart` | 8 | 改(第 2 批) |
| 17 | `lib/screens/media_detail/presentation.dart` | 8 | 改(第 1 批);`:348-386,418-424` 是压在头图上的白字/黑底,见下 |
| 18 | `lib/screens/discover_screen.dart` | 8 | 部分保留:`:847-868,989-992` 是头图上的玻璃芯片(`0x8533363c` + 白字),压图保留并集中常量;`:1120` `Colors.green` 改状态色 |
| 19 | `lib/widgets/app_bar_back_button.dart` | 7 | 保留(`circular`/`video` 样式压图,`plain` 样式已按主题取色) |
| 20 | `lib/screens/media_detail_screen.dart` | 6 | 改(第 1 批):`Colors.amber`/`redAccent`(个人评分 chip `:1148-1149`)等 |

(统计只数出现次数,同一行多次出现算多次。播放器目录合计:`lib/widgets/video_controls/**` 约 134 处、`lib/screens/video_player/**` 约 28 处,不在改动范围。)

#### 合理保留清单(不改,不要"顺手"替换)

1. 播放器控制层及其浮层:`lib/widgets/video_controls/**`、`lib/screens/video_player/**`、`lib/watch_together/widgets/watch_together_overlay.dart`——第一轮定"始终深色浮层 + 白色图标,不随主题变"。
2. 压在海报/头图上的角标与文字:`watched_indicator.dart`、`media_detail/presentation.dart` 头图区、`discover_screen.dart` 头图芯片、`app_bar_back_button.dart`(`circular`/`video`)。允许保留白字/黑渐变,**但要把散落的 `Colors.white/black.withValues(alpha:)` 收成 `PosterOverlayColors` 里的命名常量**(与 R5-5 共用该文件)。
3. 品牌色图标:`assets/rating_icons/*.svg`、`initials_palette.dart`。
4. 首页头图文字/阴影(`fusion_home_hero.dart:75-84`)在亮色下是白字压图还是随主题——C5 待产品,默认不动。

#### 语义色替换对照表

页面(非压图、非播放器)里的硬编码,按下表替换。`tokens(context)` 指 `lib/theme/mono_tokens.dart` 的 `MonoTokens`(`bg/surface/outline/text/textMuted`);`scheme` 指 `Theme.of(context).colorScheme`。

| 现有写法 | 替换为 | 说明 |
|---|---|---|
| `Colors.white`(页面文字/图标) | `scheme.onSurface`(或 `tokens(context).text`) | 亮色下变深字 |
| `Colors.white.withValues(alpha: .4~.7)`(次要文字) | `tokens(context).textMuted`;没有合适透明度时 `scheme.onSurface.withValues(alpha: x)` | 次要文字 |
| `Colors.white.withValues(alpha: .035~.125)`(淡填充、分隔线、描边) | `tokens(context).outline`(分隔/描边);淡填充用 `scheme.onSurface.withValues(alpha: .04~.08)` | 第一轮规格:分隔线与描边 = 正文色 8%-10% |
| `Colors.black`(页面里的文字,如浅色按钮上) | `scheme.onPrimary` 或 `tokens(context).bg` | 取决于所在底色,见"主按钮"行 |
| 主按钮 `Color(0xfff4f5f6)` 底 + `Color(0xff202126)` 字(`action_buttons.dart:175-176,200-201`) | 底 `tokens(context).text`,字 `tokens(context).bg` | 第一轮 P7:主按钮亮色 = 深底 `#2D2E40` + 白字,暗色 = 浅底 `#ECECF3` + 深字。**亮色下外观会变**,需截图确认 |
| `Colors.black.withValues(alpha:)` 作阴影 | 命名常量(theme 目录),**不要**用 `scheme.shadow` | `mono_theme.dart:132` 把 `shadow` 设成了透明,用了阴影会消失 |
| `Colors.red` / `Colors.redAccent` | `scheme.error` | 暗 `#FFB4AB` / 亮 `#B3261E` |
| `Colors.amber` / `Colors.orange`(警告、进行中、暂停) | 新增状态色 `StatusColors.warning(brightness)` | 默认值借用第一轮"评分图形"琥珀:亮 `#C98A12` / 暗 `#F2B33D`(默认值,设计可改) |
| `Colors.green` / `Colors.greenAccent`(成功) | 新增 `StatusColors.success(brightness)` | 项目没有成功色;默认借用青:亮 `#1F9C88` / 暗 `#5BC8B5`(默认值,设计可改) |
| `Colors.teal` | `StatusColors.success`(同上) | `action_buttons.dart:912` 同步启用状态 |
| `Colors.blue`(信息、下载中) | `scheme.primary`(强调色:亮 `#6256C8` / 暗 `#B4AAFF`) | 下载中 `download_status_icon.dart:68` |
| `Colors.grey`(禁用、取消、调试) | `tokens(context).textMuted` 或 `scheme.onSurfaceVariant` | 亮色次要 `#686B80` / 暗色 `#A6A7B8` |
| `Colors.transparent` | 保留 | 不是语义色,不计入收敛目标 |
| 压图白字/黑渐变 | `PosterOverlayColors.*` 命名常量 | 见保留清单 2 |

主题 token 参考值(第一轮 P7 亮暗对照表,原样抄,用于核对替换后的颜色):

| 语义 | 亮色 | 暗色 |
|---|---|---|
| 页面背景 | `#F1F0F6` | `#000000` |
| 分组面 / 卡片 | `#FFFFFF` | `#14151C` |
| 正文 | `#2D2E40` | `#ECECF3` |
| 次要文字 | `#686B80` | `#A6A7B8` |
| 强调 | `#6256C8` | `#B4AAFF` |
| 选中底 | `#E9E5F6` | `#36324E` |
| 主按钮 | 深底 `#2D2E40` + 白字 | 浅底 `#ECECF3` + 深字 |
| 分隔线与描边 | 正文色 8%-10% | 正文色 8%-10% |
| 底部导航底色 | `#FCFBFF` 94% | `#272733` 94% |

OLED(纯黑)沿用暗色规格,表面用 `#0A0A0A`。

#### 新增 theme 文件

- `lib/theme/status_colors.dart`:`abstract final class StatusColors { static Color warning(Brightness b); static Color success(Brightness b); }`,亮暗各一组常量(值见上表)。放 theme 目录,不计入统计。
- `lib/theme/poster_overlay_colors.dart`:与 R5-5 共用;R5 若先合入则只追加常量(如 `chipFill = Color(0x8533363c)`、`chipBorderAlpha`),不要重复建文件。
- 缺 token 先加到 theme,再在页面替换。

#### auth_screen 处理(`lib/screens/auth_screen.dart`,18 处)

整页是固定深色渐变背景(`:361` `Color(0xff262a32) → Color(0xff08090b)`,`:444` 卡片渐变)。文字白色在这个背景上是对的,把它们换成 `onSurface` 反而在亮色主题下变成深字压深底。默认做法:**不逐个换 token,而是把页面的固定深色调色板收成一个 `AuthPalette`(放 theme 目录或同文件顶部命名常量),并在文件内标注"登录页固定深色"**;只有 `:486` 主按钮 `0xfff4f5f7`/黑字、`:495,502` 这类按钮色按"主按钮"行处理。若产品要求登录页也随主题(待确认),另起任务。

#### 分批要求(一个目录一个提交)

| 批次 | 目录 / 文件 | 预期改动 |
|---|---|---|
| 0 | `lib/theme/` | 新增 `StatusColors`(+ 若缺则 `PosterOverlayColors`) |
| 1 | `lib/screens/media_detail/`(`action_buttons.dart` 13、`presentation.dart` 8)+ `lib/screens/media_detail_screen.dart`(6) | 主按钮、状态色、压图白字常量化 |
| 2 | `lib/screens/settings/`(`logs_screen.dart` 8:`_buildLevelColor` `:322-336` 用 `error/warning/primary/textMuted`;`:354,358,383` 的 `Colors.grey` → `textMuted`)+ `lib/screens/auth_screen.dart` | 见 auth 处理 |
| 3 | `lib/widgets/`(非播放器:`download_status_icon.dart`、`watched_indicator.dart` 常量化、`app_bar_back_button.dart` 常量化) | 状态色、压图常量 |
| 4 | `lib/navigation/`(`fusion_navigation.dart` 9) | 并入 `MonoPresentation` 导航色 |
| 5 | `lib/screens/discover_screen.dart` | 头图芯片常量化、`:1120` 状态色 |
| 暂缓 | `fusion_home_hero.dart`、`hero_metadata_badges.dart`(5 处,含死分支 `0xffffd58a/0xff94681f`) | 等 R1,死分支随 R1 删除 |

每个批次的提交说明写"同一统计命令的前后数量",例:`去 transparent 411 → 4xx`。**不做全仓一次性替换**。每批替换后,亮/暗/纯黑三主题各截一张该页面图。

### R8-5 断点收敛(不改变布局效果)

现状:`layout_constants.dart:6-27` 只有 `mobile 600 / wideTablet 900 / desktop 1200 / largeDesktop 1600`。用命令重新核对散落点(行号可能漂移):
`grep -rnE '\b(600|680|700|720|1100|1180|390)\b' lib --include=*.dart | grep -E 'width|Width|size|Size|>=|<=|<|>'`

处置表(比较符照抄,**不要把 `>` 改成 `>=`**):

| 位置 | 现状 | 处置 |
|---|---|---|
| `catalog_item_detail_screen.dart:954` / `:956` | `width >= 1100` / `width >= 700`(事实网格列数) | 新常量 `catalogFactsThreeColumns = 1100`、`catalogFactsTwoColumns = 700` |
| `auth/plex_pin_auth_flow.dart:228` | `width > 700`(`>`) | 新常量 `authDesktopMin = 700`,保留 `>` |
| `auth_screen.dart:281` | `width > 700`(`>`) | 同上 |
| `auth_screen.dart:352` | `size.width >= 1180`(TV 登录宽版) | 新常量 `authTvWide = 1180` |
| `media_detail/presentation.dart:197`、`media_detail/responsive_layout.dart:58` | `width < 720`(详情头部居中) | 新常量 `compactDetailMax = 720`,两处共用 |
| `media_detail/playback_selectors.dart:130` | `maxWidth >= 680`(选择器三列,另判字号 ≤1.4) | 新常量 `detailSelectorsThreeColumns = 680` |
| `rating_bottom_sheet.dart:620` | `width < 390 ? 124 : 142` | 新常量 `narrowControlMax = 390` |
| `discover_loading_skeleton.dart:45,74`、`discover_screen.dart:1272` | `width < 600` | 改用 `ScreenBreakpoints.isMobile(width)`(`<600`,完全等价) |
| `widgets/pending_auth_dialog.dart:90` | `width >= 600` | `!ScreenBreakpoints.isMobile(width)`(等价) |
| `widgets/overlay_sheet.dart:167` | `width > 600`(`>`) | `width > ScreenBreakpoints.mobile`,保留 `>`;`:171` 的 700 是最大宽度不是断点,不改 |

不属于断点、**不要改**:`mono_presentation.dart:35-36` 的 390(设计稿基准宽度 603/390)、`discover_loading_skeleton.dart:220,331` 的 `clamp(220, 390)`(高度)、`overlay_sheet.dart:171` 的 700、`artist_detail_screen.dart:154`/`collection_detail_screen.dart:321`/`responsive_layout.dart:75`/`overlay_tokens.dart:10` 的 720(内容最大宽)、`watch_together_screen.dart:304` 的 1100(内容最大宽)、`fusion_navigation.dart:63` 的 680(TV 导航最大宽)、`media_version.dart`/`resolution_label.dart` 的 720(分辨率)。

做法:在 `layout_constants.dart` 新增 `abstract final class LayoutBreakpoints`(或追加到 `ScreenBreakpoints`,二选一,写在注释里:"值与旧魔数一致,只改名不改效果"),含上表 7 个新常量;逐处替换。每个文件替换后目视对比该页面在阈值上下各一个宽度(如 699/701、719/720、679/680)的截图,无差异。若产品选择归并到 600/900/1200(C12),需单独截图对比并说明差异,不在本卡默认范围。

### R8-6 zh `auth.quickConnect`

- 现状:`lib/i18n/zh.i18n.json:38` `"quickConnect": "Quick Connect"`;en 同为 `"Quick Connect"`;zh-Hant 为 `"快速連線（Quick Connect）"`(`zh-Hant.i18n.json:38`);az/kk/uz 已译,其余 15 个语言仍为英文(Quick Connect 是 Jellyfin 的功能名,保留英文是常见做法,**本卡不改其他语言**)。用处:`seerr_settings_screen.dart:54` 等。
- 改成:zh 改为 `"快速连接（Quick Connect）"`(C9,可选)。改后运行 `dart run slang`。
- `discover.playEpisode`(zh 的 `S${season}E${episode}`)不改。

## i18n key 与常量表

| 名称 | 动作 | 默认值 | TODO 编号 |
|---|---|---|---|
| `auth.quickConnect`(仅 `zh.i18n.json`) | 改值 | `快速连接（Quick Connect）` | 无(C9) |
| 新增 key | 无 | - | - |
| `LayoutBreakpoints.catalogFactsTwoColumns` | 新增常量 | 700 | 无 |
| `LayoutBreakpoints.catalogFactsThreeColumns` | 新增常量 | 1100 | 无 |
| `LayoutBreakpoints.authDesktopMin` | 新增常量 | 700(`>`) | 无 |
| `LayoutBreakpoints.authTvWide` | 新增常量 | 1180 | 无 |
| `LayoutBreakpoints.compactDetailMax` | 新增常量 | 720(`<`) | 无 |
| `LayoutBreakpoints.detailSelectorsThreeColumns` | 新增常量 | 680 | 无 |
| `LayoutBreakpoints.narrowControlMax` | 新增常量 | 390(`<`) | 无 |
| `StatusColors.warning / success` | 新增 | 见 R8-4 表(默认值,设计可改) | 无 |
| `PosterOverlayColors.*` | 新增/追加 | 与 R5-5 共用 | 无 |
| 标签最小宽度比例 | 常量 | 最大宽 = 行宽 45%;最小宽按字号放大上限 1.5 倍 | 无 |
| 设置项 | 无 | - | - |

## TV 焦点、三主题、四形态要求

- TV 焦点:
  - R8-3 换 `AppDialog` 后,`FocusableListTile`/`FocusableButton` 必须仍被方向键依次遍历,首项能拿到初始焦点(`focusFirstItem`),返回键关闭对话框;不得让焦点困在滚动容器外。
  - R8-1/R8-2 不改变任何可聚焦控件的结构,只改文字约束。
  - R8-4 替换后,聚焦态的颜色不得丢失(`action_buttons.dart:135` 聚焦描边 `Colors.white` 在亮色下不可见,应改 `scheme.primary` 或 `scheme.onSurface`;这是替换的一部分,TV 亮色主题需目视)。
- 三主题:R8-4 每批在亮/暗/纯黑下目视;亮色下不得再出现写死的深色块或白字压浅底;纯黑主题下表面用 `#0A0A0A` 不变。对话框(R8-3)三主题下都是磨砂面,降级(`AppGlassSurface.reduceEffects`)时用不透明底,文字对比度 ≥ 4.5:1。
- 手机:长服务器名/版本串单行省略;对话框窄屏(320px)可滚动。
- 平板/桌面:详情信息行标签随字号放大不截断;断点两侧布局无变化。
- TV:对话框在 10 英尺距离字号不变;断点常量化不改变 TV 登录宽版(`authTvWide`)。

## 测试要求

修改:
1. `test/widgets/option_picker_dialog_test.dart:64`、`:71`:`find.byType(SimpleDialog)` 改为 `find.byType(AppDialog)`;其余断言(切换开关后对话框仍在、选项选择后关闭、标签单行)保持。
2. `test/watch_together/local_media_match_dialog_test.dart:147`(`requires a deliberate version choice ...`)、`:197`、`:212`、`:224`:不预期改,必须回归;若断言依赖 `SimpleDialog` 则同步为 `AppDialog`。

新增:
- `test/widgets/server_activities_button_test.dart`:`very long server name is ellipsized without overflow`:构造 80 字符的 `serverName`,窄宽(320)面板,`tester.takeException()` 为空,数量徽标仍可见。
- `test/widgets/hub_section_test.dart`:`very long hub title and server name do not overflow`:`showServerName: true`,超长标题 + 超长 serverName,320px,无异常;TV 形态同样断言。
- `test/screens/profile/borrow_connection_screen_test.dart`:`long connection label and profile name stay inside the row`。
- `test/screens/settings/add_jellyfin_screen_test.dart`:`long server name and version render on one line each`(`maxLines == 1` 的 `Text` 断言 + 无异常);需先看文件内现有的 server info 构造方式(待核对)。
- `test/screens/catalog_item_detail_screen_test.dart`、`test/screens/media_detail_screen_test.dart`:`fact label scales with text size and is not truncated`:`textScaler 1.5/2.0` + 长标签(如德语长词),标签 `Text` 无 ellipsis、无异常。
- `test/utils/dialogs_test.dart`:`option picker dialog is a glass AppDialog and scrolls on short viewports`;D-pad 下键首项到末项可达。
- 断点:`test/utils/layout_constants_test.dart`(若不存在则新建):`breakpoint constants keep the legacy thresholds`,断言每个新常量等于其旧魔数(700/700/1100/1180/720/680/390),防止被无意改动。
- 颜色(每批):在对应已有页面测试里加 `light theme has no hard-coded dark block` 类用例较难断言;改为轻量断言:关键 widget 的 `decoration.color`/`foregroundColor` 等于 `Theme.of(context)` 对应 token。至少覆盖 `action_buttons` 主按钮(亮/暗各一次)与 `logs_screen` 等级色。
- i18n:`test/i18n/` 下若有 zh 文案用例,同步;否则不新增。

## 验收清单

- [ ] `flutter analyze` 无新增告警
- [ ] `scripts/run_tests.sh test/widgets/option_picker_dialog_test.dart test/watch_together/local_media_match_dialog_test.dart test/utils/dialogs_test.dart test/widgets/server_activities_button_test.dart test/widgets/hub_section_test.dart test/screens/profile/borrow_connection_screen_test.dart test/screens/settings/add_jellyfin_screen_test.dart test/screens/catalog_item_detail_screen_test.dart test/screens/media_detail_screen_test.dart`
- [ ] `scripts/run_tests.sh` 全量通过
- [ ] `scripts/codegen.sh --check` 通过;`python3 scripts/checks/clean_translations.py --check --strict` 通过
- [ ] 颜色统计命令前后对比写入每个相关提交说明;批次 1-5 完成后去 transparent 总数低于基线 411,且排行里非保留的文件(第 2/4/15/16/17/20 位)清零或仅剩命名常量
- [ ] `git grep -n 'SimpleDialog' lib` 无结果
- [ ] `git grep -nE '(width|Width|size\.width)\s*(>=|<=|<|>)\s*(700|720|1100|1180|680|390)' lib` 无结果(魔数断点清零)
- [ ] 手动:构造 60+ 字符服务器名(Jellyfin 添加页、活动面板、首页 hub 标题行、借用连接页),320px 与 TV 下无黄黑溢出条
- [ ] 手动:德语/俄语 + 系统字号 150%/200%,详情页信息行与目录项事实行标签不截断
- [ ] 手动:选项选择对话框与观影匹配版本选择对话框外观一致(磨砂),手机/桌面/TV 方向键可操作,返回键可关闭
- [ ] 手动:亮/暗/纯黑下检查每个被改页面;主按钮亮色为深底白字,暗色为浅底深字
- [ ] 手动:阈值上下宽度(699/701、719/720、679/680、389/390、1179/1180、1099/1100)截图对比无差异
- [ ] 手动:zh 语言下 Seerr 设置里登录方式显示"快速连接（Quick Connect）"

## 提交拆分

1. `fix(显示): Jellyfin 添加页服务器名与版本串单行省略`
2. `fix(显示): 活动面板与 hub 标题行服务器名加 Flexible 与省略`
3. `fix(显示): 借用连接页长文字约束`
4. `test: 长服务器名与版本串溢出用例`
5. `fix(显示): 详情页固定宽度标签改最小宽度加上限`
6. `refactor(对话框): 选项选择对话框改用 AppDialog`
7. `refactor(对话框): 观影匹配版本选择对话框改用 AppDialog`
8. `test: 对话框改用 AppDialog 后的断言与滚动用例`
9. `feat(主题): 新增状态色与压图覆盖色命名常量`
10. `refactor(主题): 详情页目录硬编码颜色改用 token`(批次 1)
11. `refactor(主题): 设置与登录页硬编码颜色收敛`(批次 2)
12. `refactor(主题): widgets 目录状态色与压图色收敛`(批次 3)
13. `refactor(主题): 导航硬编码颜色并入 MonoPresentation`(批次 4)
14. `refactor(主题): 首页头图芯片与状态色收敛`(批次 5)
15. `refactor(布局): layout_constants 新增命名断点常量`
16. `refactor(布局): 详情与目录页断点魔数替换为常量`
17. `refactor(布局): 登录与弹层断点魔数替换为常量`
18. `test: 断点常量保持旧阈值`
19. `fix(i18n): 中文 Quick Connect 译为快速连接`

## 风险与待确认

1. C5:首页头图/压图文字亮色策略未定,`fusion_home_hero.dart` 本卡不动。
2. C9:zh `quickConnect` 是否译,可选。
3. C12:断点常量 vs 归并,默认只命名不改值。
4. 主按钮改为 token 后亮色下由浅底变深底,是第一轮 P7 规定的方向,但会改变外观,需设计过目。
5. 登录页是否要随主题(默认保持固定深色),待产品。
6. `StatusColors` 的 success 色是借用青色的默认值,设计可改。
7. `AppDialog` 不带滚动/标题,R8-3 初始焦点行为需 TV 实测(待核对)。
8. 颜色统计口径含 `GlassSheetColors.of` 的 13 处误匹配,写前后数时用同一命令,不要与第一轮"约 413"直接比绝对值。
9. 播放器目录占总量约四成,本卡不改;若以后要治理,另立任务并先和产品确认"播放器始终深色"。

## 禁止事项

- 不直接改生成的 Dart 文件;改 `lib/i18n/*.i18n.json` 后运行 `dart run slang`(全量生成 `scripts/codegen.sh`,校验 `scripts/codegen.sh --check`,来自 AGENTS.md 与 CONTRIBUTING.md)。
- 不删除 Plex/Jellyfin/Emby、一起看、TV 支持;不改 mpv/ExoPlayer。
- 不引入需要新凭据的第三方服务。
- 不改播放器控制层颜色,不改压图角标的"深底白字"原则。
- 不改变任何断点的阈值或比较符;不把压图白字换成 `onSurface`。
- 不用 `colorScheme.shadow` 做阴影(主题里它是透明)。
- 不在一个提交里混多个目录的颜色替换;不做全仓一次性替换。
- 不提交凭据、构建产物、本地参考文件;保留 Plezy 上游署名。
