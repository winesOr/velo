> 历史研究摘要，来自本地资料快照 `c350c4a`（2026-11-14 整理）。原始证据未公开；文内观察、推断和未验证边界按原文保留，不能当作本次复测结果。公开副本仅脱敏路径并处理未公开证据链接。

# VidHub 首页启动观测（单次，模拟器）

基准点是应用日志 `home_load_started`，不是点击图标或进程创建；表内方法区间是应用日志区间，不是 DNS/TLS/首字节或图片解码时长。

| 阶段 | 相对基准时间 | 观测及边界 |
|---|---:|---|
| 系统启动 Activity | TotalTime 995 ms / WaitTime 998 ms | 单次进程冷启；与下列相对基准不同；不是媒体资源就绪 |
| 来源列表首次就绪 | +77 ms | FileSourceLoadPerf 自身 elapsedMs=1，列表数量仅保留 positive |
| 隐藏 loading | +133 ms | 不是内容全部就绪 |
| all_enabled_sections_ready | +134 ms；日志 elapsedMs=135 | 相应 section.* 数量均 zero；不能作为首次缓存内容渲染 |
| 来源列表提交 | +135 ms | ui_file_sources_committed，列表 positive；不是媒体海报绘制证据 |
| home_resource_flow | +144 ms | positive；没有保留内容/来源名称 |
| getMediaViews | +165 → +1285 ms | 同方法 Succeed，日志区间 1120 ms |
| getResumeItems | +1289 → +1561 ms | 同方法 Succeed，日志区间 272 ms |
| getSystemInfo 开始 | +1811 ms | 本次未保留可配对成功日志，不能认定完成 |
| 5 个 getLatestItems 开始 | +1812 … +1815 ms | 3 ms 内发起方法调用；不是 socket 并发证明 |
| Latest 首个/最后成功 | +2108 / +2168 ms | 5 个成功；未保留库 ID，不能逐一配对或断言 UI 分批提交 |
| 未归属 provider 异常 | +30147 ms | SocketTimeoutException；不把它当首页完成时间 |
| 一次暖回前台 | WaitTime 166 ms；无 TotalTime | 同 PID 2056，系统仅将已有 task 置前；不是资源重新加载166ms |

本次没有页面截图/可视首帧证据，不能判断何时第一张海报、第一行或所有行实际显示。没有读取私有缓存数据库，未证明磁盘缓存命中/TTL；未抓包，未确认后端类型或每个网络阶段。保留原应用数据，冷启前正常force-stop；没有clear-data、重装、退出账号、修改服务器或登录状态。没有与Velo做同设备同服务器测量，不报告倍率/P95。
