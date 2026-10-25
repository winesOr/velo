# P0 实施与验收记录

> 历史阶段记录：以下结论保留当时语境。2026-10-23 后续 P1 实施及新包交付见 `fusion-delivery.md`；这里记录的旧 APK 已按用户要求清理，不再作为当前安装包。

日期：2026-10-23。范围：本 change 的任务 1–4；P1 尚未实施。P0 已实现，18/22 项勾选；4.2 的间歇测试结论及 4.3–4.5 的实环境验收保持未完成。

## 实现映射

| 任务 | 实现与证据 |
| --- | --- |
| 1.1–1.4 | `lib/danmaku/danmaku_{source,settings,settings_repository,session}.dart`；空源、源 CRUD/顺序/连接测试、带路径前缀地址、版本化持久化及敏感导出隔离。`test/danmaku/` 覆盖持久化、失败、作用域与 HTTP fixture。 |
| 1.2、1.5 | 两个 `danmaku_*_sheet.dart`；首次添加/取消、本地导入、slang 英文/简体/繁体及生成翻译。`test/widgets/danmaku_settings_sheet_test.dart` 验证窄屏、大字体、键盘操作和保存失败。 |
| 2.1–2.7 | v2 三步/旧路由兜底、自有签名、顺序换源、作用域匹配记忆和有效偏移。协议与独立签名样本见 `lib/danmaku/README.md`。 |
| 2.5–2.6 | `DanmakuPlaybackBinding` 接入播放器初始化、换集、回滚、profile 切换和 dispose；owner token 隔离旧页面，订阅当前播放器 duration。绑定测试验证旧路由不能修改后继播放会话。 |
| 3.1–3.5 | `DanmakuHeatmap` 分桶/P95/九桶平滑/缓存；`BufferRangePainter` 同 canvas 绘制热度、章节、缓冲和跳过区间；时间轴点击、长按、TV 长按确认与取消行为。位置更新不触发数据重新统计。 |
| 4.1 | `VideoControlsHeader` 使用已映射自身/父级 Logo，保留 tag 并设置 maxHeight=720、quality=90；失败回退文字，随原 HUD 生命周期显示。 |

## 验收环境

- macOS 本地 checkout；Flutter 3.47.7 / Dart 3.13.5，SDK `<flutter-sdk>`。
- Python 3.13 用于仓库代码生成脚本；JDK17 `<jdk-home>`。
- Android 使用已有 `prebuilt_mpv/` 本地预编译产物。
- `adb devices -l` 无连接设备。未提供自有官方 AppId/AppSecret，因此未进行真实官方请求。
- `CredentialVault` 沿用项目现有本地加密机制；不是系统 Keychain。普通配置导出排除弹幕敏感资源。

## 自动化检查记录

- 首轮 `flutter analyze`：子包 `packages/wakelock_plus` 开发依赖未初始化导致 49 个诊断；在该子包执行 pub get 后，全仓复跑 **No issues found**。未修改子包源码。
- `scripts/codegen.sh` 成功。所有 locale 按规范补齐空键，slang 配置使空键回退英文。原始 `--check` 同时检查内容和未提交的生成文件；当前翻译生成文件未提交，因此原始检查失败。临时调用原检查器并仅移除 `_dirty_generated_paths` 条件，隔离重生成内容比对退出 0；没有修改检查器或 Git index。之后的 locale 规范化再次完整 codegen 成功。
- 首轮 CI：Dart analyzer、硬编码文案、用户错误文本、工作流守卫、native format、unused code 和 unused files 通过。
- CI 基线问题：未改动的 ambient_palette_extractor、vidhub_ambient_backdrop 及其测试有格式差异；原 track_chapter_controls 也有格式差异，因本次入口修复已格式化。翻译检查报告原有 lockScreen/longPressToUnlock/screenLockButton 三个未使用键。原有 video_controls 锁屏分支仍用两个 Icons，属于既有图标违规。
- 新增图标违规已全部改为 AppIcon + rounded Symbols；最后图标检查仅剩 HEAD 已存在的两个锁图标。翻译规范化复验仅剩 HEAD 已存在的三个未使用键。`git diff --check` 通过。
- Android arm64 release 多次构建成功；最终产物见下方记录。

### 已通过的测试批次

- 冻结 P0 源码后的最终合并回归：**221/221 全部通过**（33 秒），包括所有下列 P0 测试、完整 video_controls/player_ui_refinement 及桌面点击回归。命令与日志保存在 `dist/p0-acceptance-2026-10-23/`。
- 父代理 P0 综合集成：**104/104**，覆盖 test/danmaku、设置面板、热力时间轴、播放器入口、Logo 和播放绑定。
- 控件/时间轴/入口最终回归：**119/119**，包括弹幕独立图标、九焦点节点及取消拖动不提交 seek。与上批有重叠，不能相加作为去重总数。
- 后端 HTTP/会话/overlay：**58/58**；设置面板 **14/14**；热力图算法/绘制/交互 **18/18**；原时间轴 **14/14**。包含在综合批次或回归中。
- 最终全仓 `flutter analyze`：**No issues found**（33.4s）。
- 最终 `scripts/ci_checks.sh` 的 analyzer、硬编码文案、用户错误文本、工作流守卫、native format、unused code/files 全部通过。总退出非零仅涉及上述三文件格式、三个既有未使用翻译、两个既有锁图标，以及未提交生成文件检查；没有将其写成 CI 全绿。

### 全仓诊断与验收限制

- 实施期间运行的全仓测试耗时 25:06，结果 **8042 通过、6 跳过、10 失败**。该运行跨越修复和新增测试，不作为最终冻结版本的通过证据。
- 其中 API 畸形数组、Logo 大字体、三个设置面板用例和字幕/弹幕图标冲突，均已在冻结版本的 221 项合并回归中通过。
- `playback_open_throw_test`、`playback_open_failure_test` 的全仓启动失败在独立复跑中通过。
- Discover 的 `non-TV hero keeps indicators visible in keyboard mode and fades to solid bg` 在 pristine HEAD 上同样失败于第 727 行，已确认既有基线；未改动首页实现或该测试。
- `ambient_lighting_startup_restore_test` 当前工作区独立三次结果为通过/失败/失败，HEAD 三次通过。之后同一隔离当前副本插桩，保留与移除弹幕绑定交替各三次均通过；相同六个启动测试并发组，保留绑定 6/6、移除绑定 6/6 均通过。字体准备 414–676ms，首次条件达成 619–886ms，没有稳定的绑定额外延迟。这些结果提示时序敏感性，但尚不能证明早期失败与本次改动无关；不以之后通过抹去该限制，也未放宽公共测试超时。临时插桩和隔离目录已移除，共享生产代码未因诊断修改。**4.2 暂不勾选**，后续应在固定负载下复验并关闭此疑点。

### 最终产物

- APK：`dist/plezy-p0-arm64-release.apk`，173451855 字节。
- 构建：`flutter build apk --release --target-platform android-arm64`，最终增量构建成功（30.2 秒）。依赖仍带其他 ABI 的 native 文件，Flutter 播放目标为 arm64。
- SHA256：`34a5ba31d61fa6745ac3f7ca3628ac6915385987ddee6fa1c61aabb0dd069d03`。
- APK 未部署到设备；没有连接 Android 手机/TV。

### 验收中修复的问题

- 初始暂停仍可能入队弹幕；短距离 seek 需要使用目标事件重置游标。
- 非对象 API 数组成员被静默丢弃，已改为严格响应错误。
- 源切换、延迟写入、旧页面销毁的竞态与偏移隔离。
- TV/桌面缺少弹幕入口；桌面焦点节点增加至 9，字幕和弹幕使用不同图标。
- 旧取消拖动测试与本次“取消不提交 seek”规格冲突，更新并断言收尾仅一次。
- 切集清除旧候选、写失败即时反馈、编辑源后丢弃旧连接测试结果。
- Logo 失败回退在窄屏/大字体下按文字缩放扩展高度。

## 尚未完成的实环境验收

以下项目保持未勾选，不能用 mock、widget test 或构建成功替代：

1. **4.3**：Android 实机自建网关匹配 → 播放 → 热力跳转 → 重启恢复，记录设备、影片、脱敏源配置和 APK hash。
2. **4.4**：TV 实体遥控器入口/焦点/偏移/长按跳峰；同设备影片开关热力各 60 秒，记录 FrameTiming P95/P99、超预算帧比例及实际刷新率。
3. **4.5**：用户自有官方凭据完成直连搜索、分集、评论链路，记录脱敏 HTTP 结果；不保存真实密钥到本报告。

## 使用与回退

播放界面打开弹幕设置，首次添加自有网关；可取消并导入本地 XML/JSON。按作品、分集手动纠正匹配，集号偏移和时间偏移分别设置。源切换后重新匹配。热力图的点击、长按原始计数和 TV 操作见 `lib/danmaku/README.md`。

关闭热力图可恢复普通时间轴；关闭弹幕可停止绘制。源删除会清除对应匹配记忆。代码回退时只回退本次 P0 文件，保留用户此前的 design、openspec、reference 和其他未提交改动；本轮未自动提交或归档整个 change。
