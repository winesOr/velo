# R02 缺陷修复

- 基线提交:`8885b39`(2026-11-12)。行号均在此基线上逐文件核对。
- 核对方式:静态读码,未运行(本环境无 flutter);"待核对"处需在有 flutter 的环境确认。
- 目标:修复直播节目表加载失败永久转圈、头图元数据死分支、个人评分 /10 与星数不一致、Jellyfin/Emby 影评来源标注四个问题。
- 优先级:高(R2-1、R2-2、R2-3),中(R2-4)。
- 规模:小。
- 前置依赖:R2-2 与 R1-4 改同一文件(`hero_metadata_badges.dart`),先做 R1 再做 R2-2。R2-1、R2-3、R2-4 互相独立。
- 不在范围:直播其它标签页(已接入 `LiveTvLoadError`);评分条上限与"我的评分"并入评分条(C2/C3,R5);评分设置页;头图文字亮色策略(C5/R10-4)。

## 0. 与清单/审计不一致或新发现

| # | 说明 |
|---|---|
| E1 | 清单 R2-2 称默认前景在 `hero_metadata_badges.dart:12`,实际是 `:15`(`this.foreground = Colors.white`);★ 死分支实际在 `:58-60`(审计的 `:54-58`/`:57-58` 都偏),`lightInk` 在 `:29`、`:51` 仍用于底色,不能一起删 |
| E2 | 清单 R2-3 称卡片 "x/10"。实际卡片文字是 `'${mediaRatingLabel(rating)}/10'`(`lib/widgets/media_ratings_strip.dart:132`)= 一位小数,如 `9.0/10`,且已有测试断言(`test/widgets/media_card_full_card_test.dart:153` `find.text('9.0/10')`)。**所以共享函数必须保持一位小数,卡片输出不变** |
| E3 | **新发现**:第三处星数换算在 `lib/widgets/episode_card.dart:105-108`(`userRating / 2`,手写整数判断),与详情页 `media_detail_screen.dart:1136` 重复;一并改用共享函数 |
| E4 | **新发现**:`ratingsSemanticLabel`(`media_rating_badge.dart:63-66`)对个人评分也拼 `${mediaRatingLabel(rating)}/10`(因为 `ratingSourceLabel('personal')` 为 null),需与卡片共用同一函数 |
| E5 | `rating_utils.dart` 文件名对应的测试已存在:`test/utils/rating_utils_test.dart` |
| E6 | R2-4:`jellyfin_mappers.dart:426-428` 的注释断言 `CriticRating` 就是 Rotten Tomatoes Tomatometer;这个断言本身**待核对**(见 R2-4) |

## 1. 涉及文件表

| 文件 | 行号 | 现状 | 动作 |
|---|---|---|---|
| `lib/screens/livetv/live_tv_show_schedule_screen.dart` | `:44-46` | `_programs`、`_isLoading = true`,无错误态 | 改:加 `_errorMessage`、`_retryFocusNode` |
| 同上 | `:56-89` | `_loadSchedule` 无 try/catch;`client == null`(`:58-62`)只置 `_isLoading=false` 显示空;`fetchSchedule`(`:72`)抛错则 `_isLoading` 永为 true | 改 |
| 同上 | `:138-150` | `build` 里 `_isLoading ? LoadingIndicatorBox.sliver : _programs.isEmpty ? Center(noPrograms) : 列表` | 改:加错误分支 |
| 同上 | 文件末 `State` | 无 `dispose` | 增:释放 `_retryFocusNode` |
| `lib/screens/livetv/live_tv_load_error.dart` | 全文 | 现成组件:`message`、`onRetry`、`focusNode`、`autofocus`、`onNavigateUp`、`onBack`、`content` | 不改,复用 |
| `test/screens/livetv/live_tv_show_schedule_screen_test.dart` | `:23-110`、fakes `:150-210` | `_FakeLiveTvSupport.fetchSchedule` 恒返回 `programs` | 新增 3 个用例与可抛错的 fake |
| `lib/widgets/hero_metadata_badges.dart` | `:58-60` | `label.startsWith('★')` 死分支,硬编码 `0xffffd58a`/`0xff94681f` | 删分支 |
| 同上 | `:15` | 默认前景 `Colors.white` | 待核对(见 R2-2) |
| `lib/utils/rating_utils.dart` | 文件末(新增) | 无个人评分换算 | 增 3 个函数 |
| `lib/widgets/media_ratings_strip.dart` | `:132` | `'${mediaRatingLabel(rating)}/10'` | 改用共享函数 |
| `lib/widgets/media_rating_badge.dart` | `:63-66` | 同上 | 改用共享函数 |
| `lib/screens/media_detail_screen.dart` | `:1133-1137` `_userRatingChipLabel` | `formatRating(userRating / 2.0)`,只有星数 | 改:星数 + "x/10" |
| `lib/widgets/episode_card.dart` | `:105-108` | 手写 `/2` 整数判断 | 改用共享函数 |
| `lib/services/jellyfin_mappers.dart` | `:436-438` | `CriticRating` → `source: 'rottenTomatoesCritic'` | 视核对结果改(R2-4) |
| `test/services/jellyfin_mappers_test.dart` | `:70`、`:122-131` | 断言 `rottenTomatoesCritic` | 视 R2-4 改 |
| `test/utils/rating_utils_test.dart` | 新增用例 | — | 增 |

## 2. 逐步修改说明

### R2-1 直播节目表加载失败不再永久转圈
现状 → 改成:
- 现状:`_loadSchedule`(`live_tv_show_schedule_screen.dart:56`)里 `await genericClient.liveTv.fetchSchedule(...)`(`:72`)没有 try/catch;抛错后 `_isLoading` 永远为 true(`:45`、`:139-140`),一直转圈。`genericClient == null` 时(`:58-62`)直接显示"无节目"。
- 改成:失败显示错误视图 + 重试按钮;`client == null` 显示明确文案;重试成功后显示列表。

做法:
1. 状态:新增 `String? _errorMessage;`、`final _retryFocusNode = FocusNode(debugLabel: 'show_schedule_retry');`,`dispose()` 里释放。再加一个自增的 `int _loadGeneration`,防止重试时旧请求晚返回覆盖新结果。
2. `_loadSchedule()` 开头:`setStateIfMounted(() { _isLoading = true; _errorMessage = null; })`(第一次进入时 `_isLoading` 已是 true,不会多余重建)。
3. `client == null`:`_errorMessage = t.errors.noClientAvailable`(已有 key,en "No client available"),`_isLoading = false`,return。
4. 把 `fetchSchedule` 到 `setState` 包进 `try { ... } catch (e) { appLogger.e('Failed to load show schedule', error: e); if (mounted && generation == _loadGeneration) setState(() { _isLoading = false; _errorMessage = localizedLoadErrorText(e, context: t.liveTv.programsSection); }); }`。`localizedLoadErrorText` 在 `lib/utils/error_message_utils.dart:18`(`whats_on_tab.dart:180` 同用法),`t.liveTv.programsSection` 已有(en "Programs"),结果如 "Unable to load Programs. Please try again."。需新增 import:`../../utils/error_message_utils.dart`、`../../utils/app_logger.dart`、`live_tv_load_error.dart`。
5. `build`:在 `if (_isLoading)` 之后、`_programs.isEmpty` 之前加
   `else if (_errorMessage != null) SliverFillRemaining(child: LiveTvLoadError(message: _errorMessage!, onRetry: _loadSchedule, focusNode: _retryFocusNode, autofocus: true, onBack: () => Navigator.pop(hostContext)))`。
   `SliverFillRemaining` 用默认 `hasScrollBody: true`(给子组件确定高度;`LiveTvLoadError` 内部是 `LayoutBuilder`+`SingleChildScrollView`,不支持 `hasScrollBody: false` 的固有尺寸测量,待核对)。
6. 错误态时头部"录制"按钮(`showRecord`,`:126`)因 `_programs` 为空自然不显示;不额外处理。
7. TV:`autofocus: true` 使重试按钮在 D-pad 下可聚焦;正常列表路径的 `autofocus: index == 0`(`:171`)不变。
8. 不改成功路径、过滤与排序(`:75-82`)。

### R2-2 删除 hero 元数据 ★ 死分支
- 现状:`hero_metadata_badges.dart:58-60`
  `color: label.startsWith('★') ? (lightInk ? const Color(0xffffd58a) : const Color(0xff94681f)) : foreground.withValues(alpha: .9)`。labels 里不会出现以 ★ 开头的文本(年份、分级、类型、时长都不会;评分已由 `InlineRatingBadges` 绘制),分支永远走不到。
- 改成:`color: foreground.withValues(alpha: .9)`。
- 做法:只改这三行。`lightInk`(`:29`)仍用于 `:51` 的底色,保留。验证:`grep -n "ffd58a\|94681f\|★" lib/widgets/hero_metadata_badges.dart` 为 0 命中。
- 默认前景 `Colors.white`(`:15`):调用方(`fusion_home_hero.dart:167`、`discover_screen.dart:1777`)都显式传 `foreground`,默认值只在测试里生效。**默认不改**(C5 未定),只在提交说明里写明;若要随主题,改为 `Theme.of(context).colorScheme.onSurface` 需先确认 `media_ratings_strip_test.dart:109` 不依赖白色(待核对)。

### R2-3 个人评分 /10 与星数显示一致(默认值,产品可改,C4)
- 现状:个人评分存的是 0-10 数值。卡片角标 `9.0/10`(`media_ratings_strip.dart:132`);详情页 chip 只显示星数 `formatRating(userRating/2)`(`media_detail_screen.dart:1136`),如 8 → "4";评分面板用 `_serverStars = rating / 2`(`rating_bottom_sheet.dart:71`)。Plex 习惯 5 星的用户看到卡片 "8.0/10" 与详情 "4" 可能困惑。
- 改成:卡片保持 `x.x/10`(一字不变);详情 chip 同时显示星数与 /10,例如 `★ 4 · 8.0/10`;三处换算走同一组函数;不改存储值、不改评分面板。

做法:
1. `lib/utils/rating_utils.dart` 新增(顶层函数,文件需 `import 'formatters.dart';` 取 `formatRating`,`formatters.dart` 不反向引用本文件,无环):
   ```dart
   /// 0-10 的个人评分换算成星数,按半星取整:7 -> 3.5,7.3 -> 3.5,8 -> 4。
   double userRatingStars(double userRating) => (userRating).roundToDouble() / 2;
   String formatUserRatingStars(double userRating) => formatRating(userRatingStars(userRating));  // "3.5" / "4"
   String formatUserRatingOutOfTen(double userRating) => '${userRating.toStringAsFixed(1)}/10';   // "8.0/10",与现有卡片输出一致
   ```
   (取整规则:先对 0-10 数值四舍五入到整数再除 2,即半星;默认值,产品可改。)
2. 卡片:`media_ratings_strip.dart:132` → `Text(formatUserRatingOutOfTen(rating.value), ...)`。
3. 无障碍:`media_rating_badge.dart:63-66` 里 `source == 'personal'` 时改用 `formatUserRatingOutOfTen`,其他无来源分数保持 `${mediaRatingLabel(rating)}/10`。
4. 详情 chip:`_userRatingChipLabel`(`media_detail_screen.dart:1133`)在 `isNumeric && hasRating` 时返回 `'${formatUserRatingStars(v)} · ${formatUserRatingOutOfTen(v)}'`(v 为 `metadata.userRating!`);否则仍是 `t.mediaMenu.rate`。chip 内 `Text`(`:1216-1219`)已有 `fontSize: 13`,`ConstrainedBox minWidth: 48`,文字变长不会溢出,但在 320 宽 + 200% 字号下要目视(现有用例 `media_detail_screen_test.dart:3150-3162` 守护 chip 尺寸)。语义标签 `'${t.explore.detail.yourRating}: $label'`(`:1153`)随之变长,可接受。
5. 剧集卡:`episode_card.dart:105-108` 的三元表达式换成 `formatUserRatingStars(episode.userRating!)`(只显示星数,不加 /10,卡片空间小,默认值)。
6. `catalog_item_detail_screen.dart:982`(`userRating.toStringAsFixed(1)`,用于 Simkl 等目录条目)不在本包。

### R2-4 Jellyfin/Emby critic 分来源标注(中)
- 现状:`jellyfin_mappers.dart:436-438`:`CriticRating`(0-100)→ `MediaRatingSource(source: 'rottenTomatoesCritic', value: critic / 10)`,UI 会挂 Rotten Tomatoes 图标(`rating_utils.dart:30-35`)。`:426-428` 注释称它就是 Tomatometer。
- 改成:**先核对再改**。
  1. 核对(无代码):查 Jellyfin/Emby 官方 API 文档与服务端源码中 `BaseItemDto.CriticRating` 的定义与填充来源(NFO `criticrating`、OMDb 插件等)。本环境没有联网核对,**待核对**。
  2. 若能确认该字段在两个服务端上就是 RT 影评百分比:不改代码,只在 `:426-428` 注释里补上来源依据,R2-4 关闭。
  3. 若不能确认(默认结论):把来源改为通用 `'critic'`(已有 key,`rating_utils.dart:45` 标签 `t.common.ratingSource.critic`,无品牌图标,`ratingInfoForSource` 返回 null,UI 用星形回退图标),数值仍 `critic / 10`。`rating_display_policy.dart:11` 的默认排序里已含 `'critic'`。
- 影响:Jellyfin/Emby 用户在评分设置里若曾为 `rottenTomatoesCritic` 调过顺序/禁用,改后该设置对其不再生效,需在提交说明里写明。
- 测试:`jellyfin_mappers_test.dart:70`(期望 `['audience', 'rottenTomatoesCritic']`)与 `:122-131`(`divides the Tomatometer rather than range-sniffing it`,断言 source 与 0.9)按核对结论改;新增 `CriticRating` 缺失/越界(>100、<0、非数)时不产生该条的用例(现有 `:136` 起 `reports no ratings` 若已覆盖则不重复,待核对)。

## 3. i18n key 与常量/设置项

i18n:无新增(复用 `errors.noClientAvailable`、`errors.unableToLoad`、`liveTv.programsSection`、`common.retry`、`common.ratingSource.critic`)。
设置项/常量:

| 名称 | 默认值 | TODO 编号 |
|---|---|---|
| 个人评分星数取整规则(半星) | 先四舍五入到 0-10 整数再 /2 | `TODO(VELO-R2-03)`(写在 `userRatingStars` 上,产品可改) |
| 详情 chip 文本格式 | `星数 · x.x/10` | 同上 |
| Jellyfin critic 来源 | 视 R2-4 核对;未确认则 `critic` | `TODO(VELO-R2-04)` |

## 4. TV 焦点、三主题、各形态要求

- TV(R2-1):错误视图的重试按钮 `autofocus`,选中键重试,返回键 `Navigator.pop`;重试成功后列表第一项重新取得焦点(`autofocus: index == 0`,若实测焦点未回到列表,在重试成功后 `WidgetsBinding.instance.addPostFrameCallback` 请求首项焦点,待核对)。原有用例 `record action is D-pad reachable ...` 不得回归。
- 三主题:错误视图用 `ErrorStateWidget` 的主题色,不写死颜色;R2-2 删的是写死色值,不引入新色;R2-3 chip 沿用现有 `fgColor`/`bgColor`。
- 手机/平板/桌面:R2-1 在窄屏、200% 字号下错误文案可滚动(`LiveTvLoadError` 已处理);R2-3 chip 在 320 宽 200% 字号不溢出。

## 5. 测试要求

要改的现有测试:
- `test/utils/rating_utils_test.dart`:不改,追加。
- `test/services/jellyfin_mappers_test.dart:70, :122-131`:仅当 R2-4 走第 3 条路径时改(source 断言)。
- `test/widgets/media_card_full_card_test.dart:153` `'9.0/10'`:**不应失败**,是 R2-3 的回归守护。
- `test/screens/media_detail_screen_test.dart`:`userRating: 8` 的用例(`:2182`、`:2568`、`:2692`)若断言 chip 文本为 `4`,会因文本变成 `4 · 8.0/10` 失败,需更新(待核对,先 `grep -n "find.text('4')\|yourRating" test/screens/media_detail_screen_test.dart`)。
- `test/widgets/media_ratings_strip_test.dart:109`(R2-2 后回归):不应变。

要新增的测试:

| 文件 | 用例名 | 断言要点 |
|---|---|---|
| `test/screens/livetv/live_tv_show_schedule_screen_test.dart` | `fetch failure shows an error with retry instead of spinning` | fake `fetchSchedule` 抛 `Exception`;pump 后 `find.byType(CircularProgressIndicator)` 为空,出现 `LiveTvLoadError` 与 `t.common.retry` 的按钮,文案含 `t.errors.unableToLoad(context: t.liveTv.programsSection)` |
| 同上 | `retry reloads and shows the schedule` | fake 前 1 次抛错、第 2 次返回节目;点重试后 `fetchSchedule` 调用计数为 2,出现节目标题,错误视图消失 |
| 同上 | `TV retry button is focused and activates with select` | `TvDetectionService.debugSetAppleTVOverride(true)`(文件已设);抛错后 `primaryFocus` 在重试按钮,`sendKeyEvent(select)` 触发重试(计数 +1) |
| 同上 | `missing client shows the no-client message` | provider 里不注册客户端,显示 `t.errors.noClientAvailable`,不转圈、不显示 `noPrograms` |
| `test/utils/rating_utils_test.dart` | `user rating stars round to half stars` | 8→"4";7→"3.5";7.3→"3.5";0.0 与无效值由调用方过滤;`formatUserRatingOutOfTen(8)`=="8.0/10" |
| `test/screens/media_detail_screen_test.dart` | `personal rating chip shows stars and out-of-ten` | `userRating: 8` 的电影详情,chip 文本含 `4` 与 `8.0/10`;`userRating: 7` 含 `3.5` 与 `7.0/10` |
| `test/widgets/media_card_full_card_test.dart` | 沿用 `:153` | 卡片仍 `9.0/10` |
| `test/widgets/episode_card_test.dart` | `episode user rating uses shared star formatting` | `userRating: 7` 显示 `3.5`;`8` 显示 `4`(待核对该文件现有构造辅助) |
| `test/widgets/hero_metadata_badges_test.dart`(新) 或并入 `media_ratings_strip_test.dart` | `hero badges contain no star-label color branch` | 用文本以 `★` 开头的类型(`genres: ['★ Fav']`)渲染,其 `Text.style.color` 等于 `foreground.withValues(alpha: .9)`,不等于 `0xffffd58a`/`0xff94681f` |
| `test/services/jellyfin_mappers_test.dart` | 视 R2-4 | 有值 → 对应 source;无值/越界 → 无该条 |

## 6. 验收清单

命令:
- [ ] `flutter analyze` 无新增告警(特别是 R2-1 新 import 与 `_retryFocusNode` dispose)。
- [ ] `scripts/run_tests.sh` 全绿;单独跑:`flutter test test/screens/livetv/live_tv_show_schedule_screen_test.dart test/utils/rating_utils_test.dart test/widgets/media_card_full_card_test.dart test/widgets/episode_card_test.dart test/widgets/media_ratings_strip_test.dart test/services/jellyfin_mappers_test.dart test/screens/media_detail_screen_test.dart`
- [ ] `grep -n "ffd58a\|94681f" lib/widgets/hero_metadata_badges.dart` 无输出。
- [ ] `grep -rn "userRating *! */ *2\|userRating / 2" lib` 只剩 `rating_bottom_sheet.dart`(评分面板自身换算)与 `rating_utils.dart`。

手动:
- [ ] 断网/服务器报错时打开某节目的"即将播出"页:出现错误文案与重试按钮,不再转圈;恢复网络后点重试出列表。
- [ ] 同一页在 TV:重试按钮有焦点环,选中键可重试,返回键退出。
- [ ] 已评分(如 8 分)的影片:卡片 `8.0/10`,详情 chip `★ 4 · 8.0/10`;7 分 → `3.5 · 7.0/10`;三主题、320 宽 200% 字号不溢出。
- [ ] Jellyfin/Emby 影片(有 CriticRating):按 R2-4 结论,图标与标签符合预期。

## 7. 提交拆分

1. `fix(直播): 节目表加载失败显示错误与重试,不再无限转圈`(含 3 个新增测试)
2. `fix(首页): 删除头图元数据中无调用的星标颜色分支`
3. `refactor(评分): 抽出个人评分星数与十分制格式函数并补测试`
4. `fix(评分): 详情个人评分同时显示星数与十分制,剧集卡改用共享换算`
5. `fix(评分): Jellyfin/Emby 影评分来源标注按核对结果调整`(若核对确认是 RT,则改为 `docs(评分): 补充 CriticRating 来源依据`)

## 8. 风险、待确认、禁止事项

风险与待确认:
- R2-1:`SliverFillRemaining` 里放 `LayoutBuilder` 的布局表现待在 flutter 里验证;备选:`SliverToBoxAdapter(child: SizedBox(height: MediaQuery.sizeOf(context).height * .6, child: LiveTvLoadError(...)))`。
- R2-3:取整规则与 chip 文本格式为默认值(C4);半星规则若产品要求只显示整数星需改 `userRatingStars`。
- R2-4:`CriticRating` 来源待核对;改 source 会让 Jellyfin/Emby 用户已有的评分源排序/禁用设置对该条失效。
- 审计基线是 `fe12755`,其后只有文档提交,行号无漂移(已逐项复核)。

禁止事项:
- 不直接改 `lib/i18n/strings*.g.dart`;本包不新增文案,若后续新增,改 `lib/i18n/*.i18n.json` 后运行 `dart run slang`(`scripts/codegen.sh --check` 校验)。
- 不删减 Plex/Jellyfin/Emby、一起看、TV 支持;不动 mpv/ExoPlayer 后端。
- 不改评分存储值与服务端写入逻辑(`rating_bottom_sheet.dart` 的保存)。
- 不顺手改评分条上限、"我的评分"位置(C2/C3);一个提交只做一件事;不提交凭据或构建产物,保留 Plezy 上游署名。
