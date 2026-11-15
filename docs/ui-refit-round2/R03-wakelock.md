# R3 屏幕常亮收尾 任务卡

- 基线提交:`8885b39`(与清单所用 `fe12755` 之间只多一个纯文档提交,代码行号一致)
- 声明:静态读码,未运行。本环境无 flutter,未跑 analyze/测试,未上真机。行号动手前用 grep 复核。
- 目标:消除"首帧后 ExoPlayer 短暂进入 IDLE 导致常亮被瞬时释放"的隐患,并用真机数据完成 30 分钟不熄屏验收。
- 优先级:R3-1 中(代码),R3-3 高(真机验收),其余低。
- 规模:代码小(约 1 个新类 + 策略 1 个参数 + 测试),真机验收另算。
- 前置依赖:无。R3-3 需要 Android 手机和 Android TV 各一台(或至少一台)。
- 不在范围:不改退避 1/2/5s 与重申 5s(R3-4 仅记录);不在原生核心写 `FLAG_KEEP_SCREEN_ON`(R3-2 / 待确认 C13,无真机数据前不加);不动 iOS/桌面常亮;不改 mpv 与 ExoPlayer 的选择逻辑。

## 1. 涉及文件表

| 文件 | 行号(HEAD 8885b39) | 现状 | 动作 |
|---|---|---|---|
| `lib/screens/video_player/screen_awake_policy.dart` | 5-27;idle 分支 `:23` | `idle => openingWithPlayIntent`,首帧后 idle 一律不常亮 | 改:新增参数 `idleGraceActive` |
| `lib/screens/video_player/idle_wakelock_grace.dart` | 无 | 无 | 新增:宽限计时类 |
| `lib/screens/video_player/parts/playback_services.dart` | 监听 `:205-209`;buffering 监听 `:223-228`;`_shouldKeepPlaybackScreenAwake :837-859`;`_syncPlaybackWakelock :861` | 注意路径在 `parts/` 下(`video_player_screen.dart` 的 part 文件) | 改:持有宽限实例并传参 |
| `lib/screens/video_player_screen.dart` | `_wakelockController :167`;`_setWakelock :2762-2763`;`didChangeAppLifecycleState :1184`;paused 分支释放 `:1631`;启用 `:2161`;释放 `:2551` | `_setWakelock` 实际是 `enabled && _shouldKeepPlaybackScreenAwake()` 双重判断 | 改:dispose 时释放宽限计时器;其余不动 |
| `lib/screens/video_player/wakelock_controller.dart` | 工厂 `:11-28`;`TODO(VELO-P1-01) :14`;重试 `:132-141`;`_reconcile :92-124` | 失败后按 1/2/5s 退避,同原因只记一次日志 | 不改(R3-4) |
| `packages/wakelock_plus/android/src/main/kotlin/dev/fluttercommunity/plus/wakelock/Wakelock.kt` | 全文 52 行;`toggle :21`;`applyRequestedState :28`;activity setter `:11-15` | 保存 `requestedEnabled`,Activity 重新 attach 自动重放;无 Activity 抛 `NoActivityException` | 不改,仅真机观察 |
| `android/app/src/main/kotlin/com/edde746/plezy/exoplayer/ExoPlayerCore.kt` | `emitPlaybackActivity :481-494`;`emitPlaybackErrorOnce :501-520`(发 idle+false);状态回调 `:1218-1273`(末行 `emitCurrentPlaybackActivity`);`handlePlayerError :1347`;解码器恢复 `:1490-1545`(prepare `:1542`);音频恢复 `:1588-1650`(prepare `:1649`);DV 重载 `:3838-3876`;外挂字幕重载 `:4058-4075`、`:3995-4005`;`stop() :3895` | 恢复路径 `setMediaSource` + `prepare()`;错误后 Media3 先到 IDLE | 不改(原生);只读核对 |
| `lib/mpv/player/player_base.dart` | `playback-activity :677-693`;reload 清空 `:1345-1376` | activity 按 sourceId 过滤;reload 时置 null | 不改 |
| `lib/mpv/player/platform/player_android.dart` | `:85` | 回退 mpv 时忽略 `playback-activity`,并置 null | 不改 |
| `android/app/src/main/kotlin/com/edde746/plezy/mpv/*` | grep `KEEP_SCREEN_ON` 无命中(只有 debug 的 `MpvLifecycleTestActivity.kt`) | mpv 原生无常亮兜底,完全靠 Dart | 不改(R3-2) |
| `test/screens/video_player/screen_awake_policy_test.dart` | 用例 `:10`(矩阵)、`:39`、`:58`、`:64`、`:81`;辅助 `_visible` 在文件末 | 矩阵用例断言 idle 一律 false | 改 + 新增 |
| `test/screens/video_player/idle_wakelock_grace_test.dart` | 无 | 无 | 新增 |
| `test/screens/video_player/wakelock_controller_test.dart` | 19 个用例,退避相关 `:46`、`:69`、`:319` | 现有行为已覆盖 | 不改(R3-4 调参时才改) |
| `test/screens/video_player/playback_wakelock_lifecycle_test.dart` | `:71` 单用例,mock 平台通道 `:259` | 整屏生命周期 | 改动后必须仍通过 |

## 2. 逐步修改说明

### R3-1 IDLE 短暂释放(宽限期)

**隐患的触发路径(代码推断,未实机证实)**
1. ExoPlayer 播放中遇到可恢复错误,例如解码器恢复(`retryVideoDecoderInPlace`,`ExoPlayerCore.kt:1490`)、音频输出恢复(`:1588`)、DV 转换重载(`:3838`)。
2. Media3 在 `onPlayerError` 后把播放状态置为 `STATE_IDLE`(Media3 文档行为,本仓库代码里未看到证据,待真机日志验证)。`handlePlaybackStateChanged`(`:1218`)末尾调用 `emitCurrentPlaybackActivity`(`:1272`),向 Dart 发 `playback-activity {phase: idle, playWhenReady: true}`。恢复代码此时已存了 `savedPlayWhenReady` 并会 `prepare()`,所以 playWhenReady 仍为 true。
3. Dart 侧 `player_base.dart:677` 收到后 `setPlaybackActivity`,`playbackActivity` 流触发 `_syncPlaybackWakelock`(`playback_services.dart:205-208`)。
4. 策略 `screen_awake_policy.dart:23`:`idle => openingWithPlayIntent`。首帧已渲染后 `openingWithPlayIntent` 为 false(`playback_services.dart:852-857` 要求 `!_firstFrame.rendered`),所以返回 false,`_setWakelock(false)` 立即清除 `FLAG_KEEP_SCREEN_ON`。
5. `prepare()` 之后状态变 BUFFERING/READY,再次发 activity,常亮才被重新申请。中间这段(毫秒到数秒)没有常亮;若恰好系统息屏计时已接近到点,屏幕会变暗或熄灭。
- 不会触发的情形:`setMediaSource` 作用在已 prepare 的播放器上通常直接进 BUFFERING,不经过 IDLE;所以只有"错误后恢复"这类路径有风险。
- 不属于本隐患(应继续释放):`emitPlaybackErrorOnce`(`:501`)先把 `playWhenReady` 置 false 再发 idle,策略自然返回 false;致命错误由 `fatalError` 参数拦截;`stop()`(`:3895`)是用户退出。

**现状 → 改成什么**
- 现状:首帧后 idle 必释放。
- 改成:首帧后进入 idle 且 `playWhenReady=true` 时,给一个宽限期;宽限期内仍视为"要常亮",宽限结束仍是 idle 才释放。
- 与清单的差异:清单写"idle 且 playWhenReady=true 且无致命错误时一直保持"。本卡改为"有限宽限",避免卡死在 IDLE 时一直亮屏。宽限时长是业务数值,做成可注入参数,默认 5 秒,`TODO(VELO-P1-02)`,拿到 R3-3 真机日志后调整。

**具体做法**
1. 新增 `lib/screens/video_player/idle_wakelock_grace.dart`:
   ```
   class IdleWakelockGrace {
     IdleWakelockGrace({
       Duration grace = const Duration(seconds: 5), // TODO(VELO-P1-02)
       required VoidCallback onExpired,
     });                         // grace 必须 > 0,否则 ArgumentError(与 WakelockController 风格一致)
     bool get active;            // 处于 idle 宽限内
     void update(PlayerPlaybackActivity? activity, {required bool firstFrameRendered, required bool fatal});
     void dispose();
   }
   ```
   规则:`activity?.phase == idle && activity.playWhenReady && firstFrameRendered && !fatal` 时,若尚未计时则启动一次性 `Timer(grace)`,`active=true`;计时到期置 `active=false` 并调 `onExpired`(屏幕据此重新同步常亮,结果为释放)。phase 变成非 idle,或 activity 为 null,或 playWhenReady 为 false,或 fatal:取消计时,`active=false`。同一段连续 idle 只计一次时,不因重复事件重置计时。
2. `screen_awake_policy.dart`:函数新增 `bool idleGraceActive = false`(带默认值,旧调用与旧测试不变);idle 分支改为 `PlayerPlaybackPhase.idle => openingWithPlayIntent || (idleGraceActive && activity.playWhenReady)`。
3. `parts/playback_services.dart`:
   - 屏幕 State 持有 `IdleWakelockGrace`,`onExpired: _syncPlaybackWakelock`;在 `dispose`(`video_player_screen.dart` 的 dispose,约 `:2444-2552` 一带,具体处待核对)里 `dispose()`。
   - 在 `:205-209` 的 `playbackActivity` 监听里,先 `grace.update(currentPlayer.state.playbackActivity, firstFrameRendered: _firstFrame.rendered, fatal: _hasFatalPlaybackError || _playerInitializationError != null || _playbackFailureMessage != null)`,再 `_syncPlaybackWakelock()`。
   - `_shouldKeepPlaybackScreenAwake`(`:837`)向策略传 `idleGraceActive: grace.active`。
   - 换源/重新打开(`:1188` 创建新 attempt 处)调用 `grace.update(null, ...)` 复位。
4. 不要改 `WakelockController`:释放判断仍在策略层。

### R3-2 mpv/原生兜底(只评估,无数据不改)
- 现状:mpv 原生无 keep-on,靠 Dart;ExoPlayer 同样靠 `playback-activity`。对方刻意不在原生核心写 FLAG。
- 做法:本包不改代码。R3-3 的日志里若出现"播放中屏幕熄灭且 Dart 侧没有 release 日志",才开新任务;届时在 mpv 原生侧由唯一 owner 设置,不得与 `Wakelock.kt` 的 `requestedEnabled` 重放冲突。结论写入提交说明(待确认 C13)。

### R3-3 真机验收(见第 7 节详细步骤)

### R3-4 退避参数
- 不改;`TODO(VELO-P1-01)` 保留。真机观察到 `Wakelock enable failed` 后再调常量;调整时同步改 `wakelock_controller_test.dart` 中 `:69` 一带的退避用例。

### R3-5 mpv 停在末尾窗口不申请 / 后台释放
- 不改(`playback_services.dart:158-168`、`screen_awake_policy.dart:18` 合理)。写进验收观察项。

## 3. i18n / 常量

- i18n:无。
- 常量:

| 名称 | 默认值 | TODO 编号 |
|---|---|---|
| `IdleWakelockGrace.grace`(构造参数) | 5 秒 | `TODO(VELO-P1-02)` 新增 |
| `WakelockController.refreshInterval` | 5 秒(不改) | — |
| `WakelockController.retryDelays` | 1s/2s/5s(不改) | `VELO-P1-01` 已有 |

## 4. 形态与主题要求

- 手机/平板:Android 前台与 PiP 内都要常亮;`lifecycle` 为 hidden/paused 且非 PiP 时释放(现状)。
- TV:`tvBackgroundSuspended` 时释放(现状);Android TV 同样 30 分钟验收。不涉及焦点控件。
- 桌面/iOS:本包不改,策略共用但这些平台通常不出 idle 事件(ExoPlayer 仅 Android);回归跑单测即可。
- 主题:无界面改动,三主题无要求。

## 5. 测试要求

改现有 `screen_awake_policy_test.dart`:
- `:10` 的矩阵用例保持不变(默认 `idleGraceActive=false`,idle 仍为 false),确认仍通过。

新增(同文件):
- `idle + playWhenReady=true + idleGraceActive=true + 无 fatal => true`
- `idle + playWhenReady=true + idleGraceActive=true + fatal => false`
- `idle + playWhenReady=false + idleGraceActive=true => false`
- `idle + playWhenReady=true + idleGraceActive=false + opening=false => false`(旧行为不变)
- `idleGraceActive=true` 但 `completed`/后台/automotive 阻断仍为 false

新增 `test/screens/video_player/idle_wakelock_grace_test.dart`(用 `testWidgets` + `tester.pump`,风格同 `wakelock_controller_test.dart`):
- `holds active during the grace and expires once`:注入 `grace=1s`,idle+true+首帧后 → `active==true`;999ms 仍 true、`onExpired` 未调;再 1ms → false,`onExpired` 恰好 1 次。
- `recovery before expiry cancels the timer`:idle 后 500ms 收到 buffering → `active==false`,到期后 `onExpired` 不再调用。
- `repeated idle events do not restart the timer`。
- `no grace before the first frame, on fatal, or when playWhenReady is false`。
- `dispose cancels a pending timer`。
- `non-positive grace throws ArgumentError`。

整屏回归:`playback_wakelock_lifecycle_test.dart` 必须仍通过(它在同一 FakeAsync 时钟上跑,新计时器要在 dispose 中取消,否则会报 pending timer)。

## 6. 提交拆分

1. `feat(播放器): 常亮策略支持 IDLE 宽限参数`(policy 参数 + policy 测试)
2. `feat(播放器): 新增 IDLE 常亮宽限计时器`(新类 + 其测试)
3. `fix(播放器): 首帧后短暂 IDLE 不再释放屏幕常亮`(接入 playback_services / 屏幕 dispose)
4. `docs: 记录屏幕常亮真机验收结果`(真机数据整理后,仅文档,放在 R3-3 完成后)

## 7. 验收清单

命令:
- [ ] `flutter analyze` 无新增告警
- [ ] `scripts/run_tests.sh test/screens/video_player/screen_awake_policy_test.dart test/screens/video_player/idle_wakelock_grace_test.dart test/screens/video_player/wakelock_controller_test.dart test/screens/video_player/playback_wakelock_lifecycle_test.dart`
- [ ] `scripts/run_tests.sh` 全量通过

真机(R3-3,两种后端各做一遍;设置里切换播放内核,具体入口待核对):
1. 记录设备型号、Android 版本、构建版本、后端(ExoPlayer / mpv)。
2. 系统设置把"屏幕超时/休眠"设为最短(30 秒)。关闭省电模式的自动变暗以外的干扰项,并记录。
3. 终端开日志:`adb logcat -c`,然后 `adb logcat -v time | grep -E "Wakelock|wakelock|ExoPlayerCore|MpvPlayerCore|flutter"`。重点:`Wakelock enable failed`(Dart 的 `appLogger.w`,release 包是否输出取决于日志级别设置,待核对;必要时在应用设置里开调试日志)、`playWhenReady lost`、`video-recovery`、`audio-recovery`。
4. 长播:同一个 ≥30 分钟视频,开始后不触碰屏幕,屏幕全程不变暗不熄。记录有无变暗时间点。
5. 暂停:手动暂停,最多等一个系统息屏时间(30 秒)后屏幕应变暗/熄灭;再点播放,屏幕恢复并保持常亮。
6. 缓冲:用限速或断网制造缓冲(`paused-for-cache`),缓冲期间屏幕不熄;网络恢复后继续。
7. PiP:进入 PiP 后不触碰,PiP 窗口期间屏幕保持;退出 PiP 回到全屏仍常亮。
8. 前后台:按 Home 切后台(非 PiP)→ 应释放,30 秒后屏幕可熄;回到前台继续播放 → 应重新常亮。锁屏再解锁同理。
9. 恢复路径(验证 R3-1):在 ExoPlayer 下尝试触发解码器/音频恢复(例如播放高码率 HEVC/DV 片源,或切换音轨/外挂字幕触发重载),`grep "video-recovery\|audio-recovery\|idle"` 查看是否出现 idle 事件并确认屏幕未闪灭。若始终不出现 idle,则在提交说明里写"本隐患未能复现"。
10. TV:Android TV 同样 30 分钟,遥控器不操作。
11. 结果(通过/失败、`Wakelock enable failed` 次数与时间点、设备信息)写入第 4 个提交的说明或 PR 描述。

## 8. 风险与待确认

- 待确认:Media3 在 `onPlayerError` 后是否一定先到 IDLE,以及 `emitPlaybackActivity` 是否真的在恢复期间被 Dart 收到(只看了代码,未跑)。第 7 节第 9 步用来验证。
- 待确认 C6/C13:宽限 5 秒是推断值,退避/重申不变;mpv 原生兜底无数据前不加。
- 风险:宽限期内若 ExoPlayer 实际卡在 IDLE,最多多亮 5 秒屏幕,可接受。
- 待核对:屏幕 State 的 dispose 具体行号(`video_player_screen.dart` 内 `_firstFrame.dispose()` 在 `:2444`,据此附近加入即可);核对方法:`grep -n "_firstFrame.dispose" lib/screens/video_player_screen.dart`。

禁止事项:
- 不直接改生成的 Dart 文件(本包不涉及 i18n,若误动文案,改 `lib/i18n/*.i18n.json` 后运行 `dart run slang`;全量生成用 `scripts/codegen.sh`,检查用 `scripts/codegen.sh --check`)。
- 不删除 Plex/Jellyfin/Emby/一起看/TV 支持;保留 mpv 与 ExoPlayer。
- 不在原生核心直接写 `FLAG_KEEP_SCREEN_ON`(无真机数据前)。
- 不提交日志、构建产物、凭据、本地参考文件。
