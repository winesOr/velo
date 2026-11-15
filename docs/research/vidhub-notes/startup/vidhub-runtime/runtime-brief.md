> 历史研究摘要，来自本地资料快照 `c350c4a`（2026-11-14 整理）。原始证据未公开；文内观察、推断和未验证边界按原文保留，不能当作本次复测结果。公开副本仅脱敏路径并处理未公开证据链接。

# VidHub 启动运行时简报
1. 证据目录：`design/vidhub-study/evidence/startup/vidhub-runtime/`；本次仅1次进程冷启+1次暖返，无P95/倍率，无Velo同环境实测。
2. 初始ADB无设备/无qemu；正常恢复原研究AVD数据（environment-resume.json:1），未wipe/重装/clear-data/退出账号/修改服务器。
3. cold-launch.json:1：Launcher→MainActivity，COLD TotalTime995ms/WaitTime998ms，PID2056；AVD刚启动，保留app磁盘数据，非首次安装冷缓存。
4. MainActivity最终仍前台（final-front-state.json:1）；未能CUA识别模拟器，无首页海报/首帧视觉确认，不以Activity显示冒充资源完成。
5. cold-startup-phases.json:1与cold-stage-disambiguation.json:1：home_load_started为12:14:43.085；loading_hidden elapsed133ms；all_enabled_sections_ready elapsed135ms，但相应section.*均zero。
6. first_file_sources_ready/ui_file_sources_committed/home_resource_flow列表positive，只证明来源列表非空；不证明首次缓存媒体渲染或图片加载。
7. getMediaViews +165→1285ms（日志方法区间1120ms），随后getResumeItems +1289→1561ms（272ms）；起点相对home_load_started。
8. getSystemInfo +1811ms；5个getLatestItems +1812…1815ms方法发起，首个/最后Succeed +2108/+2168ms；仅日志调度与回调，不是socket并发或UI分批提交证明。
9. +30147ms存在MediaServerFileProvider SocketTimeoutException，未归属端点，不代表首页完成时间；backend-and-failure-derived.json:1。
10. warm-return.json:1：启动Android HOME后暖返同PID2056，WaitTime166ms、无TotalTime，系统明确已有task置前；warm-log-derived.json无新首页/媒体方法日志。
11. backend枚举/client类白名单未匹配；不能从getMediaViews等API名认定Emby/Jellyfin/Plex，也不以库条数推断来源。
12. 不保存原始运行消息、完整URL/query、token、账号、媒体名称、库ID；日志内存白名单提取阶段/时间/方法及zero/positive；无数据送ReArkAI。
13. 缺少网络DNS/TLS/TTFB/具体cache命中/TTL/首张海报与首行显示时间；没有抓包/MITM/root；135ms空栏目ready是主要易误读点。
14. startup-timeline.md:1/cold-timeline.json:1为报告可用时间表；保留AVD与应用进程，不承诺工具会话外常驻；无新HTTP测试服务。
