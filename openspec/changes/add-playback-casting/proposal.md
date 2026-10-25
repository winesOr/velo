# Proposal

## Why

播放器的投屏入口目前只显示未支持提示。用户需要把当前影片的服务器播放地址交给普通 DLNA 电视，确认起播后即可退出手机应用，由电视独立取流与遥控。

## What Changes

- Android 手机播放器接入真实 DLNA 设备发现、刷新、选择与一次性播放投送。
- 复用后端的自包含鉴权直链解析，保留所选媒体版本及续播位置；不复用手机本地文件或转码会话。
- 投送前暂停本地，失败恢复；确认远端起播后结束本地播放器，关闭控制连接不发送 Stop。
- 说明原格式、字幕、弹幕和分段文件边界；离线文件、直播和一起看暂不开放此入口。
- 增加协议、播放地址及交互测试，并保留真实电视验收记录。

## Capabilities

### New Capabilities

- `playback-casting`: Android 到 DLNA 接收器的一次性影片投送与独立播放。

### Modified Capabilities

无。当前主规格目录为空，既有视觉 change 中的占位行为由此新能力接续。

## Impact

新增独立 DLNA 协议/发现/投送服务和播放器玻璃选择面板；扩展播放器回调、Android 组播支持与 slang 文案。复用现有 http/xml 依赖，不新增第三方投屏库、不替换 mpv/ExoPlayer、不修改 reference。服务器转码、持续遥控/进度上报、Google Cast、AirPlay、自有 TV 投送及一起看联动不在本期范围。
