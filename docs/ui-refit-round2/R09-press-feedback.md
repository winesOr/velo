# R9 交互反馈收尾 任务卡

- 基线提交:`8885b39`(与清单所用 `fe12755` 之间只多一个纯文档提交,代码行号一致)
- 声明:静态读码,未运行。本环境无 flutter,未跑 analyze/测试,未在真机/TV 验证。行号动手前用 grep 复核。
- 目标:把第一轮已建好的 `PressFeedback` 按压反馈补接到评分星星、菜单选项行、`FocusableButton`、筛选 Chip、"查看全部"/人物卡、剧集卡等控件,补齐遮罩/触感/加载文案/箭头旋转,并给按压包装补单测。
- 优先级:中为主(R9-1 测试、R9-3、R9-4、R9-5),其余低。
- 规模:中(约 12 个提交,每个都小)。
- 前置依赖:R9-1(测试)先做;R9-10(箭头旋转)与 R4-1 同改 `app_select_field.dart`,先合 R4-1;R11 动效 token 未定,时长先用现有 `InteractionTokens`。
- 不在范围:首页头图按钮(`discover_screen.dart:1576` 与 `fusion_home_hero.dart:234` 的按压归 R1,R1 会删掉按钮);动效/转场(R11);设置项行与 `FocusableListTile`(见"待确认"第 2 条);播放器内传输按钮的暗层(规格要求只缩放不加暗层,本包不动)。

## 0. 第一轮规格(原样抄录,来源 `docs/ui-ratings-selectors-performance-plan-2026-11-11.md` P8)

通用按下包装:`lib/widgets/press_feedback.dart`,包按下与抬起驱动 `AnimatedScale` 与一层明暗遮罩;缩放比例、时长做成 `lib/theme` 常量;各控件复用,不要各写一套。

| 控件 | 按下 | 完成 / 选中 | 触感 |
|---|---|---|---|
| 主按钮(播放) | 缩到 97%,底色变暗一档 | 进入加载态时显示小转圈和"正在打开" | 轻触感 |
| 圆形次要按钮 | 缩到 94%,底色提亮、描边加强 | 开关型按钮切到选中底 + 强调色图标 | 无 |
| 海报卡片 | 缩到 96%,叠 22% 暗层 | 长按弹出现有上下文菜单(`media_context_menu.dart`) | 长按触发时一次 |
| 下拉触发行 | 底色提亮,箭头变亮 | 展开时 2px 强调色描边,箭头旋转 180° | 无 |
| 菜单选项 | 10% 前景底色 | 选中底 + 对勾淡入,延迟 120ms 再关闭菜单 | 选择触感 |
| 底部导航 | 图标缩到 90% 后回弹 | 强调色 + 加粗(保持现有选中样式) | 选择触感(已有) |
| 打分星星 | 当前星放大到 120% | 依次点亮,保存后显示"已保存" | 每颗一次 |
| TV 遥控器 | 焦点描边不变,确认键时缩到 97% | 同上 | 无 |

规则:
- 时长:按下 120ms,回弹 180–200ms,曲线 `Curves.easeOutCubic`;不做弹簧过冲。
- 降级:`MediaQuery.disableAnimationsOf(context)` 为真时只变色、不缩放;`DevicePerformance.isReduced` 时去掉暗层动画。
- 触感只走 `selectionFeedback()`,不直接调 `HapticFeedback`;TV 与桌面不触发。
- 按下态不得改变布局尺寸(用 `Transform` 缩放),避免列表跳动;滚动手势开始时立即取消按下态。
- 播放器内的传输按钮保持白色图标,只加缩放,不加暗层。
- 验收:手机上每个可点击控件按下都有可见变化;滑动列表时卡片不误触发;开启系统"减弱动态效果"后无缩放;TV 遥控器焦点与确认反馈正常;给按下包装加 widget 测试(按下、抬起、取消、禁用动画四种情况)。

## 1. 现状核实(HEAD 8885b39)

- `lib/theme/interaction_tokens.dart`(15 行):`selectPressedScale .97`、`mainPressedScale .97`、`secondaryPressedScale .94`、`cardPressedScale .96`、`navigationPressedScale .90`、`pressDuration 120ms`、`releaseDuration 180ms`、`menuSelectionDuration 120ms`、`pressCurve easeOutCubic`;`TODO(VELO-P8-01) :5`。
- `lib/widgets/press_feedback.dart`(103 行):`PressFeedback`(`:10`)纯绘制,参数 `pressed/enabled/pressedScale/pressDuration/releaseDuration/borderRadius`;遮罩固定 `onSurface` 8%(`:43`);减弱动画只变色(`:33-36`);`DevicePerformance.isReduced` 去掉遮罩动画时长(`:40`)。`PressFeedbackBuilder`(`:54`)提供 `setPressed` 与 `confirm`(确认键 120ms 一次性按下,`:83-87`)。
- `lib/utils/selection_feedback.dart:9`:`selectionFeedback()` = 非 TV 的 Android/iOS 上 `lightImpact`。
- 已接入:`navigation/fusion_navigation.dart:119,192`、`widgets/mobile_navigation_rail.dart:164`、`widgets/side_navigation_rail.dart:369,1490`、`widgets/media_card.dart:1789`(`_CardTapRegion :1694`)、`media_detail/action_buttons.dart:275`(主按钮)、`media_detail/action_press.dart:28`(次要按钮,`DetailActionPress`)、`widgets/app_select_field.dart:156`;首页头图 `discover_screen.dart:1576`、`fusion_home_hero.dart:234`(R1 将删)。
- 触感已在:`focusable_list_tile.dart:217`、`setting_tile.dart:34`、`player_settings_controls.dart:108,197`、`expressive_button_group.dart:110`、`app_select_field.dart:111`、`fusion_navigation.dart:46`。
- 未接入(已逐个读码):
  - `lib/focus/focusable_button.dart`(85 行):只有焦点透明度动画,无按压;约 57 个文件在用,含播放器内(`desktop_video_controls.dart`、`player_prompt_overlays.dart` 等)。
  - 菜单选项行 `lib/widgets/app_menu.dart` 的 `AppMenuItemTile`(`:531`):悬停/聚焦 8% 底,选中 12% 主色底 + 对勾(`_backgroundColor`、`trailing`,约 `:575-690`),`GestureDetector.onTap`(无按下态),对勾无淡入。`anchored_option_menus.dart` 只是组装 `AppMenuItem`,不用改。
  - 评分星星 `lib/widgets/rating_bottom_sheet.dart` 的 `_StarRatingControl :710-783`:`GestureDetector`(`onTapDown/onTapUp/onPanUpdate/onPanEnd`),无放大、无触感、无 `onTapCancel/onPanCancel`;值为 0–10(半星)。"已保存"已有:`_run :443-455` 成功后设 `_statuses[key]=_SectionStatus(t.rateSheet.saved)`,但仅以 `_TrailingStatus`(`:686`)的对勾图标 + Tooltip 呈现,副标题仅在出错时显示(`:618` 一带 `statusText`)。
  - 筛选 Chip:`focus/` 的 `FocusBuilders.buildFocusableChip`(`lib/widgets/focus_builders.dart:26-63`)——`FocusableFilterChip`(`focusable_filter_chip.dart:84`)、`FocusableTabChip`(`focusable_tab_chip.dart:154`)共用;只有 `GestureDetector(onTap)`。
  - "查看全部"与人物卡:`FocusBuilders.buildLockedFocusWrapper`(`focus_builders.dart:78-130`),使用处 `hub_section.dart:745`(查看全部)、`hub_section.dart:803`(内容是 `MediaCard`,已有按压)、`cast_member_strip.dart:213`(人物)、`tv_browse_rail.dart:1657`、`media_detail_screen.dart:4551`(内容是 `MediaCard`)。触摸模式下该函数只返回 `GestureDetector`(`:104-110`)。
  - 剧集卡 `lib/widgets/episode_card.dart`:`FocusableWrapper(disableScale: true)`(`:147-152`)+ `InkWell`(`:159-165`),无 `PressFeedback`。
  - 设置项行:`setting_tile.dart` `_SettingRow`(`:44`)用 `FocusableListTile`(Material `ListTile` 自带 ink)。
- `media_card.dart`:长按走 `_CardTapRegion` 的 `GestureDetector.onLongPress`(`:1769`、桌面 `InkWell :1782`)→ `showContextMenuFromTap`(`:380` 覆盖,`:508`、`:628` 传入);无触感。
- `action_buttons.dart`:主按钮加载态 `:248-251` 只显示 20px 转圈(`semanticsLabel: t.common.loading`);`PressFeedback :275-281` 已带 `enabled: !_playLaunchPending`。
- `app_select_field.dart`:边框 `:160-166` 展开 2px 强调色已有;箭头 `:209` 在 `expand_less_rounded/expand_more_rounded` 间切换;选中延迟 120ms(`:84-86`,清单 C8 保持)。
- `companion_remote/mobile_remote_screen.dart`:直接 `HapticFeedback.lightImpact()` 在 `:153`(`_sendCommand`)、`:518`、`:555`、`:635`、`:660`、`:732`;文件内 `import 'package:flutter/services.dart'` 在 `:4`。
- 现有相关测试:`test/widgets/app_select_field_test.dart`(`:221` 滚动取消、`:249` 减弱动画)、`f4_home_feedback_test.dart`、`media_card_full_card_test.dart`(位置待核对:`find test -name media_card_full_card_test.dart`)、`selection_feedback_test.dart`。无 `press_feedback_test.dart`。

## 2. 涉及文件表

| 文件 | 行号 | 现状 | 动作 |
|---|---|---|---|
| `test/widgets/press_feedback_test.dart` | 无 | 无 | 新增 |
| `lib/theme/interaction_tokens.dart` | 全文 15 行 | 无遮罩 token | 改:新增遮罩 alpha 常量 |
| `lib/widgets/press_feedback.dart` | `:10-50`、`:54-103` | 遮罩固定 8% | 改:新增 `overlayColor/overlayAlpha`;新增指针包装 `PressFeedbackPointer` |
| `lib/focus/focusable_button.dart` | `:54-85` | 无按压 | 改 |
| `lib/widgets/app_menu.dart` | `AppMenuItemTile :531-690` | 无按下态,对勾无淡入 | 改 |
| `lib/widgets/rating_bottom_sheet.dart` | `_StarRatingControl :710-783`;`_run :443-455`;`_RatingRow` 副标题约 `:618` | 无放大/触感/取消处理 | 改 |
| `lib/widgets/focus_builders.dart` | `buildFocusableChip :26-63`;`buildLockedFocusWrapper :78-130` | 无按压 | 改:chip 默认接入;locked wrapper 新增开关参数 |
| `lib/widgets/hub_section.dart` | `:745` | "查看全部" | 改:打开开关 |
| `lib/widgets/cast_member_strip.dart` | `:213` | 人物卡 | 改:打开开关 |
| `lib/widgets/episode_card.dart` | `:147-165` | 无 | 改 |
| `lib/widgets/media_card.dart` | `_CardTapRegion :1694-1800`;遮罩 `:1789-1796` | 无长按触感;遮罩 8% | 改 |
| `lib/screens/media_detail/action_buttons.dart` | `:248-251`、`:275-281` | 加载态只有转圈 | 改 |
| `lib/screens/media_detail/action_press.dart` | `:28-33` | 次要按钮 | 不改(或仅传遮罩参数,见 R9-2) |
| `lib/widgets/app_select_field.dart` | `:209` | 图标切换 | 改:箭头旋转 |
| `lib/screens/companion_remote/mobile_remote_screen.dart` | `:153,518,555,635,660,732`、`:4` | 直调 `HapticFeedback` | 改 |
| `lib/i18n/*.i18n.json` | `detailPlayback` 组(en `:2581`) | 无"正在打开" | 新增 1 key |
| `test/widgets/selection_feedback_test.dart` | 全文 | 触感通道 mock `:30-33` | 追加用例 |

## 3. 逐步修改说明

### R9-1 补 `press_feedback_test.dart`(先做)
新文件 `test/widgets/press_feedback_test.dart`,参考 `app_select_field_test.dart` 的 `_pumpField`(`MaterialApp` + `testMonoTokens`,`test/test_helpers/theme.dart`)。用例见第 6 节。目的:先把现状行为固定住,后面改遮罩参数时有保护。

### R9-2 遮罩可配置(按控件类型)
- 现状:`press_feedback.dart:43` 遮罩固定 `onSurface` 8%。
- 改成:`PressFeedback` 与 `PressFeedbackBuilder` 增加 `Color? overlayColor`、`double? overlayAlpha`(为空沿用 8% `onSurface`,旧调用不变)。`interaction_tokens.dart` 新增:
  - `selectOverlayAlpha = .08`(现状)
  - `menuOverlayAlpha = .10`(规格:菜单选项 10% 前景底色)
  - `cardOverlayAlpha`:规格是"22% 暗层,亮色更深、暗色更淡"。取亮色 `.22`、暗色 `.16`(暗色数值为推断,规格只写"更淡"),暗层颜色用黑。`TODO(VELO-P8-02)` 真机后调;写成 `cardOverlayAlphaLight/Dark` 两个常量。
  - `mainOverlayAlpha = .10`(规格"底色变暗一档",无数值,推断),黑色,`TODO(VELO-P8-02)`。
- 接入:`media_card.dart:1789` 传卡片遮罩(按 `Theme.of(context).brightness` 选 alpha,黑色);`action_buttons.dart:275` 传主按钮遮罩;`action_press.dart`(圆形次要按钮)规格是"底色提亮、描边加强",本包只保持现有 8% 前景色叠加,描边加强不做(待确认,见第 9 节)。
- `DevicePerformance.isReduced` 与减弱动画逻辑保持。

### R9-3 `FocusableButton` 接入按压
- 现状:只有焦点透明度动画,约 57 个文件在用;TV 确认键(`FocusableWrapper.onSelect`,`focusable_wrapper.dart:455-462`)没有按压反馈;触摸由子按钮自己的 ink 处理。
- 改成:
  - TV/键盘:确认键触发 97% 一次性缩放(`PressFeedbackBuilder.confirm`)。
  - 触摸:新增 `PressFeedbackPointer`(放在 `press_feedback.dart`)——一个包 `Listener` 的小组件,`onPointerDown` 置按下,`onPointerUp/Cancel` 复位,`onPointerMove` 位移超过 `kTouchSlop`(`package:flutter/gestures.dart`)即复位(满足"滚动手势开始时立即取消");不拦截手势,不改命中。
- 做法:
  - `FocusableButton` 新增 `bool pressFeedback = true`、`double pressedScale = InteractionTokens.selectPressedScale`。
  - `build` 内:`PressFeedbackBuilder(enabled: enabled && pressFeedback, pressedScale: ..., borderRadius: 100圆角, builder: (ctx, setPressed, confirm) => PressFeedbackPointer(onPressedChanged: setPressed, child: FocusableWrapper(onSelect: widget.onPressed == null ? null : () { confirm(); widget.onPressed!(); }, ...原参数)))`。结构上 `PressFeedback` 在最外层,缩放整个按钮(含焦点描边)——规格写"焦点描边不变",所以描边不应跟着缩;若实现后发现描边被缩,把 `PressFeedback` 放到 `AnimatedOpacity` 的 child 内(只缩内容)。以"TV 确认时描边尺寸不变"为准。
  - 播放器内按钮(`desktop_video_controls.dart`、`player_settings_controls.dart`、`danmaku_sources_sheet.dart`、`dlna_cast_sheet.dart`、`subtitle_search_sheet.dart`、`sleep_timer_active_status.dart`、`player_prompt_overlays.dart`、`screens/video_player/parts/build.dart` 用了 `FocusableButton(`)规格要求"只缩放不加暗层":这些调用点传 `pressFeedback` 默认即可(默认就是只缩放 + 现有 8% 遮罩),需把 `overlayAlpha: 0` 作为参数暴露:`FocusableButton.pressOverlay = true`,播放器内调用点设 `false`。具体哪些算"传输按钮"待核对(grep 上述文件逐个看)。
  - `useBackgroundFocus: true` 的按钮(背景色变化表示焦点)同样接入。
- 注意:`FocusableButton` 的 child 常是 `TextButton/FilledButton`,自带 ink;缩放 + ink 同时存在属预期。

### R9-4 菜单选项行
- 现状:`AppMenuItemTile`(`app_menu.dart:531`)无按下态;选中底 `primary 12%`、对勾直接出现。
- 改成:按下时整行底色 10% 前景(`menuOverlayAlpha`);选中时对勾淡入(120ms,`InteractionTokens.menuSelectionDuration`);减弱动画下无淡入,直接显示。
- 做法:
  - `_AppMenuItemTileState` 新增 `bool _pressed`,`GestureDetector` 增加 `onTapDown: (_) => setState(() => _pressed = true)`、`onTapUp/onTapCancel` 复位;在 `_backgroundColor` 里 `_pressed` 优先于 hover/focus:`onSurface.withValues(alpha: InteractionTokens.menuOverlayAlpha)`(`stateLayerColor` 的危险项保持其红色)。滚动取消靠 `onTapCancel`(菜单里的 `ListView` 滚动会触发)。
  - 对勾:在 `initState` 记 `_initiallySelected = _selected`;`trailing` 为对勾时包 `TweenAnimationBuilder<double>`:初始已选中的不动画(`begin: 1`),因选中变为 true 才出现的从 0→1。因为 `trailing` 目前是"选中才创建",`TweenAnimationBuilder` 在首次挂载时从 `begin` 起跑,正好满足。时长 `MediaQuery.disableAnimationsOf(context) ? Duration.zero : InteractionTokens.menuSelectionDuration`。
  - 不改 `selectionDelay` 逻辑(`:516-529`,已按 120ms)。
  - 触感:`AppSelectField` 已在 `:111` 调 `selectionFeedback()`;`showAnchoredSelectionMenu` 等其他调用方不在本包补触感(待确认,见第 9 节)。
- 影响面:所有 `AppMenuItem`(上下文菜单、排序、下拉)都会获得按下态,需回归 `anchored_option_menus_test.dart`、`floating_app_menu_test.dart`、`media_context_menu_test.dart`。

### R9-5 评分星星
- 现状:`_StarRatingControl`(`rating_bottom_sheet.dart:727`)无放大、无触感、无取消处理。
- 改成:
  - 手指按下/拖动时,当前所指星(第 `ceil(value/2)` 颗)放大到 120%(`AnimatedScale`,按下 `pressDuration`,回弹 `releaseDuration`);松手/取消复位。减弱动画下不缩放,可保持当前颜色不变。
  - 触感:每跨过一颗星触发一次 `selectionFeedback()`(半星步进不触发,只在 `ceil(value/2)` 变化时触发)。`_setFromDx`(`:775-780`)里比较新旧星序再调用。
  - 保存反馈:`_run` 成功后副标题显示 `t.rateSheet.saved`(已有 key)而不只是对勾 Tooltip:在 `_RatingRow` 里,`status` 非错误时 `statusText = status.text`,约 2 秒后恢复为 subtitle(用 `Timer`,`dispose` 取消)。具体显示时长 2 秒为推断,`TODO(VELO-P8-03)`。
- 做法:`_StarRatingControlState` 新增 `bool _pressing`;`GestureDetector` 补 `onTapCancel`、`onPanCancel`、`onPanStart`;`onTapDown`/`onPanStart` 置 true,`onTapUp/onPanEnd/onTapCancel/onPanCancel` 置 false(同时清 `_pointerValue`)。每颗星外包 `AnimatedScale(scale: _pressing && i == activeIndex && !reduceMotion ? 1.2 : 1.0, ...)`。星星不改布局尺寸(`Transform`)。
- TV:该控件靠 `_RatingRow` 的 `onDecrease/onIncrease`(`:173-174`)操作,不走手势;TV 不触感、不放大;"已保存"显示同样生效。
- 与 R5 的边界:R5 不改此文件(清单 R5 只涉评分条与角标);若 R5 的提交也改 `rating_bottom_sheet.dart`,以先合并者为准。

### R9-6 筛选 Chip 与"查看全部"/人物卡
- 现状:`buildFocusableChip` 仅 `GestureDetector(onTap)`;`buildLockedFocusWrapper` 触摸模式只返回 `GestureDetector`。
- 改成:
  - `buildFocusableChip`:包一层 `PressFeedbackBuilder`(`pressedScale: selectPressedScale`,`borderRadius: BorderRadius.circular(borderRadius)`),`GestureDetector` 增加 `onTapDown/onTapUp/onTapCancel` 调 `setPressed`;`onKeyEvent` 外面再包一层:确认键(enter/select/space/gameButtonA)按下时调 `confirm()` 后再交给原回调。该函数是静态方法无 State,所以用 `PressFeedbackBuilder` 提供状态。所有 Chip(`FocusableFilterChip`、`FocusableTabChip`)一次性受益。
  - `buildLockedFocusWrapper`:新增参数 `bool pressFeedback = false`、`double pressedScale = InteractionTokens.cardPressedScale`;为 true 时在触摸分支与键盘分支都包 `PressFeedbackBuilder`。只在 `hub_section.dart:745`("查看全部")、`cast_member_strip.dart:213`(人物)传 true。`hub_section.dart:803`、`media_detail_screen.dart:4551`、`tv_browse_rail.dart:1657` 的内容是 `MediaCard`(已有按压),不要打开,避免双重缩放。
- 触感:Chip 的"选中"是业务状态变化,不在此统一触发;若某 Chip 切换筛选,由调用方自己调 `selectionFeedback()`(本包不加,避免漏判)。

### R9-7 剧集卡
- 现状:`episode_card.dart:147-165`:`FocusableWrapper(disableScale: true)` 内 `InkWell`。
- 改成:`InkWell` 外包 `PressFeedback`,用 `InkWell.onHighlightChanged` 驱动 `pressed`(与 `media_card.dart` 桌面分支 `:1775-1785` 同一做法,滚动取消由 `InkWell` 自己处理);`pressedScale: InteractionTokens.cardPressedScale`?剧集卡是整行宽卡,96% 偏大——规格没单列,先用 `selectPressedScale`(97%),`TODO(VELO-P8-01)`;遮罩用卡片遮罩(R9-2)。`MediaContextMenu` 长按路径不变。TV 确认键:`FocusableWrapper.onSelect` 里调 `confirm`(用 `PressFeedbackBuilder`)。
- 触感:长按弹菜单时 `selectionFeedback()`(同 R9-8,走 `showContextMenuFromTap` 前调用)。

### R9-8 海报卡长按触感
- 现状:`media_card.dart` 长按无触感。
- 改成:长按触发上下文菜单时触发一次 `selectionFeedback()`。
- 做法:在 `_CardTapRegionState.build`(`:1747-1790`)两个分支的 `onLongPress` 包一层:`onLongPress: widget.onLongPress == null ? null : () { selectionFeedback(); widget.onLongPress!(); }`。`_CardTapRegion` 新增 `bool hapticOnLongPress = true`;目录占位卡(`item is MediaItem && item.isCatalogItem`,`media_card.dart:538`,长按没有菜单)传 `false`,避免"震了但没菜单"。调用点:`:508`(列表)与 `:628`(网格)两处创建 `_CardTapRegion` 的地方,具体参数传递路径待核对(`grep -n "_CardTapRegion(" lib/widgets/media_card.dart`)。桌面/TV 的 `selectionFeedback` 自行 no-op。
- 注意:`Semantics.onLongPress`(`:529`)是无障碍入口,不触感。

### R9-9 主按钮加载文案
- 现状:`action_buttons.dart:248-251` 只显示 20px 转圈。
- 改成:转圈 + "正在打开"文本(新 key `detailPlayback.opening`)。保持按钮宽度不跳:用 `Row(mainAxisSize: min)`,文本 `Flexible` + 单行省略,样式用 `playTextStyle`(同文件 `:261` 一带)。无图标布局(`playButtonLabel.isEmpty`,紧凑模式)只显示转圈。
- 不可重复点击:已有 `onPressed: _playLaunchPending ? null : onPlayPressed`(`:319`)、`PressFeedback enabled: !_playLaunchPending`(`:277`),保持。
- 语义:`semanticsLabel` 改用 `t.detailPlayback.opening`;`MediaQuery.disableAnimationsOf` 下转圈保留(`CircularProgressIndicator` 不受影响)。

### R9-10 下拉箭头旋转
- 现状:`app_select_field.dart:209` 在 `expand_less_rounded` 与 `expand_more_rounded` 间切换。
- 改成:始终用 `expand_more_rounded`,外包 `AnimatedRotation(turns: _menuOpen ? .5 : 0, duration: reduceMotion ? Duration.zero : InteractionTokens.releaseDuration(180ms), curve: pressCurve)`;`busy` 时仍显示转圈。R11 的动效 token 定后再替换时长。
- 同文件 `side_navigation_rail_test.dart:551` 引用的是侧栏的 `expand_less_rounded`,与此无关。
- 前置:R4-1 先合。

### R9-11 遥控屏幕触感统一
- 现状:`mobile_remote_screen.dart` 6 处直调 `HapticFeedback.lightImpact()`。
- 改成:全部改为 `selectionFeedback()`(`import '../../utils/selection_feedback.dart'`)。行为差异:`selectionFeedback` 在 TV/桌面不触发,本屏幕是手机遥控,不受影响。
- 清理:确认文件内是否还有其他 `services.dart` 符号(如 `Clipboard`、`SystemChannels`),没有则删 `:4` 的导入(以 analyzer 为准)。
- 验收 grep:`grep -n "HapticFeedback" lib/screens/companion_remote/mobile_remote_screen.dart` 无结果。

## 4. i18n / 设置项 / 常量

| key | en | zh | zh-Hant | 其余语言 |
|---|---|---|---|---|
| `detailPlayback.opening`(新增) | Opening… | 正在打开 | 正在開啟 | 英文占位(复制 en,共 19 个:az bg da de es fr hu it ja kk ko nb nl pl pt ru sv tr uz;与现有 `detailPlayback` 在各语言里是英文的做法一致) |

清单 R9-4 写"其余按 R5-8 方式占位",即同样英文占位。`t.rateSheet.saved` 已有,不新增。生成命令:`dart run slang`(CONTRIBUTING.md);全量 `scripts/codegen.sh`,校验 `scripts/codegen.sh --check`。

常量(`lib/theme/interaction_tokens.dart`):

| 名称 | 默认值 | TODO 编号 |
|---|---|---|
| `menuOverlayAlpha` | .10 | `VELO-P8-01` |
| `cardOverlayAlphaLight` | .22 | `VELO-P8-02`(新增) |
| `cardOverlayAlphaDark` | .16(推断) | `VELO-P8-02` |
| `mainOverlayAlpha` | .10(推断) | `VELO-P8-02` |
| `ratingStarPressedScale` | 1.2 | `VELO-P8-01` |
| 评分"已保存"副标题显示时长 | 2 秒(推断) | `VELO-P8-03`(新增) |
| 其余缩放/时长 | 保持现值 | `VELO-P8-01` 已有 |

无新增设置项。

## 5. TV 焦点、主题、形态

- TV:新控件/改动都在 `FocusableWrapper`/`FocusableButton`/`Focus` 之内,不新增裸手势控件;确认键触发 `confirm()` 的一次性 97%(120ms),焦点描边不动;`selectionFeedback` 在 TV 不触发。`FocusableButton` 的 `onSelect` 包装后,`autofocus`、`onNavigate*`、`onBack` 行为不变。
- 手机:所有可点击控件按下有可见变化;列表里按下后滑动立即取消(靠 `InkWell`/`GestureDetector` 取消回调或 `PressFeedbackPointer` 的位移阈值)。
- 平板/桌面:鼠标按下同样有缩放/遮罩;悬停态不变;`selectionFeedback` 在桌面不触发。
- 减弱动画(系统"移除动画"):只变色、不缩放、对勾不淡入、箭头不旋转、星星不放大。
- 三主题:卡片遮罩亮色用黑 22%、暗色/纯黑用黑 16%(纯黑背景上黑色遮罩几乎看不见,需目视确认,必要时纯黑下改用白色 8% 提亮,待确认);菜单按下底用 `onSurface` 10%;不写死十六进制,颜色取自 `colorScheme`。

## 6. 测试要求

新增 `test/widgets/press_feedback_test.dart`:
- `pressed scales to the token value and releases to 1`:`pressed: true` 后 `pump(150ms)`,`AnimatedScale.scale == InteractionTokens.selectPressedScale`;`pressed: false` 后 `pump(200ms)` 回 1。
- `custom pressedScale overrides the default`(传 `.94`)。
- `reduced motion only tints`:`MediaQuery(disableAnimations: true)` 下 scale 恒为 1,`foregroundDecoration` 颜色 alpha > 0(参考 `app_select_field_test.dart:249` 的取法)。
- `disabled never reacts`:`enabled: false, pressed: true` → scale 1、无遮罩。
- `custom overlay alpha is applied`(R9-2 之后)。
- `PressFeedbackBuilder confirm presses for 120ms then releases`:调 `confirm`,`pump(119ms)` 仍按下,`pump(2ms)` 已释放;`enabled:false` 时 `confirm` 无效。
- `PressFeedbackBuilder disposes its confirmation timer`(卸载后无 pending timer)。
- `PressFeedbackPointer cancels when the pointer moves beyond touch slop`;`pointer cancel releases`;`up releases`;且不拦截子组件的 `onTap`。

新增/修改其他测试:
- `test/widgets/focusable_button_test.dart`(位置待核对:`find test -name "focusable_button*"`):`confirm key scales once and still calls onPressed`;`pointer down scales and move beyond slop releases`;`pressFeedback: false never scales`;`disabled button does not scale`;`autofocus and onNavigate callbacks unchanged`。
- `test/widgets/app_menu_press_test.dart`(或并入 `floating_app_menu_test.dart`):`pressing an option shows the 10 percent fill and cancel clears it`;`selected check fades in when selection becomes pending, but an initially selected item shows it immediately`;减弱动画下无淡入。
- `test/widgets/rating_bottom_sheet_test.dart` 增加:`pressing a star scales the active star to 1.2 and releases on cancel`;`crossing a star boundary pulses haptics once, half steps do not`(参考 `selection_feedback_test.dart:30-33` 的触感通道 mock);`saved status text shows then reverts`(`fakeAsync`/`pump(2s)`)。
- `test/widgets/selection_feedback_test.dart` 增加:`card long press pulses exactly once and catalog cards do not`(用 `MediaCard` 夹具,参考 `media_card_full_card_test.dart`);`TV and desktop long press stay silent`(沿用 `:166` 的参数化写法)。
- `test/widgets/app_select_field_test.dart` 增加:`arrow rotates half a turn while the menu is open`(找 `AnimatedRotation.turns`),`reduced motion rotates without animation`;现有用例仍通过。
- 评分/详情按钮:`test/screens/media_detail/` 下新增或扩展一个用例(位置待核对):`play button shows opening label while launch is pending and ignores taps`。
- `f4_home_feedback_test.dart`:R1 删除头图按钮后会受影响,不在本包处理。
- 现有 Chip、`options_chips_bar_test.dart`、`anchored_option_menus_test.dart`、`floating_app_menu_test.dart`、`media_context_menu_test.dart`、`episode_card` 相关测试必须仍通过。

## 7. 验收清单

命令:
- [ ] `flutter analyze` 无新增告警
- [ ] `scripts/run_tests.sh test/widgets/press_feedback_test.dart test/widgets/app_select_field_test.dart test/widgets/selection_feedback_test.dart test/widgets/rating_bottom_sheet_test.dart test/widgets/options_chips_bar_test.dart test/widgets/anchored_option_menus_test.dart test/widgets/floating_app_menu_test.dart test/widgets/media_context_menu_test.dart`
- [ ] `scripts/run_tests.sh` 全量通过
- [ ] `scripts/codegen.sh --check` 通过(新增 i18n key 后)
- [ ] `grep -n "HapticFeedback" lib/screens/companion_remote/mobile_remote_screen.dart` 无结果

手动(手机 + 平板 + 桌面 + TV 各一遍,亮/暗/纯黑三主题):
- [ ] `FocusableButton` 类按钮:触摸按下缩放,TV 确认键 97% 一次,焦点描边大小不变;播放器内按钮只缩放不加暗层。
- [ ] 菜单选项:按下 10% 底色,选中后对勾淡入、120ms 后菜单关闭,选择有触感(手机)。
- [ ] 评分:按住星星当前星放大,滑过每颗触感一次,松手保存后副标题短暂显示"已保存"。
- [ ] 筛选 Chip、"查看全部"、人物卡:按下有缩放;在横向列表里滑动不误触发。
- [ ] 剧集卡:按下缩放 + 遮罩,长按弹出菜单并触感一次。
- [ ] 海报卡:按下缩 96% 并叠暗层(亮色更深),长按一次触感;目录占位卡长按无震动。
- [ ] 详情页播放按钮:点击后显示转圈 + "正在打开",再点无响应。
- [ ] 下拉触发行:展开箭头旋转 180°,关闭转回。
- [ ] 手机遥控屏幕各按钮触感正常。
- [ ] 系统"减弱动画"开启:所有上述控件只变色,不缩放/旋转/淡入。
- [ ] 滑动列表(剧集列表、首页横向列表)不会出现卡在按下态的控件。

## 8. 提交拆分

1. `test: 补充按压反馈组件单元测试`
2. `feat(交互): 按压遮罩支持按控件类型配置`(tokens + `PressFeedback` 参数 + 卡片/主按钮接入)
3. `feat(交互): 新增按压指针包装并接入 FocusableButton`
4. `feat(菜单): 选项行按下底色与对勾淡入`
5. `feat(评分): 星星按下放大、逐星触感与已保存提示`
6. `feat(交互): 筛选 Chip 接入按压反馈`
7. `feat(交互): 查看全部与人物卡接入按压反馈`
8. `feat(剧集): 剧集卡接入按压反馈与长按触感`
9. `feat(卡片): 海报卡长按触发一次触感`
10. `feat(详情): 播放按钮加载态显示正在打开`(含 i18n 与 slang 生成)
11. `feat(控件): 下拉箭头展开时旋转`
12. `refactor(遥控): 触感统一走 selectionFeedback`

## 9. 风险与待确认

1. 待确认:圆形次要按钮"底色提亮、描边加强"中的"描边加强"本包不做,只保留 8% 前景叠加。
2. 待确认:设置项行/`FocusableListTile` 不接入——它们是 Material `ListTile`,已有 ink 按压色;加缩放会让整行跳动。如产品要求,另开任务,做法是只变色(`pressedScale: 1`)。
3. 待确认:`anchored_option_menus.dart` 的选择(排序、筛选)是否也要触感;目前只有 `AppSelectField` 有。
4. 待确认:纯黑主题下卡片黑色暗层不可见,是否改为白色提亮;`cardOverlayAlphaDark=.16` 与 `mainOverlayAlpha=.10` 是推断值。
5. 风险:`FocusableButton` 有约 57 个文件在用,默认开启按压会让这些按钮都出现缩放;提交 3 后需整体目视;如发现个别不适合的,用 `pressFeedback: false` 逐个关闭。
6. 风险:`PressFeedbackPointer` 用 `Listener` 与子按钮的 ink 同时工作,多指触摸时状态可能卡住,靠 `PointerCancel`/`Up` 复位,并有单测。
7. 风险:菜单选项行改动影响所有菜单,回归面大。
8. 风险:与 R1 同时改 `discover_screen.dart`/`fusion_home_hero.dart` 会冲突,本包不碰它们。
9. 待核对:`media_card_full_card_test.dart` 与 `focusable_button` 现有测试的具体路径;`_CardTapRegion` 的创建点传参路径。

禁止事项:
- 不直接改生成的 Dart 文件(`lib/i18n/strings*.g.dart`);改 `lib/i18n/*.i18n.json` 后运行 `dart run slang`。
- 触感只走 `selectionFeedback()`,不新增直接 `HapticFeedback` 调用。
- 不删除 Plex/Jellyfin/Emby/一起看/TV 支持;保留 mpv 与 ExoPlayer。
- 新控件用 `FocusableWrapper`/`FocusableButton` 包装,TV 方向键与确认键可用、初始焦点不丢。
- 按下态不得改变布局尺寸(只用 `Transform`/`AnimatedScale`)。
- 不提交凭据、构建产物、本地参考文件。
