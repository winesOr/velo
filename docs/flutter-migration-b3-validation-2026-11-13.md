# B3 设置视觉迁移独立验证（2026-11-13）

结论：本批定向验证通过。18 项测试（10 项行为/布局及 8 项截图）通过；格式、规则、Flutter 分析和 debug Dart bundle 编译通过。截图是 Flutter 生产组件配合受控偏好状态的 widget fixture，不是设备截图或真实服务器联调。

## 命令与证据

环境沿用 Flutter `<local-path>`、已有 Python 3.12 `<local-path>`。未安装工具、更改全局环境或设备。

| 检查 | 结果 | 日志 |
| --- | --- | --- |
| `scripts/run_tests.sh test/widgets/settings_migration_test.dart --dart-define=CAPTURE_TABLET=true --dart-define=CAPTURE_TV=true` | exit 0，18 项 | `<local-artifacts>/velo-b3-tests-round1.log` |
| `dart format --output=none --set-exit-if-changed`，本批 13 个 Dart 文件，测试修复后仅复查该测试 | exit 0，均 0 changed | `<local-artifacts>/velo-b3-format.log`、`<local-artifacts>/velo-b3-format-final.log` |
| `bash scripts/ci_guard_checks.sh`（完整 Flutter/Python PATH） | exit 0 | `<local-artifacts>/velo-b3-guard-final.log` |
| `python3 scripts/checks/check_hardcoded_strings.py` | exit 0 | `<local-artifacts>/velo-b3-hardcoded.log` |
| `python3 scripts/checks/check_user_facing_errors.py` | exit 0 | `<local-artifacts>/velo-b3-errors.log` |
| `dart run scripts/checks/check_icon_consistency.dart` | exit 0，1010 个非生成文件 | `<local-artifacts>/velo-b3-icons.log` |
| `flutter analyze --no-pub <local-artifacts>/velo-analysis-project` | exit 0，No issues found | `<local-artifacts>/velo-b3-analyze-final.log` |
| `flutter build bundle --debug` | exit 0；Dart bundle，不是 APK | `<local-artifacts>/velo-b3-build-bundle.log`（成功无输出） |
| `git diff --check` | exit 0 | 工具执行记录 |

`<local-artifacts>/velo-analysis-project` 指向同一工作树；沿用 ASCII 路径规避已知 Unicode 工作目录 LSP 初始化协议问题。实际运行的是 Flutter analyze，未改 SDK。guard 初跑 PATH 漏加 dart，exit 1；补全本进程 PATH 后成功，不是产品失败。guard 日志中的模拟 publish/play 输出属于其脚本测试，没有发布操作。无翻译或生成输入变更，本批不重复 codegen；按授权仅定向测试，未跑全仓测试及全量 CI 总入口。

编译后唯一修复是测试源码的滚动稳定处理和截图用例，生产代码没有再次变化，因此不重复编译相同生产实现。

## 任务逐项验证

- 浅色、深色、OLED 三种主题：SettingsAppearance 样式限定在设置子树；外层主题、列表默认样式不泄漏。
- 320×740、390×844、844×390、820×1180，200% 字号：设置名称、说明和当前值换行；滚动后真实命中开关、保存偏好，不直接调用 onChanged。
- 真实 RatingSettingsScreen：修改偏好，返回并重进后实际开关值保持。
- 注入 SharedPreferences 写失败：点击真实来源排序按钮，写失败计数为 1，显示错误提示，busy 解除后按钮可再次操作。
- TV：使用真实 SettingsCategoryPane 与设置叶子，Enter 进入、Back 返回并检查现有焦点路径。
- 源码作用域：六个叶子沿用 SettingsPage.slivers 契约，连接、配置与快捷键业务代码未在本批改造；不将仅编译通过称为认证/导入导出联调通过。

首轮 10 项有 3 项失败：320/短横开关、写失败注入按钮在 ensureVisible 后立即点击时仍落在视口外。原作者第 1 轮仅在测试补 pumpAndSettle 与 hitTestable 唯一断言，再执行真实 tap；最终全过。没有关闭 missed-hit 警告、绕过交互或改生产布局来掩盖失败。初轮日志 `<local-artifacts>/velo-b3-tests-new.log` 保留。

## 实图审阅

使用既有 `loadTabletFonts(loadDefaultFont: true)` 和截图 helper，加载真实字体/MaterialSymbols；8 张均实际查看，没有 Ahem 方块或资源超时。窄屏 200% 内容自然增高、需要滚动，未压缩字号，测试已验证滚动后开关可达；横屏采用滚动内容。浅/深/OLED 的正文、说明、选中与禁用操作可区分。分栏截图验证平板、桌面与 TV 的分类/内容结构。

手机截图为生产 RatingSettingsScreen；分栏截图为生产 SettingsCategoryPane 配合真实叶子 builders。它们不是完整账号环境下 SettingsScreen 根页面导航的设备截图。

新产物：

- `docs/fixtures/tablet/b3-settings-phone-dark.png`（390×844）
- `docs/fixtures/tablet/b3-settings-phone-light.png`（390×844）
- `docs/fixtures/tablet/b3-settings-phone-oled.png`（390×844）
- `docs/fixtures/tablet/b3-settings-phone-large.png`（320×740，200%）
- `docs/fixtures/tablet/b3-settings-phone-landscape.png`（844×390，200%）
- `docs/fixtures/tablet/b3-settings-tablet.png`（1024×768）
- `docs/fixtures/tablet/b3-settings-desktop-light.png`（1440×900）
- `docs/fixtures/tv/b3-settings-tv.png`（1280×720）

这些截图位于 `.gitignore:107` 的 `/docs/fixtures/` 下，是可重生成的本地产物；未 stage。现仓原有 5 张设置金标无现存 matcher/生成测试入口，本轮没有盲更新、也不宣称旧金标比较通过。

## 精确本批文件清单与默认值

生产修改（12）：

1. `lib/theme/settings_presentation.dart`
2. `lib/widgets/settings_section.dart`
3. `lib/widgets/settings_page.dart`
4. `lib/widgets/setting_tile.dart`
5. `lib/screens/settings/settings_screen.dart`
6. `lib/screens/settings/settings_category_pane.dart`
7. `lib/screens/settings/mpv_config_screen.dart`
8. `lib/screens/settings/keyboard_shortcuts_screen.dart`
9. `lib/screens/settings/add_connection_screen.dart`
10. `lib/screens/settings/edit_jellyfin_connection_screen.dart`
11. `lib/screens/settings/add_jellyfin_screen.dart`
12. `lib/screens/settings/add_plex_account_screen.dart`

新增源码测试：`test/widgets/settings_migration_test.dart`。新增报告：`docs/flutter-migration-b3-validation-2026-11-13.md`。共 14 个本批可提交文件，另有上述 8 张忽略的本地截图。QA 只写本报告和生成截图，没有修改实现或测试源码。

共享 theme/settings widgets 仅设置作用域启用新样式。集中默认值：`pageMaxWidth=920`、`columnBreakpoint=900`、`compactValueBreakpoint=420`、`groupInset=16`、`iconTileSize=34`；保留 `TODO(VELO-UI-03)` 用于设备截图后的间距调整。

既有未跟踪 `design/prototype-v2/`、`docs/player-native-observations-2026-11-13.md`、`docs/ui-refresh-validation-2026-11-10.md` 原样保留，不属于本批。未提交或推送。

## 范围与限制

未连真实 Plex/Jellyfin/Emby、未使用实体手机/TV，未验证真实账号认证、服务器连接持久化、文件导入导出、播放器内核或平台文件选择器。偏好成功/失败使用真实设置 UI 与替换的本地存储测试后端，不代表设备磁盘故障测试。未穷尽每个设置叶子和各语言长文案；主设置根页面与所有入口链路未做设备 UI 自动化。未发现剩余定向失败或需要扩展服务接口的材料冲突，以上未测范围不计入通过结论。
