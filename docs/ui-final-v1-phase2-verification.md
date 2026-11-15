# 最终原型落地 · 第二批验收（首页与启动资源链路）

日期：2026-11-14（America/Los_Angeles）。起始 HEAD：`7e7f952`。本报告仅覆盖本批生产代码与独立 QA；不将历史逆向推断当作 Velo 实测。

本批新增 **38 项回归**：Provider/聚合时序 24 项、真实后端客户端 HTTP 夹具 6 项、组件 6 项、完整首页手机/TV 2 项。完整测试结果 **198 通过、7 跳过、4 个已核验历史 golden 失败**；新增回归没有失败。没有连接用户媒体服务器、读取账号或测量真实网络提速。

## 任务卡对照

| 范围 | 实际变化 | 验收结果/证据 |
|---|---|---|
| HOME：快资源先显 | 同服务器按库渐进发布，manifest 与每节结果分开处理 | 快库已进入 `DiscoverProvider.hubs`，完整 `DiscoverScreen` 已构建媒体卡/TV rail，慢库 Completer 仍未完成；见 `test/screens/discover_screen_test.dart:268` |
| HOME：局部失败 | 错误保旧，局部重试不会等待慢兄弟，同 key 防重入 | 快库失败 → 局部 retry 完成 → 慢库仍 pending → 慢库完成后两者均保留；成功空仅清自身，只有成功 Views manifest 可删缺失库 |
| HOME：失败/空/加载 | 局部骨架、保旧刷新、可重试失败、真实空态分别呈现 | 390 宽组件无溢出；Views 冷失败、缓存失败及曾成功后的刷新失败均终结 loading；错误文本不含原异常 |
| HOME：评分与导航 | 轮播评分沿用图标+数值；点击打开居中说明 | `HeroMetadataBadges` 点击评分不触父层导航；来源可在说明里查看；原手机/桌面/TV hero 导航测试继续通过 |
| LIBRARY：视觉 | 局部筛选/排序使用 Velo 紫色选中与焦点色 | 深、浅、OLED token 与可点击行为通过；既有媒体库移除条件/持久化/筛选测试在完整套件通过；没有改查询与分页语义 |
| STARTUP：磁盘与网络 | 已授权上下文下快照读取与请求并行，迟到缓存只补未覆盖内容 | 慢磁盘不挡请求或首个非空网络内容；晚缓存不能覆盖新行；缓存读取失败仍能加载网络 |
| STARTUP：身份与竞态 | profile/PIN、隐藏、auth session、可见服务器和内容 revision 保护 | 迟到回调不提交受限内容；离线保留已有合法内存，隐藏/401/403清空；watch/delete/order 改变不复活旧数据、不留下永久 loading |
| BACKEND：继续观看 | 先发布安全基础结果，随后日期或 logo 补全 | 真实客户端解析夹具验证 J 系 Resume 先于日期补全；Emby 不预览未经验证 NextUp；Plex 去重预览不可变，补 logo 不改已发布对象 |
| BACKEND：取消/重试 | 每次重试前检查 parent，连接当前 attempt abort | 挂起 HTTP 收到取消；连接失败触发 parent abort 后不再发请求；Plex 全局 retry 请求真实 `/hubs`，未伪装成 `/hubs/sections/*` |

## 受控时序结果

所有“阻塞”均为可控 Future/Completer；表中描述因果顺序，不是用户设备耗时或百分比。

| 场景 | 未释放的 Future | 此时实际已可用 | 不作出的结论 |
|---|---|---|---|
| 慢库 | 同服务器 slow library | fast library 已发布；手机390/TV1280完整首页在一次布局 pump 后可找到可见媒体组件，随后100ms测试动画推进时仍未释放慢库 | 不声称100ms真实首屏，不等于 OS TTID |
| 慢磁盘 | snapshot read | 网络已请求并发布非空行；`firstUsefulNetwork` 与 `metadataTerminal` 已发出 | metadataTerminal **不包含**快照 I/O；快照恢复是 unawaited，图片/帧也不包含 |
| 慢补全 | J 系列日期 / Emby最近播放扫描 / Plex logo | J Resume；Emby仅合法Resume；Plex去重后的基础继续观看 | 最终排序与过滤仍待补全，不把 partial 当最终权威快照 |
| 局部重试 | sibling library | 失败库独立 retry 已完成且可见；重复触发只一次 | 没有为整个服务器刷新 TTL 的权威 |
| 仅空结果 | 全部内容为0 | 成功空态；没有 firstUsefulCache/Network | empty、image-ready 均不是首个有效内容/首个绘制帧 |
| 缓存先到后遇错 | library load/error | 保留缓存行；firstUsefulNetwork 尚未发出，直到局部 retry 返回非空新内容 | 不能把 loading/error 状态通知误记为新网络内容 |

`HomeLoadTiming` 测试注入的 7ms/3ms 仅验证事件时钟与字段，不是测速数据。完整首页测试验证了真实 Flutter 组件布局可见，但没有 FrameTiming/OS启动采样；没有把 `visibleImageReady` 称为完成绘制。实际前后对比仍需同设备、同账号/媒体库、冷/热启动多轮记录。

## 视觉证据与边界

下列四图均来自**实际生产 Flutter 组件**的测试渲染，字体取仓库 Noto/Material Symbols。已逐张目视检查，没有裁切、溢出或缺字；不是 HTML 原型、设备照片、真实服务器截图。

- [局部加载 / 成功空 / 保旧刷新，390×844](ui-final-v1-phase2/phase2-progressive-states.png)：`HomeSectionStatus` 三种状态。
- [局部失败与重试，390×844](ui-final-v1-phase2/phase2-retained-error.png)：保旧提示与紫色重试；上方按钮仅用于焦点夹具。
- [轮播评分说明，390×844](ui-final-v1-phase2/phase2-hero-rating.png)：`HeroMetadataBadges` → 共享 `AppAlertDialog`，居中显示；主页面仍仅图标和数值。
- [浅色筛选主题，700×420](ui-final-v1-phase2/phase2-library-light.png)：真实 `LibrarySelectionTheme` 包裹标准 FilterChip/ListTile 的隔离样例，展示统一紫色；**不是整页 LibraryBrowseTab 截图**。该页业务行为由既有完整页面测试覆盖。

生成命令：`flutter test --dart-define=CAPTURE_TABLET=true test/widgets/home_batch2_test.dart`；输出先到忽略目录 `docs/fixtures/tablet/phase2-*.png`，以上4图复制到本报告目录。生产完整首页手机/TV、原hero焦点/导航由 `discover_screen_test.dart` 验证；没有 Android/TV 实机交互或播放网络动态验收。

## 检查记录

- 完整 `scripts/run_tests.sh --reporter expanded`：198 pass / 7 skip / 4 历史 golden fail；日志 `<local-artifacts>/velo-batch2-full-tests.log`。
- 原4张 Continue Watching 失败图片与上一批独立 clean HEAD `c41732f5` 的已核验输出 SHA-256 **全部一致**，本次没有更新任何golden。比较记录 `<local-artifacts>/velo-batch2-golden-comparison.txt`。
- 专项完整首页与新测试的首次汇总58/58；随后补第38项 library-order 回归通过，并由完整测试再次覆盖；日志 `<local-artifacts>/velo-batch2-targeted-final.log`、`<local-artifacts>/velo-batch2-order.log`。旧首页 fake 增加正式 auth/session scope 合同，不绕过生产授权。
- 最终 `flutter analyze --no-pub <repo>/lib <repo>/test`：No issues found；日志 `<local-artifacts>/velo-batch2-analyze-final.log`。使用ASCII路径避免主机中文SDK路径下旧LSP环境问题。
- `scripts/ci_checks.sh`：全部通过，包含1072个Dart文件格式、`scripts/codegen.sh --check`、翻译清理/回退、项目脚本规则、错误文本、图标、native格式、Dart analyzer与unused code/files；日志 `<local-artifacts>/velo-batch2-ci.log`。未重复运行等价规则脚本。
- 最后仅测试夹具scope合同与lint语法收尾后，受影响的真实客户端与完整首页两文件定向复跑 **29/29通过**；日志 `<local-artifacts>/velo-batch2-post-lint-tests.log`。没有修改生产代码，未再次无差别全跑。
- Android debug 编译：`./gradlew assembleDebug -Ptarget-platform=android-arm64 -Ptarget=lib/main.dart -Ptrack-widget-creation=true --console=plain`，**BUILD SUCCESSFUL，27s，639任务（41执行）**；日志 `<local-artifacts>/velo-batch2-android-build.log`。仅编译验证，非交付打包；产物 `build/app/outputs/apk/debug/app-debug.apk` 留在忽略目录，不入git、不作为正式发布包。项目自身ABI配置可能打入多个ABI，不称为arm64-only交付。
- 工具环境沿用现有SDK/JDK17；没有Xcode，未宣称macOS原生编译通过。Gradle临时使用既有ASCII Flutter别名，忽略的 `android/local.properties` 先备份后**字节恢复**；无pubspec、依赖锁或Android追踪配置diff。`git diff --check`通过。

历史 SHA-256：

| 旧golden场景 | 本次输出 SHA-256（与已核验基线相同） |
|---|---|
| phone | `c42e9cf1b6144c1b3f864dd216ab6ec393cbe9b557131196a64d09e5f15bfdd1` |
| phone_light | `adfce51e194a4aa0206570a305f5ff8eae882932ee77a131a837eeec21716d9e` |
| phone_large | `49d8b242b08aa8c507864cf95cc7751a9c9018ad6f2abd94b0162479ec048dba` |
| tv | `11cf0e77a520cdcd5def822609453a8dbbf25301656646131d009f06f552c3e2` |

## 默认值、共享文件与提交分组

保留既有预算：连接/内容 gate 合用2s；快照24h；并发库3；NextUp最多24系列、并发4、每次3s；J日期补全全程4s，Emby不能等同描述为相同4s总预算。没有新增业务常量、网关、密钥、数据源或版本号；`2.23.26+6207`保持不变。本批不是交付打包任务。

建议主会话按以下逻辑分别提交；QA没有提交或推送。

**C 后端/模型（6文件）**：`lib/media/home_section_load.dart`、`lib/media/progressive_continue_watching_client.dart`、`lib/services/data_aggregation_service.dart`、`lib/services/jellyfin_client.dart`、`lib/services/jellyfin_client/parts/browse.dart`、`lib/services/plex_client.dart`。聚合/后端方法共享已有调用者，旧最终返回合同保留。

**B 状态/启动（3文件）**：`lib/providers/discover_provider.dart`、`lib/services/home_startup_timing.dart`、`lib/widgets/home_startup_gate.dart`。共享 provider 的变更受现有首页、scope、快照、watch/delete tests覆盖；不是全局修改缓存TTL。

**A UI（10文件+26翻译文件）**：`lib/screens/discover_screen.dart`、`lib/widgets/home_section_status.dart`、`lib/widgets/hero_metadata_badges.dart`、`lib/widgets/media_ratings_strip.dart`、`lib/screens/libraries/library_selection_theme.dart`、`lib/screens/libraries/library_quick_filters.dart`、`lib/screens/libraries/library_filter_summary.dart`、`lib/screens/libraries/filters_bottom_sheet.dart`、`lib/screens/libraries/sort_bottom_sheet.dart`、`lib/screens/libraries/filters/filter_operator_row.dart`。共享评分说明helper由详情与hero共用；筛选主题作用域局部。

翻译精确清单：`lib/i18n/{az,bg,da,de,en,es,fr,hu,it,ja,kk,ko,nb,nl,pl,pt,ru,sv,tr,uz,zh-Hant,zh}.i18n.json` 22份，及 `strings.g.dart`、`strings_en.g.dart`、`strings_zh.g.dart`、`strings_zh_Hant.g.dart`。英文base、简繁中文落实，其余按原slang空串回退规范；生成文件来自codegen，未手改。main仅为freshness暂存这26份文件。

**QA（5测试文件+报告+4截图）**：新增 `test/services/home_sections_batch2_test.dart`、`test/services/progressive_clients_batch2_test.dart`、`test/widgets/home_batch2_test.dart`、`test/test_helpers/progressive_home_fixtures.dart`；更新 `test/screens/discover_screen_test.dart`。新增本报告及 `docs/ui-final-v1-phase2/` 4PNG。上一批所有测试与报告保留。

**保留历史未跟踪文件，不纳入本批**：`design/prototype-v2/`、`design/vidhub-study/`、`docs/player-native-observations-2026-11-13.md`、`docs/ui-refresh-validation-2026-11-10.md`。

## 未覆盖/与材料不同

- 本批执行首页渐进资源与视觉方案，未优化播放器参数、编码器/硬解、真实线路算法、真实启动DNS/TLS/接口TTFB；这些不能据本报告宣称已改善。
- 普通离线只保留当前已授权内存，不新增离线磁盘恢复；隐藏/401/403会撤销显示。与“任意离线都读缓存”不同，这是当前身份边界。
- 取消测试证明接入本次 parent abort 的真实HTTP transport收到取消及旧结果不提交；未证明所有平台/所有后端socket都可物理中断。
- 浅色库图是主题隔离样例；整页手机/TV验证为widget行为测试。没有新增像素黄金基准，也未用本批截图替换历史golden。
