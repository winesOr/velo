# B2 库与搜索视觉迁移独立验证（2026-11-13）

结论：本批定向验证通过。15 项相关测试通过，3 张经实图复核的库金标在普通比较模式通过，格式、规则检查、Flutter 分析和 debug Dart bundle 编译通过。本报告不将 widget fixture 称为真实服务器或设备联调。

## 验证命令与证据

Flutter 使用 `<local-path>`。规则脚本所需 Python 使用已有 `<local-path>`，未安装工具或更改全局环境。

| 检查 | 结果 | 日志 |
| --- | --- | --- |
| `scripts/run_tests.sh test/widgets/catalog_migration_test.dart test/screens/libraries/library_browse_tab_test.dart` | exit 0，15 项；最终普通比较模式 | `<local-artifacts>/velo-b2-tests-final.log` |
| `dart format --output=none --set-exit-if-changed`，仅下列 12 个 Dart 文件 | exit 0，12 files / 0 changed | `<local-artifacts>/velo-b2-format-final.log` |
| `scripts/ci_guard_checks.sh` | exit 0；负例 fixture 的 would-be-rewritten 信息不代表失败 | `<local-artifacts>/velo-b2-guard.log` |
| hardcoded strings / user-facing errors / icon consistency 检查 | 均 exit 0 | `<local-artifacts>/velo-b2-hardcoded.log`、`<local-artifacts>/velo-b2-errors.log`、`<local-artifacts>/velo-b2-icons.log` |
| `flutter analyze --no-pub <local-artifacts>/velo-analysis-project` | exit 0，No issues found | `<local-artifacts>/velo-b2-analyze-final.log` |
| `flutter build bundle --debug` | exit 0；生成 `build/flutter_assets/`，不是 APK | `<local-artifacts>/velo-b2-build-bundle.log`（成功无输出） |
| `git diff --check` | exit 0 | 工具执行结果 |

分析目标 `<local-artifacts>/velo-analysis-project` 是同一工作树的 ASCII 软链接，规避既有 Unicode 工作目录 LSP 初始化协议问题；本轮最终运行的确是 `flutter analyze`，未修改 Flutter SDK。未改生成输入，故本批未重复 codegen。按本批授权运行相关测试，未运行全仓测试或全量 CI 总入口。

## 与任务逐项对应

- 库标题区：320×740、390×844、844×390 的 200% 字号组件测试，验证标题区受限且保留海报视口；手机真实库 fixture 在 390×844 下验证 100% / 200% 字号。
- 筛选：条件 chip 精确删除单个字段，Reset 独立；真实库 widget 使用模拟 Plex transport，验证移除 genre 后 year=2024 仍进入请求并保留持久化。
- 排序：从真实 Sort 入口定位 Title 行并选择降序，验证 `sort=titleSort:desc` 请求与持久化。不是直接调用状态函数。
- 搜索：浅/深色清除后回焦；未传 `cinemaStyle` 的默认样式、controller 通知、clear 显隐和回焦均有回归；短屏大字号错误面板可滚动到 retry 并触发回调。
- 对比度：暗色 / OLED RepaintBoundary 实际像素检查，输入底亮度 < 0.08、hint/icon 对比 > 4.5；并人工查看修复后手机 1× / 2× 与 TV 实图。
- TV：960×540 真实库 fixture 保留侧栏与海报墙，在分页追加后焦点仍落在实际条目，金标比较通过。
- 搜索结果/状态组件沿用真实搜索调用与服务层；本批没有伪造搜索历史或扩展数据源。

## 金标审阅与修复记录

初轮发现 undefined `focusSearchInput`、fixture platform override 恢复时机、暗色输入底色/前景低对比；均由原作者修复。后补排序用例出现多个 SegmentedButton 的 finder 歧义，原作者改为定位 Title 行，最终真实请求与持久化断言通过。QA 未改实现或测试源码。

先查看失败实际图与旧金标，再获主会话确认，仅更新以下三张：

- `test/screens/libraries/goldens/fusion_library_phone_1x.png`
- `test/screens/libraries/goldens/fusion_library_phone_2x.png`
- `test/screens/libraries/goldens/fusion_library_tv.png`

字体为已加载的 FusionFixture / MaterialSymbols，不是 Ahem；海报使用既有缺图 fixture。确认差异包括手机移除重复排序 chips、工具栏顺序/布局，以及旧金标尚未包含的中性色与评分角标；TV 侧栏/海报几何布局保持。深灰输入底和浅色 hint/icon 可读，无观察到的溢出。更新模式仅用于这三项，日志 `<local-artifacts>/velo-b2-goldens-update.log` exit 0；随后最终 15 项普通模式再次通过。旧失败图备份 `<local-artifacts>/velo-b2-before-review/`。

## 本批精确文件清单

生产文件（10）：

1. `lib/screens/catalog_search_screen.dart`
2. `lib/screens/libraries/library_quick_filters.dart`
3. `lib/screens/libraries/tabs/library_browse_tab.dart`
4. `lib/screens/search_screen.dart`
5. `lib/widgets/search_input_field.dart`
6. `lib/screens/libraries/library_browse_header.dart`（新增）
7. `lib/screens/libraries/library_filter_summary.dart`（新增）
8. `lib/theme/catalog_presentation.dart`（新增）
9. `lib/widgets/catalog_result_surface.dart`（新增）
10. `lib/widgets/catalog_state_panel.dart`（新增）

测试源码（2）：`test/widgets/catalog_migration_test.dart`（新增）、`test/screens/libraries/library_browse_tab_test.dart`。另含上述 3 张金标，以及本验证报告，共 16 个本批文件。共享 SearchInputField 以 opt-in `cinemaStyle=false` 保留默认行为；没有改服务/API/debounce、翻译或生成文件。

既有未跟踪 `design/prototype-v2/`、`docs/player-native-observations-2026-11-13.md`、`docs/ui-refresh-validation-2026-11-10.md` 原样保留，不属于 B2。未提交、推送或安装到设备。

## 默认值、边界与遗留

`CatalogPresentation` 默认结果最大宽 1120、标题区高度占比 0.45、结果/筛选间距均 8；保留 `TODO(VELO-UI-02)`，后续根据手机/平板/TV 截图调密度。共享输入 `cinemaStyle=false`。现有服务搜索无 history 存储，本批不补造。

未做物理手机/TV、真实 Plex/Jellyfin/Emby 服务器、真实断网/恢复、多服务器搜索取消/竞态联调；未执行独立平板/桌面整页截图矩阵。已有组件/fixture 覆盖不能替代这些验证。错误面板验证的是 UI 可达与回调，不是网络重试成功。评分角标仅随库实图观察，本批未重跑全部评分业务矩阵。未发现尚未修复的本批定向测试失败；以上未测范围如实保留，不扩大通过结论。
