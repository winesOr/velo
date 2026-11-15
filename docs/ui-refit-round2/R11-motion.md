# R11 动效 任务卡

- 基线提交:`8885b39`(静态读码,未运行;本环境无 flutter,所有行号、数量来自 grep/读码,动效观感与帧率均未实测)
- 目标:建立一套统一的动效时长/曲线/减弱规则,把界面动效写死的时长收敛到 token,并按第一轮 P9 规格补齐 海报→详情、详情入场、导航滑块、已看对勾、环境色、下拉菜单 六类转场。
- 优先级:R11-1/2/3(token 与判定)中;R11-4(替换)中;R11-5(详情路由)中;R11-6 Hero、R11-7 入场、R11-8~R11-11 低。
- 规模:大。**必须拆成可独立提交、可独立回滚的子任务,顺序固定:先 token → 再替换写死时长(分目录分批)→ 再各转场。**
- 前置依赖:R10 的 token 工作(清单:先 token 再详情页)与 R9-5(下拉箭头旋转)。R11-11(下拉菜单)依赖 R9-5 先落地;R11-6/7 依赖 R11-1~R11-3。
- 不在范围:播放器控制层显示/隐藏、抽屉滑入(P9 第 5 条;未核对、未动,保持现状,见"禁止替换清单");TV 焦点 104% 缩放与 150ms 描边(原有逻辑 `lib/focus/focus_theme.dart`、`focusable_wrapper.dart:256`,不动);任何 mpv/ExoPlayer 帧时序;弹簧/过冲动画(规格明确不用)。

## 与清单/材料不一致及新发现(已核实)

1. **海报→详情的路由不是 `fadeRoute`**。清单 R11-4 引用 `navigation_transitions.dart:9-17`,但海报点击实际经 `navigateToMediaItem` → `navigateToMediaItemDetails`(`lib/utils/media_navigation_helper.dart:158、267-300`)→ `mediaDetailRoute`(`lib/screens/media_detail_screen.dart:294-328`):非 TV 用 `MaterialPageRoute`(`:308`,走平台默认转场,工程内**没有**自定义 `pageTransitionsTheme`,grep 无结果),TV 用 `PageRouteBuilder` 淡入 `AppDurations.animMedium`(300ms,`:325-326`)。`fadeRoute`(`navigation_transitions.dart:7-18`,500ms)只用于 启动页→主界面、登录页、同步接收页(`main.dart` 7 处、`auth_screen.dart` 6 处、`sync_receive_screen.dart:132`)。因此 R11-5/R11-6 的改动点是 `mediaDetailRoute`,`fadeRoute` 的 500ms 单独处理(R11-5b)。
2. **"256 处裸 `Duration(milliseconds:)`"口径偏大**:该数是 `lib/` 下所有该字面量出现次数(grep 复核为 256 行)。其中大量是 时间值换算(`Duration(milliseconds: viewOffsetMs)`)、超时/防抖/轮询/重试、播放器与同步逻辑,**不是界面动效**。按文件人工分类,播放器/同步/媒体/焦点/服务等目录之外的 133 行里,真正的界面动画时长约 55 处(±5,分类见"替换批次");播放器目录内也有少量界面动画(`video_controls.dart:1313-1594` 的 6 处 150~200ms 淡入等),本包不动。第一轮 P9 所说"200ms 约 35 处、150ms 约 22 处"与当前计数一致(36、21),但同样含非动画项。
3. **统计(`grep -rn 'Duration(milliseconds:' lib`)**:总计 256 行。字面量取值分布(前 10):200×36、150×21、300×13、500×11、100×8、250×7、120×7、400×6、350×5、50×4、180×4、1500×4。按目录:`widgets/video_controls` 47、`widgets`(根) 23、`watch_together/services` 21、`services` 20、`mpv/player` 17、`screens`(根) 16、`utils` 15、`screens/video_player` 13、`theme` 10、`screens/libraries` 10、`media` 9、`services/music` 7、`focus` 7、`widgets/music` 6、`screens/media_detail` 6、`screens/music` 5,其余 ≤3。
4. **前 20 文件排行(含并列的第 20 名)**:`mpv/player/player_base.dart` 16;`widgets/video_controls/widgets/timeline_slider.dart` 11;`watch_together/services/host_playback_coordinator.dart` 11;`widgets/video_controls/parts/playback_input.dart` 9;`widgets/video_controls/video_controls.dart` 8;`watch_together/services/guest_playback_reconciler.dart` 7;`services/music/music_playback_service_impl.dart` 6;`screens/media_detail_screen.dart` 6;`screens/libraries/tabs/library_browse_tab.dart` 6;`screens/video_player/parts/playback_open.dart` 5;`widgets/optimized_media_image.dart` 4;`utils/scroll_utils.dart` 4;`theme/mono_theme.dart` 4;`screens/music/now_playing_screen.dart` 4;`media/stepped_seek.dart` 4;`media/media_source_info.dart` 4;`widgets/video_controls/widgets/transport_feedback_indicator.dart` 3;`widgets/music/lyrics_view.dart` 3;`utils/media_server_timeouts.dart` 3;`theme/interaction_tokens.dart` 3(此后 3 次的并列文件还有 `services/gamepad_service.dart`、`external_player_service.dart`、`apple_tv_remote_touch_service.dart` 等)。排行前 20 里**只有 `media_detail_screen.dart`、`library_browse_tab.dart`(1 处)、`optimized_media_image.dart`、`scroll_utils.dart`、`mono_theme.dart`、`now_playing_screen.dart`、`lyrics_view.dart`、`interaction_tokens.dart` 含界面动画**,其余全部属于禁止替换范围。
5. **减弱动画判断分散**(`grep disableAnimationsOf` 共 14 处,12 个文件):`navigation/home_theme.dart:92`、`screens/discover_screen.dart`、`widgets/app_glass_surface.dart:30`、`press_feedback.dart`、`app_select_field.dart:84`、`ambient_skeleton.dart`、`fusion_home_hero.dart`、`startup_loading_view.dart`、`video_controls/sheets/player_settings_controls.dart:120`、`mobile_edge_adjustment_indicator.dart:43`、`timeline_slider.dart:378`、`velo_play_pause_icon.dart`;另一条 `DevicePerformance.reducedDuration` 共 10 处调用(`mono_motion.dart`、`navigation_transitions.dart:15-16`、`music_navigation.dart`、`tv_spotlight_background.dart:123、307`、`cycling_media_backdrop.dart`、`side_navigation_rail.dart:474`)。`AppGlassSurface.reduceEffects`(`app_glass_surface.dart:29-30`)= `isReduced || highContrast || disableAnimations`,管"磨砂",不是动效统一入口。
6. **环境色时长已有但与规格不同**:`MonoPresentation.artworkDuration = 560ms`(`mono_presentation.dart:9`,被 `home_theme.dart:92`、`cycling_media_backdrop.dart:38` 使用),规格是 600ms;`vidhub_ambient_backdrop.dart:115` 的色彩补间 380ms;`ambient_skeleton.dart:25` 骨架周期 **1800ms**,规格是"高光 1.4s 扫过一次",差异待产品确认后调整(C-R11-3)。
7. **下拉菜单已有部分规格**:`app_menu.dart:98-130` 已用 `OverlayTokens.motion = 180ms`(`overlay_tokens.dart:13`)、`Curves.easeOutCubic`、缩放 0.96→1 + 淡入,**缺少 6px 位移、强调减速曲线、选中对勾淡入**;箭头目前是换图标 `expand_less/expand_more`(`app_select_field.dart:209`),旋转属 R9-5。`selectionDelay` 为 `InteractionTokens.menuSelectionDuration` 120ms(`app_select_field.dart:84-86`),规格为 140ms 后关闭,见 C-R11-2。
8. **底部导航选中态没有动画**:`fusion_navigation.dart:140-149` 选中底色是普通 `Container(decoration: color: selected ? VeloBrand.selection(...) : transparent)`,切换瞬时完成;各目的地是 `Row` 里的 `Expanded`(`:73-75`)。
9. **已看对勾**:`lib/widgets/watched_indicator.dart:62` `WatchedIndicator` 是 `StatelessWidget`,对勾为 `AppIcon(Symbols.check_rounded)`(`:111`),无状态可检测"刚变为已看"。

## 涉及文件表

| 文件 | 行号 | 现状 | 动作 |
|---|---|---|---|
| lib/theme/mono_tokens.dart | 18-60、62-95、97-122 | `MonoTokens` 字段 `fast/normal/slow/expressive`(Duration);`copyWith`、`lerp` | 改:新增五档字段,旧字段保留 |
| lib/theme/mono_theme.dart | 268-286(时长 `:275-278`) | 唯一生产构造点:120/200/300/350 | 改:传入五档 |
| lib/theme/mono_motion.dart | 全文(`emphasized :15`、`standard :18`、`shape/fill/press :21-27`) | 两条曲线;时长取旧 token 并经 `DevicePerformance.reducedDuration` | 改:加退出曲线、退出 0.75×、五档访问器、统一判定 |
| lib/theme/interaction_tokens.dart | 11-13 | 120/180/120 裸值 | 改:引用 `MotionDurations` |
| lib/theme/overlay_tokens.dart | 13 | `motion = 180ms` | 改:引用 `MotionDurations.quick` |
| lib/theme/mono_presentation.dart | 9 | `artworkDuration = 560ms` | 改(R11-10 环境色) |
| lib/utils/layout_constants.dart | 30-35 | `AppDurations.animMedium 300 / animSlow 500` | 改:别名并入五档 |
| lib/utils/navigation_transitions.dart | 7-18 | `fadeRoute` 500ms 淡入,`opaque:false`,低性能档归零 | 改:时长 280ms |
| lib/screens/media_detail_screen.dart | 294-328 | `mediaDetailRoute`:非 TV `MaterialPageRoute`,TV 淡入 300ms | 改(R11-5、R11-6) |
| lib/utils/media_navigation_helper.dart | 158-300 | `navigateToMediaItem`/`navigateToMediaItemDetails` 不传 hero 信息 | 改:透传 `heroTag` |
| lib/widgets/media_card.dart | 209-300、1149、1196、418-440 | 海报由 `OptimizedMediaImage` 渲染;点击 `_handleTap` → `navigateToMediaItem` | 改:新增 `heroScope`,包 Hero |
| lib/widgets/optimized_media_image.dart | 94、136、168、481 | `fadeInDuration` 默认 300ms | 改(批次 W) |
| lib/screens/media_detail_screen.dart | 3231-3262、3267-3300、4337-4440 | 详情 build 入口 `HomeThemeScope`;首屏 `_buildDetailPage`;紧凑布局的竖版海报在 `_buildHeroBackdropLayer`(`:4356-4361` 取 `thumbPath`,`CyclingMediaBackdrop :4410-`) | 改:Hero 目标、入场 |
| lib/screens/media_detail/presentation.dart | 154、195-228 | `_buildCompactDetailHeader`:标题 `:210`、元数据 `:212-218`、评分条 `:219`、个人评分 chip `:221-222`、按钮 `:224` | 改:入场包装 |
| lib/screens/media_detail/responsive_layout.dart | 49、56-80、172 | 宽屏 `_buildHeroHeader`;选择器 `:172` | 改:入场包装 |
| lib/widgets/media_ratings_strip.dart | 44-56 | `Wrap` 评分项 | 改:逐项延迟参数 |
| lib/navigation/fusion_navigation.dart | 59-101、105-165 | 底部导航;选中底色 `Container :140-149` | 改:滑块 |
| lib/widgets/watched_indicator.dart | 62-115 | 对勾为静态图标 | 改:描边动画 |
| lib/navigation/home_theme.dart | 80-100 | `HomeThemeScope` 用 `TweenAnimationBuilder<Color?>` 560ms | 改:600ms(R11-10) |
| lib/widgets/cycling_media_backdrop.dart | 38 | `fadeDuration = artworkDuration` | 随 R11-10 |
| lib/widgets/vidhub_ambient_backdrop.dart | 92、115 | 380ms 色彩补间;`reduced` 已判 | 评估对齐 |
| lib/widgets/ambient_skeleton.dart | 25 | 骨架 1800ms | 待确认后调(C-R11-3) |
| lib/widgets/app_menu.dart | 98-130、151 | 下拉动画 180ms/缩放/淡入 | 改(R11-11) |
| lib/widgets/app_select_field.dart | 84-86、209 | `selectionDelay`;箭头换图标 | 改(R11-11,依赖 R9-5) |
| test/test_helpers/theme.dart | 8-40 | `testMonoTokens`、`testMonoTokensAnimated` 两处 const 构造 | 新字段给默认值则不必改 |
| test/theme/mono_theme_test.dart | 43-90 | 调色板/实例用例 | 保持通过 |

## 禁止替换清单(播放器帧时序/进度/手势及非动画时长)

以下目录/文件里的 `Duration(milliseconds: …)` **一律不替换为动效 token**:

- `lib/mpv/player/`(17 处,含 `player_base.dart` 16):渲染/同步/状态轮询。
- `lib/widgets/video_controls/` 全目录(47 处):含 `timeline_slider.dart`(进度条)、`parts/playback_input.dart`(手势/长按/双击)、`video_controls.dart`(控制层淡入淡出 `:1313-1594`、自动隐藏)、`transport_feedback_indicator.dart`、`content_strip.dart`、`velo_play_pause_icon.dart`(360ms)、`sheets/`。P9 的"控制层 180/280、抽屉 280"**未核对、未动**,本包不碰,另立任务。
- `lib/screens/video_player/`(13 处,如 `parts/playback_open.dart`)。
- `lib/watch_together/services/`(21 处):一起看的同步/对账时序。
- `lib/media/`(9 处):`stepped_seek.dart`(seek 防抖 800ms 等)、`media_source_info.dart`、`media_part_timeline.dart`。
- `lib/services/music/music_playback_service_impl.dart`(6 处)及其他 `lib/services/` 下的计时(`gamepad_service.dart`、`apple_tv_remote_touch_service.dart`、`live_seek_accumulator.dart`、`casting/dlna_sender.dart`、`external_player_service.dart`、`jellyfin_lan_discovery_service.dart`、`remote_subtitle_loader.dart`、`video_filter_manager.dart`、`trackers/*`、`discord_rpc_service.dart`、`offline_watch_sync_service.dart`)。
- `lib/focus/`(7 处):`dpad_select_long_press_controller.dart`(500ms 长按)、`key_repeat_helper.dart`、`focus_theme.dart:52、66`(焦点 150ms/Apple TV 500ms)、`focusable_wrapper.dart:256、400`(焦点 150ms 与跟随滚动 200ms)。TV 焦点体系不动。
- 非动画类:时间值换算(`Duration(milliseconds: <ms 变量>)`,如 `viewOffsetMs`、`durationMs`、`formatters.dart:57`)、网络超时与重试(`utils/media_server_timeouts.dart`、`happy_eyeballs.dart`、`paginated_item_loader.dart`)、防抖/节流(`debounced_media_search.dart`、`library_browse_tab.dart` 的 `Timer`、`alpha_jump_bar.dart:142`、`mpv_config_screen.dart:44`、`rating_bottom_sheet.dart:47` 自动保存 600ms、`discover_screen.dart:104`、`playback_tracks_status.dart:59`、`download_provider.dart:80`)。
- `lib/utils/scroll_utils.dart`(4 处)与 `focusable_detail_screen_mixin.dart:55` 等"焦点跟随滚动":属 TV 方向键手感,先保留,见 C-R11-4。

## 逐步修改说明

### R11-1 新增五档时长 token(中)—— 清单 R11-1

- 现状:`MonoTokens` 只有 `fast120/normal200/slow300/expressive350`(`mono_theme.dart:275-278`);`mono_tokens.dart` 无新字段。
- 改成:新增常量源 + token 字段。
  - 在 `mono_motion.dart` 新增 `abstract final class MotionDurations`:`press = 120ms`、`quick = 180ms`、`standard = 280ms`、`emphasized = 420ms`、`ambient = 600ms`(const,供无 context 的默认参数/别名使用),`TODO(VELO-R11-01)` 实机调。
  - `MonoTokens` 增加字段 `motionPress/motionQuick/motionStandard/motionEmphasized/motionAmbient`(`Duration`),构造函数里为**可选参数并带默认值**(引用 `MotionDurations`),这样 `test/test_helpers/theme.dart` 两处 const 构造与其它测试不必改;同步改 `copyWith`、`lerp`(沿用 `lerpD`)。`mono_theme.dart:268` 显式传入。
  - 旧字段 `fast/normal/slow/expressive` **保留且数值不变**(此提交不改变任何现有行为),`@Deprecated` 注释说明迁移目标:`fast→motionPress`、`normal→motionQuick`、`slow→motionStandard`、`expressive→motionEmphasized`;真正替换与删除放在 R11-4 之后。
  - `InteractionTokens.pressDuration/releaseDuration/menuSelectionDuration`、`OverlayTokens.motion` 改为引用 `MotionDurations`(数值同为 120/180/120/180,行为不变)。
  - `AppDurations`(`layout_constants.dart:30-35`)新增 `static const animStandard = MotionDurations.standard` 等别名;`animMedium(300)`/`animSlow(500)` 暂留并加 `@Deprecated`(改动在 R11-5)。
- 验收:旧调用不报错;`MonoTokens` 序列化/`lerp` 单测。

### R11-2 曲线与退出时长(中)—— 清单 R11-2

- 现状:`MonoMotion` 只有 `emphasized = Easing.emphasizedDecelerate`(`mono_motion.dart:15`)与 `standard = Curves.easeOutCubic`(`:18`);无退出曲线;退出时长 0.75× 缺。
- 改成:新增 `static const Curve exit = Curves.easeInCubic;`;新增 `static const double exitFactor = 0.75;` 与 `static Duration exitOf(Duration enter) => Duration(milliseconds: (enter.inMilliseconds * exitFactor).round());`。三条曲线用途写入注释:强调减速(位移/展开/形状)、标准 easeOutCubic(缩放回弹/颜色/透明度)、退出 easeInCubic(离开屏幕的元素)。不引入弹簧。
- 现有 `shape/fill/press`(`:21-27`)保持原行为,改为在 R11-3 统一判定落地后再改取新档。

### R11-3 统一"减弱动效"判定(中)—— 清单 R11-10

- 现状:见"不一致"第 5 条,两套并存、无统一规则。
- 改成:在 `mono_motion.dart` 新增
  - `enum MotionLevel { full, reduced, minimal }`
  - `static MotionLevel level(BuildContext context)`:`DevicePerformance.isReduced` → `minimal`(低端设备:时长归零、关环境色辉光与骨架高光);否则 `MediaQuery.disableAnimationsOf(context)` → `reduced`(系统减弱动画:位移与缩放归零,只保留 ≤120ms 的淡入淡出);否则 `full`。
  - `static Duration resolve(BuildContext context, Duration full, {bool fadeOnly = false})`:`minimal` → `Duration.zero`;`reduced` → `fadeOnly ? min(full, MotionDurations.press) : Duration.zero`;`full` → `full`。
  - `static bool allowTransform(BuildContext)`:仅 `full` 为真(位移/缩放/Hero/描边绘制都以它为准)。
- 迁移:新增转场一律走这三个入口;旧的 14 处 `disableAnimationsOf` 与 10 处 `reducedDuration` 在各自所在批次替换时一并改(不单独大改)。`AppGlassSurface.reduceEffects`(含高对比度)保持,只管磨砂。
- TV:`DevicePerformance.isReduced` 对 TV 低内存机型自动为真(`device_performance.dart`),所以 TV 低端机 = `minimal`;高端 TV 为 `full` 但路由层单独规定"TV 不做共享元素"(R11-6)。

### R11-4 写死时长替换(中,按目录分批,每批一个提交)—— 清单 R11-3

通则:只替换"界面动效类"(`AnimatedContainer/AnimatedOpacity/AnimationController/animateTo/transitionDuration/fadeInDuration/Tween` 的时长);进入 `禁止替换清单` 的不动;每批提交说明列出 替换数/保留数/保留理由;一批只含一个目录。

映射规则(旧值 → 档位,按用途判断,不是机械换算):

| 旧值 | 用途 | 新档 |
|---|---|---|
| 100/120 | 按下、底色快变 | `press` 120 |
| 140/150/160/180 | 回弹、菜单、对勾、淡入淡出、颜色 | `quick` 180 |
| 200/250 | 面板/列表内容出现、滚回顶部 | 淡入淡出类 `quick` 180;展开/抽屉类 `standard` 280 |
| 300/350/380 | 导航滑块、抽屉、内容进入、形状变化 | `standard` 280(形状变化 350 的 `expressive` 用法见下) |
| 400/500 | 整页/大块展开 | `emphasized` 420(整页淡入 500 → `standard` 280,见 R11-5b) |
| 560/600 | 环境色、头图交叉淡入 | `ambient` 600 |
| 600(`pin_entry_dialog.dart:40` 抖动) | 错误抖动 | 保留(非规格内语义) |
| 900/1200/1500/1800 | 循环/节奏动画(均衡器、骨架) | 保留 |

批次(估计数量按"人工分类"得出,±数处;动手前以 `grep -n` 重新定位):

| 批 | 目录/文件 | 约数 | 备注 |
|---|---|---|---|
| B1 | `lib/theme/`、`lib/utils/layout_constants.dart`、`utils/navigation_transitions.dart` | 8 | 指向 `MotionDurations`;`AppDurations` 别名;不含 token 定义本身 |
| B2 | `lib/widgets/`(根目录,不含 `music/`、`video_controls/`):`optimized_media_image.dart`(4,淡入 300→`standard`)、`overlay_sheet.dart:393`(250→`standard`)、`focusable_list_tile.dart:103`、`app_bar_back_button.dart:118`、`tv_number_spinner.dart:193`、`seerr_request_sheet.dart:570`、`tv_virtual_keyboard.dart:777`、`horizontal_scroll_with_arrows.dart:127`、`media_details_sheet.dart:60`、`tv_spotlight_background.dart:123/307`、`side_navigation_rail.dart:474` | 约 15 | `tv_*` 文件涉及 TV 手感,改前后目视;`vidhub_ambient_backdrop.dart:115`、`ambient_skeleton.dart:25` 归 R11-10 |
| B3 | `lib/screens/media_detail_screen.dart`(6)、`screens/media_detail/responsive_layout.dart:49`、`screens/catalog_item_detail_screen.dart`(3)、`screens/discover_screen.dart:331、658` | 约 12 | 详情页滚动与淡入;`discover_screen.dart:104` 为刷新间隔,保留 |
| B4 | `lib/screens/`其余:`libraries/alpha_scroll_handle.dart`(2)、`library_browse_tab.dart:1759`、`profile/pin_entry_dialog.dart:526、624`、`auth_screen.dart:482`、`downloads/sync_rules_screen.dart:390`、`settings/logs_screen.dart:342`、`livetv/tabs/guide_tab.dart:1162-1166`、`playlist/playlist_detail_screen.dart:467` | 约 11 | `guide_tab`/`playlist` 的 150/200ms 为 D-pad 焦点跟随滚动,按 C-R11-4 保留 |
| B5 | `lib/widgets/music/`、`lib/screens/music/`:`mini_player.dart:244`、`lyrics_view.dart:173、207`、`now_playing_screen.dart:99`、`queue_sheet.dart:161`、`equalizer_icon.dart:26`(保留) | 约 6 | 已部分使用 `MonoMotion`(`music_navigation.dart`、`now_playing_screen.dart`、`mini_player.dart`);歌词同步滚动不得影响播放时序 |
| B6 | `lib/main.dart:2377`(启动页状态文字切换 200ms) | 1 | |
| — | `utils/scroll_utils.dart`(4)、`focusable_detail_screen_mixin.dart:55` | 5 | 暂保留(C-R11-4) |

每批的验收:该批文件里已替换处的目视一致(时长变化 ≤ 80ms 不应被感知为"变慢");`flutter analyze`、`scripts/run_tests.sh` 通过;提交说明含"替换/保留数量与保留理由"。旧 token 字段(`fast/normal/slow/expressive`)在全部批次完成且 `grep` 无引用后,单独一个提交删除。

### R11-5 路由时长与详情路由(中)—— 清单 R11-3/R11-4 的前半

- R11-5a `mediaDetailRoute`(`media_detail_screen.dart:294-328`):TV 分支的 `transitionDuration/reverseTransitionDuration` 由 `AppDurations.animMedium`(300)改 `MotionDurations.standard`(280),保持淡入,曲线 `easeOutCubic`/反向 `easeInCubic`(已是,`:321`)。非 TV 分支暂保持 `MaterialPageRoute`(Hero 在 R11-6 引入时再评估是否换成自定义 `PageRouteBuilder`)。`MotionLevel.minimal` 时 TV 分支时长为 0(沿用现有 `reducedDuration` 语义)。
- R11-5b `fadeRoute`(`navigation_transitions.dart`):`AppDurations.animSlow`(500)改 `MotionDurations.standard`(280),保持 `opaque: false` 与"低性能档归零";该路由只用于 启动页/登录/同步接收,风险低。
- 保持 `opaque: true`(TV 详情)的原注释理由。

### R11-6 海报→详情共享元素 Hero(低,依赖 R11-1~R11-5)—— 清单 R11-4

- 起止属性(规格):0→420ms(`emphasized` 档,`Easing.emphasizedDecelerate`);海报从卡片位置/尺寸/圆角 12 展开成头图位置/尺寸/圆角 0。
- 范围:仅手机/平板(`PlatformDetector.isMobile(context)` 为真,且非 TV);桌面与 TV **不做** Hero,保持淡入 280ms。`MotionLevel != full` 时不做 Hero(`allowTransform` 为假),直接用淡入。
- 做法:
  1. `MediaCard` 新增可选参数 `String? heroScope`(默认 null = 不包 Hero)。非空时在海报图(`media_card.dart:1149`、`:1196` 的 `OptimizedMediaImage`)外包 `Hero(tag: heroTag, ...)`,`heroTag = 'poster:${serverId}:${itemId}:${heroScope}'`(元组或字符串均可,但必须含 serverId+itemId)。**同一 item 在同一页面出现多次时 `heroScope` 必须不同**(如 货架 id、库 id),否则触发"同一子树多个 Hero 同 tag"断言;调用方(首页货架、库网格、搜索结果、相关推荐)各自传入自己的作用域。首批只接入 首页货架 与 库网格,其余保持 null。
  2. `navigateToMediaItem`/`navigateToMediaItemDetails`(`media_navigation_helper.dart:158、267`)、`mediaDetailRoute`(`media_detail_screen.dart:294`)新增可选 `Object? heroTag`,透传到 `MediaDetailScreen`。
  3. 详情页在紧凑布局的竖版海报分支(`media_detail_screen.dart:4356-4361`,`portrait` 取 `thumbPath`)的 `CyclingMediaBackdrop`(`:4410` 起)外包同 tag 的 `Hero`;宽屏/横版头图(无 portrait)不包。
  4. `flightShuttleBuilder` 两个方向都返回**源卡片的海报子树**(取 `fromHeroContext.widget as Hero` 的 child),外套 `ClipRRect`,圆角随 `animation` 在 12→0 之间插值(返回时反向),避免展开时换图闪一下(规格要求复用列表里已解码的同一张图;详情页的图 `memCache` 尺寸与卡片不同,默认用目标 Hero 的子树会重新解码而闪白)。
  5. 非 TV 的 `MaterialPageRoute` 保留平台转场;Hero 时长由路由 `transitionDuration` 决定:若平台默认转场时长与 420ms 不符,Hero 场景改用 `PageRouteBuilder`(`transitionDuration = MotionDurations.emphasized`,反向 `MonoMotion.exitOf(...)` ≈315ms,但规格要求"返回整体不超过 300ms",取 `min(exit, 300ms)`)。**此处是否换路由类型待实测**:Android 预测性返回手势在 `PageRouteBuilder` 下表现需核对,影响面大,换路由类型作为独立可回滚提交。
- 降级:TV/桌面/`reduced`/`minimal` → 无 Hero,淡入(TV 280ms,`minimal` 为 0)。返回手势可随时打断(Flutter Hero 默认支持,验收项)。
- 风险:Hero 与列表滚动偏移、`ListView.builder` 回收后源 Hero 不存在(滚出屏幕再返回时无飞回,属正常降级);详情页首帧骨架(`MediaDetailLoadingSkeleton`)与 Hero 目标同时存在时目标需在骨架里也存在,否则飞行落空——骨架页 `:3267-3300` 的 `_isLoadingMetadata` 分支也要包同 tag 的海报占位(待核对骨架是否渲染 thumb)。

### R11-7 详情页入场编排(低,依赖 R11-1~R11-3,可与 R11-6 独立)—— 清单 R11-5

- 规格时序(手机,自路由开始计时,单位 ms;每个元素的动画时长取 `standard` 280,曲线 `emphasized`,位移 12px 向上):
  - 0–200:首页内容淡出并缩到 98%(位于被覆盖路由,见下方 R11-7b,可选);
  - 80:底部渐隐遮罩(`MonoPresentation.artworkBlend` 那层,`:4425` 附近)淡入;
  - 160:标题与元数据淡入并上移 12px;
  - 240:评分逐项进入,每项错开 60ms;
  - 480:操作按钮;
  - 540:下拉分组(播放选择器)。
  - 返回时反向,所有延迟归零,整体 ≤ 300ms;
  - 元数据晚到(`_isLoadingMetadata` 骨架先出,内容后到)时**不重播入场**,只做 200ms 淡入(取 `quick` 180 档,见 C-R11-5);
  - TV 与桌面:不做编排,保留整页淡入 280ms。
- 做法:新增 `lib/widgets/staggered_entrance.dart`:`StaggeredEntrance({required Animation<double> parent, required Duration delay, Duration duration = MotionDurations.standard, double rise = 12, required Widget child})`,内部用 `Interval(delay/total, (delay+duration)/total, curve: MonoMotion.emphasized)` + `FadeTransition` + `SlideTransition`(或 `Transform.translate`),`total = 540 + 280 = 820ms`。在 `_MediaDetailScreenState` 持有一个 `AnimationController`(时长 820ms,`vsync`),在首次 build 内容时(路由动画已开始且元数据已在手)`forward()`;`_isLoadingMetadata` 阶段不播放,内容到达后若路由已结束则仅对整个内容区做 200ms 淡入。插入点:`presentation.dart:210`(标题)、`:212-218`(元数据)、`:219`(评分条,逐项延迟由 `MediaRatingsStrip` 新增参数 `entranceStep = 60ms` 接收,`media_ratings_strip.dart:44-56`)、`:224`(按钮);宽屏 `responsive_layout.dart:56-80` 同理(宽屏 = 桌面/平板横屏,按"TV 与桌面不做"处理时该路径直接不包装)。选择器:`responsive_layout.dart:172`、`media_detail_screen.dart:3381`。
- R11-7b(可选,更低优先):首页内容缩到 98% + 底部导航下移退出。需在被覆盖页面用 `ModalRoute.of(context)!.secondaryAnimation` 包一层 `ScaleTransition/FadeTransition`;影响首页全部形态,风险大,单独提交,可整体不做。
- 降级:`reduced`(系统减弱动画)→ 不位移,每块直接 `quick`/`press` 档淡入或直接显示;`minimal` → 直接显示。入场期间的 D-pad 焦点必须可用(元素在动画期间已可聚焦,**不得用 `IgnorePointer`/`ExcludeFocus` 包裹**)。

### R11-8 导航选中滑块(低)—— 清单 R11-6

- 起止:选中底色块从旧标签位置平移到新标签位置,`standard` 280ms,曲线 `emphasized`;文字/图标颜色 `quick` 180ms 过渡,曲线 `standard`;标签结构不变(首页/媒体库/一起看/设置)。
- 现状:`fusion_navigation.dart:140-149` 每个目的地各画各的底色,切换瞬时。
- 做法:把选中底色提到目的地 `Row`(`:73-76`)下层的一个 `AnimatedPositioned`/`AnimatedAlign`(宽度 = 容器宽 / 目的地数,位置 = 选中索引),各目的地的 `Container` 底色改为透明,保留 `foregroundDecoration`(选中描边,`:147-` 起,需随滑块同步或同样移到滑块上,避免描边瞬移,待实现时核对)。文字颜色改 `AnimatedDefaultTextStyle`/`TweenAnimationBuilder<Color?>`。注意 `Row` 里最后一项 `_options(context)`(`:76`)不是目的地,索引与位置计算要排除;TV 分支(`isTv`)目的地宽度不均(`minWidth 54 / maxWidth 136`),滑块需用实测 `RenderBox` 位置而不是平均宽度——TV 与低端机直接保持瞬时切换(`minimal`)。
- 不改:`PressFeedback` 按下缩放(`InteractionTokens`)、焦点样式。侧边栏(`side_navigation_rail.dart`)与 `mobile_navigation_rail.dart` 不在本项,另见 C-R11-6。

### R11-9 已看对勾描边动画(低)—— 清单 R11-7

- 起止:对勾路径从起点绘制到终点(`standard` 280ms,`emphasized`);底色与图标色 `quick` 180ms 过渡(`standard` 曲线)。仅在"未看 → 已看"的**状态跃迁**时播放,首次构建与滚动回收重建不播。
- 做法:`WatchedIndicator`(`watched_indicator.dart:62`)改为 `StatefulWidget`,`didUpdateWidget` 检测 `watched` false→true 才 `forward()`;对勾用 `CustomPainter` 画 `Path`,以 `PathMetric.extractPath(0, length * t)` 描边;非跃迁直接 `value = 1`。把现有 `AppIcon(Symbols.check_rounded)`(`:111`)保留为 `minimal`/`reduced` 的回退。列表里大量实例,`AnimationController` 仅在跃迁时创建(lazy),避免每张卡片常驻控制器。
- 降级:`reduced`/`minimal` 直接显示静态对勾。

### R11-10 环境色(低)—— 清单 R11-8

- 起止:切换条目时环境色(`HomeThemeScope` 的 `artworkSurface` 与径向辉光)600ms 交叉淡入(`ambient` 档,曲线 `standard`),辉光压到约 50% 透明度;`minimal` 关闭辉光与骨架高光。
- 做法:`MonoPresentation.artworkDuration` 由 560 改引用 `MotionDurations.ambient`(600);`home_theme.dart:92` 的减弱判定改用 `MonoMotion.resolve`;`vidhub_ambient_backdrop.dart:115` 的 380ms 色彩补间是否对齐到 600 需目视决定(它是氛围层内部的颜色变化,与整体背景交叉淡入不同),默认保持 380 并记录;`ambient_skeleton.dart:25` 的 1800 与规格 1.4s 不同,**等 C-R11-3 确认后再改**。核对"长渐隐 260px":`MonoPresentation.artworkBlend` 的实际高度/三段渐隐 stops **待核对**(方法:`grep -n 'artworkBlend' lib/theme/mono_presentation.dart` 读 stops,与规格"约 260px 三段渐隐、无硬边"对照)。
- 验收:切换详情页/首页头图无色闪(目视,慢动作录屏逐帧看)。

### R11-11 下拉菜单(低,依赖 R9-5)—— 清单 R11-9

- 起止(规格):从触发行下沿展开,透明度 0→1、缩放 96%→100%、上移 6px 归位,`quick` 180ms、曲线 `emphasized`;箭头旋转 180°(R9-5);选中对勾 120ms 淡入并从 60% 放大;选中后延迟关闭(规格 140ms,现状 120ms,见 C-R11-2)。
- 现状:`app_menu.dart:98-130` 已有 180ms + `easeOutCubic` + 缩放 0.96→1 + 淡入;缺位移 6px、曲线应改 `MonoMotion.emphasized`、对勾淡入。
- 做法:在 `transitionBuilder`(`:108-127`)内加 `Transform.translate(offset: Offset(0, (1 - curved.value) * 6))`(方向按 `_transitionAlignment`:菜单向上展开时取反);曲线 `curved` 的 `curve` 改 `MonoMotion.emphasized`、`reverseCurve` 改 `MonoMotion.exit`、反向时长 `MonoMotion.exitOf(quick)=135ms`(`showGeneralDialog` 支持 `reverseTransitionDuration` 参数,待核对其在当前 Flutter 版本的参数名,不支持则只保持对称);选中对勾(菜单项,`AppMenuItem` 渲染处,文件待定位 `grep -n 'check' lib/widgets/app_menu.dart`)用 `TweenAnimationBuilder`:`opacity 0→1` 120ms(`press` 档)+ `scale 0.6→1`;`selectionDelay` 默认值仍取 `InteractionTokens.menuSelectionDuration`(`app_select_field.dart:84-86`)。
- 降级:`AppGlassSurface.reduceEffects` 已让 `transitionDuration = 0`(`:98`);`reduced` 下另外不位移不缩放(用 `MonoMotion.allowTransform`)。

## i18n key 与设置项/常量

| 名称 | 默认值 | 位置 | TODO |
|---|---|---|---|
| `MotionDurations.press/quick/standard/emphasized/ambient` | 120/180/280/420/600 ms | mono_motion.dart,同时进 `MonoTokens` 五个新字段 | TODO(VELO-R11-01)(实机调) |
| `MonoMotion.exitFactor` | 0.75 | mono_motion.dart | TODO(VELO-R11-01) |
| `MonoMotion.exit` | `Curves.easeInCubic` | mono_motion.dart | — |
| 详情入场偏移:标题/元数据 160、评分 240(步长 60)、按钮 480、选择器 540、位移 12px、总长 820 | 同左 | `staggered_entrance.dart` 常量,可注入 | TODO(VELO-R11-02) |
| 详情返回总时长上限 | 300 ms | 路由常量 | TODO(VELO-R11-02) |
| 下拉位移 | 6 px | app_menu.dart | TODO(VELO-R11-03) |
| 选中延迟关闭 | 120 ms(规格 140,待确认) | InteractionTokens | TODO(VELO-P8-01) 已有 |
| i18n key | 无(动效不含文案) | | |
| 设置项 | 无(沿用系统"减弱动态效果"与"视觉效果"设置,不新增开关) | | |

## TV 焦点、主题、形态要求

- TV:不做 Hero、不做详情入场编排、不做导航滑块(保留瞬时);整页淡入 280ms。TV 焦点 104%/150ms 描边不动。动画期间所有 `FocusableWrapper`/`FocusableButton` 必须保持可聚焦,详情页初始焦点(Play 按钮)不得因入场延迟而丢失;任何包装不得使用 `ExcludeFocus`/`IgnorePointer`。
- 低端机(`DevicePerformance.isReduced`,即 `minimal`):所有新增动效时长为 0、无位移缩放、无环境色辉光、无骨架高光,路由直接切换。
- 系统"减弱动态效果"(`reduced`):位移与缩放归零,仅保留 ≤120ms 淡入淡出;无 Hero、无描边绘制(对勾直接显示)。
- 三主题(亮/暗/纯黑):导航滑块底色用 `VeloBrand.selection(brightness)`(已有);对勾描边色随 `tokens(context).bg`/强调色,纯黑主题下对比度目视;环境色交叉淡入在亮色下不得出现暗色闪烁(`MonoPresentation.artworkSurface` 已按亮度计算)。
- 手机/平板:Hero + 入场 + 滑块 + 对勾 + 下拉;桌面:淡入 280ms、下拉、对勾、滑块(桌面使用侧栏时不适用,见 C-R11-6);TV:仅淡入与已有焦点动画。

## 测试要求

修改现有:
- `test/theme/mono_theme_test.dart`:保持通过;新增对五档数值的断言。
- 凡是对 `AppDurations.animMedium/animSlow` 断言或依赖时长做 `pumpAndSettle` 的用例,批次替换后需复核(用 `grep -rn 'animMedium\|animSlow\|Duration(milliseconds: 500)' test`)。
- `test/widgets/app_select_field_test.dart`(`selectionDelay` 相关)、`test/widgets/press_feedback_*`(间接)保持通过。

新增:
- `test/theme/mono_motion_test.dart`:`五档数值为 120/180/280/420/600`、`exitOf(280)==210 且 exitOf(420)==315`、`曲线:exit 为 easeInCubic、emphasized 单调`、`MonoMotion.level` 在 `debugReset(autoReduced: true)` 下为 `minimal`、在 `MediaQuery(disableAnimations: true)` 下为 `reduced`、其余为 `full`、`resolve` 在 minimal 返回 0,在 reduced 返回 `min(d,120)`(fadeOnly)或 0、`MonoTokens.lerp/copyWith` 含新字段、旧字段数值未变。
- `test/theme/duration_guard_test.dart`(守卫):读取 `lib/` 源文件,断言 `禁止替换清单` 目录下的文件**不含** `MotionDurations`/`motion*` token 引用(防止误替换);并断言本卡"已替换"批次文件不再含 `Duration(milliseconds:` 动画字面量(白名单列保留项)。
- `test/utils/navigation_transitions_test.dart`:`fadeRoute` 时长为 280ms;`DevicePerformance.isReduced` 时为 0。
- `test/screens/media_detail_route_test.dart`:TV 下 `mediaDetailRoute` 的 `transitionDuration == 280ms` 且无 Hero;手机下带 `heroTag` 时路由可构造。
- `test/widgets/media_card_hero_test.dart`:`heroScope` 非空时海报外有 `Hero`,tag 含 serverId+itemId+scope;`heroScope` 为空时无 Hero;`同一 item 出现在两个不同 scope 的货架不抛"重复 Hero tag"异常`;TV(`PlatformDetector` 测试替身)与 `reduced` 下无 Hero。
- `test/widgets/staggered_entrance_test.dart`:到各自延迟前不可见、延迟后淡入并上移 12px(`pump` 指定毫秒断言 opacity/offset)、`reduced` 下首帧即完整显示、`minimal` 下无动画。
- `test/screens/media_detail_entrance_test.dart`:元数据已在手时入场播放一次;`_isLoadingMetadata` 骨架→内容只做 200ms 淡入(不重播);入场期间 Play 按钮可聚焦。
- `test/navigation/fusion_navigation_slider_test.dart`:切换选中项后滑块在 280ms 内到达新位置;TV 与 `minimal` 瞬时。
- `test/widgets/watched_indicator_test.dart`:false→true 触发一次描边动画;初始已看/重建不触发;`reduced` 直接静态。
- `test/widgets/app_menu_motion_test.dart`:展开过程中菜单在 180ms 内位移 6px 归位、缩放 0.96→1;`reduceEffects` 下无动画。
- 性能:`test/widgets/detail_entrance_frame_budget_test.dart`(可选)用 `tester.binding` 计 build 次数,入场期间详情页根 build 次数不随帧增长(入场只重建动画子树,不重建整页)。

## 验收清单

- [ ] `flutter analyze` 无新增告警
- [ ] `scripts/run_tests.sh` 通过,含 `test/theme/mono_motion_test.dart`、守卫测试
- [ ] 每个替换批次提交说明含 替换/保留 数量与保留理由;最终汇总表(批次 × 替换数 × 保留数)写入本卡所在 PR
- [ ] `grep -rn 'Duration(milliseconds:' lib` 在"替换批次"文件里只剩白名单项;禁止替换清单目录与改前逐行一致(`git diff --stat` 在这些目录应为 0)
- [ ] 手动(手机):首页点海报进详情——海报展开为头图、无换图闪烁、无整页白闪;滑动返回可打断;连点两张不同海报无异常
- [ ] 手动(手机):详情页标题/元数据/评分/按钮/选择器按 160/240(+60 步长)/480/540ms 错峰出现;骨架→内容不重播;返回 ≤ 300ms
- [ ] 手动:开启系统"减弱动态效果"后,上述所有转场无位移缩放、无 Hero(只有 ≤120ms 淡入或直接显示);`visualEffects=reduced` 时无动画、无环境色辉光
- [ ] 手动(TV):海报进详情为 280ms 淡入;方向键在详情页入场期间可立即操作,初始焦点在 Play;导航切换无滑块
- [ ] 手动(三主题):导航滑块、已看对勾、环境色交叉淡入各看亮/暗/纯黑,无色闪
- [ ] 量化:60Hz 真机用 Flutter 性能面板(或 `flutter run --profile` + DevTools Performance)录制"首页→详情→返回"三次,UI/Raster 线程每帧 ≤ 16.6ms 的帧占比 ≥ 95%,无连续 3 帧以上掉帧;低端 TV 对照"关闭动效"组不劣化
- [ ] 量化:详情入场期间用 "Track widget rebuilds" 确认只重建动画子树,详情页根 build 次数 ≤ 改前 + 1

## 提交拆分(按顺序,每个可独立回滚)

1. `feat(动效): 新增五档时长与退出曲线 token`
2. `feat(动效): 新增统一减弱动效判定 MotionLevel`
3. `test(动效): 新增 token 与判定用例及禁止替换守卫`
4. `refactor(动效): theme 与 utils 时长引用 token`(批次 B1,含 AppDurations 别名)
5. `refactor(动效): widgets 根目录动画时长改用 token`(B2,可按文件拆成 2~3 个提交)
6. `refactor(动效): 详情与首页动画时长改用 token`(B3)
7. `refactor(动效): 其余页面动画时长改用 token`(B4)
8. `refactor(动效): 音乐页面动画时长改用 token`(B5)
9. `refactor(动效): 启动页状态切换改用 token`(B6)
10. `perf(动效): 路由淡入时长对齐 280ms`(R11-5a、5b)
11. `refactor(动效): 删除未再引用的旧时长 token`(全部批次完成后)
12. `feat(动效): 海报点击携带 Hero 标识`(MediaCard.heroScope 与透传,无视觉变化)
13. `feat(动效): 海报到详情共享元素转场`(仅手机/平板)
14. `feat(动效): 详情页入场错峰动画`
15. `feat(动效): 底部导航选中滑块`
16. `feat(动效): 已看对勾描边动画`
17. `feat(动效): 环境色 600ms 交叉淡入`
18. `feat(动效): 下拉菜单位移与对勾淡入`(依赖 R9-5)
19. `docs: 记录动效替换/保留统计与真机帧率结果`

## 风险与待确认

- C-R11-1:Hero 方案是否需要把手机端 `MaterialPageRoute` 换成 `PageRouteBuilder`(影响 Android 预测性返回)。默认先试 Hero 配合现有路由,不行再独立提交换路由。
- C-R11-2:下拉选中后关闭延迟 120ms(现状)还是 140ms(规格);沿用清单 C8,保持 120ms。
- C-R11-3:骨架高光周期现 1800ms,规格 1.4s,是否调整;环境色辉光 50% 透明度与现有 `vidhub_ambient_backdrop` 的实际值差异(待核对其 alpha)。
- C-R11-4:`scroll_utils.dart`、焦点跟随滚动的 150/200ms 属 TV 手感,默认保留。
- C-R11-5:元数据晚到的 200ms 淡入用 `quick`(180)还是严格 200,默认 `quick`。
- C-R11-6:侧边栏(`side_navigation_rail.dart`)与 `mobile_navigation_rail.dart` 是否也做选中滑块,默认不做(仅底部导航)。
- 风险:Hero 的重复 tag 断言;`ListView` 回收导致源 Hero 缺失(降级为淡入);入场动画与 TV/键盘焦点的交互;大批量替换造成观感回归——所以每批一个目录、可单独回滚;`MonoTokens` 新增字段需同步 `lerp/copyWith`,否则主题切换动画报错。
- 所有时长/位移均为设计建议值(第一轮已声明),实机调过再定,保留 `TODO(VELO-R11-xx)`。
- 禁止事项:不直接改生成的 Dart 文件(含 slang 生成文件);不删 Plex/Jellyfin/Emby/一起看/TV 支持;保留 mpv 与 ExoPlayer;不改播放器帧时序相关时长(seek 防抖、控制层自动隐藏、mpv/ExoPlayer 渲染与同步、一起看同步);缓存必须按用户/服务器隔离,不得跨用户泄露(本包不触碰缓存);不引入弹簧过冲;不一次性全仓替换。
