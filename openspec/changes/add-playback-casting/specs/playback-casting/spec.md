# Spec Delta

## Purpose

让 Android 手机播放器把当前影片一次性交给局域网中的 DLNA 电视或盒子播放。接收器直接从已有媒体服务器取流，手机在确认起播后即可退出应用，电视播放不依赖手机持续运行、网络代理或遥控心跳。

## ADDED Requirements

### Requirement: Discover playable receivers

系统 SHALL 仅在播放器中提供投屏入口，Android 在线影片能够扫描、刷新并选择 DLNA 播放接收器，展示扫描中、空列表和失败状态，关闭面板释放发现资源。

#### Scenario: Discover and refresh
- **WHEN** 用户打开面板或刷新
- **THEN** 系统发现局域网媒体接收器并按设备身份去重，忽略非播放设备和无效响应

#### Scenario: Unsupported playback contexts
- **WHEN** 当前处于非 Android 平台、离线播放、直播或一起看房间
- **THEN** 系统给出对应不可用说明，不向电视发起投送

### Requirement: Send independent media URLs

系统 SHALL 使用所选服务器媒体版本的自包含鉴权 HTTP(S) 直链，拒绝本地文件、回环地址及手机转码会话；不建立手机媒体代理，不向接收器发送仅手机支持的请求头。

#### Scenario: Authenticated media
- **WHEN** 用户选择接收器
- **THEN** 电视收到可自行取流的带鉴权播放地址和标题，URL 中的特殊字符经过正确协议转义，原始鉴权地址不进入错误提示

#### Scenario: Unsupported source
- **WHEN** 无法解析独立直链、原文件为光盘镜像、影片为多个连续文件或媒体地址指向回环地址
- **THEN** 系统显示不可投送说明并保留手机播放

### Requirement: Handoff current playback

系统 SHALL 在投送前保存实际播放位置并暂停手机，仅在电视报告当前投送媒体处于播放状态后确认成功；有续播位置时尝试绝对时间跳转，接收器拒绝续播时明确说明从头播放。

#### Scenario: Successful handoff
- **WHEN** 电视报告所投送影片正在播放
- **THEN** 系统提示可以退出手机应用，并结束手机播放器，不再持续遥控或上报远端观看进度

#### Scenario: Failed handoff
- **WHEN** 加载或起播确认失败
- **THEN** 系统显示可重试错误，保留已打开的本地播放器；确定电视未开始该媒体播放时恢复原先的手机播放状态

### Requirement: Detach without stopping playback

系统 MUST 在成功后关闭面板、退出播放器或退出手机应用时只清理手机资源，不向电视发送停止播放指令，不撤销电视使用的媒体地址，也不关闭与电视绑定的服务器播放资源。

#### Scenario: Phone exits after casting
- **WHEN** 投送成功后手机播放器销毁或手机应用退出
- **THEN** 手机不发送 Stop，不运行媒体代理、续期或遥控任务，电视继续直接从服务器播放，并由电视遥控器控制

### Requirement: Present receiver limitations

系统 SHALL 在投送面板说明按原格式播放、兼容性由电视决定、电视端不显示手机弹幕且字幕由电视支持决定，不承诺手机退出后回传观看记录。

#### Scenario: Receiver controls playback
- **WHEN** 用户查看投送说明或成功结果
- **THEN** 界面清楚说明电视独立播放以及字幕和弹幕边界，不显示持续遥控页
