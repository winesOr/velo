# R4 选择器收尾 任务卡

- 基线提交:`8885b39`(与清单所用 `fe12755` 之间只多一个纯文档提交,代码行号一致)
- 声明:静态读码,未运行。本环境无 flutter,未跑 analyze/测试。行号动手前用 grep 复核。
- 目标:让所有"选项多或文案可变长"的选择器改用下拉(`AppSelectField` 或设置页的 `SettingSelectionTile`),触发器内显示字段标签,长文案一律单行省略而不是缩放或溢出。
- 优先级:R4-1/R4-2 中偏高,其余中/低。
- 规模:中(约 9 个提交)。
- 前置依赖:无硬依赖。R4-1 先做,R4-2/R4-5 复用其新参数。
- 不在范围:播放器抽屉的音频/字幕下拉(已完成);danmaku、文件信息的展示用 Wrap;`mobile_remote_screen` 全部;`filter_operator_row`、`sort_bottom_sheet`;R9 的按压/箭头旋转(`AppSelectField` 的箭头动画归 R9-5,同一文件改动要先合并再做下一个,避免冲突)。

## 0. 取舍规则与逐项结论

规则(清单 C11):选项超过 4 项,或文案可变长(来自服务端/文件/用户输入)→ 改下拉;2–3 个短固定项 → 保留分段/Chip。保留的也要保证不溢出、不缩到不可读。

| 控件 | 位置(HEAD) | 选项数与文案 | 结论 |
|---|---|---|---|
| 详情页版本/音频/字幕 | `media_detail/playback_selectors.dart:59,78,97` | 可变长 | 已是下拉;R4-1 补触发器内标签 |
| 版本抽屉(嵌入态) | `version_quality_sheet.dart:125` | 版本数不定、`displayLabel` 可变长 | 改下拉(R4-2) |
| 画质抽屉(嵌入态) | `version_quality_sheet.dart:166` | `TranscodeQualityPreset.displayOrder` 全部预设(原画+多档),带体积估算 | 改下拉(R4-2) |
| 版本/画质非嵌入底部列表 | `version_quality_sheet.dart:233` | 列表行 | 保留列表,仅标题加 `maxLines: 2` + 省略(R4-4) |
| `track_selection_helper.dart:87-96` 嵌入分支 | 死代码(见 R4-3) | — | 删除 |
| `showOptionPickerDialog` 标题/选项 | `dialogs.dart:624`、`:668` | 标题可变长(如"剧集名 - 选择版本");选项为版本名 | 标题改 2 行省略;选项保持可折行(见 R4-4) |
| `fitted_metadata_line` | `fitted_metadata_line.dart:187,195` | 元数据单元 | 加 `Flexible` + 省略(R4-4) |
| 录制模板选择 `_EntryChooser` | `livetv/record_options_sheet.dart:388-415` | 数量待核对(`entries.length>1` 才显示,`:314`);标题由服务端提供,可变长 | 改下拉(R4-5) |
| 标签建议 Chip | `widgets/tag_edit_dialog.dart:147-159` | 不是选择器:点一下把建议加进标签,最多 `_maxVisibleSuggestions` 个,可按输入过滤 | 保留 Chip,给 `FocusableFilterChip` 加最大宽度+单行省略(R4-6) |
| 外观:视图模式 | `appearance_settings_screen.dart:278` | 2 项:Grid/List | 不动 |
| 外观:网格间距 | `:288` | 3 项短词(Tight/Normal/Spacious;德 Großzügig、俄 Просторные 最长约 10 字符) | 保留;真机/测试在德/俄 + 1.3 倍字号下检查,若缩放明显再改 |
| 外观:剧集海报模式 | `:299` | 3 项长文案(Series Poster / Season Poster / Thumbnail;德 Serienposter/Staffelposter;俄 Постер сериала) | 改为 `SettingSelectionTile`(R4-7) |
| 外观:继续观看动作、剧集动作 | `:310`、`:320` | 各 2 项(Play / Open Details;俄 "Открыть сведения") | 保留;依赖 `ExpressiveButtonGroup` 的缩放,德/俄需检查 |
| 播放设置:长按倍速 | `playback_settings_screen.dart:451-458` | 4 项数字(1.5/2.0/2.5/3.0,`SettingsService.longPressSpeedOptions :761`) | 保留(短固定数字,恰为 4 项) |
| 追踪器库过滤模式 | `tracker_library_filter_screen.dart:89-103` | 2 项(Blacklist/Whitelist;德 Ausschlussliste/Zulassungsliste) | 保留 |
| 外部播放器类型 | `external_player_screen.dart:239-248` | 2 项(包名/命令 与 URL 方案) | 保留 |
| `ExpressiveButtonGroup` 缩放 | `expressive_button_group.dart:218` | `FittedBox(scaleDown)` | 保留行为;文档化"只用于 ≤4 个短文案" |
| 筛选运算符 | `libraries/filters/filter_operator_row.dart:125,204` | 2–3 项 | 不动 |
| 排序方向 | `libraries/sort_bottom_sheet.dart:159` | 2 项图标 | 不动 |
| 画面比例 | `player_settings_drawer.dart:294-325`(`_ChoiceRow`) | 3 项(默认/拉伸/填充) | 不动(`PlayerDrawerChoice` 已单行省略,`player_settings_controls.dart:160-163`) |
| 弹幕设置 | `danmaku_settings_sheet.dart:657,723` | 2–3 个短项 | 不动 |
| 弹幕来源按钮 | `danmaku_sources_sheet.dart:187,424` | 动作按钮 | 不动 |
| 文件信息 Wrap | `widgets/file_info_bottom_sheet.dart:100,638,670`(注意路径是 `lib/widgets/`,不是 `video_controls/sheets/`) | 展示用 | 不动 |
| 手机遥控 | `companion_remote/mobile_remote_screen.dart:208`(3 个固定标签页 + 图标)、`:277`(5 个命令 Chip)、`:400`(命令卡片) | 命令按钮/标签页,不是选项选择器 | 不动 |

## 1. 涉及文件表

| 文件 | 行号 | 现状 | 动作 |
|---|---|---|---|
| `lib/widgets/app_select_field.dart` | 类 `:25-47`;构造参数 `label/options/onChanged/value/placeholder/enabled/busy/compact/focusNode`;标题计算 `:127`;触发器 `:174-213` | 触发器只显示"所选项主标题 + 副标题",label 只用于菜单标题和语义(`:82`、`:137`) | 改:新增 `showLabel` 渲染触发器内标签 |
| `lib/screens/media_detail/playback_selectors.dart` | 三个字段 `:59`、`:78`、`:97`;`columns` 判断(宽度 ≥680 且字号 ≤1.4)在 `fieldsContent` 的 `LayoutBuilder` 内 | 选中后只见值不见字段名 | 改:三处传 `showLabel: true` |
| `lib/widgets/video_controls/sheets/version_quality_sheet.dart` | `VersionQualityPicker :24`;`_VersionColumn :110`(`SheetSelectionColumn :125`);`_QualityColumn :143`(`:166`);`_SelectionTile :196`(`FocusableListTile :232`) | 嵌入态走 `SheetSelectionColumn` 的 Wrap 回退 | 改:两列加 `embeddedBuilder`;嵌入态不用 `SheetSplitColumns`;`_SelectionTile` 文本加 `maxLines: 2` |
| `lib/widgets/video_controls/sheets/sheet_selection_column.dart` | `embeddedBuilder :39`;嵌入态 `:91-113`(Wrap 回退 `:102`) | 回退 Wrap 在版本/画质外已无使用者 | 改(可选):`embeddedBuilder` 改为 required 后删 Wrap 回退;若保留则不动 |
| `lib/widgets/video_controls/sheets/video_settings_sheet.dart` | `_buildVersionQualityView :1372`;调用 `:1700` | 把 `VersionQualityPicker` 放进抽屉 | 不改,验证嵌入态 |
| `lib/widgets/video_controls/helpers/track_selection_helper.dart` | `_buildSelectableTile :75-136`;嵌入分支 `:87-96`;导入 `:8,:9` | 嵌入分支丢 `secondaryLabel` | 删嵌入分支及不再使用的导入 |
| `lib/widgets/video_controls/sheets/track_sheet.dart` | 4 个 `SheetSelectionColumn`:`:176`、`:248`、`:345`、`:445`,均有 `embeddedBuilder` | 调用方唯一 | 不改,仅作为"死路径"证据 |
| `lib/utils/dialogs.dart` | `_OptionPickerDialogState.build :623`;标题 `:624`;选项文本 `:668` | 标题无 maxLines(清单/audit 写的 `:648` 在当前 HEAD 对不上,以 `:624` 为准) | 改 |
| `lib/widgets/fitted_metadata_line.dart` | 最终 `Row` `:208`;文本 `:187`、`:195` | 单元被丢弃到放得下为止,但最后剩下的单个长单元仍可能超宽;无 `Flexible` | 改 |
| `lib/screens/livetv/record_options_sheet.dart` | `_EntryChooser :388-415`;使用 `:314-317`;`_selectEntry`、`_entry` 状态约 `:107` | `Wrap` + `ChoiceChip(entry.title)`,无省略 | 改:用 `AppSelectField` |
| `lib/widgets/focusable_filter_chip.dart` | `:92-99` | `Row(min)` 内 `Text` 无省略 | 改:`Flexible` + `maxLines: 1` + ellipsis;另一调用方 `options_chips_bar.dart:115` 同步受益 |
| `lib/widgets/tag_edit_dialog.dart` | Wrap `:147`;chip `:152` | 保留结构 | 不改(靠 chip 组件修) |
| `lib/screens/settings/appearance_settings_screen.dart` | `_episodePosterModeSelector :299-308` | `SettingSegmentedTile` 3 项长文案 | 改为 `SettingSelectionTile<EpisodePosterMode>` |
| `lib/widgets/setting_tile.dart` | `SettingSelectionTile :229-273`;`SettingSegmentedTile :365` | 已有现成"点击弹选择框"控件 | 不改 |
| `lib/screens/settings/settings_utils.dart` | `DialogOption :32` | 选项数据类型 | 不改 |
| `lib/i18n/*.i18n.json` | `liveTv` 组(`recordOptions` 在 en 约 `:1638`) | 无"录制方式"标签 | 新增 1 个 key(见第 4 节) |

## 2. 逐步修改说明

### R4-1 `AppSelectField` 触发器内显示字段标签
- 现状:触发器 `title = selected?.label ?? widget.placeholder ?? widget.label`(`:127`),`label` 不画出来;详情页三列并排时选中后只见值。
- 改成:触发器内两层——左上"标签"(次要色,字号 13,单行省略),下面主文字(15/w500)+可选副文字(12)。
- 做法:
  - 新增构造参数 `bool showLabel = false`(默认 false,保持旧用法与旧测试不变)。播放器抽屉内(`track_sheet.dart` 已有标题头)保持 false。
  - `build` 内 Column 最前插入 `if (widget.showLabel) Text(widget.label, maxLines: 1, overflow: ellipsis, style: bodySmall(fontSize: 13, color: colors.onSurfaceVariant))`,与下方文字间距 2。
  - 最小高度:`compact` 为 52,否则 58;显示标签后行数从 1–2 行变成 2–3 行,需把 `minHeight` 改为 `showLabel ? (compact ? 64 : 72) : (compact ? 52 : 58)`(数值为估算,以文字不被裁切为准,实现时用 `ConstrainedBox(minHeight)` 而非固定高度)。
  - 选中为空时主文字仍显示 `placeholder ?? label`,此时标签与主文字会是同一个词("Version / Version"):`showLabel` 且 `selected == null && placeholder == null` 时只渲染一行(label 作主文字),不重复;不新增文案。
  - 语义 `semanticLabel: widget.label`、`semanticValue` 不变。
  - TV 焦点、`FocusableWrapper`、按压反馈都不动。
- `playback_selectors.dart`:三处 `AppSelectField` 增加 `showLabel: true`。窄屏(<680)三行堆叠、宽屏三列(`LayoutBuilder` 已有)都要不溢出。

### R4-2 版本/画质抽屉嵌入态改下拉
- 现状:`_VersionColumn`/`_QualityColumn` 只传 `itemBuilder`,嵌入态回退到 `Wrap` 平铺 `_SelectionTile`(`FocusableListTile`)。长版本名折行或在 Wrap 里排布异常。
- 改成:两列各自提供 `embeddedBuilder`,返回 `AppSelectField`;非嵌入(底部面板)路径不变。
- 做法:
  - `_VersionColumn`:`AppSelectField<int>(label: t.videoControls.versionColumnHeader, value: selectedIndex, compact: true, options: [for (i, v) in versions.indexed) AppSelectOption(value: i, label: v.displayLabel, subtitle: t.fileInfo.versionCounter(index: i + 1, count: versions.length))], onChanged: (i) => onSelected(i))`。副标题格式与详情页(`playback_selectors.dart:69`)一致。`MediaVersion` 里是否有 `isPlayable`(详情页用于 `enabled`)在该列表里可用,待核对:`grep -n isPlayable lib/media/media_version.dart`。
  - `_QualityColumn`:`AppSelectField<TranscodeQualityPreset>`,`label` 用 `qualityPresetLabel(preset, sourceBitrateKbps: ...)`,`subtitle` 用现有 `trailing`(体积估算,为空则 null),`enabled: isOriginal || enabledForTranscoding`。`value: selected`。
  - `onSelected` 里现有的 `OverlaySheetController.of(context).close()`(`:57`、`:69`)在嵌入态是否应该关闭整个抽屉,需要与现状行为保持一致;下拉选中后行为 = 原来点一项后的行为,不要改。验证方法:看 `BaseVideoControlSheet.embeddedIn` 为 true 时 `OverlaySheetController` 是否存在;`SheetSelectionColumn._select` 在嵌入态**不**关闭(`sheet_selection_column.dart:80`),而这里直接关闭——两者不一致,按"嵌入态不关闭"处理更合理,但这是行为变化,待确认(写入提交说明)。
  - 嵌入态且版本和画质同时存在时,`VersionQualityPicker.build`(`:76-77`)用 `SheetSplitColumns` 左右各占约一半(抽屉宽 318/400)导致下拉触发器过窄:嵌入态改为上下两个 `Column`(`BaseVideoControlSheet.embeddedIn(context)` 判断),间距 8。非嵌入保持左右分栏。
  - `_SelectionTile`(`:196`):`Text(label)` 加 `maxLines: 2, overflow: TextOverflow.ellipsis`。
  - 焦点:每列已被 `FocusTraversalGroup` 包着(`:49`、`:64`),`AppSelectField` 内部是 `FocusableWrapper`,方向键进出不需要额外代码;验收时确认。

### R4-3 `track_selection_helper.dart` 嵌入分支
- 核对结论:`TrackSelectionHelper` 只有 `track_sheet.dart` 调用(`:193,271,282,367,524,557,587` 等)。`track_sheet.dart` 的 4 个 `SheetSelectionColumn`(`:176,248,345,445`)都有 `embeddedBuilder`,嵌入态不会调用 `itemBuilder`,所以 `_buildSelectableTile` 的嵌入分支(`:87-96`)是死代码。动手前再用 `grep -rn "TrackSelectionHelper\." lib test` 复核一次。
- 做法:删除 `:87-96` 嵌入分支;删除随之不再使用的导入(`player_settings_controls.dart`、`base_video_control_sheet.dart`,以 analyzer 为准)。非嵌入 tile 不动(已有 `maxLines: 1` 和副标题)。
- 提交说明写明调用方 grep 结论。

### R4-4 标题与元数据行溢出
- `dialogs.dart:624`:`title: Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis)`。`_TextInputDialog` 的 `:503` 不在本包范围。
- `dialogs.dart:668` 选项文本:保持可折行。理由:选项是版本名,需要完整读出来区分;截断会让两个版本看不出差别。如果产品要求限制,最多 `maxLines: 3`(待确认,默认不限)。
- `version_quality_sheet.dart:233`:见 R4-2。
- `fitted_metadata_line.dart`:`MetadataLineText` 与 `MetadataLineIconText` 内的 `Text`(`:187`、`:195` 一带)包 `Flexible` 并加 `overflow: TextOverflow.ellipsis`(保持 `maxLines: 1`)。最终 `Row(mainAxisSize: min)` 保持。确认 `InlineRatingBadges` 不受影响。

### R4-5 录制模板选择
- 现状:`_EntryChooser` 为 `Wrap` + `ChoiceChip(Text(entry.title ?? ''))`;仅当 `entries.length > 1` 显示(`:314`)。条目数取决于服务端模板,具体数量待核对(查法:`grep -n "entries" lib/screens/livetv/record_options_sheet.dart`,再看调用它的 `show` 入口 `:39-69` 以及服务端模板返回)。
- 改成:无论数量,改为 `AppSelectField<int>`(值用 `entries.indexOf`,因为原代码用 `identical()` 比较对象)。理由:标题由服务端提供、可变长,符合规则。
- 做法:
  - `_EntryChooser` 保留类名,内部改为 `AppSelectField<int>(label: t.liveTv.recordType, showLabel: true, value: entries.indexOf(selected), options: [for (i, e) in entries.indexed) AppSelectOption(value: i, label: e.title ?? '')], onChanged: (i) => onSelect(entries[i]))`。`e.title` 为空时回退 `t.liveTv.recordOptions`(已存在)。
  - 外层原先用 `FocusableButton` 包,改后不再需要(`AppSelectField` 自带焦点)。
  - 在 sheet 里 `autofocus` 的初始焦点原本在第一个设置行(`autofocus: index == 0`),不要被新字段抢走:`AppSelectField` 默认不自动聚焦,保持。
- 需要 `R4-1` 的 `showLabel`。

### R4-6 标签对话框 Chip
- 结论:不改下拉。理由:它是"点击即添加"的建议快捷键,不是单选/多选控件,数量由输入过滤。
- 做法:改 `FocusableFilterChip`(`focusable_filter_chip.dart:92-99`):`Text` 包 `Flexible`,`maxLines: 1`,`overflow: ellipsis`;`Row` 保持 `mainAxisSize.min`。`Wrap` 给的是松约束,所以超长标签会在对话框宽度(`SizedBox(width: 400)`,`tag_edit_dialog.dart` 约 `:117`)内被省略。已应用标签列表 `:178` 是 `FocusableListTile`,可折行,不动。
- `options_chips_bar.dart:115` 同一组件,回归检查它不变形。

### R4-7 设置页分段控件
- 只改 1 处:`appearance_settings_screen.dart:299` `_episodePosterModeSelector` 改为
  `SettingSelectionTile<EpisodePosterMode>(pref: SettingsService.episodePosterMode, icon: Symbols.image_rounded, title: t.settings.episodePosterMode, subtitleBuilder: <枚举 → 现有 t.settings.seriesPoster/seasonPoster/episodeThumbnail>, options: [DialogOption(value:..., title:...), ...])`。参考用法 `general_settings_screen.dart:113-120`。这是设置页已有的"下拉"形态(整行点开选择框),不是 `AppSelectField`。TV 焦点由 `FocusableListTile` 提供。
- 其余分段控件(见第 0 节)保留,在提交说明里逐条写一句结论。
- `expressive_button_group.dart:218` 不改实现;在类注释里补一句"仅用于 ≤4 个短固定文案,更长请用下拉",避免后人再加长文案。
- `SettingSegmentedTile` 若测试里引用外观页的这个分段(`setting_tile_test.dart`、`selection_feedback_test.dart:86` 用的是别的偏好,待确认),按失败信息调整。

### R4-8 不动清单
- 见第 0 节"不动"各行,提交说明里列出即可,不需要改代码。

## 3. 小结:是否会用到 `SettingSelectionTile` 的新增行为
无。只复用现有控件。

## 4. i18n / 常量

| key | en | zh | zh-Hant | 其余语言 |
|---|---|---|---|---|
| `liveTv.recordType`(新增,R4-5 的字段标签;文案待产品确认) | Recording type | 录制方式 | 錄製方式 | 英文占位(复制 en 文案,与仓库现有做法一致:如 `detailPlayback` 在 de/ru/ja 等里就是英文) |

- 常量:`AppSelectField` 的标签字号 13、最小高度 64/72 为实现常量,直接写在 widget 内,不用 TODO;无新增设置项。
- 其余语言共 19 个:az bg da de es fr hu it ja kk ko nb nl pl pt ru sv tr uz。
- 生成命令:改完 `lib/i18n/*.i18n.json` 后运行 `dart run slang`(CONTRIBUTING.md 规定;全量生成用 `scripts/codegen.sh`,检查用 `scripts/codegen.sh --check`)。`slang.yaml` 的 `fallback_strategy: base_locale_empty_string`,空串回退英文,但仍按现有惯例写英文占位。

## 5. TV 焦点、主题、形态

- TV:`AppSelectField` 自带 `FocusableWrapper`,确认键打开菜单、返回键关闭并还原焦点;`_EntryChooser`、版本/画质下拉、外观页 `SettingSelectionTile` 都要用遥控器走通"进入 → 选择 → 返回焦点在原处"。详情页三列时上下键行为(`playback_selectors.dart` 的 `Focus.onKeyEvent`)不得被破坏。
- 手机:`showAdaptiveAppMenu` 在 Android/iOS 为底部面板,桌面为锚点弹层。窄宽(<360)、字号 1.4 倍下触发器内标签与值单行省略,不溢出。
- 平板/桌面:详情页宽度 ≥680 三列,每列触发器宽约 200–300,标签/值都要省略而不是撑宽。
- 三主题(亮/暗/纯黑):`AppSelectField` 底色用 `colorScheme.surfaceContainer`、描边 `onSurface` 8%、强调色 `VeloBrand.foreground`,标签用 `onSurfaceVariant`;不新增写死十六进制。纯黑下标签对比度需肉眼确认。

## 6. 测试要求

修改:
- `test/widgets/app_select_field_test.dart`:现有用例必须不变通过(`showLabel` 默认 false)。
- `test/widgets/fitted_metadata_line_test.dart`:现有 13 个用例通过;`collapses to nothing rather than clipping a lone field`(`:131`)的预期可能因 `Flexible` 变化,按失败信息核对语义后调整,不要放宽成"允许溢出"。
- `test/widgets/option_picker_dialog_test.dart`、`test/widgets/video_settings_sheet_test.dart`(`:262` 的版本摘要用例)、`test/widgets/track_sheet_test.dart`、`test/screens/livetv/record_options_sheet_test.dart`、`test/widgets/tag_edit_dialog_test.dart`、`test/widgets/options_chips_bar_test.dart`:全部要仍通过。

新增:
- `app_select_field_test.dart`:
  - `showLabel shows the field label above the selected value`:同时 `find.text('Audio')` 与 `find.text('One')`。
  - `showLabel with long label and value never overflows at 200 percent text scale`:`tester.takeException()` 为空。
  - `default keeps the trigger label-less`:`showLabel` 不传时 label 文本在触发器内不出现(菜单关闭状态)。
- `test/widgets/version_quality_sheet_test.dart`(新文件):
  - `embedded version column uses a select field with long titles ellipsized`(嵌入 scope 下 pump,断言 `AppSelectField<int>` 存在、无 `Wrap` 平铺、无异常)。
  - `embedded quality column disables transcode presets when unsupported`。
  - `non embedded list still renders tiles with two-line titles`。
  - 如何构造嵌入 scope:参考 `video_settings_sheet_test.dart` 现有包装方式,待核对。
- `fitted_metadata_line_test.dart`:`a single overlong text unit ellipsizes instead of overflowing`。
- `test/widgets/focusable_filter_chip_test.dart`(新文件):超长 label 放入 200 宽的 `Wrap`,无溢出异常、`Text.overflow == ellipsis`。
- `record_options_sheet_test.dart`:`multiple entries render a select field and switching entry updates the settings list`(构造 2 个 `MediaSubscription` 模板,选第二项后断言所选模板变化)。
- `test/widgets/setting_selection_tile_test.dart` 已有,可补一条 `episode poster mode opens a selection dialog`(或放在新文件 `test/screens/settings/appearance_episode_poster_test.dart`,待确认外观页是否已有测试夹具)。

## 7. 验收清单

命令:
- [ ] `flutter analyze` 无新增告警
- [ ] `scripts/run_tests.sh test/widgets/app_select_field_test.dart test/widgets/fitted_metadata_line_test.dart test/widgets/option_picker_dialog_test.dart test/widgets/video_settings_sheet_test.dart test/widgets/track_sheet_test.dart test/screens/livetv/record_options_sheet_test.dart test/widgets/tag_edit_dialog_test.dart test/widgets/options_chips_bar_test.dart test/widgets/setting_selection_tile_test.dart`
- [ ] `scripts/run_tests.sh` 全量通过
- [ ] `dart run slang` 后 `scripts/codegen.sh --check` 通过

手动:
- [ ] 详情页:宽 ≥680 三列、<680 三行;选中后每个触发器都能看到"版本/音频/字幕"字样;超长轨道名单行省略,菜单内完整可读。
- [ ] 播放器抽屉(手机、平板、TV 各一):版本/画质显示为下拉,长版本名不折成多行平铺;抽屉内版本与画质上下排列;遥控器可进入、选择、返回。
- [ ] 非嵌入的版本/画质面板:长标题最多 2 行加省略。
- [ ] 下载版本选择等 `showOptionPickerDialog` 弹窗:超长标题 2 行省略,选项可折行,不溢出。
- [ ] 详情元数据行:窄屏、字号 1.4 倍下无黄黑溢出条。
- [ ] 直播录制弹窗:有多个模板时显示下拉,超长标题不溢出;TV 可操作。
- [ ] 标签编辑对话框:超长建议标签被省略,D-pad 仍能离开 Chip 行。
- [ ] 外观设置:剧集海报模式为点开选择框;其余分段在德语、俄语、字号 1.3 倍下可读。
- [ ] 亮/暗/纯黑三主题各看一遍上述界面。
- [ ] `grep -rn "TrackSelectionHelper\." lib` 的结果与 R4-3 结论一致。

## 8. 提交拆分

1. `feat(控件): 选择下拉触发器支持显示字段标签`
2. `feat(详情): 版本音频字幕下拉显示字段标签`
3. `feat(播放器): 版本与画质抽屉嵌入态改用下拉`
4. `refactor(播放器): 删除轨道选择嵌入分支死代码`
5. `fix(界面): 选项弹窗标题与元数据行长文案省略`
6. `feat(直播): 录制模板选择改用下拉`(含新增 i18n key 与 slang 生成结果)
7. `fix(控件): 筛选 Chip 长文案单行省略`
8. `feat(设置): 剧集海报模式改用选择框`
9. `test: 补充选择器长文案与嵌入态用例`(若每个提交已带自己的测试,则不单列)

## 9. 风险与待确认

- 待确认 C11:阈值按"项 >4 或文案可变长"执行,已按此逐项给结论。
- 待确认:版本/画质嵌入态选择后是否关闭抽屉(R4-2),默认"与原行为一致"并写入提交说明。
- 待确认:`liveTv.recordType` 文案;录制模板实际条目数(待核对,不影响实现,因为已改为下拉)。
- 风险:`AppSelectField` 最小高度增加会使详情页选择区变高,需目视检查与播放按钮的间距。
- 风险:R9-5 也要改 `app_select_field.dart`(箭头旋转);R4-1 先合并,R9-5 再基于最新文件改。
- 与清单不一致:`dialogs.dart` 标题在 HEAD 是 `:624`(清单/audit 写 `:648`);`file_info_bottom_sheet.dart` 实际在 `lib/widgets/` 下。

禁止事项:
- 不直接改生成的 Dart 文件(`lib/i18n/strings*.g.dart`);改 `lib/i18n/*.i18n.json` 后运行 `dart run slang`。
- 不删除 Plex/Jellyfin/Emby/一起看/TV 支持;保留 mpv 与 ExoPlayer。
- 新控件必须用 focusable 包装(`FocusableWrapper`/`FocusableButton`),不得退化成裸 `GestureDetector`。
- 用户可见文案不硬编码,一律走 slang。
- 不提交凭据、构建产物、本地参考文件。
