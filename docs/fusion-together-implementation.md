# 一起看：原型到真实房间

## 范围与入口

本批对应 `plan-plezy-fusion-redesign` 7.1–7.4，复用既有
`WatchTogetherProvider` / controller / relay 协议；没有重写时钟、房主控制或访客校正。
主导航嵌入 `WatchTogetherScreen(embedded: true, onBack: ...)`，原有独立路由仍使用默认构造。
页面 State 实现 `FocusableTab`，由主壳进入时恢复内容焦点；嵌入模式的返回键交给主壳。

手机窄屏为纵向房间卡片，宽屏（可用宽度至少 760）为房间/成员双栏；大字体回到单栏。
全部按钮、房间卡和输入使用现有 `lib/focus/` 包装，最近房间在 TV 长按确认可重命名/移除。
没有引入原型六位邀请码、固定电影、假成员或“我准备好了”状态。

## 操作

1. 打开“一起看”，创建房间时选择真实控制模式；房间名称仅是最近房间的本地别名，不发明协议字段。
2. 房主将可复制的房间码发送给朋友；加入对话框接受协议允许的 1–64 位字母、数字、`_`、`-`，按现有服务语义转为大写。
3. 最近房间按当前 profile 与中继规范基址隔离；进入时继续使用既有 probe/enterRoom。空房间可能由进入者接管，页面明确提示这一语义，不将历史记录当作仍在线的房间。
4. 房主从媒体库开始播放；访客使用已连接服务器解析房主的 `(serverId, itemId)`，解析成功才允许“加入当前播放”。无服务器、404 或请求失败显示不可用与重试，不根据同名影片猜测替代资源。访客可主动“更换匹配”：在自己已连接的在线服务器中搜索，选择电影或剧集，核对季集与剪辑版本，再明确确认。多版本资源必须选择具体可播放版本；结果列表从不自动分配匹配。
5. 主动离开/结束仍经确认并调用既有 `leaveSession`，立即拆除本地同步绑定；中继销毁/房主退出后显示房间结束提示。断网时显示真实 transport 流的重连状态，成功后仍走原有 resume/快照同步。

## HTTP(S) 中继

设置沿用 `SettingsService.customRelayUrl` 与 `WatchTogetherRelayEndpoint`，没有新存储键。
填写 `https://relay.example.test/watch` 时，派生：

- 健康检查：`https://relay.example.test/watch/health`
- WebSocket：`wss://relay.example.test/watch/relay`

`http` 相应派生 `ws`；拒绝直接填 `ws/wss`、用户密码、query、fragment 和非法端口。
不把设置页文案中的 WebSocket 示例当作可保存基址。页面监听真实中继设置变更，重新检查健康与最近房间；generation 隔离旧健康响应。
空设置继续使用项目原有默认中继，不等于本次已在线验收该公共中继。

## 访客本地匹配

`WatchTogetherProvider` 在当前房间内存中保存一次显式映射，不持久化，也不改变 relay 字段或房主同步协议。协议与同步引擎始终使用房主的 `(serverId, itemId)`；只有本地元数据解析、路由打开与播放器媒体切换使用访客选定的服务器/条目。绑定输出时重新使用房主身份，因此访客晋升房主或同一资源重载也不会意外把访客文件 ID 广播为另一部影片。

- 房主换影片/集数、结束媒体或离开房间时清除映射；打开匹配面板时捕获 playback lease，期间媒体切换/离房后的迟到确认无效。
- 改选本地源时使旧的异步打开与旧输出 binding 失效。旧播放器退出不能结束新匹配正在等待的同一个房间媒体；下一次 heartbeat 或“加入当前播放”使用新映射。
- 搜索按在线服务器分组；相同条目 ID 在不同服务器仍是不同结果；取消搜索/版本选择/确认不修改映射。输入改动使旧查询失效，即使后端忽略 Abort 也不回填旧结果。
- 具体版本优先按后端 source ID 重取，缺失或不可播放时失败，不退回另一剪辑；无 ID 时只接受唯一的签名与版本名匹配。列表重排不改变所选 source ID。在最终 playback resolver 返回后、native open 前再次校验实际版本，覆盖“选取后源下线而后端回退到另一剪辑”的竞态。
- 没有跨服文件哈希或帧对齐证据。季集、时长与剪辑信息供用户核对，同名结果不是自动等价证明。不同剪辑造成的时间轴差异不在本批自动修复。

## 验证证据（2026-10-23）

- `flutter analyze --no-pub lib/watch_together test/watch_together`：无问题，日志 `/tmp/fusion-together-analyze-final.log`。
- `flutter test --no-pub --dart-define=CAPTURE_FUSION=true test/watch_together`：306 tests passed，日志 `/tmp/fusion-together-regression-final.log`。
- 保留既有同步回归；新增真实 loopback WebSocket admission fixture 验证 64 位和 `_-` 标识原样通过协议、加入框粘贴不截断/不剥离字符、非法格式留在表单。
- Provider fixture 验证 transport 断开/恢复、离开后解绑、终止房间提示和新房间清除旧提示。
- Widget fixture 验证 390×844、960×540、320×640/2 倍字体、内容焦点进入/返回壳、缺资源不能开播、空入口创建取消与加入流程。
- 新增 `test/watch_together/local_media_match_dialog_test.dart` 和 Provider 本地匹配回归：显式确认、服务器隔离、版本选择、过期查询/lease、旧 binding 退出保护、房主晋升保留协议身份。最终集中批次 443 项通过，另 8 项本地匹配 UI 测试全部通过（`/tmp/plezy-final-together-tests.log`、`/tmp/plezy-final-local-match-tests.log`；集中首轮的 4 项 spinner 超时已修复并由后者重跑覆盖）。
- 最终版本校验补丁后 `test/screens/video_player/playback_reload_failure_test.dart` 与 `test/watch_together/watch_together_provider_test.dart` 共 73 项全部通过（`/tmp/plezy-final-local-version-tests.log`）。两条新增真实 Screen fixture 经 backend 初始化与 in-place reload，分别证明 source ID 重排仍可打开/重新绑定，以及剪辑回退在 native open 前被拒绝。对应 scoped analyze 无问题（`/tmp/fusion-local-reload-guard-analyze.log`）。
- 截图：`docs/qa/fusion/together-phone.png`、`docs/qa/fusion/together-tv.png`。通过 `CAPTURE_FUSION=true` 重建，加载仓库字体，已人工查看；数据仅来自测试专用 Provider fixture，**不是实际中继/真实双端截图**。

## 未闭环与不可声称

7.1 的真实入口、协议格式、创建/加入/最近房间/离开已有实现和 fixture；7.3 的解析与错误约束已有实现和回归。

7.2 的显式更换匹配、协议身份/本地源分离、版本核对与房间生命周期失效已实现；实际两端不同服务器的观看验证仍属于 7.4，不能用 Provider fixture 代替。

7.4 **未完成**：没有本批实际双客户端同步播放验收、Android/TV 遥控器真机验收，也没有真实中继连接结果、seek 漂移或时钟误差测量。loopback 协议测试与 UI fixture 不是双端看片证据。后续验收需记录两端设备/版本、中继、共同资源、播放/暂停/seek/房主退出/断网恢复与结果。

## 维护与回退

本批新增运行态为中继重连标志、结束提示与房间内显式本地匹配，均不持久化；原最近房间和中继存储结构不变。
回退 UI 时可继续用独立房间路由和既有 Provider，不需要清除用户房间历史。翻译由根任务集中写入 slang 源并生成，未手改生成文件。
