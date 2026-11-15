# 最终原型落地 · 第三批独立验收

日期：2026-11-14（America/Los_Angeles）。起始HEAD `41d5f31`，分支 `codex/r1-home-hero`。本批仅设置、一起观看与播放器表现层，不改业务协议、播放核心、缓存/硬解默认或版本。

新增 **15 项行为回归**，完整套件 **213通过 / 7跳过 / 4个已核验历史golden失败**；本批没有新增失败。QA只改测试与文档，没有生产代码修改、提交或推送。最终analyze、项目CI与Android debug编译均通过。

## 任务卡逐项对照

| 任务卡 | 生产实现与验收 | 范围/差异 |
|---|---|---|
| SETTINGS-01 | 设置作用域的行高、圆角、字号与紫色选中/焦点；真实SettingSelectionTile保存system/light/dark/oled，再次打开显示已选，取消不写值；ThemeProvider立即响应 | 保留全部4模式，OLED背景确为黑色；没有照原型删除OLED。既有rating偏好成功、失败后释放控件、返回重开、320窄屏2×和TV双栏测试继续通过 |
| SETTINGS-01/SHARED | SettingsAppearance下的选择弹窗继承局部主题，外部弹窗不受污染；选中底色与focus色不同 | 不改变设置之外的共享行默认样式；200%字号允许增高/换行，不把58dp当固定裁切高度 |
| SETTINGS-02/03 | 原有资源、服务、播放偏好入口保留；enableHardwareDecoding默认true的回归断言仍通过 | 未新增原型中的假最快线路、假缓存容量、空设置页；没有重做SettingsService/MutationService、真实清缓存业务 |
| TOGETHER-01 | 真实WatchTogetherProvider+注入传输夹具：非法code不提交；合法join挂起跨帧、失败回lobby后重开保留完整草稿；取消不入房间 | 真实允许字母数字下划线连字符及64字符，保留hostOnly/anyone与权限；未引入模拟ready按钮、六位码限制 |
| TOGETHER-01/SHARED | 320×740/2×下64字符room code在lobby与实际播放器房间panel换行，Clipboard写入完整64字符；居中panel的nested确认首Escape只取消确认，房间仍active，Close仅关panel | 测试壳加入生产已有BackKeySuppressorObserver；原先缺observer的孤立KeyUp不是生产新增缺陷。Copy顶部成功通知在320/2×可暂覆盖panel上部，测试推进其期限后确认Close可点；没有隐藏这一差异 |
| PLAYER-01 | 实际OverlaySheet+PlayerSettingsDrawer：标题/Close、四tab固定外框、深/浅/OLED紫色选中、390宽2×内容无溢出；ClipPath限制面板效果范围 | 保留44/平板52触摸目标，未机械压至原型36。2×英文长tab会折行；外框保持不跳动。HUD白色按钮验证独立于浅色面板 |
| PLAYER-01焦点 | 在真实PlexVideoControls的生产opener验证显式initial tab focus，首次Enter不退出；嵌套数字设置Escape只关上层；Shift+Tab→Enter可到Close并关闭，回到触发按钮 | 作者第1轮修正Close插入后抢占初始焦点：每次打开创建tab FocusNode，传入overlay/drawer，完成后dispose；未加异步抢焦点逻辑 |
| PLAYER-02/03 | 上两批轨道pending/去重/失败保旧/主次互斥测试保留；本批未改轨道切换合同 | 新speed测试确认调用房间onRateRequested并等待后才关闭，未偷调本地player.setRate；章节guest不能seek、授权后等待真实callback |
| PLAYER-04 | 真实队列provider：当前globalKey副本选中不导航，非当前项回调一次，320/2×长标题可操作；DLNA空/错误刷新与danmaku真实偏好既有测试保留 | 没有调用真实DLNA、播放器、relay、媒体服务器；不能宣称完成实机播放/同步/网络性能验收 |

## 独立测试与截图

新增测试分布：`test/widgets/settings_migration_test.dart` 5项（四模式+dialog隔离）；`test/widgets/watch_together_migration_test.dart` 3项（pending失败草稿+两处64码）；`test/widgets/player_migration_test.dart` 7项（三种外观+焦点/嵌套+同步速度+章节权限+队列身份）。同时增强原有真实生产播放器opener测试与设置选中色断言，保留全部第一/二批回归。

五张图片均为**真实Flutter生产组件的widget fixture**，已目视检查；不是HTML原型或真机照片。没有账号/服务器数据，房间号为测试字符串。播放器背景为空黑测试画布，不代表实际影片或播放性能。

- [OLED设置，390×844](ui-final-v1-phase3/phase3-settings-oled.png)：实际SettingsPage/SettingSelectionTile、真实已保存OLED值；隔离的设置条目样例，不是全部设置页。
- [失败后再次加入，390×844](ui-final-v1-phase3/phase3-together-retry.png)：真实JoinSessionDialog居中，保留已提交邀请草稿；背后lobby仍显示实际夹具的relay不可达状态。
- [播放器房间panel，320×740/2×](ui-final-v1-phase3/phase3-together-overlay.png)：完整64字符自动换行，后续成员与结束操作可在内容区滚动访问；顶部通知层不在该panel边界截图内，覆盖行为见上表。
- [浅色播放器panel，390×844/2×](ui-final-v1-phase3/phase3-player-light.png)：真实居中OverlaySheet、固定四tab、可滚动正文，紫色仅用于选中/焦点。
- [TV播放器panel，1280×720](ui-final-v1-phase3/phase3-player-tv.png)：真实面板与初始tab选择、显式Close。TV widget模式不是实体遥控器验收。

复现截图：`flutter test --dart-define=CAPTURE_TABLET=true test/widgets/settings_migration_test.dart test/widgets/watch_together_migration_test.dart test/widgets/player_migration_test.dart --name phase3`。原始截图落忽略目录 `docs/fixtures/tablet/phase3-*.png`，仅上述5图进入报告目录。

## 验证记录

- 完整 `scripts/run_tests.sh --reporter expanded`：213通过/7跳过/4历史golden失败；`<local-artifacts>/velo-batch3-full-tests.log`。
- 四张Continue Watching失败图片SHA-256与上一批已核验基线完全相同；`<local-artifacts>/velo-batch3-golden-comparison.txt`，未更新任何golden：

| 场景 | SHA-256 |
|---|---|
| phone | `c42e9cf1b6144c1b3f864dd216ab6ec393cbe9b557131196a64d09e5f15bfdd1` |
| phone_light | `adfce51e194a4aa0206570a305f5ff8eae882932ee77a131a837eeec21716d9e` |
| phone_large | `49d8b242b08aa8c507864cf95cc7751a9c9018ad6f2abd94b0162479ec048dba` |
| tv | `11cf0e77a520cdcd5def822609453a8dbbf25301656646131d009f06f552c3e2` |

- 设置+播放器新回归12/12、Together3/3分别通过；截图日志 `<local-artifacts>/velo-batch3-capture.log`、`<local-artifacts>/velo-batch3-capture-final.log`、`<local-artifacts>/velo-batch3-together-notice.log`。最终修正截图捕获到完整dialog路由，未将只截到背后页面的中间图片交付。
- 最终 `flutter analyze --no-pub <repo>/lib <repo>/test`：No issues found（8.2s）；`<local-artifacts>/velo-batch3-analyze-final.log`。
- `scripts/ci_checks.sh`：All checks passed；含1072个Dart文件格式、`scripts/codegen.sh --check`、翻译卫生、项目脚本规则、错误文本、图标一致性、native格式、Dart analyzer、unused code/files；`<local-artifacts>/velo-batch3-ci.log`。无新翻译键，不需要改生成文件。
- 完整测试后增强同一焦点用例的Shift+Tab→Enter关闭与返回焦点断言，定向复跑通过；`<local-artifacts>/velo-batch3-keyboard-close.log`。随后仅修测试中一处大括号lint，不再无差别重跑完整套件。
- Android debug：`./gradlew assembleDebug -Ptarget-platform=android-arm64 -Ptarget=lib/main.dart -Ptrack-widget-creation=true --console=plain`，**BUILD SUCCESSFUL，30s，639任务（41执行）**；`<local-artifacts>/velo-batch3-android-build.log`。这是编译验证，未交付发布包，项目配置可能包含多ABI，不称为arm64-only发行。
- 使用既有ASCII Flutter路径、Python3.12、Android SDK与JDK17；忽略的`android/local.properties`先备份再临时改SDK别名，编译后**字节恢复**。无pubspec/依赖锁/Android追踪配置diff；`git diff --check`通过。产物仅在忽略目录`build/app/outputs/apk/debug/app-debug.apk`，不入git。

## 文件、共享边界与默认值

**A设置（7）**：`lib/theme/settings_presentation.dart`、`lib/screens/settings/settings_category_pane.dart`、`lib/screens/settings/settings_utils.dart`、`lib/widgets/settings_section.dart`、`lib/widgets/setting_tile.dart`、`lib/widgets/expressive_button_group.dart`、`lib/widgets/focusable_list_tile.dart`。后两者是共享组件，修改为设置作用域/显式样式能力，保留其他调用者默认行为；选择弹窗继续区分取消null与选择nullable值。

**B一起观看（5）**：`lib/watch_together/theme/watch_together_presentation.dart`、`lib/watch_together/screens/watch_together_screen.dart`、`lib/watch_together/widgets/join_session_dialog.dart`、`lib/watch_together/widgets/local_media_match_dialog.dart`、`lib/watch_together/widgets/watch_together_overlay.dart`。Join新增可选`initialSessionId`，默认空；是输入草稿，不是协议默认房间。没有更改provider/services/生成协议。

**C播放器（11）**：`lib/widgets/video_controls/player_presentation.dart`、`lib/widgets/video_controls/widgets/player_hud_surface.dart`、`lib/widgets/video_controls/parts/mobile_chips.dart`、`lib/widgets/video_controls/sheets/{player_settings_controls,player_settings_drawer,player_popovers,chapter_sheet,queue_sheet,version_quality_sheet,video_settings_sheet,subtitle_search_sheet}.dart`。共享drawer/popover仅改样式、可达性、控制器生命周期；速度/章节/队列/轨道业务回调保留。

**QA（9交付路径）**：上述3测试文件、本报告、`docs/ui-final-v1-phase3/`5PNG。没有新增i18n键，没有改生成Dart、业务默认值、版本、依赖锁或播放核心。`2.23.26+6207`保留；非正式打包任务不bump。

保留现有硬解true、buffer tier auto、mpv/Exo能力门控、2s启动gate、24h快照、后台并发等既有设置。本批唯一效果参数调整为**面板blur22、HUD仍12**，作用区域由已有ClipPath约束；没有GPU帧耗时/功耗实测，不能据此称性能提升。

保留且不纳入本批4个历史untracked：`design/prototype-v2/`、`design/vidhub-study/`、`docs/player-native-observations-2026-11-13.md`、`docs/ui-refresh-validation-2026-11-10.md`。

## 遗留验证与材料差异

原型不是功能白名单：保留所有设置入口、system/light/dark/oled、真实房间控制模式与64字符规则、真实chapter/queue/danmaku/cast与播放器能力判断。没有填入原型假媒体、人数、手动ready或假硬解选项。当前没有Xcode/在线真机证据；未跑实体TV遥控、Android输入法、真实入房/重连/媒体匹配/同步播放、真实字幕搜索或缓存清理的端到端场景。上述协议与服务不在本批变更范围，不能将widget夹具当作实测完成。
