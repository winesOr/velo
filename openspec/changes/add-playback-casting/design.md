# Design

## Context

动机见 proposal.md。现有投屏面板为占位。MediaServerClient.resolveExternalPlayback 已提供 Plex/Jellyfin/Emby 的带鉴权原文件地址；Jellyfin/Emby 的调用不创建转码会话。Plex 可返回多文件 partTimeline。播放器持有本地进度上报、转码清理和退出流程，不能把现有转码 URL 直接交给电视。仓库已有 xml 7 与 http；候选 dlna_dart 依赖 xml 6，因此不直接引入该包。

## Goals / Non-Goals

**Goals:** 以独立、可测试的协议服务实现一次性移交；成功后仅电视取流；沿用播放器玻璃面板、slang 和焦点组件。

**Non-Goals:** 不增加常驻投屏控制器、手机中继、转码保活或后台播放服务，不假设电视拥有手机解码、字幕、弹幕或同步能力。

## Decisions

1. `lib/services/casting/` 放置纯 Dart 的 DLNA 描述解析、SSDP 发现、SOAP 控制和独立直链解析；复用现有 http/xml。Android 只补一个作用域化组播锁桥接。替代方案是引入 DLNA 插件，但目前依赖或平台限制增加不必要耦合。
2. 发现采用有时限的 M-SEARCH，按 UDN 去重；解析 URLBase、相对 controlURL 和服务版本，只接受 MediaRenderer 的 AVTransport。关闭或刷新取消旧扫描；网络响应与 SOAP 有超时和大小边界。
3. 直链解析复用 resolveExternalPlayback，固定所选 mediaIndex/mediaSourceId，拒绝多文件、光盘镜像和回环地址。既有本地缓存与当前手机 HLS 均不作为投送来源；不修改当前播放器质量与字幕设置。
4. SOAP 使用 XML builder 转义带 token 的 URL、标题和 DIDL-Lite。按 SetAVTransportURI → Play → 检查当前媒体/TransportState 执行。非零位置尝试 Seek；拒绝时返回明确从头播放结果。确认与重试只存在于一次有界调用内。
5. 面板负责临时发现与投送。移交前暂停本地，成功后经专用回调退出本地播放器；释放协议客户端不调用 Stop。失败时只在未确认电视播放的情况下恢复本地，避免双端同时播放。进行中的投送禁止面板返回/重复点击；应用被杀后的远端结果不能被手机自动补偿。
6. 首版 Android 在线点播可用；直播、离线和一起看显示具体不可用原因，其他平台沿用尚未支持提示。音轨/内嵌字幕由电视自行选择，外置字幕和弹幕不跟随。

## Risks / Trade-offs

- [电视格式与 Seek 差异] → 面板提前说明原格式边界；确认起播；续播拒绝时展示从头播放提示，保留测试记录。
- [手机可访问但电视不可访问服务器] → 使用服务器原址；报错不泄漏 URL/token；最终以电视状态及真设备持续播放验收，不以手机 HTTP 成功替代。
- [投送期间应用被杀或网络断开] → 操作有限时，不承诺取消已发送命令；绝不发送退出 Stop，结果不确定时避免自动恢复双端声音。
- [多文件无法无人值守换 part] → 本期拒绝多文件地址，避免只播放半部电影。
- [iOS 原始组播需要 entitlement] → 首版只开放 Android，不将纯 Dart 跨平台误当已完成 iOS 验收。

## Migration Plan

无数据迁移、无新依赖。替换播放器占位面板；回滚时恢复占位入口并移除新服务/组播桥接即可，不改变服务器或媒体。真实电视和强制结束手机验收在 tasks 中保持独立未完成项，模拟测试仅验证协议与生命周期行为。
