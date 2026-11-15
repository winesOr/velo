# 正式 App 评分展示独立验证 · 2026-11-13

## 结论

本轮针对正式 Flutter App，最终 **30 项相关测试全部通过**，Dart bundle 编译通过，直接 Dart 分析无诊断；格式、规则、图标、文案与翻译检查通过。不是 HTML 原型验收，也不是 APK、真机或真实服务器联调通过。

两项命令仍须如实保留非零状态：`flutter analyze` 在分析服务器 LSP 初始化时异常退出；`scripts/codegen.sh --check` 因未提交生成文件退出 1。对后者补充隔离完整重生成与当前文件逐字节比较，实际内容差异为 **0**。没有为检查通过而暂存、提交或改动检查规则。

依据仅为 `<local-artifacts>/velo-rating-implementation-brief.md`、作者 READY 后代码/测试的相关片段以及本代理实际运行结果。基线分支 `codex/r1-home-hero`、HEAD `39ab68d`；本轮没有提交或推送。

## 任务对应与证据范围

| 任务 | 本轮证据 | 结论/边界 |
|---|---|---|
| 首页最多 4、详情最多 4 | `media_ratings_strip_test.dart` 对 0/1/2/4/5 个来源验证 HeroMetadataBadges 与 MediaRatingsStrip 实际 0/1/2/4/4；TV spotlight 独立用例 | 通过组件验证；没有用空评分占位补到 4 |
| 实际数量决定布局与高度 | 0 源高度为 0；190 宽度验证 1/2/4 个实际行；300 宽度验证 1/2 源同排、4 源两行，检查真实 cell 数、行坐标、首末 cell 与 strip 边缘 | 通过；窄宽允许合法换行，不把 190 必须容下两列作为要求 |
| 普通海报最多 1 个客观分 | `media_card_rating_policy_test.dart` 验证有个人分仍选 IMDb、只有个人分则隐藏、顺序/禁用/非法值/中性 headline 回退 | 通过；userRating 本身不被改写 |
| 继续观看例外、整卡焦点与开关 | `tv_browse_rail_test.dart` 验证实际 MediaCard 的整卡焦点、角标开关和继续观看无角标 | 通过组件验证；不是遥控器真机验收 |
| 来源启停/顺序即时生效 | SettingsService 测试写入后重新渲染，全部禁用后收起；海报开关关闭不隐藏 hero/detail | 通过组件状态验证；不是设置页手工操作或持久化重启验证 |
| 客观分与个人能力分离 | Jellyfin/Emby 测试数据有 userRating 仍显示中性客观分；没有用错误品牌 SVG；fallback 不混拼两组来源 | 通过展示层验证；未联调这些服务器或个人编辑保存 |
| 320 宽度、200% 字号 | 实际详情评分组件四品牌、亮/暗主题、SVG 数量与各 badge 边界、无 Flutter 布局异常 | 通过；未验证完整手机首页在 200% 字号下的全屏构图 |
| TV 四评分不被拟合元信息丢弃 | 1280×720、2 倍字号、受限内容宽度；实际 TvSpotlightBackground 渲染 4 个来源且 Wrap 换行 | 通过；修复 bottom 定位内容无界高度问题，保留真实宿主用例 |
| 非交互评分语义与主题对比 | 语义包含来源/值、不可聚焦；亮/暗主题角标使用命名深色底/白字 token | 通过组件断言；不等同纯黑主题、真实浅深海报或屏幕对比度测量 |
| 不扩数据来源 | 变更清单未包含服务、mapper、网络、provider/cache 或凭据文件；本轮没有添加豆瓣 | 范围保持 UI/策略；真实服务缺分原因未调查 |

`home_hero_info_only_test.dart` 的既有输入实际为 3 条来源，更新后期望 3，符合“实际有几条显示几条”；四项上限由独立 0/1/2/4/5 矩阵验证。`hero_text_blocks_test.dart` 继续验证标题、简介与剧集防剧透行为。

## 执行环境与命令

实际工具链：Flutter 3.47.7、Dart 3.13.5；Flutter 位于 `<local-path>`。默认 shell 的 Python 3.9.6 不满足部分规则测试语法，改用本机已有 Python 3.12，没有安装或替换系统工具。

验证进程 PATH 加入 Flutter bin 与 `<local-path>`。默认 Flutter 查询版本实际遇到外部 SDK 缓存写权限拒绝，随后按工具提供的合法升级执行成功；以下需要 SDK 缓存/临时 worktree 的检查采用相同权限方式。没有修改 SDK。

| 命令/范围 | 实际退出码 | 证据 |
|---|---:|---|
| `scripts/run_tests.sh test/utils/media_card_rating_policy_test.dart test/widgets/media_ratings_strip_test.dart test/widgets/home_hero_info_only_test.dart test/widgets/tv_browse_rail_test.dart test/widgets/hero_text_blocks_test.dart` | 0 | `<local-artifacts>/velo-rating-tests-complete.log`，30 passed |
| `dart format --output=none --set-exit-if-changed` 本次 10 个非生成 Dart 文件；修复后仅重查改动文件 | 0 | 工具输出 `0 changed`；未自动重写实现 |
| `git diff --check` | 0 | 无空白错误输出 |
| `bash scripts/ci_guard_checks.sh`，补齐 Python 3.12 与 Dart PATH | 0 | `<local-artifacts>/velo-rating-guard-final.log` |
| `python3 scripts/checks/check_hardcoded_strings.py` | 0 | `<local-artifacts>/velo-rating-hardcoded.log` |
| `python3 scripts/checks/check_user_facing_errors.py` | 0 | `<local-artifacts>/velo-rating-errors.log` |
| `dart run scripts/checks/check_icon_consistency.dart` | 0 | `<local-artifacts>/velo-rating-icons.log`，扫描 1003 个非生成文件 |
| `python3 scripts/checks/clean_translations.py --check --strict` | 0 | `<local-artifacts>/velo-rating-translations.log` |
| `flutter analyze` | 255 | `<local-artifacts>/velo-rating-analyze.log`；LSP JSON `Unexpected end of input`，未得到代码诊断；中文路径只是未证实猜测 |
| `dart analyze --format machine` | 0 | `<local-artifacts>/velo-rating-dart-analyze-final.log`，无诊断；不替代宣称 flutter analyze 成功 |
| `scripts/codegen.sh --check` | 1 | `<local-artifacts>/velo-rating-codegen.log`；隔离完整生成成功，22 个本轮翻译生成文件被 dirty-generated 规则列出 |
| 同一 codegen 检查器增加只读快照记录，保留原检查与返回值 | 1 | `<local-artifacts>/velo-rating-codegen-content.log`，`OBSERVED_GENERATED_CONTENT_DIFFERENCES: 0`；辅助脚本 `<local-artifacts>/velo-rating-codegen-observer.py` |
| `flutter build bundle --debug` | 0 | `<local-artifacts>/velo-rating-build-bundle.log`；产出 `build/flutter_assets/kernel_blob.bin`，是 Dart/assets 编译，不是 APK |

首次 guard 因 Python 3.9 语法错误、随后因缺少 Dart PATH 失败；环境补齐后的实际结果才列为通过。规则脚本日志中的商店/发布字样来自其自带离线测试，未执行真实发布。

## 修复闭环

- 首轮发现 `MediaCard` 的 Object 类型取 globalKey 编译失败、语义句柄未释放、TV 动画 Stack 无界高度，以及自然高度用例错误假定窄宽能放两列；统一交回原作者修复，本代理未改实现或测试。
- 废弃语义 API 改写曾误用不存在的字段，按当前 SDK 的 `isFocused == Tristate.none` 修正后通过。
- 自然高度问题最多两轮修复：最终保留 190 窄宽行为，另用 300 宽度验证两项同排，直接检查实际行数和无空槽。没有通过放宽所有高度断言隐藏失败。
- 最终 30 项通过；日志仍有 SVG `<metadata/>` 非失败提示，未在本轮修改既有图标资源。

## 文件与范围清单

相对准备阶段无 tracked 修改的基线，本轮作者修改 52 个 tracked 文件：

- `lib/utils/rating_display_policy.dart`、`lib/widgets/media_rating_badge.dart`、`lib/widgets/media_ratings_strip.dart`、`lib/widgets/media_card.dart`、`lib/widgets/tv_spotlight_background.dart`。
- `test/widgets/media_ratings_strip_test.dart`、`test/widgets/home_hero_info_only_test.dart`、`test/widgets/tv_browse_rail_test.dart`。
- 22 个 `lib/i18n/*.i18n.json` 的既有 `showRatingBadgesDescription` 与对应 22 个生成 Dart 文件；语言为 az/bg/da/de/en/es/fr/hu/it/ja/kk/ko/nb/nl/pl/pt/ru/sv/tr/uz/zh/zh-Hant。生成文件由作者 slang 生成，QA 只检查。

本轮新文件：`lib/theme/rating_presentation_tokens.dart`、`test/utils/media_card_rating_policy_test.dart`、本文。原先已经 untracked 的 `design/prototype-v2/`、`docs/player-native-observations-2026-11-13.md`、`docs/ui-refresh-validation-2026-11-10.md` 保留；原有 untracked 的 `docs/rating-badges-plan-2026-11-13.md` 由作者按任务同步。QA 唯一仓库写入为本文，未覆盖上述其他产物。

采用具名默认上限：poster=1、hero=4、detail=4；按现有启用来源顺序选有效值，无有效分隐藏。保留 `TODO(VELO-P3-01)` 来源优先级/设备确认，新增 `TODO(VELO-P3-02)` 四来源大字设备确认。未添加新 API key、评分来源请求、豆瓣、SQL 或缓存工程。

## 未完成的验证与交付限制

- 当前 ADB 无设备，未发现已有 JDK；Xcode 仅 CommandLineTools。本轮没有编译 APK、安装到设备、开启模拟器、真实手机/TV 交互或拍摄正式 App 截图；没有安装工具或改全局配置。
- 未连接真实 Plex/Jellyfin/Emby，测试使用构造数据；未验证真实服务来源完整性、个人评分编辑保存、离线编辑入口或重启持久化。
- 未做 390 宽度完整界面、纯黑主题、真实浅/深海报、完整首页 200% 字号构图和真实遥控器焦点验收。320/TV 数据仅来自上述 Flutter Widget 实际布局测试。
- 未跑无关全量单测与整个 `ci_checks.sh`，本轮按范围执行相关 5 个测试文件及明确列出的规则检查；没有提交授权，也未提交推送。
- 不把 flutter analyze 的工具协议失败或 codegen 的未提交约束隐去。实际生成内容一致，但提交前仍需在合适环境完成原命令要求；本文不构成全平台发布验收。
