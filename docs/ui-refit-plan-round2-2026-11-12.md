# UI 改造第二轮方案(2026-11-12)

- 基线 HEAD:`fe12755`(文中行号均以此为准;标"近似"的行号来自核对材料中的 `~`,同样近似,动手前先 grep 定位)
- 第一轮方案:`docs/ui-ratings-selectors-performance-plan-2026-11-11.md`(P1–P9);对方实现提交 `8c6ae6b..77ec375`(77ec375 为纯文档)
- 声明:本文所有"现状"来自**静态读码**。本环境无 flutter,**未运行 `flutter analyze`、未运行任何测试、未在真机/TV 上验证**。接手者动手前须先自行 grep 复核行号与现状。
- 读者:接手实现的另一个 AI。每条含 现状(文件:行号)/ 改成什么 / 验收。

---

## 1. 第一轮完成情况总表

| 包 | 主题 | 状态 | 说明 |
|---|---|---|---|
| P1 | 屏幕常亮 | 已完成(代码层) | 退避重试、重新 attach 重放、意图/阶段策略已做;有 IDLE 短暂释放隐患、mpv 原生侧无兜底、真机 30 分钟未验。见 R3 |
| P2 | 选择器/下拉 | 部分 | 新增 AppSelectField,播放器音轨/字幕、详情页版本/音频/字幕已改下拉;触发器无字段标签,版本/画质嵌入态仍平铺,标题无 maxLines,多处平铺未评估。见 R4 |
| P3 | 评分 | 部分 | 策略、设置页、卡片角标、首页最多 2 个已做;缺来源图标、上限 4 与方案 5 不一致、角标配色、Jellyfin/Emby 无 IMDb/TMDB、19 语言仅英文占位。见 R5 |
| P4 | 冷启动 | 部分 | 2s 共享预算、渐进内容、24h 首页快照已做;启动串行链未并行、缓存依赖在线 client、refreshMetadataFromCache 仍发网络。见 R7 |
| P5 | 运行时性能 | 部分 | 下载 300ms 节流、导航栏/ambient 模糊降级已做;播放器 HUD 模糊未降级、侧栏仍 watch、FutureBuilder 未改、下载快照每次进度失效。见 R6 |
| P6 | 错误/空态/显示问题 | 部分(只做直播) | whats_on/guide/recordings 已有错误+重试;节目表页漏做;长文字溢出、固定宽度、SimpleDialog、硬编码色、断点均未做。见 R2、R8 |
| P7 | 视觉 | 部分 | 主题色 token、底部导航、详情页下拉、TV 浏览条角标已做;**首页头图未去按钮(用户明确要求,漏做)**,圆角/字阶 token、详情页新结构未做。见 R1、R10 |
| P8 | 交互反馈 | 部分 | PressFeedback、交互 token、减弱动画已做;多数控件未接入,遮罩/触感/文案/箭头旋转/测试欠缺。见 R9 |
| P9 | 动效 | 基本未做 | 仅有按压缩放/回弹/模糊降级(属 P8);五档时长、转场、编排、滑块、对勾均未做。见 R11 |

---

## 2. 第二轮任务包

通用:每条验收默认包含"亮色/暗色/纯黑三主题"与"手机/桌面/TV 受影响形态"逐一目视;单测命令见第 3 节。

### R1 首页头图只展示影片信息(高,用户明确要求,第一轮漏做)

目标:手机/平板/桌面/TV 首页轮播只留:标题(或 logo)、外文原名、年份·时长·类型·分级、最多 2 个评分、简介、页码指示。不再有播放按钮、详情按钮、下载、版本/音频信息。

| 编号 | 优先级 | 现状 | 改成什么 | 验收 |
|---|---|---|---|---|
| R1-1 | 高 | 手机:`lib/screens/discover_screen.dart:1574` 传入 `playButton`,`:1575-1604` 传入 `detailsButton` 给 `FusionHomeHero`;`fusion_home_hero.dart:31-41`(参数)、`:173-181`、`:199`(渲染按钮) | 删除 `playButton`/`detailsButton` 参数及调用处,头图布局不再为按钮留空 | 手机首页头图无任何按钮;grep `detailsButton`/`playButton` 在 hero 相关文件无残留 |
| R1-2 | 高 | 平板/桌面/TV 分支:`discover_screen.dart:1773,1829` 调用 `_buildSmartPlayButton(heroItem)`;TV 焦点节点近似 `:1407`。下载、版本/音频信息在该分支的具体位置材料未给出,**待核对**(在 `:1760-1840` 近似范围内查) | 删除该分支的播放按钮、下载入口、版本/音频信息;删除不再被引用的焦点节点,但保留轮播项本身的焦点(见 R1-6) | 三种宽度/TV 头图上无按钮与版本/音频文字 |
| R1-3 | 高 | `fusion_home_hero.dart:248-294` `HomeHeroPrimaryButton`(固定白底黑字,亮色主题不合);`_buildSmartPlayButton` 的调用方见 R1-1/R1-2 | 删除 `HomeHeroPrimaryButton`;删除 `_buildSmartPlayButton`(先 grep 确认无其他调用方,**待核对**);同时清理随之无用的 import/字段/TV 焦点节点 | `flutter analyze` 无 unused;grep `HomeHeroPrimaryButton` 为 0 |
| R1-4 | 高 | 手机 `FusionHomeHero`(`fusion_home_hero.dart:125-185`)有外文原名+logo+元数据,**无简介** | 补简介,最多 2 行,省略号;位于元数据之后、页码之前 | 手机头图有 ≤2 行简介,长简介不溢出;无简介的影片不留空白 |
| R1-5 | 高 | 平板/桌面/TV 分支有简介(`discover_screen.dart:~1768`),**无外文原名** | 补外文原名(原名与标题相同或为空则不显示),位置同手机:标题上方 | 有外文原名的影片可见,无则不占位 |
| R1-6 | 高 | 点击:手机 `discover_screen.dart:1573` `_openHero` 进详情;桌面/TV `:1651-1653` 传 `play:true` 直接播放,无障碍提示 `tapToPlay`(`:1651`) | **默认值,待产品确认(C1)**:三种形态统一为点击/确认键进入详情页;把 `:1653` 的 `play:true` 去掉;无障碍提示 `tapToPlay` 改为"打开详情"类文案(slang 新增 key 或复用已有详情 key,先 grep 已有 key) | 桌面鼠标点击、TV 确认键、手机点击都进详情;屏幕阅读器提示不再说"播放" |
| R1-7 | 高 | TV 首页轮播项的焦点依赖 `:~1407` 的焦点节点与 `:1651` 附近的点击处理 | 删除按钮后轮播项本身必须仍可聚焦(用 focusable 包装),方向键左右切页、确认键进详情、初始焦点不丢 | TV 上无按钮时遥控器仍能聚焦头图并进入详情;初始焦点图不为空 |
| R1-8 | 中 | 评分最多 2 个已做(`hero_metadata_badges.dart:42`,策略 `heroLimit=2`);页码指示在 `discover_screen.dart:1470`(全局) | 保持不变;改动后回归确认评分 ≤2、页码仍显示 | 头图评分 ≤2;页码正常 |
| R1-9 | 中 | 无头图专属 widget 测试(材料未提及) | 补 widget 测试:断言头图树内无 `FilledButton/播放/下载` 类控件、简介与原名存在、点击回调为打开详情 | 新增测试通过(需有 flutter 的环境) |

注:`tv_spotlight_background.dart`(库/探索页的 TV 聚光图)材料核对为已无按钮、评分 ≤2(`:349`),不属本包;首页 TV 用的是 `discover_screen.dart` 里的头图。

### R2 缺陷修复(高)

| 编号 | 优先级 | 现状 | 改成什么 | 验收 |
|---|---|---|---|---|
| R2-1 | 高 | `lib/screens/livetv/live_tv_show_schedule_screen.dart:55-90` `_loadSchedule` 无 try/catch;`fetchSchedule` 抛错则 `_isLoading`(`:45`、`:139`)永远 true,一直转圈;`client==null` 时直接显示空 | 捕获异常,置错误态,接入已有 `LiveTvLoadError`(带重试与 TV focusNode,见 `guide_tab.dart:185,1202-1210`)或 `ErrorStateWidget`;`client==null` 给明确文案而非静默空 | 单测:fetchSchedule 抛错后出现错误视图与重试按钮,点击重试再请求;TV 上重试可聚焦 |
| R2-2 | 高 | `hero_metadata_badges.dart:54-58`(目录待核对)(颜色行 `:57-58`,两处材料行号略有出入)有已无调用的 '★' 死分支,硬编码 `0xffffd58a`/`0xff94681f`;默认前景 `Colors.white`(`:12`) | 删除死分支及其硬编码色;`:12` 默认前景是否随主题**待核对**(见 C5) | grep 两个色值在该文件为 0;analyze 无 unused |
| R2-3 | 高 | 卡片个人评分角标显示 "x/10"(`media_rating_badge.dart` 的 `mediaCardRatingFor`),详情个人评分 chip 按 `userRating/2` 显示星数(`media_detail_screen.dart:1136`);Plex 5 星用户可能混淆 | **默认值,待确认(C4)**:卡片保持"x/10"(第一轮刻意明确),详情个人评分处同时显示星数和"x/10"文字,两处数值来自同一换算函数(抽到 `rating_utils.dart`);不改存储值 | 单测:userRating=8 时卡片显示 8/10,详情星数 4 且文字 8/10;半星(如 7)的取整行为有用例 |
| R2-4 | 中 | Jellyfin/Emby 把 critic 分一律标为 `rottenTomatoesCritic`,即使服务端数据并非 RT(`jellyfin_mappers.dart:437`,第一轮前已存在) | 先确认服务端 critic 字段语义(**待核对**);不能确认来源是 RT 时,来源标为"影评/其他"而不挂 RT 图标 | 映射单测覆盖 critic 有值/无值 |

### R3 屏幕常亮收尾

| 编号 | 优先级 | 现状 | 改成什么 | 验收 |
|---|---|---|---|---|
| R3-1 | 中 | `screen_awake_policy.dart:23`:idle 阶段仅 `openingWithPlayIntent`(首帧前)为真。`ExoPlayerCore.kt` 解码器恢复/重新 prepare 路径(近似 `:1503`、`:1625`,saved playWhenReady)若短暂回到 `STATE_IDLE`,首帧后会短暂释放常亮,等下一事件或 5s 重申才恢复。**此为代码推断,未实机证实** | 先确认恢复路径是否会发 idle;若会:策略改为"idle 且 playWhenReady=true 且无致命错误时保持常亮" | `screen_awake_policy` 单测新增:idle+playWhenReady+无 fatal 保持;idle+fatal 释放;idle+playWhenReady=false 释放 |
| R3-2 | 低 | mpv 原生插件无 keep-on 兜底,完全依赖 Dart 侧(仅 debug 测试 Activity 用到 FLAG);ExoPlayer 侧同样依赖 Dart 事件(`ExoPlayerCore.kt:480-499` 发 playback-activity)。对方刻意不在原生核心写 `FLAG_KEEP_SCREEN_ON` | 先评估 Dart 事件丢失/延迟的真实概率(依赖 R3-3 真机数据);若需兜底,在 mpv 原生侧由唯一 owner 设置,且不与 `packages/wakelock_plus` 的 `requestedEnabled` 重放冲突。无数据前不改 | 有真机数据后再定;无数据时本条只记录结论 |
| R3-3 | 高(验收) | 真机 30 分钟/TV 长播、缓冲/音频焦点/PiP/息屏均未验 | 真机步骤:① Android 手机装当前构建,设置系统息屏 30 秒;② 分别用 mpv 与 ExoPlayer 播放同一个长视频 ≥30 分钟,不触屏,屏幕须不熄;③ 中途手动暂停,≤息屏时间后屏幕应可熄,恢复播放后应再次常亮;④ 弱网制造缓冲(限速)期间屏幕不熄;⑤ 进 PiP/切后台/锁屏再回来后恢复;⑥ TV(Android TV)同样跑 30 分钟。全程 `adb logcat` 过滤 `Wakelock enable failed`,出现次数与时间点记录下来,附设备型号/系统版本 | 30 分钟内屏幕不熄;logcat 无持续的 `Wakelock enable failed`;结果写入提交说明 |
| R3-4 | 低 | `wakelock_controller.dart:14` `TODO(VELO-P1-01)`,失败后退避 1/2/5s 再保持 5s(`:90-131`),同原因只记一次日志(`:105-107`) | 参数保持不变并保留 TODO;R3-3 真机观察瞬时失败/持续失败/耗电后再调,调整时改常量不改结构 | 调整后 `wakelock_controller_test.dart` 的退避用例同步更新并通过 |
| R3-5 | 低 | `playback_services.dart:158-168`:mpv `completed=false` 且停在末尾窗口内刻意不申请常亮;`screen_awake_policy.dart:18` lifecycle hidden/paused 且非 PiP 即释放(合理) | 不改;写进 R3-3 验收观察项 | — |

### R4 选择器收尾

| 编号 | 优先级 | 现状 | 改成什么 | 验收 |
|---|---|---|---|---|
| R4-1 | 中 | `lib/widgets/app_select_field.dart`(近似 `:150-190`)触发器内无字段标签,label 只用作菜单标题/语义;详情页三列并排时选中后只见值不见字段名(`playback_selectors.dart:59,78,97`) | 触发器内显示"标签(次要色,13)+ 主文字 + 可选副文字";窄宽时标签单行省略 | widget 测试:触发器同时含标签与当前值;三列宽度 680 以上/以下都不溢出 |
| R4-2 | 中 | `version_quality_sheet.dart:125`(版本)、`:166`(画质)嵌入态走 `sheet_selection_column.dart:102` 的 Wrap 回退平铺;`:233` `_SelectionTile` 文本无 maxLines | 嵌入态提供 `embeddedBuilder`,用 `AppSelectField`(参考 `track_sheet.dart:180,253` 与 `sheet_selection_column.dart:99-101` 的用法);非嵌入态保持 | 长版本标题在嵌入态不再折成多行平铺;TV 方向键可进出 |
| R4-3 | 低 | `track_selection_helper.dart:87-96` 嵌入分支只传 `label` 给 `PlayerDrawerChoice`,丢 `secondaryLabel`;因 track_sheet 已改 AppSelectField,**该路径是否还有其他调用方待核对** | 若无调用方:删除死路径;若有:补传 secondaryLabel | grep 调用方结论写入提交说明;有调用方则加单测 |
| R4-4 | 中 | `lib/utils/dialogs.dart:648` 标题 Text 无 maxLines;`version_quality_sheet.dart:233` 同;`fitted_metadata_line.dart:187,195` 为 maxLines:1,是否有 Flexible 包裹**待核对** | 标题 `maxLines: 2` + ellipsis;fitted_metadata_line 确认 Flexible,必要时补 | 构造超长版本名的测试/截图不溢出 |
| R4-5 | 中 | `lib/screens/livetv/record_options_sheet.dart:398-410` Wrap+ChoiceChip(`entry.title` 无省略,选项文案可变长) | 选项 >4 或文案可变长 → 改 `AppSelectField`;2–3 个短固定项保留 chip。具体选项数**待核对** | 超长标题不溢出,TV 可操作 |
| R4-6 | 中 | `lib/widgets/tag_edit_dialog.dart:147-152` Wrap+`FocusableFilterChip`(标签,可变长) | 是否多选**待核对**:若是标签多选集合,不改下拉,但给 chip 加最大宽度+单行省略;若是单选且项多,改下拉 | 超长标签不撑破对话框 |
| R4-7 | 中 | 设置页分段控件:`appearance_settings_screen.dart:282-330`(3 项长文案,`expressive_button_group.dart:218` 用 FittedBox 缩小而非省略)、`playback_settings_screen.dart:455`(长按倍速)、`tracker_library_filter_screen.dart:93`、`external_player_screen.dart:239`(各自项数/文案长度**待核对**) | 逐个按规则处理:项数 >4 或文案可变长 → 下拉;2–3 个短固定项 → 保留。appearance 的 3 项长文案优先改下拉或改为上下行展示,避免 FittedBox 缩到不可读 | 每个控件一句处理结论写进提交说明;小字号/长语言(德/俄)下不缩到不可读 |
| R4-8 | 低 | 评估后**保留不改**:`libraries/filters/filter_operator_row.dart:125,204`、`libraries/sort_bottom_sheet.dart:159-168`(SegmentedButton,项少且短);`player_settings_drawer.dart:294-325`(3 个短固定 aspect 项,已加省略号);`danmaku_settings_sheet.dart:657,723`(2-3 个短项);`danmaku_sources_sheet.dart:187,424`、`file_info_bottom_sheet.dart:100,638,670`(展示用 Wrap,非选择器);`screens/companion_remote/mobile_remote_screen.dart:208,277,400`(选项数**待核对**) | 不改;mobile_remote 若项 >4 再按 R4-5 规则 | — |

### R5 评分收尾

| 编号 | 优先级 | 现状 | 改成什么 | 验收 |
|---|---|---|---|---|
| R5-1 | 中 | `media_ratings_strip.dart:60-85` 单元格只有数字+文字来源名,**无来源图标**;`assets/rating_icons/` 已有 6 个 svg;`ratingInfoForSource` 可取资源 | 每个单元格加来源图标(用现有 svg,不新增自绘),图标 + 数字(18/w600 等宽数字)+ 来源名(11) | widget 测试:每个来源有图标;无图标资源的来源回退为文字 |
| R5-2 | 低 | `media_ratings_strip.dart:44-56` 为等宽 Wrap,手机无细分隔线,无桌面/TV 变体(方案:桌面数字 22、间距 28) | 手机加细分隔线;桌面/TV 用大一号变体 | 三种形态目视 |
| R5-3 | 中 | `rating_display_policy.dart:17` `detailLimit=4`,方案为 5(手机上限 4 列);策略文件 `:5` 已有 `TODO(VELO-P3-01)` | **待确认(C2)**:上限做成常量/配置项(默认值先保持 4),TODO(VELO-P3-01) 保留;若定 5,手机端用换行/横滑而非挤 5 列 | 单测:0/1/2/4/5 个评分的裁剪与顺序 |
| R5-4 | 中 | "我的评分":独立 `_buildUserRatingChip`(`media_detail_screen.dart:1145-1238`,`presentation.dart:222`,`responsive_layout.dart:164`),不在评分条内,无分隔;方案为条末强调色单元、点击开评分面板 | **待确认(C3)**,默认保持独立 chip(对方按画稿"四外部+独立个人入口"解释);确认并入后再迁 | 点击仍打开评分面板;TV 可聚焦 |
| R5-5 | 中 | 卡片角标:`media_ratings_strip.dart:108-140`(圆角 6,左下,`media_card.dart:670`)背景为 `colorScheme.surfaceContainerHighest` .94、文字 `onSurface`,亮色主题下变成浅底;个人评分见 `media_rating_badge.dart:33-37` | 两种主题统一为深色半透明底 + 白字(压在海报上);个人评分角标用选中色底。颜色用 token,不新写十六进制 | 亮/暗/纯黑下角标在浅色海报与深色海报上都可读 |
| R5-6 | 中 | `media_ratings_strip.dart:51` 评分条高度按 `maxRatings` 个槽位预留,只有 1 个评分时留空白(大字号更明显);无加载占位 | 高度按实际数量;仅"加载中"时预留占位避免跳动 | 1 个评分时无多余空白;加载→出现无布局跳动 |
| R5-7 | 中 | Jellyfin/Emby:`jellyfin_mappers.dart:432-439` 只映射 audience + RT critic,无 IMDb/TMDB;Plex `Rating[]` 未改 | **先确认**服务端返回里是否带 IMDb/TMDB 分值(查真实响应/字段,**待核对**);不带 → 不做,在映射处加注释写明"服务端不提供",不去外部抓分;带 → 补映射与单测 | 结论(做/不做+依据)写入提交说明 |
| R5-8 | 低 | 22 个 `lib/i18n/*.i18n.json` 各加 12 个新 key(设置 9:`ratings, showRatingBadges, showRatingBadgesDescription, ratingSources, ratingSourcesDescription, otherRatingSources, moveRatingUp, moveRatingDown, ratingSettingsSaveFailed`;`detailPlayback` 3:`version, unavailable, loadFailed`),只有 en/zh/zh-Hant 有译文,其余 19 个为英文占位 | 为 19 个语言补译文(可分批,一次一个语言文件集合);改 json 后用项目既有 slang 生成命令重新生成,不手改 `.g.dart` | strict translations 检查通过;抽查 3 个语言在界面中显示 |
| R5-9 | 低 | `media_card.dart:662` 每次构建 overlay 都计算 `mediaCardRatingFor(item)`,即使角标关闭;`:483` 与 `:664` 条件重复 | 角标关闭时跳过计算;合并重复条件为一个局部变量 | 行为不变,相关 widget 测试通过 |
| R5-10 | 低 | 缺卡片角标与个人评分的测试(`test/widgets/media_ratings_strip_test.dart:60` 只覆盖条的数量) | 补卡片角标(开关、继续观看无角标、个人评分)用例 | 新测试通过 |

### R6 运行时性能

| 编号 | 优先级 | 现状 | 改成什么 | 验收 |
|---|---|---|---|---|
| R6-1 | 高 | `lib/widgets/video_controls/widgets/player_hud_surface.dart:16-17` 无条件 `BackdropFilter` sigma 10(对方新增的共享 HUD,叠在视频上做实时模糊) | 接入 `AppGlassSurface.reduceEffects`(参考 `fusion_navigation.dart:59,99`),降级时用不透明底色 | widget 测试:reduceEffects 为真时树内无 BackdropFilter;TV/低端机目视 |
| R6-2 | 中 | `lib/providers/download_provider.dart`(`_DownloadMutationMap` / `_invalidateDownloadsSnapshot`,行号待核对)每个进度事件都使 downloads 快照失效,下次 getter 全量重建 O(n)(每 300ms) | 纯进度数值更新时原地更新快照、不失效;结构变化(增删/状态变)才失效 | 单测:进度更新不使快照对象重建,结构变化会;已有 144 个性能相关用例不回退 |
| R6-3 | 中 | 仍整体随 300ms 脉冲重建的 `Consumer<DownloadProvider>`:`action_buttons.dart:803`(目录待核对)、`album_detail_screen.dart:209`、`sync_rules_screen.dart:39`、`smart_deletion_handler.dart:49` | 各改 `Selector`,只取该处需要的字段(单个下载项状态/进度) | 下载进行中,这些页面的 build 次数明显下降(用 rebuild 计数 widget 测试) |
| R6-4 | 低 | `discover_provider.dart` `_homeProgressively` 的 onProgress 每台服务器完成就 `safeNotifyListeners`(onDeck、hubs 各一次),N 台 = 2N 次重建;`data_aggregation_service.dart` 每次都 `mergeContinueWatching` 全量重算 | 用帧合并(同一帧内多次回调只通知一次);merge 改增量或节流 | 多服务器下首页重建次数 ≤ 帧数;结果与原来一致 |
| R6-5 | 中 | `side_navigation_rail.dart:884-885` 仍 `context.watch<LibrariesProvider>/<HiddenLibrariesProvider>`,整栏 build 内遍历库列表(其余 provider 已改 select) | 改 Selector,或把库分组下沉为子 widget | 库列表不变时侧栏不重建 |
| R6-6 | 中 | build 里新建 future 的 FutureBuilder:`settings_screen.dart:711,1040`(`getCurrentDownloadPathDisplay`)、`external_player_screen.dart:55`(`KnownPlayers.getForCurrentPlatform`)、`about_screen.dart:20`(同类,行号待核对) | future 缓存到 `initState`/字段 | 重建时不再重复发起 |
| R6-7 | 低 | 直播节目单 `guide_tab.dart` 的 `Column`(近似 `:1246`、`:1680`)是否懒构建**待核对**,频道/节目多时可能整体构建 | 核对;若长列表整体构建,改 `ListView.builder`/Sliver | 构造 500+ 节目的测试不卡顿 |
| R6-8 | 低 | Plex 详情页:`media_detail_screen.dart` 近似 `:1470`、`:1537` 的 `_loadExtras`/`_loadRelatedHubs` 仍 unawaited 并发;"用列表元数据先渲染"未做,方案要求必须用实测证明收益 | 无实测数据前**不动**;有数据再评估 | — |

### R7 冷启动二期

| 编号 | 优先级 | 现状 | 改成什么 | 验收 |
|---|---|---|---|---|
| R7-1 | 中 | `lib/main.dart:2137-2182` 串行 await:`bootstrap.run` → prune → `reloadFromStorage` → `ConnectivityProbe.check`(最长 3s)→ `connectionRegistry.list` | `ConnectivityProbe.check` 与迁移/prune 无依赖,先发起(unawaited/Future)再 await;`list()` 可并行。保持授权 gate 语义 | 启动单测/时间线日志:总耗时下降,顺序依赖的行为不变 |
| R7-2 | 中 | `main.dart:975` storage 与 `:979` database 串行,`:991` imageCache 后串行;`:943` locale、`:954` windowManager、`:963` deviceCapabilities 各自串行 | 互不依赖的用 `Future.wait`;`applyImageCacheBudget` 后移到首帧后 | 同上 |
| R7-3 | 高 | 首页快照读取依赖在线 client(`home_snapshot_store.dart:84`,`discover_provider.dart` `_restoreHomeSnapshot` 依赖 `_homeClients`/`onlineServerIds`),所以"先显示缓存"发生在服务器连上之后;全离线/弱网冷启动拿不到缓存 | 按 profile 持久化上次的 scope 列表,读快照不再依赖在线 client;读出后标注"缓存,可能过期"状态不阻塞后续刷新。key 仍含 profileId/scope/隐藏库/useGlobalHubs,authenticationSessionId、Plex profile scope 校验保持 | 单测:无任何在线 client 时仍能展示快照;换 profile/登出不串数据 |
| R7-4 | 中 | `main.dart:2312-2328` 已改为导航后 postFrame 触发并 catchError;但 `download_provider.dart:2330-2370` 仍对每个下载项串行 `fetchOnMiss:true` 发网络请求,与首页首批请求争带宽 | `refreshMetadataFromCache` 改只读缓存(`fetchOnMiss:false`),缺失项推迟到空闲/用户进入下载页再补 | 首页显示后启动阶段无下载元数据网络请求;下载页元数据仍能补齐 |
| R7-5 | 低 | `home_snapshot_store.dart:93-95` 每台服务器 try/catch 跳过损坏行,但不删除,每次启动重复解析失败直到被新写覆盖 | 解析失败时删除该 key | 单测:损坏行读一次后被删除 |
| R7-6 | 低 | 2s 预算为注入参数(`main.dart:1260-1310` `awaitStartupContentReady`,`home_startup_gate.dart:34-98`),`TODO(VELO-P4-01)`;24h 快照 `home_snapshot_store.dart:62` `TODO VELO-P4-02`,均非设置项 | 保留 TODO,不做成设置项;真机数据出来后再调 | — |
| R7-7 | 低 | `AppDatabase.open` 迁移仍在首帧前串行 | 评估放后台 isolate/executor,**无测量数据前不动** | 评估结论写入提交说明 |
| R7-8 | 高(验收) | `lib/services/home_startup_timing.dart`、`main.dart:147 start()`、`markContentVisible(fromSnapshot)` 已有计时;无 5 次数据。模拟器 `am start` 2676ms **不算**冷启动证据 | 测量方法:同一台真机、同一账号与网络;每个版本(改造前 `fe12755`、改造后)各装一次;每次测前强制停止进程(`adb shell am force-stop`)后启动,不清数据;各冷启动 5 次,记录 `markContentVisible` 时间与是否来自快照,取中位数;另测一组"飞行模式/弱网"冷启动 | 表格:版本×5 次原始值×中位数;中位数不劣于改造前 |

### R8 其他显示问题

| 编号 | 优先级 | 现状 | 改成什么 | 验收 |
|---|---|---|---|---|
| R8-1 | 中 | Row/Column 内长文字无约束:`add_jellyfin_screen.dart:~931`(版本 Text 无 maxLines)、`widgets/server_activities_button.dart:~324`(serverName 无 Flexible)、`widgets/hub_section.dart:~568`(serverName 无 Flexible/省略)、`profile/borrow_connection_screen.dart:~415,428`(Row 内 Text 无 Flexible)。`discover_screen.dart:~1085` 仅数字徽标,基本无风险,不改 | 统一 `Flexible`/`Expanded` + `maxLines` + `TextOverflow.ellipsis` | 构造超长 serverName/版本串的 widget 测试无 overflow 异常 |
| R8-2 | 中 | 固定宽度标签:`catalog_item_detail_screen.dart:910` `SizedBox(width:140)`;`media_detail_screen.dart:4581` `SizedBox(width:120)` | 改 `ConstrainedBox(minWidth)` 或 `IntrinsicWidth`,长语言/大字号不截断 | 德/俄语+大字号目视 |
| R8-3 | 中 | `lib/utils/dialogs.dart:623`、`watch_together/widgets/local_media_match_dialog.dart:128` 仍是 `SimpleDialog` | 换成项目 `AppDialog`(磨砂弹窗),保持 TV 焦点 | 两处对话框样式一致,方向键可操作 |
| R8-4 | 中 | 硬编码颜色基本未收敛:`lib/` 非 theme 目录 `Color(0x` 67 处 + `Colors.xxx` 441 处(含 `Colors.transparent` 97,不含为 344),合计 508,去 transparent 后 411,与第一轮的约 413 基本持平。优先文件:`media_detail/action_buttons.dart` 15、`auth_screen.dart` 13、`media_detail/presentation.dart` 8、`settings/logs_screen.dart` 8;另 `fusion_home_hero.dart:75-84` 阴影/文字 `Colors.black/white`(叠在海报上是否需随主题**待确认 C5**) | 按上面 4 个文件逐个替换为 `lib/theme` 的 token(缺的 token 先加到 theme);压在图片上的白字/黑渐变允许保留但要集中为命名常量。不做全仓一次性替换 | 提交说明写出前后数量(同一统计命令);4 个文件在亮色下无写死深色块 |
| R8-5 | 低 | 断点散落;`layout_constants.dart` 仅 mobile 600/wideTablet 900/desktop 1200。散落点:`catalog_item_detail_screen.dart:954,956`(1100/700)、`plex_pin_auth_flow.dart:228`(700)、`auth_screen.dart:281`(700)、`:352`(1180)、`media_detail/presentation.dart:197` 与 `responsive_layout.dart:58`(720)、`discover_loading_skeleton.dart:45,74`、`discover_screen.dart:1272`(600)、`overlay_sheet.dart:167`、`pending_auth_dialog.dart:90`、`rating_bottom_sheet.dart:620`(390)、`playback_selectors.dart`(680) | 在 `layout_constants.dart` 补命名常量(是否新增 700/720/1100 档,或归并到现有三档,**待确认 C12**),逐处替换;不改变现有布局阈值的效果(归并要截图对比) | grep 魔数断点减少;受影响页面截图无差异或差异已说明 |
| R8-6 | 低 | zh 的 `auth.quickConnect='Quick Connect'`;zh 的 `discover.playEpisode='S${season}E${episode}'` 与 en 相同,为有意保留 | `quickConnect` 改"快速连接"(**待确认 C9**,可选);`playEpisode` 不改 | zh 界面显示中文 |

### R9 交互反馈收尾

| 编号 | 优先级 | 现状 | 改成什么 | 验收 |
|---|---|---|---|---|
| R9-1 | 中 | 已接入:`fusion_navigation.dart:119,192`、`mobile_navigation_rail.dart:164`、`side_navigation_rail.dart:369,1490`、`media_card.dart:1789`、`media_detail/action_buttons.dart:275`(主)、`action_press.dart:28`(次)、`app_select_field.dart:156`。**未接入**:评分面板星星(无 120% 放大/逐星触感/"已保存"反馈)、菜单选项行(`anchored_option_menus.dart`/`app_menu`:应有 10% 填充+对勾淡入)、`focus/focusable_button.dart`(无按压)、TV 确认键 97%(仅少数处经 `Builder.confirm`)、筛选 chip、hub "查看全部"、`episode_card`、人物/演员卡、设置项 | 按"点击频率高、TV 可见"顺序接入 `PressFeedback`:先 FocusableButton、菜单选项行、评分星,再 episode_card/人物卡/设置项/chip/see all;每个控件一个小提交或一组同类一个提交 | 每类控件:按下缩放/变色、减弱动画下只变色、TV 确认键有反馈 |
| R9-2 | 低 | `press_feedback.dart:43` 遮罩统一为 `onSurface` 8%;方案:卡片 22% 暗层(亮色更深/暗色更淡),主按钮变深 | 给 PressFeedback 加按控件类型的遮罩参数 | 卡片/主按钮/次按钮三种按下色目视 |
| R9-3 | 低 | `media_card.dart:508/529` 长按无触感 | 长按触发一次触感,走 `selection_feedback.dart:12` 封装 | 长按一次触感一次(真机) |
| R9-4 | 低 | `media_detail/action_buttons.dart:251` 主按钮加载中只有转圈,无"正在打开"文案(**待核对**是否已有 key) | 加载态显示转圈+"正在打开"(slang 新 key,en/zh/zh-Hant 译文,其余按 R5-8 方式占位) | 点播放后按钮显示文案且不可重复点击 |
| R9-5 | 低 | `app_select_field.dart:160-165` 边框 2px 强调色已有;箭头通过切换 `expand_less/expand_more`(`:209`)实现,无旋转动画;菜单项选中延迟 120ms(`:84-86`) | 改 `AnimatedRotation` 180°(时长待 R11 token,先用 180ms);减弱动画下不旋转直接切换 | 打开/关闭箭头旋转;减弱动画下无动画 |
| R9-6 | 中 | 无 `test/widgets/press_feedback_test.dart`,仅间接覆盖(`f4_home_feedback_test`、`app_select_field_test`、`media_card_full_card_test`) | 新增:按下缩放值、回弹、减弱动画只变色、禁用不响应 | 新测试通过 |
| R9-7 | 低 | `screens/companion_remote/mobile_remote_screen.dart:153,518,555,635,660,732` 直接调 `HapticFeedback`(第一轮前已存在) | 改走 `selection_feedback.dart` 封装 | grep 该文件无直接 `HapticFeedback` |

### R10 视觉 token 与详情页结构

| 编号 | 优先级 | 现状 | 改成什么 | 验收 |
|---|---|---|---|---|
| R10-1 | 中 | `lib/theme` 下无圆角/字阶 token;圆角写死(如 `press_feedback.dart:20` 14、`discover_screen` 24) | 新增圆角 token(12/14/18/24/100)与字阶 token;先落地 token,再随各包顺手替换,不做全仓一次性替换 | token 有单测/golden;新代码只用 token |
| R10-2 | 低 | 分组面 #14151C 仅硬编码在 `settings_presentation.dart:84`;OLED 面 `0A0A0A` 已对(`mono_theme.dart:58`) | 提为共享 token,设置页与卡片类分组面共用 | 设置页外观不变 |
| R10-3 | 中 | 详情页新结构(标题 40/64 w600、外文原名 Georgia、描边评分/4K 框、3px 进度条、52 高主按钮)**未做/未验证**;`media_detail/` 下无 Georgia;元数据为纯文本(`presentation.dart:217`) | 按第一轮方案详情页小节实现(动手前 `grep` 方案对应小节后 `sed -n` 只读该段)。Georgia 是否随包/是否有许可**待确认 C7**,未确认前用系统衬线字体回退,不加字体文件 | 手机/平板/桌面/TV 详情页目视;三主题 |
| R10-4 | 中 | 亮色下写死深色:`fusion_home_hero.dart:248-294`(R1-3 删除后自然消失)、`hero_metadata_badges.dart:57-58`(R2-2 删除)、hero 默认前景 `Colors.white`(`:12`);亮色下头图渐隐与文字色决策未定(`home_typography` 的 `artworkTextColors` 未改) | R1/R2 完成后再复查剩余项;头图文字色**待确认 C5** | 亮色主题首页头图文字可读 |
| R10-5 | — | 已核对一致,不需动:主题色(`mono_theme.dart:65-77`、`velo_brand.dart:11-14`、`mono_presentation.dart:82`);outline 为黑色 10% 而非文字色 8–10%,差异很小可忽略 | 不改 | — |

### R11 动效(第一轮基本未做)

约束:播放器帧时序相关时长(seek 防抖、控制层自动隐藏、mpv/ExoPlayer 渲染与同步相关)**不替换**为动效 token;播放器控制层/抽屉时长未核对、未动。

| 编号 | 优先级 | 现状 | 改成什么 | 验收 |
|---|---|---|---|---|
| R11-1 | 中 | `mono_theme.dart:275-278` 仍是 fast120/normal200/slow300/expressive350;`mono_tokens.dart` 无新字段 | 增加五档 120/180/280/420/600;旧字段先保留,逐步迁移后再删 | token 单测;旧调用不报错 |
| R11-2 | 中 | `mono_motion.dart:15-18` 只有 emphasized、standard;无 easeIn 退出曲线;退出 0.75× 缺 | 补三条曲线(进入/标准/退出),退出时长为进入的 0.75× | 单测:退出时长=进入×0.75 |
| R11-3 | 中 | `layout_constants.dart:30` `AppDurations` 未动;`lib` 内 256 处裸 `Duration(milliseconds:)`;`navigation_transitions.dart:9-17` 用 `AppDurations.animSlow`(500) | `AppDurations` 并入 MonoTokens 五档(留别名过渡);裸 Duration 只替换 UI 动效类,播放器帧时序类保留 | 提交说明列出"替换/保留"数量与保留理由 |
| R11-4 | 中 | 海报→详情无共享元素(无 Hero);`navigation_transitions.dart:9-17` 为 `fadeRoute` | 海报做 Hero 转场(tag 含 serverId+itemId,避免重复 tag);TV 与减弱动画降级为淡入 | 手机/桌面转场连贯;TV/减弱动画无 Hero |
| R11-5 | 低 | 详情页编排入场未做 | 标题、元数据、评分、按钮按 R11-1 档位错峰淡入 | 减弱动画下直接显示 |
| R11-6 | 低 | 导航滑块 280ms 未做 | 导航选中指示滑块用 280ms | 目视 |
| R11-7 | 低 | 已看对勾描边动画未做 | 标记已看时对勾描边绘制 | 目视;减弱动画下直接显示 |
| R11-8 | 低 | `vidhub_ambient_backdrop.dart`、`ambient_skeleton.dart` 已有;无 600ms 交叉淡入/50% 规格;长渐隐 260px、骨架 1.4s 未核对 | 海报切换时环境色 600ms 交叉淡入;核对 260px/1.4s | 切换详情页无色闪 |
| R11-9 | 低 | 下拉菜单仅 `selectionDelay` 120ms(`app_select_field.dart:84-86`);无缩放 96%/位移 6px/对勾淡入(箭头旋转见 R9-5) | 菜单展开缩放 96%+位移 6px,选中对勾淡入 | 目视;减弱动画下无动画 |
| R11-10 | 中 | 减弱动画判断分散:`disableAnimationsOf` 14 处(含 `press_feedback`、首页头图页码点);另一条走 `DevicePerformance.reducedDuration`(`mono_motion`/transitions);无统一规则 | 抽一个统一判定(系统减弱动画 或 低端设备),所有新旧动效走它;TV 焦点 104% 为原有逻辑,不动 | 单测:判定为真时时长为 0/退化为淡入 |

---

## 3. 验证欠账

- 对方 `flutter analyze --no-pub` 两次 exit255(LSP JSON/channel 解析被截断),用 full machine 输出替代得到零诊断;**不能算 `flutter analyze` 通过**。
- 未运行全仓 `scripts/ci_checks.sh`、未运行全量测试;只跑过分批用例(首批 21 文件 293/293、P1 Dart 186+native 51、P5 144、P6 Plex 96/UI 35 等,日志在对方工作区外 `/tmp`,仓库内无法复核)。
- 所有真机/TV 项均未验:30 分钟常亮、TV 长播、PiP/息屏、真实切轨、5 次冷启动、FPS/内存、真实评分保存、真实远程服务端、TV 遥控、手机触感、Apple 工具链(完整 Xcode 未装,macOS/iOS/tvOS 未构建)。
- 对方截图为本地 Flutter fixture,不等同真机验收。
- **第二轮每包提交前必须**:`flutter analyze`(须真正 exit 0,不接受替代分析)与 `scripts/run_tests.sh`;改了 i18n json 须按项目命令重新生成并通过 strict translations 检查。本环境无 flutter 时,不得声称已通过,提交说明写明"未运行"。

---

## 4. 材料不一致

| # | 不一致 | 本文处理 |
|---|---|---|
| M1 | 对方简报称"八包",P9 动效未单列;指示与第一轮方案为 P1–P9 | 按 P1–P9;P9 以 audit B 为准,判"基本未做" |
| M2 | 简报称 P7 首页"通过、24 张图";audit B 查代码显示首页头图按钮、版本信息均未去 | 以代码为准,列 R1 |
| M3 | 简报称 P5 含"blur 降级、侧栏 select 通过";audit C 显示播放器 HUD 模糊未降级、侧栏仍 watch 两个 provider(仅导航栏/ambient 已降级) | 判 P5 部分,列 R6-1、R6-5 |
| M4 | 简报称 P8 完成;audit B 列出大量未接入控件、遮罩/触感/文案缺口 | 判 P8 部分,列 R9 |
| M5 | 简报称 P5 "Plex 附加请求"已做;audit C 判"做法不同/未确认",且无实测收益 | 列 R6-8,无实测不动 |
| M6 | 简报称评分"四外部+个人"为对方对画稿的解释,audit B 指出上限 4(方案 5)、个人评分在条外 | 列 R5-3/R5-4,待确认 |
| M7 | audit A 称 `track_selection_helper.dart` 嵌入分支为"死路径",又说"若有其他调用方仍丢副标题" | 列 R4-3,先核对调用方 |
| M8 | `hero_metadata_badges.dart` 死分支行号:audit B 两处写 `:54-58` 与 `:57-58` | 文中并列,动手前定位 |
| M9 | `action_buttons.dart:803`(audit C)未写目录,而 audit A/B 的 `action_buttons.dart` 在 `media_detail/` 下 | 目录标"待核对" |
| M10 | 简报同时写"Android arm64 debug 构建通过"与"当前 APK 非 arm64-only(338,009,263 bytes)" | 与本方案无直接关系,仅提示:构建产物不入库 |
| M11 | audit A 把硬编码色统计为 508(含 transparent),又称"去 transparent 411"与第一轮约 413 持平 | R8-4 两个口径都列 |
| M12 | 指示称 R2 含"评分 /10 与星数不一致",仅 audit B N8 提到,且标"可能" | 列 R2-3,先复现 |

---

## 5. 待确认项汇总

| 编号 | 问题 | 当前采用的默认值 |
|---|---|---|
| C1 | 首页头图点击行为 | 三种形态统一进详情页(手机现状;桌面/TV 由直接播放改为进详情) |
| C2 | 详情评分条上限 4 还是 5 | 先保持 4,做成常量/配置项,`TODO(VELO-P3-01)` |
| C3 | "我的评分"并入评分条还是独立 chip | 保持独立 chip |
| C4 | 个人评分 /10 与星数的统一显示 | 卡片"x/10",详情同时显示星数与"x/10" |
| C5 | 头图文字/阴影在亮色下的颜色策略(白字压图 vs 随主题) | 保持现状白字压图,不动,待产品定 |
| C6 | 常亮退避 1/2/5s、重申 5s;启动 2s 预算;快照 24h;通知节流 300ms | 保持现值,真机数据后调(`VELO-P1-01`、`VELO-P4-01`、`VELO-P4-02`、`VELO-P8-01`) |
| C7 | 详情页外文原名 Georgia 字体能否随包/许可 | 用系统衬线回退,不加字体文件 |
| C8 | 下拉选中后延迟 120ms 关闭(方案为立即关闭) | 保持 120ms(对方自定) |
| C9 | zh 的 `quickConnect` 是否译"快速连接" | 译(可选,低优先) |
| C10 | Jellyfin/Emby 服务端是否提供 IMDb/TMDB 分值 | 先查;不提供则不做 |
| C11 | 选择器改下拉阈值 | 项 >4 或文案可变长改下拉;2–3 个短固定项保留 |
| C12 | 断点是新增常量还是归并到现有 600/900/1200 | 先新增命名常量保持现有阈值,不改布局效果 |
| C13 | mpv 原生侧是否需要 keep-on 兜底 | 无真机数据前不加 |

---

## 6. 建议执行顺序与规模

一个提交只做一件事;每个提交前跑 analyze 与 `scripts/run_tests.sh`。

| 顺序 | 包 | 规模 | 备注 |
|---|---|---|---|
| 1 | R1 首页头图 | 中 | 用户明确要求;R1-3 同时消除 R10-4 的一部分 |
| 2 | R2 缺陷 | 小 | R2-1、R2-2 各一个提交 |
| 3 | R3 常亮 | 小(代码)+真机验收 | R3-1 一个提交;R3-3 需真机 |
| 4 | R4 选择器 | 中 | R4-1/R4-2 优先 |
| 5 | R5 评分 | 中 | R5-7 先查服务端再决定;R5-8 翻译可分语言分批 |
| 6 | R8 显示问题 | 中 | 硬编码色按文件拆提交 |
| 7 | R9 交互反馈 | 中 | 先 R9-6 测试再接入控件 |
| 8 | R6 运行时性能 | 中 | R6-1、R6-2 优先 |
| 9 | R7 冷启动二期 | 大 | 先做 R7-8 基线测量再改 |
| 10 | R10 token 与详情页 | 中到大 | 先 token,再详情页 |
| 11 | R11 动效 | 大 | 依赖 R10 token 与 R9-5 |

---

## 7. 通用约束

- 保留 Plex/Jellyfin/Emby 三类服务与"一起看"、手机与 TV 形态。
- 保留 mpv 与 ExoPlayer 两套播放内核,不改其选择逻辑。
- 所有用户可见文案走 slang(改 `lib/i18n/*.i18n.json` 后用项目命令重新生成);不硬编码中文/英文。
- TV 上的可交互控件用 focusable 包装(`FocusableWrapper`/`FocusableButton`),保证方向键与确认键可用、初始焦点不丢。
- 不直接修改生成的 Dart 文件(如 `.g.dart`)。
- 不提交凭据、构建产物、日志、本地参考文件;Velo 派生自 Plezy(GPL-3.0),保留上游署名。
- 业务数值未定时:用配置项或常量加默认值,并加 `TODO(编号)`(沿用 `VELO-Pn-xx` 体系)。
- 亮色、暗色、纯黑三种主题逐一验收。
- 一个提交只做一件事;只改本包范围内的文件。
