# B4 一起看视觉迁移独立验证（2026-11-13）

结论：本批定向验证通过。最终 14 项测试（10 项交互/布局/像素，4 项截图）通过，规则、格式、Flutter analyze、debug Dart bundle 与 diff-check 通过。真实 WatchTogetherProvider 配合 fake peer transport 验证，不是实际 relay/多人网络联调。

## 命令、退出码与证据

工具环境沿用 Flutter `<local-path>`、Python 3.12 `<local-path>`；未安装依赖或更改全局配置。

| 检查 | 结果 | 日志 |
| --- | --- | --- |
| `scripts/run_tests.sh test/widgets/watch_together_migration_test.dart --dart-define=CAPTURE_TABLET=true --dart-define=CAPTURE_TV=true` | exit 0，14 项 | `<local-artifacts>/velo-b4-tests-final.log` |
| `dart format --output=none --set-exit-if-changed`，仅本批 4 个 Dart 文件 | exit 0，0 changed | `<local-artifacts>/velo-b4-format-final.log` |
| `bash scripts/ci_guard_checks.sh` | exit 0 | `<local-artifacts>/velo-b4-guard.log` |
| `python3 scripts/checks/check_hardcoded_strings.py` | exit 0 | `<local-artifacts>/velo-b4-hardcoded.log` |
| `python3 scripts/checks/check_user_facing_errors.py` | exit 0 | `<local-artifacts>/velo-b4-errors.log` |
| `dart run scripts/checks/check_icon_consistency.dart` | exit 0，1011 个非生成文件 | `<local-artifacts>/velo-b4-icons.log` |
| `flutter analyze --no-pub <local-artifacts>/velo-analysis-project` | exit 0，No issues found | `<local-artifacts>/velo-b4-analyze-final.log` |
| `flutter build bundle --debug` | exit 0；Dart bundle，不是 APK | `<local-artifacts>/velo-b4-build-bundle.log`（成功无输出） |
| `git diff --check` | exit 0 | 工具执行记录 |

分析使用指向同一工作树的 ASCII 软链接，沿用既有 Unicode 工作目录 LSP 协议问题的环境绕行；未改 SDK。本批没有生成输入/翻译变化，未重复 codegen。仅跑本批相关测试和上述规则，未扩全仓 tests/CI 总入口。

## 与任务逐项对应

- 创建：从实际对话框选择 hostOnly / anyone，真实 provider 成为 host，controlMode 和 canControl 一致；fake peer 创建调用计数为 1。
- 取消/退出：取消创建不产生 peer 请求；取消结束保留房间，确认结束/访客离开清除实际会话状态并返回大厅。
- 加入：实际 JoinSessionDialog 输入小写邀请，传输层收到标准化 `ABC123`；真实 provider 是 guest，hostOnly 下 canControl=false，页面显示主持人控制提示。
- 失败重试：fake transport 第一次创建抛错，实际错误提示出现且不进房；第二次从创建入口成功。日志中的 fixture unavailable 是刻意注入错误，不是测试失败。
- 嵌入返回：Escape 调用宿主 onBack，外层 route 未被 pop，WatchTogetherScreen 仍在树中。
- 小屏/大字：320×740、390×844、844×390 的 200% 字号下大厅/错误 Retry/加入可达；加入按钮滚动后 hitTestable，Escape 可取消，不直接提交真实网络操作。
- TV：1280×720 时 Enter 从实际焦点打开创建对话框，再确认 hostOnly 后进入房间。权限与焦点行为是 widget 输入验证，不是实体遥控器测试。
- 对比度：实际 RepaintBoundary 像素检查浅色主按钮底色与面板的亮度区别和标签亮像素，配合重拍实图确认。

测试采用真实 provider 公共方法及 UI tap/key，fake transport 只替代 peer 创建/加入/广播发送；没有直接给 provider 填充 session state 冒充网络。截图房间通过 provider.createSession 建立，UI 交互用例另行从对话框进入。

## 视觉发现与修复

初轮 13 项测试通过，但实图发现浅色主按钮填色与面板背景近似，主次不清；初次描述为整块空白，随后重新核实并更正：文字与加号实际存在，问题是填色区分不足。旧图备份 `<local-artifacts>/velo-b4-phone-light-before-fix.png`。原作者第 1 轮改为浅色深底浅字、深色浅底深字，并匹配 busy 指示前景，新增实际像素回归。

邀请码白矩形源于 widget fixture 的 monospace 字体未加载；原作者只在测试把 bundled Noto 字形注册为 monospace alias，未更改生产邀请码样式。重拍 `ABC123` 清楚可读，但此 alias 不证明真实系统等宽字体的度量完全一致。

最终四图逐张检查，正文/状态/参与者/按钮可读，无观察到的溢出；房间图为无媒体、1 名本地 fixture 主持人的真实 UI 状态，没有伪造播放进度/准备开关。

- `docs/fixtures/tablet/b4-together-phone-dark.png`：390×844，深色大厅/relay 不可达/空历史。
- `docs/fixtures/tablet/b4-together-phone-light.png`：390×844，浅色大厅，修复后深色主按钮。
- `docs/fixtures/tablet/b4-together-phone-oled-room.png`：390×844，OLED 主持房间、邀请码、参与者与结束入口。
- `docs/fixtures/tv/b4-together-tv-room.png`：1280×720，TV 分栏房间及结束焦点。

截图由已有 helper 载入真实字体/MaterialSymbols；它们是生产组件 fixture，不是设备截图。这四张在 `.gitignore` 的 `/docs/fixtures/` 中，属于可重生成的本地产物，未 stage；不改旧金标，不虚称 golden 比较通过。

## 精确本批文件与共享改动

可提交文件共 5 个：

1. `lib/watch_together/theme/watch_together_presentation.dart`（新增）
2. `lib/watch_together/screens/watch_together_screen.dart`
3. `lib/watch_together/widgets/join_session_dialog.dart`
4. `test/widgets/watch_together_migration_test.dart`（新增）
5. `docs/flutter-migration-b4-validation-2026-11-13.md`（本报告）

另有上述 4 张被忽略的新截图。QA 未修改实现/测试源码；全部修复回原作者完成。没有变更后端协议、provider、服务、持久化 schema、凭据、全局主题或其他批次组件。原有未跟踪 `design/prototype-v2/`、`docs/player-native-observations-2026-11-13.md`、`docs/ui-refresh-validation-2026-11-10.md` 原样保留。未提交、推送或安装设备。

本包集中默认值：contentWidth=1120、columnBreakpoint=840、gap=28、heroInset=28、compactInset=20、heroTitleSize=34、sectionRadius=20、actionHeight=52；保留 `TODO(VELO-UI-04)`，后续以实体触屏/TV 验证呈现值。

## 未测与材料边界

没有实体手机/TV、真实 relay、多人广播、同步播放/缓冲、断线重连、历史房间重进/邀请复制系统集成或真实媒体播放联调。已点击的 relay Retry 证明可达，不代表远端连接恢复成功。游客 hostOnly 权限经 provider 断言，未在真实播放器尝试越权 seek。截图没有覆盖所有语言、状态或完整平板/桌面矩阵。无现存“准备”业务开关，保留实际加入播放/等待缓冲语义，不引入原型虚构状态。当前无未修复的本批定向失败；上述未测项不计入通过结论。
