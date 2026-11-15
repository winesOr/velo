> 历史研究摘要，来自本地资料快照 `c350c4a`（2026-11-14 整理）。原始证据未公开；文内观察、推断和未验证边界按原文保留，不能当作本次复测结果。公开副本仅脱敏路径并处理未公开证据链接。

# VidHub 首页评分运行时简报
1. 本轮范围为首页轮播与海报角标评分；用户确认这些位置已显示评分，不要求先打开详情，不推断图标颜色对应提供方。
2. 同研究AVD/PID2056仍前台MainActivity；本轮只读，没有详情/播放/刷新/force-stop/重装/清数据/修改账号或server。
3. `existing-log-rating-derived.json:1`：启动至此前417行包日志白名单检查，仅MediaScrapper初始化、AppCompatDelegate元数据关键词及HomeStartupPerf ByRating栏目命中。
4. 这些初始化/栏目记录不等于评分请求；没有捕获可用于归属首页评分的响应字段、source枚举、HTTP方法/路径/状态或cache-hit。
5. `home-ratings-post-marker-derived.json:1`：从device11-14 12:38:00.000读至host04:41:45UTC，目标PID新日志0行，前台仍MainActivity；无新请求证据，也不能证明没有请求。
6. 既有startup证据的getMediaViews/getResumeItems/getLatestItems只有方法阶段与成功回调，没有可用响应body；不能据此断言这些响应带CommunityRating或其他评分字段。
7. 首页星形、紫色或海报角标的实际来源，运行时目前均未验证；需要静态绑定/转换链补证，不把TMDB/豆瓣/IMDb/RT/Trakt任一猜测写成运行事实。
8. 运行证据不能区分服务端透传评分、客户端评分补取、本地缓存字段或混合来源；同样不能证明请求合并/无独立评分请求。
9. 当前CUA inventory仍无emulator/qemu入口；本轮不绕过UI限制，不构造私有Activity extras，不要求用户继续操作。
10. 只保留时间、静态标签、已知字段名/来源enum及泛化host/path；无账号token/query、媒体标题/ID、私有完整URL或原始消息落盘，无数据送ReArkAI。
11. 未抓包/MITM/root、未使用账户key访问服务器；未清logbuffer、未新增后台监听；登录和媒体源配置保留。
12. 报告应写“首页评分显示为用户观察事实；当前运行日志只有加载方法阶段，无法验证rating来自哪个response”，而不是等待详情作为前提。
