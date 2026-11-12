# 界面、评分、选择器与性能改造方案(2026-11-11)

本文是给实现者(人或 AI)的任务说明。结论来自静态读码,**没有真机复现,也没有跑过应用**;行号对应提交 `f955f2a`,
动手前请先核对。标"待确认"的条目需要先验证再改。

通用约束见 `AGENTS.md`:保留 Plex / Jellyfin / Emby / 一起看 / 手机与 TV 支持;用户可见文案走 slang;
TV 上的可交互控件必须用 focusable 包装;不直接改生成文件;提交前跑 `flutter analyze` 与 `scripts/run_tests.sh`。
每个任务包独立提交,一个提交只做一件事。

建议顺序:P1 → P2 → P3 → P4 → P5 → P6 → P7 → P8 → P9(P8 的按下包装可与 P2、P3 的新控件一起落地;P9 的 token 扩充宜在 P2 之前先做)。

---

## P1 屏幕常亮丢失(Android 手机播放久了先变暗后熄屏)

**现象**:流畅播放、无操作,一段时间后屏幕变暗并熄屏;用户未开睡眠定时器。

**最可能的根因(未在真机证实)**:`lib/screens/video_player/wakelock_controller.dart:75-92`。
常亮每 5 秒重申一次,重申前把 `_effectiveEnabled` 置空;平台调用只要失败一次(例如 Android 在 Activity
瞬时不可用时抛 `NoActivityException`,`packages/wakelock_plus` 的 `Wakelock.kt:17`),`target == true`
分支就 `_cancelRefreshTimer()` 并返回,此后不再重试,而播放状态不再变化,也就没有新事件重新申请。

**改动**
1. `wakelock_controller.dart`:启用失败时保留周期定时器并重试(建议退避 1s / 2s / 5s,之后维持 5s),
   只有期望状态为关闭时才取消定时器。失败日志保留,但同一原因不要每 5 秒刷一条。
2. `test/screens/video_player/wakelock_controller_test.dart:46` 的用例
   "a failed enable neither starts refreshes nor retries automatically" 固化了旧行为,需改成"失败后会重试并最终生效"。
3. Android 原生兜底:在 ExoPlayer 与 mpv 插件侧,按"用户意图为播放"(`playWhenReady` / 未暂停)直接对
   Activity window 设置或清除 `FLAG_KEEP_SCREEN_ON`,不依赖 Dart 侧事件。入口参考
   `android/app/src/main/kotlin/**/ExoPlayerCore.kt:1182-1191`。
4. 顺带修两条同类路径:
   - ExoPlayer 缓冲时 `isPlaying` 为 false,被当成暂停而释放常亮(`ExoPlayerCore.kt:1190` →
     `lib/screens/video_player/playback_services.dart:796`)。判据改为"用户意图为播放",缓冲期间继续持有。
   - mpv 播完后回拖继续播放时不再申请常亮(`playback_prompts.dart:40`、`playback_services.dart:129-160`)。
     `completed` 回到 false 且仍在播放时重新申请。

**验收**:注入"第 N 次重申失败"的假平台,断言随后恢复为启用;真机播放 30 分钟以上不熄屏;
暂停、播完、退出播放页后常亮被释放(系统息屏时间后正常熄屏)。

---

## P2 轨道选择改为下拉(播放器抽屉 + 详情页)

**现象**:音频 / 字幕选项只显示语言名,长标题按词折行,同语言多条轨分不清。

**根因**
- `lib/widgets/video_controls/helpers/track_selection_helper.dart:87-96`:嵌入模式只把 `label.primary` 传给
  `PlayerDrawerChoice`,`secondaryLabel`(编码、声道、轨道标题)被丢弃。
- `lib/widgets/video_controls/sheets/player_settings_controls.dart:160`:标签 `Text` 没有 `maxLines` / `overflow`。
- `lib/widgets/video_controls/sheets/sheet_selection_column.dart:77-91`:所有选项用 `Wrap` 平铺在
  318px(手机)/ 400px(平板)抽屉里;字幕弹层 280px(`mobile_chips.dart:33`)。

**新组件 `AppSelectField<T>`**(建议放 `lib/widgets/app_select_field.dart`)
- 触发器:左侧标签(次要色 13),中间主标题(15 / w500,单行省略)+ 副标题(12,次要色,单行省略),右侧下箭头。
  最小高度 58(抽屉内 52),圆角 14,底色 `#14151C`(暗)并带 8% 前景描边。
- 焦点态(TV / 键盘):2px 强调色描边(暗 `#B4AAFF` / 亮 `#6256C8`),箭头同色。
- 展开:复用 `showAdaptiveAppMenu` / `AppMenuItem`(`lib/widgets/app_menu.dart:76,245,28`)的磨砂菜单;
  菜单项两行(主 / 副),选中项用选中底(暗 `#36324E` / 亮 `#E9E5F6`)+ 对勾;菜单项主标题允许 2 行。
- TV 焦点基于 `FocusablePopupMenuButton`(`lib/widgets/focusable_popup_menu_button.dart:7`)的做法,
  保证遥控器可达。
- 文案数据直接用 `TrackLabelBuilder`(`lib/utils/track_label_builder.dart:140-228`)的 primary / secondary,
  版本用 `MediaVersion.displayLabel`(`lib/media/media_version.dart:87-112`)拆成主副两段。

**替换点**
1. 播放器抽屉音频 / 字幕:`track_sheet.dart`(含字幕副轨 `:515-530`)、`sheet_selection_column.dart` 嵌入分支。
2. `player_settings_drawer.dart:317-323` 的 `_ChoiceRow` 与 `danmaku_settings_sheet.dart:662,727,734`:
   选项多于 4 个或文字可变长的改下拉;2-4 个短固定选项可保留分段,但给 `PlayerDrawerChoice` 加
   `maxLines: 1` + 省略号。
3. 详情页新增"版本 / 音频 / 字幕"三行下拉分组,替换只读的轨道状态行
   (`lib/screens/media_detail/playback_tracks_status.dart:243-245`);手机为一组三行,桌面 / TV 为三列并排。
   选择结果要带入播放(现有预选偏好逻辑待确认后复用,不要新造一套)。
4. 版本 / 画质弹窗:`lib/utils/dialogs.dart:648`、`version_quality_sheet.dart:233` 标题允许 2 行。
5. `fitted_metadata_line.dart:187`:主文字加 `Flexible` + 省略号,避免裁切。

**验收**:轨道标题 60 字符以上时触发器单行省略、菜单内完整可读;同语言三条轨能靠副标题区分;
TV 遥控器可打开、选择、返回;加 widget 测试覆盖长标题与无副标题两种情况。

---

## P3 评分展示扩展

**现状**:评分数据与展示代码已存在,但常被隐藏。
- 数据:`MediaItem.rating` / `userRating` / `ratings`(`lib/media/media_item.dart:158-165`,
  `lib/media/media_rating.dart:14-37`),统一 0-10。Plex 列表接口只有 1-2 项,详情接口才有完整 `Rating[]`
  (`lib/services/plex_mappers.dart:959-1008`);Jellyfin 最多 2 项(`jellyfin_mappers.dart:423-439`);
  Emby 是否同路径待确认。
- 展示:`lib/widgets/media_rating_badge.dart`(`InlineRatingBadges`)、图标映射 `lib/utils/rating_utils.dart:28-42`、
  图标资源 `assets/rating_icons/`(imdb / tmdb / rt_fresh / rt_rotten / rt_upright / rt_spilled)。
- 被隐藏的原因:详情页空间不足时评分 `dropPriority` 为 4,最先被丢(`media_detail_screen.dart:1294` 附近);
  卡片角标只在 `showRatingBadge: true` 时显示,仅 `discover_screen.dart:1264,1318` 开启;
  搜索(`search_screen.dart:522`)、库网格、相关推荐都不显示;首页头图只显示单个星标分
  (`hero_metadata_badges.dart:28`)。

**改动**
1. 详情页:评分从元数据标签行里拿出来,做成标题下独立的一行评分条,不参与丢弃。
   - 每项 = 来源图标 + 数字(手机 18 / w600,桌面 22 / w600,等宽数字)+ 下方 11-12 的来源名或评分人数。
   - 手机等分列并用细线分隔,最多 4 列外部评分;桌面 / TV 横排,间距 28。
   - "我的评分"用强调色放在末尾(手机放在操作按钮行),与外部评分用竖线分开,点击打开现有
     `rating_bottom_sheet.dart`。
   - 量纲:烂番茄与 TMDB 显示百分比,IMDb 显示一位小数,社区分显示一位小数。沿用现有 ×10 的展示换算。
   - 降级:无数据的来源隐藏;全无则整行不渲染;加载中用等宽占位,到达时不跳动。
   - 最多 5 项,默认顺序:烂番茄影评、烂番茄观众、IMDb、TMDB、其余。
2. 卡片角标:库网格、搜索结果、相关推荐默认开启;位置左下,半透明暗底圆角 6;
   用户打过分时显示强调色的"我的评分";继续观看卡不显示。保留 `showRatingBadge` 开关并加一个设置项
   (默认开)。实现在 `lib/widgets/media_card.dart:634-641`。
3. 首页头图:`hero_metadata_badges.dart` 改为最多显示 2 个带来源图标的评分(复用 `mediaRatingsFor`,
   参考 `tv_spotlight_background.dart:345-349`)。
4. 设置里增加"评分来源与顺序"(启用 / 排序),卡片角标取排在首位且有数据的来源。数值未定的地方用配置项加默认值。
5. 豆瓣目前没有数据来源(`lib/` 内无相关代码),**不在本包范围**;如需要,另开任务评估来源与授权。

**验收**:窄屏长标题下评分仍可见;无评分条目不留空行;Plex 列表卡片只有单分、进详情后补全且不跳动;
亮色主题对比度达标;加 widget 测试覆盖 0 / 1 / 2 / 5 项。

---

## P4 冷启动提速

**时序**:`runApp` → 初始化门控 → 闪屏 `SetupScreen` 等所有服务器绑定 → 刷新下载元数据 → 首页 → 网络拉取 onDeck / hubs。

**改动(按收益排序)**
1. 闪屏不再等所有服务器:`lib/main.dart:2249` 的 `awaitStartupBindSettle` 改为"任一服务器在线,或最多等
   1.5-2 秒(做成配置项)即进入首页",其余后台继续连。`DiscoverProvider` 已支持按服务器增量合并
   (`_loadDeltaOnce`)。单台连接预算 6.5s 见 `lib/utils/media_server_timeouts.dart:81`。
2. 首页先显示缓存:`lib/providers/discover_provider.dart:381-560` 的 onDeck / hubs 只在内存。
   把上次结果落盘(可用现有 `lib/services/api_cache.dart`),启动先渲染缓存再后台刷新;
   `lib/services/data_aggregation_service.dart:563-571` 的 hubs 改为每台服务器返回即提交,不等最慢的一台。
3. `lib/main.dart:2267` 的 `downloadProvider.refreshMetadataFromCache()` 移到首页显示之后,或只读缓存不发请求
   (`lib/providers/download_provider.dart:2302-2304`)。
4. `lib/main.dart:2083-2205`:`ConnectionBootstrap.run`、`pruneUnreferencedJellyfinConnections`、
   `ConnectivityProbe.check`(最长 3s)互不依赖,改并行。
5. `lib/main.dart:941-989`:`StorageService.getInstance` 与数据库打开并行。

**验收**:在 `StartupPhase` 或日志里记录"进程启动 → 首页首个内容可见"的耗时,改造前后各测 5 次冷启动取中位数;
一台服务器离线时首页不被卡住;缓存内容与刷新结果不一致时平滑替换。

---

## P5 运行时性能

1. 下载进度节流:`lib/providers/download_provider.dart:590-628` 每个进度事件都 `notifyListeners`,
   `downloads` getter 每次全量拷贝。按 key 做 250-500ms 节流(状态变化立即发),缓存 `downloads` 视图,
   `lib/screens/downloads/downloads_screen.dart:261,397,713` 改用按条目的 `Selector`。
2. 导航栏模糊降级:`lib/navigation/fusion_navigation.dart:64-65` 的 `BackdropFilter`(sigma 28)不受降级开关控制。
   复用 `AppGlassSurface.reduceEffects`(`lib/widgets/app_glass_surface.dart:62`),降级时用不透明底色。
3. 播放器浮层模糊降级:`lib/widgets/video_controls/widgets/player_hud_surface.dart:16`(sigma 10)同样处理。
   `lib/widgets/vidhub_ambient_backdrop.dart:98` 是否缺降级判断待确认。
4. 详情页:Plex 路径用列表已有元数据先渲染并并发请求季 / 花絮 / 相关
   (`lib/screens/media_detail_screen.dart:1700-1735`);收益待实测,注释里提到 Jellyfin 提前并发更差,不要动 Jellyfin 路径。
5. 侧栏 `lib/widgets/side_navigation_rail.dart:870-898` 一次 watch 5 个 provider,改 `Selector`;
   `settings_screen.dart:712,1041`、`external_player_screen.dart:56` 的 `FutureBuilder` 不要在 build 里创建 future。

---

## P6 其他界面显示问题

1. 直播电视错误状态:`lib/screens/livetv/live_tv_show_schedule_screen.dart:72` 请求失败后一直转圈;
   `tabs/guide_tab.dart:538`、`tabs/whats_on_tab.dart:95` 失败后空白。接入
   `lib/screens/libraries/state_messages.dart` 的 `ErrorStateWidget` / `EmptyStateWidget`,带重试。
2. 长文字溢出(待实机确认):`lib/screens/settings/add_jellyfin_screen.dart:931`、
   `lib/widgets/server_activities_button.dart:324`、`lib/widgets/hub_section.dart:568`、
   `lib/screens/profile/borrow_connection_screen.dart:415,428`、`lib/screens/discover_screen.dart:1085`。
   Row 内可变文本统一 `Flexible` + `maxLines` + 省略号。
3. 固定宽度标签:`catalog_item_detail_screen.dart:909`(140)、`media_detail_screen.dart:5200`(120)改最小宽度。
4. 未走磨砂封装的弹窗:`lib/utils/dialogs.dart:623`、`lib/watch_together/widgets/local_media_match_dialog.dart:128`
   换 `AppDialog`。
5. 硬编码颜色约 413 处,先收敛非播放器页面:`lib/screens/media_detail/presentation.dart`、
   `lib/screens/auth_screen.dart`、`lib/screens/settings/logs_screen.dart:325-383`、
   `lib/screens/media_detail/action_buttons.dart:218`。播放器覆盖层的白色保留。
6. 响应式断点收敛到 `lib/utils/layout_constants.dart`(现散落 600 / 700 / 1100 / 1180 / 390,约 13 处)。
7. 疑似漏翻的中文 key:`videoControls.addTime`、`videoControls.qualityPresetLabel`、`discover.playEpisode`、
   `discover.playSeason`、`accessibility.mediaCardEpisode`、`accessibility.mediaCardSeason`、`auth.quickConnect`。
   `auth_screen.dart:735` 的调试入口是否有 `kDebugMode` 保护待确认。

---

## P7 视觉改版(与 P2、P3 同步落地)

设计稿为外部画布,不入库;以下是落地所需的全部规格。

**沿用的设计语言**(不新增品牌色)
- 色:背景 `#000000`;分组面 `#14151C`(新增一级,介于背景与表面之间);表面 `#20212B`;正文 `#ECECF3`;
  次要 `#9A9BAE`(对黑底约 7:1);强调 暗 `#B4AAFF` / 亮 `#6256C8`;选中底 暗 `#36324E` / 亮 `#E9E5F6`;
  分隔线 前景 8%-10% 透明度。亮色与 OLED 主题按同样层级映射,颜色进 `lib/theme` token,不在页面里写死。
- 字:系统字体;字阶沿用 11 / 12 / 13 / 15 / 18 / 22;详情页标题手机 40、桌面 64,w600。
- 形:海报 12、卡片 14、下拉菜单 18、弹窗 24、胶囊 100;无阴影。
- 磨砂只用于导航、菜单、弹窗这类浮层,不用于卡片和正文;降级时用不透明底色(见 P5)。

**底部导航**(保持现状,不改结构)
- 主标签固定为 首页 / 媒体库 / 一起看 / 设置(`lib/navigation/navigation_tabs.dart:12-17`),右侧是"选项"按钮
  (`fusion_navigation.dart` 的 `_options`);下载、直播电视、探索、搜索不在主标签里。改版不增删标签。

**详情页(手机)自上而下**
1. 全幅头图,底部长渐隐到背景色。
2. 标题区居中:外文原名(Georgia 10,字距 3,全大写,可选)→ Clear Logo 或文字标题。
3. 元数据一行纯文字,点号分隔:年份 · 时长 · 类型;分级用 1px 描边小框;4K / 杜比视界 / ATMOS 用更淡的描边小框。
   不再使用整排实心标签。
4. 评分条(见 P3)。
5. 操作行:主按钮高 52、胶囊、浅色底深色字("继续播放 · 剩余 X 分");右侧圆形次要按钮(下载)和"我的评分"按钮。
   主按钮下方 3px 进度条,强调色。
6. 版本 / 音频 / 字幕下拉分组(见 P2)。
7. 简介(14,行高 1.8,可展开)→ 演职员(60 圆形头像)→ 相关推荐(海报带评分角标)。

**详情页(桌面 / TV)**:背景全屏,左侧 600 宽信息区(标题 64、元数据、评分条、简介、操作行高 56、三个下拉并排),
左向右与自下而上的暗化遮罩,底部一行相关推荐(海报 150×225)。TV 上所有控件需有 2px 强调色焦点描边。

**首页**:头图轮播只展示影片信息,不放任何操作按钮——去掉现有的播放按钮(`lib/widgets/fusion_home_hero.dart:160`
的 `playButton`),也不放下载、版本、音频等控件,这些只出现在详情页。头图内容自上而下:外文原名 → Clear Logo
或标题 → 元数据行 → 最多两行简介 → 轮播指示点。整张头图可点击,点击行为沿用现状(`fusion_home_hero.dart:81`
的 `onTap`),是否改为进入详情页待产品确认。TV 上头图本身是焦点目标,确认键触发同一行为。
桌面 / TV 的首页头图(`tv_spotlight_background.dart` 等)同样处理:左侧 600 宽信息区只放外文原名、标题 64、
元数据行、评分条(不含"我的评分")、简介和轮播指示点,不放播放、下载、已看、更多按钮,也不放版本 / 音频 / 字幕下拉;
底部一行海报(150×225,带评分角标)。现有 TV 头图上是否有这些控件未核对,有则移除。
元数据行内嵌最多 2 个带图标的评分;继续观看卡保持白色进度条与剩余时间,不显示评分;
海报行显示评分角标。

**播放器**:右侧抽屉结构不变(视频 / 音频 / 字幕 / 弹幕四个分段),内容区用下拉替换平铺标签;
传输图标保持白色。

---

## P8 交互反馈(按下、选中、触感)

**现状**:有 TV 焦点反馈(`lib/focus/` 的描边、发光、未聚焦变暗)和统一触感函数
`lib/utils/selection_feedback.dart:9`,但触感只在 7 个文件里调用(底部导航、`setting_tile.dart`、
`focusable_list_tile.dart`、`player_settings_controls.dart`、`expressive_button_group.dart`、
`mobile_remote_screen.dart`)。`lib/focus/focusable_button.dart` 只有焦点透明度动画,没有按下态。
海报卡片、主操作按钮、下拉菜单的按下态是否存在未逐个核对,实现前先确认,已有的就对齐规格而不是重做。

**做法**:新增一个通用按下包装(建议 `lib/widgets/press_feedback.dart`,包 `Listener` / `GestureDetector`
的按下与抬起,驱动 `AnimatedScale` 与一层明暗遮罩),各控件复用它,不要每处各写一套。
缩放比例、时长做成 `lib/theme` 里的常量。

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

**规则**
- 时长:按下 120ms,回弹 180-200ms,曲线用 `Curves.easeOutCubic`;不做弹簧过冲,避免显得轻佻。
- 降级:`MediaQuery.disableAnimationsOf(context)` 为真时只变色、不缩放;`DevicePerformance.isReduced`
  时去掉暗层动画。
- 触感只走 `selectionFeedback()`,不直接调 `HapticFeedback`;TV 与桌面不触发。
- 按下态不得改变布局尺寸(用 `Transform` 缩放),避免列表跳动;滚动手势开始时立即取消按下态。
- 播放器内的传输按钮保持白色图标,只加缩放,不加暗层。

**验收**:手机上每个可点击控件按下都有可见变化;滑动列表时卡片不误触发按下态;
开启系统"减弱动态效果"后无缩放;TV 遥控器焦点与确认反馈正常;给按下包装加 widget 测试
(按下、抬起、取消、禁用动画四种情况)。

---

## P9 动效与视觉效果

**现状**:已有动效词汇 `lib/theme/mono_motion.dart`(`emphasized` = `Easing.emphasizedDecelerate`,
`standard` = `Curves.easeOutCubic`,时长取 `MonoTokens` 的 fast / normal / expressive,低性能档归零)和
`lib/utils/layout_constants.dart:30` 的 `AppDurations`(300 / 500)。但页面里仍散落大量写死的时长
(200ms 约 35 处、150ms 约 22 处、300 / 500 / 100 / 250 / 400 等),路由切换是 500ms 整页淡入
(`lib/utils/navigation_transitions.dart:14-16`),没有海报到详情页的共享元素过渡。

**目标**:所有动效走同一套时长与曲线;关键路径(进详情页、下拉、导航切换)有明确的编排。

**时长五档**(加进 `MonoTokens`,已有的 fast / normal / expressive 对齐到其中三档,不要另起一套)

| 档 | 毫秒 | 用途 |
|---|---|---|
| 按下 | 120 | 缩放、底色变化 |
| 快 | 180 | 回弹、菜单、对勾、箭头旋转、颜色 |
| 标准 | 280 | 导航滑块、抽屉、内容进入 |
| 强调 | 420 | 海报展开成详情页 |
| 环境 | 600 | 环境色、头图交叉淡入 |

退出动画取进入的 0.75 倍。以上数值是设计建议,做成 token,实机调过再定。

**曲线三条**
- 强调减速 `Easing.emphasizedDecelerate`(0.05, 0.7, 0.1, 1):位移、展开、形状变化。
- 标准 `Curves.easeOutCubic`:缩放回弹、颜色、透明度。
- 退出 `Curves.easeInCubic`:离开屏幕的元素。
不用弹簧过冲。

**编排**
1. 海报 → 详情页(手机):
   - 0-420ms 海报从卡片位置展开成头图(位置、尺寸、圆角 12 → 0),强调减速。用 `Hero` 或自定义
     `PageRouteBuilder` + 共享矩形实现;海报图要复用列表里已解码的同一张,避免展开时闪一下换图。
   - 0-200ms 首页内容淡出并缩到 98%,底部导航下移退出。
   - 80ms 起底部渐隐遮罩淡入;160ms 起标题与元数据淡入并上移 12px;
     240ms 起评分逐项进入,每项错开 60ms;480ms 起操作按钮;540ms 起下拉分组。
   - 返回时反向,所有延迟归零,整体不超过 300ms。
   - 元数据晚到时不重播入场动画,只做 200ms 淡入。
   - TV 与桌面不做共享元素展开,保留淡入,时长降到 280ms。
2. 下拉菜单:从触发行下沿展开,透明度 0 → 1、缩放 96% → 100%、上移 6px 归位,180ms 强调减速;
   箭头旋转 180°;选中项对勾 120ms 淡入并从 60% 放大,140ms 后菜单关闭。
3. 底部导航:选中底色滑块 280ms 滑到新标签,文字颜色 180ms 过渡;标签结构不变
   (首页 / 媒体库 / 一起看 / 设置)。
4. 标记已看:对勾用描边绘制动画 280ms,底色与图标色 180ms 过渡。
5. 播放器控制层:显示 180ms 淡入,隐藏 280ms 淡出;抽屉从右侧滑入 280ms。

**视觉效果**
- 环境色:从海报取主色(已有 `HomeThemeScope.colorOf` 与 `artworkBlend`,优先复用),压到约 50% 透明度,
  在信息区后方做径向辉光;切换条目时 600ms 交叉淡入。低性能档关闭。
- 长渐隐:头图底部约 260px 三段渐隐到背景色,不出现硬边。
- 骨架屏:高光 1.4s 扫过一次;内容到达后 200ms 淡入替换,占位与内容等尺寸。
- TV 焦点:2px 强调色描边加 6px 外晕,卡片放大到 104%,描边 150ms 跟随(对齐 `lib/focus/focus_theme.dart`)。
- 磨砂仍只用于浮层(见 P5、P7)。

**降级**
- `MediaQuery.disableAnimationsOf(context)`:位移与缩放归零,只保留 120ms 淡入淡出。
- `DevicePerformance.isReduced`:沿用 `DevicePerformance.reducedDuration`,并关闭环境色辉光与骨架高光。

**落地步骤**
1. 扩充 `MonoTokens` / `MonoMotion`,把 `AppDurations` 并入或标注对应关系。
2. 先改关键路径(详情页转场、下拉、导航),再分批把写死的 `Duration(milliseconds: N)` 换成 token;
   每批限定一个目录,不要一次全仓替换。
3. 播放器内与帧时序相关的时长(手势、长按、字幕、seek)不属于界面动效,**不要替换**。

**验收**:关键路径动效与上表一致;开"减弱动态效果"后无位移缩放;低性能档无动画;
60Hz 设备上详情页转场不掉帧(用 Flutter 性能面板看);转场期间返回手势可随时打断。

---

## 未做与待确认

- 所有结论未经真机验证;P1 的根因是"与现象最吻合的代码路径",不是已复现的结论。
- 市场调研覆盖有限(部分站点无法访问),仅 Infuse 的评分来源可排序且最多 5 个、Metacritic 三段配色、
  烂番茄 60% 新鲜线有来源依据;其余产品的界面细节未证实,本方案没有依赖它们。
- Emby 评分映射、详情页轨道预选如何带入播放、`vidhub_ambient_backdrop` 的降级,都需要先读代码确认。
