# DLNA 播放投送实现与验收记录

## 状态

本功能实现 Android 手机端在线点播到 DLNA MediaRenderer 的一次性移交。手机只负责发现设备、解析服务器直链、发送 `SetAVTransportURI` / `Play` / 可选 `Seek` 并确认起播；成功后电视直接向 Plex / Jellyfin / Emby 服务器取流，不依赖 Velo 的前台、后台服务、代理或遥控心跳。真实接收器验收尚未通过：2026-10-24 小米电视实测发现 Emby 重定向存储直链在后续 Range 请求中返回 403，不能宣称已完成设备兼容性覆盖。

## 实现范围

- 协议实现位于 `lib/services/casting/`：SSDP 发现、设备描述解析、AVTransport SOAP 投送、独立播放地址解析和本地播放回滚策略。
- 播放器入口位于 `lib/screens/video_player/parts/casting.dart`，设备选择面板位于 `lib/widgets/video_controls/sheets/dlna_cast_sheet.dart`。
- Android 侧只在扫描期间持有 Wi-Fi multicast lock，并在 Activity 销毁时兜底释放。
- 投屏入口保留在播放器内；直播、离线下载、Watch Together、非 Android 平台显示明确不可用文案。
- 复用 `resolveExternalPlayback()`，固定当前 `mediaIndex` / `mediaSourceId`，只投送服务器可独立访问的静态原文件 URL。手机转码 HLS/DASH、回环地址、内嵌凭据、光盘镜像和 Plex 多 part 影片均拒绝。
- 接收器按原格式播放；音轨、内嵌字幕、外置字幕和弹幕不保证跟随。手机端观看进度和远端播放进度不回传。

## 移交流程与错误语义

1. 面板暂停本地播放并解析独立直链；解析失败时恢复原先正在播放的本地状态。
2. 发送带 XML 转义的 URL 与 DIDL-Lite 标题，执行 `Play`，轮询 `GetTransportInfo` / `GetMediaInfo`，只在该 URI 报告 `PLAYING` 时判定成功。
3. 有续播位置时执行 `Seek`；接收器拒绝则仍然完成移交，但成功提示明确说明电视从开头播放。
4. 成功后关闭面板、提示可退出 Velo 并退出本地播放器。关闭 `DlnaSender` 不会发送 `Stop`。
5. 任一远端命令或确认阶段失败时，不向用户暴露 URL、token 或网络响应。发送后结果未知的情况下，手机保持暂停，提示用户先查看电视；只有确定远端未播放时才自动恢复本地声音，避免双端同时播放。

| 阶段 | 用户可见结果 | 本地播放处理 |
| --- | --- | --- |
| 不可用上下文 / 不可独立投送来源 | 显示对应原因 | 不暂停 |
| 解析直链失败 | 提示重试或换来源 | 恢复原播放状态 |
| 接收器明确拒绝、HTTP 错误或响应损坏 | 提示检查电视与服务器后重试 | 仅确定未起播时恢复 |
| 起播确认超时、结果不一致或投送中断开网络 | 提示先查看电视，手机保持暂停 | 不自动恢复 |
| `Seek` 被拒 | 成功，但提示未接受续播位置 | 退出本地播放器 |
| 起播确认成功 | 提示可退出 Velo 并用电视遥控 | 退出本地播放器，不发送 Stop |

SSDP 搜索持续 8 秒，每 2 秒重复发送三种目标：MediaRenderer 设备、AVTransport 服务和 UPnP 根设备。设备按 UDN 去重；描述解析只接受 HTTP(S) location 和 MediaRenderer 的 AVTransport 服务。

## 回滚

该功能没有数据迁移或服务器端状态。回滚时移除 `lib/services/casting/`、播放器 casting part 与导入、DLNA 面板、相关测试、Android multicast 方法和 manifest 权限，再执行 slang codegen 与格式化。若只想临时隐藏入口，可保留实现但恢复播放器按钮到不可用提示；已投送到电视的播放不会因回滚自动停止。

## 自动化验证

记录时间：2026-10-24（Asia/Shanghai）。

- `flutter test test/services/casting test/widgets/dlna_cast_sheet_test.dart`：34 个用例通过。
- `flutter analyze`：通过、无告警。
- `scripts/codegen.sh`：完成；生成翻译文件已更新。随后 `scripts/codegen.sh --check` 仍列出全部未提交的翻译生成文件，这是该脚本把当前工作区所有 dirty generated files 判为 stale 的既有策略；生成命令本身成功。
- `openspec validate add-playback-casting --strict`：通过。
- 完整 `scripts/run_tests.sh`：12:40 完成，8281 个用例通过、6 个跳过、0 失败。

覆盖点包括 URLBase / 相对 control URL、服务版本、UDN 去重、SSDP 多目标、资源释放、XML 转义、鉴权参数方言（Jellyfin `ApiKey`、Emby `api_key`、Plex `X-Plex-Token`）、当前媒体确认、续播拒绝、超时后不确定状态、错误不泄漏 token、发送中禁止重复点击/关闭，以及成功后不发送 `Stop`。

## 真实接收器验收步骤

### 2026-10-24 17:52 小米电视取流失败

设备通过 ADB 识别为 MiTV_MFTR0（Android 9），使用系统 DLNA 接收器。用户从手机重新投送同一 Emby 单文件 MKV，电视日志显示：

1. AVTransport 接收到服务器静态地址；电视 DNS、TCP 连接及 HTTPS 请求成功。
2. 服务器返回 302，重定向到存储 CDN；首次请求返回 206，文件大小 3259839359 字节。
3. 接收器首先尝试 LiteMediaPlayer，读取少量数据后失败并切换到系统播放器。系统播放器也取得初始 206，但读取文件尾部及其他偏移时连续收到 403，日志明确出现 `http_seek_internal fail`。
4. 接收器短暂上报 STARTED，随后在位置 0 上报 PLAYBACK_COMPLETED。因此单次 PLAYING 状态不能证明已稳定播放；更不能作为手机退出后持续播放的验收结果。

受控 HTTP 对照中，分别以 `stagefright/1.2 (Linux;Android 9)` 和 `Lavf/57.83.100` 请求服务器入口，两者均能获取初始 206。对各自返回的最终直链，使用相同 UA 读取文件尾部为 206，换另一 UA 则为 403，确认这些最终链接受 UA 绑定限制。尚未直接观测到电视系统播放器失败的每次请求 UA，不能把其内部 UA 切换写成已证实原因。

又分别将上述两种 UA 从电脑解析得到的最终链接直接投给同一电视，均未起播；此结果说明预解析替换 URL 不能作为已验证的修复，可能还存在出口或接收器请求条件差异。没有增加手机中继、硬编码接收器 UA 或提交未经验证的 URL 替换。日志中的 token、签名、完整媒体地址均不写入仓库；3.2 继续保持未完成。下一步需确认服务器的重定向层能否提供接收器可独立 Range 读取的稳定地址，或由服务器代理媒体请求。

### 2026-10-24 投屏入口修复

用户报告 2.23.8 点击投屏无反应。完整播放器回归复现了原因：`_showCastSheet()` 从 State 的 `context` 查找面板控制器，该上下文在播放器自己的 `OverlaySheetHost` 上方，点击触发 `No OverlaySheetHost found in context`，release 中则无法打开面板。改为使用已有的 `_sheetContext` 解析播放器内部面板。

新增 `test/screens/video_player/casting_sheet_test.dart`，启动真实播放器页面、点击手机布局的投屏按钮、检查实际 `DlnaCastSheet` 与内部 host 打开，再点击关闭并确认仍停留在播放器。修复前测试失败，修复后通过；连同协议、设备面板、手机控件和播放器面板返回回归，共 46 项通过，`flutter analyze --no-pub` 无问题。修复发布为 2.23.9；真实接收器持续播放验证仍单独保留未完成状态。

以下矩阵必须逐项记录设备型号、App 版本、服务器版本、媒体容器、结果和问题。没有任何真实接收器时保持未完成，不得用 mock 或手机 HTTP 请求替代。

### 准备

1. Android 手机、DLNA 电视/盒子、媒体服务器在同一二层网络；服务器地址必须是电视可访问的主机名或 IP，不能是 localhost 或手机代理。
2. 记录 Velo 构建、Android 版本、接收器型号与固件、服务器类型和版本。
3. 每个服务器准备一部单文件影片，优先分别包含 MP4/H.264/AAC 和 MKV/H.264/AC3 或 Dolby Digital，用于暴露接收器格式差异。

### 每个后端的必测路径

1. 在手机播放 2 分钟后打开投屏，选择电视；确认电视显示同一媒体并可起播。
2. 确认电视从约 2 分钟位置继续；若提示未接受续播，确认电视从开头播放且手机提示一致。
3. 使用电视自带遥控暂停、播放、seek；确认 Velo 不弹出遥控页或要求保持前台。
4. 等 Velo 成功退出播放器后，从系统最近任务强制结束 Velo；电视继续播放至少 1 分钟。
5. 在电视上直接停止播放，再重新投送一次；确认第二次仍能发现并起播。
6. 分别测试 Plex、Jellyfin、Emby，并记录静态直链所用的服务器地址类型（HTTP/HTTPS/主机名/IP）。若 HTTPS 失败，同时记录电视浏览器证书错误，以区分网络不可达与证书信任问题。

### 补充边界

- 直播、离线下载、Watch Together、非 Android 平台：确认显示对应不可用原因，不开始扫描。
- 多 part 影片、ISO、手机转码 URL、localhost 地址：确认显示不可投送，手机保持播放。
- 真实电视无法解码原格式时：确认失败提示可理解，且没有双端同时播放。
- 扫描中关闭面板：确认可关闭；8 秒内没有重复提示或残留设备。
