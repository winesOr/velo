> 公开归档说明：历史记录和测试结果不代表当前版本；原始证据及私有截图未公开，替代插画不是研究证据。

# VidHub研究：从首页资源链路定位优化候选

最值得验证的是授权缓存先显、单库渐进，以及把装饰补全移出首批内容路径。VidHub的135ms空栏目ready不能当资源完成；Velo已具备多服渐进和并行加载，不能把差距归因于“全部串行”。

- VidHub单次冷进程Activity计时995ms；最后Latest成功距home日志起点2168ms，均非首海报时间。
- 5个Latest方法在3ms内发起，只证明日志调度，不证明socket并发或逐库UI提交。
- Velo快照等待授权与online；同服Latest并发3但等全库结果，装饰/排序补全还会挡首批返回。
- 当前没有Velo同条件实测、VidHub缓存命中或后端类型证据，不报告提速倍率。

@answer scope="首页启动单次日志、Velo代码对照；无同环境测速，播放研究保留为历史"
@meta locale=zh-CN quality_profile=showcase style=product

## 冷启动哪些时点不能混在一起 {#startup-times}

| 观测 | 数值 | 正确含义 |
| --- | --- | --- |
| MainActivity冷启动 | Total995ms / Wait998ms | 工具启动计时，不是内容完成 |
| loading_hidden | 应用elapsed133ms | 遮罩隐藏，不是图片完成 |
| all_enabled_sections_ready | 应用elapsed135ms | 各section计数为0，不能称缓存媒体已显示 |
| 最后Latest成功 | home起点后2168ms | 媒体方法回调，不是首图或图齐 |
| 同PID暖返回 | Wait166ms，无TotalTime | 既有task置前，不是新资源加载 |

仅一次冷进程、一次暖返回；保留磁盘数据。没有首海报视觉证据，不以空栏目ready或Activity显示替代资源完成。

## 本次资源日志按什么顺序出现 {#startup-flow}

@workflow id=startup-observed title="日志先后顺序，不按时长比例"
| startHome | home起点 | backend |
| emptyReady | 空栏目ready | frontend |
| mediaViews | Views方法 | backend |
| resumeItems | Resume方法 | backend |
| latestStart | 五条Latest发起 | backend |
| latestEnd | 最后Latest成功 | backend |
| startHome > emptyReady | 应用elapsed 135ms |
| emptyReady > mediaViews | +165ms |
| mediaViews > resumeItems | +1289ms |
| resumeItems > latestStart | +1812ms |
| latestStart > latestEnd | +2168ms |

@steps id=startup-log-steps
| startAnchor | home起点 | 设备日志12:14:43.085为零点；不要与Activity工具计时相加。 | startup-observed | startHome |
| emptyStage | 空栏目ready | 应用自报135ms，各栏目计数为zero；来源列表positive不是媒体非空。 | startup-observed | emptyReady |
| viewsStage | Views方法 | +165到+1285ms，方法日志区间1120ms；非DNS或TTFB。 | startup-observed | mediaViews |
| resumeStage | Resume方法 | +1289到+1561ms，272ms；仅观察先后，不证明所有场景依赖。 | startup-observed | resumeItems |
| latestStage | 五条Latest发起 | +1812到+1815ms，3ms窗口；缺库ID，不能逐请求配对。 | startup-observed | latestStart |
| successStage | 最后Latest成功 | 首成功+2108ms、最后+2168ms；没有逐库UI提交证据。 | startup-observed | latestEnd |

设备CST与宿主UTC分开记录，应用elapsed和墙钟差不同。后端类型未知，不能从方法名认定Jellyfin或Emby。+30147ms未归属超时不等于首页完成时间。

## Velo已经优化了什么，仍在哪里等待 {#velo-startup-code}

| 代码事实 | 已有能力 | 待验证屏障 |
| --- | --- | --- |
| Discover 559/571 | Continue与Hubs同时发起 | 不应再称串行请求 |
| aggregation 160 | 多服按完成顺序发布 | 单服Latest仍等所有worker |
| aggregation 788/849 | 同服Latest滑窗并发3 | 慢一库可能挡住已完成栏目 |
| main 1263 / HomeStartupGate | 首online与共享2秒内容预算 | 身份授权先完成，门退出仍可能skeleton |
| Discover 163/167/189 | 已有授权磁盘快照 | 仍等online与scope/epoch/隐藏库校验 |
| browse 1824/2305 | Jellyfin有界LastPlayed补全 | 首排返回前等待排序补全 |
| plex_client 1677/1689 | 合并owner metadata补logo | 装饰字段仍挡住数据返回 |

源码路径、函数签名和HEAD c41732f记录在 `evidence/startup/velo-code-trace.md`，完整报告16.4提供精确链接。代码等待点是候选因果，尚未测得耗时占比。

## 优先验证哪些改动 {#startup-priorities}

| 优先 | 候选实验 | 验收焦点 |
| --- | --- | --- |
| P0观测 | 区分授权、online、快照、方法、HTTP、首非空模型与首图 | 避免135ms空ready误读 |
| P1单库渐进 | worker完成即发布该库，保留多服渐进 | 延迟一库时其他行仍可先到 |
| P1补全延后 | Plex logo后补、Jellyfin排序分阶段 | 内容早到且焦点/排序/NextUp正确 |
| P1请求合并 | 统一Views的inflight与隐藏库分支 | 先确认重复请求，再消除 |
| P2缓存先显 | 授权scope明确后探索早于health完成读快照 | 不绕过PIN、epoch、注销和权限撤销 |
| P2并发实验 | 集中配置比较3/5/6 | 同环境看首行/图齐、错误和服务压力 |

这些是Velo建议，不是已证实的VidHub缓存策略。保持Plex/Jellyfin/Emby与多profile隔离；没有修改正式代码或原型。

## 如何使启动对照可复核 {#startup-validation}

- [ ] 同机同服同测试库，分进程冷磁盘温、清测试缓存、暖返三组。
- [ ] 每组先做至少5次初步复现，保留全部样本；尾部分位另需足量样本。
- [ ] 记录首非空模型、首海报、首行、图齐，不能用Activity计时替代。
- [ ] 注入单库延迟并测部分失败保旧、隐藏库、重复标题和切号。
- [ ] 用快照命中与授权scope证明缓存先显，不能由Room存在推断。

稳定记录在 `evidence/startup/vidhub-runtime/`、`vidhub-static/` 和 `velo-code-trace.md`。日志未保存账户、媒体名、库ID、完整URL或令牌。以下面板保留此前界面与播放研究，当前暂停播放扩展。

## 首页已有评分，来源链确认到哪一步 {#ratings-home}

首页轮播和海报角标已经有评分，不需要先打开详情才研究来源。当前没有首页响应字段或UI赋值链，不能把Latest/Resume方法成功当成评分来源证明。

| 位置 | 画面值 | 已确认或合理推断 | 请求链仍未知 |
| --- | --- | --- | --- |
| 首页轮播黄星 | 8.0 | 截图显示评分 | 哪个response字段、上游提供方、独立补取 |
| 首页海报角标 | 多个条目各有分数 | 截图与APK同类角标布局候选；首页Adapter关联未核 | 是否与轮播同字段、缓存与更新 |
| 电影/剧集详情黄星 | 7.5 / 8.0 | 详情星形控件已核 | 实际字段、提供方、尺度转换 |
| 电影/剧集详情紫标 | 8.5 / 9.4 | 与APK Trakt图标形状和紫白配色相符，属于视觉推断 | 未证该值来自Trakt响应，更未证客户端直连 |

APK有IMDb、RT audience/critics、Trakt标签及MediaRatingsView；自定义控件源码未取到。品牌资源证明展示支持，不证明请求发生。首页banner字段、CommunityRating等模型映射、请求端点与TTL均未取得。有限日志没有rating响应或cache-hit，新窗口0行也不能证明没有请求。

## Velo评分对照不能替代VidHub证据 {#ratings-code}

| Velo代码事实 | 用户可理解的含义 | 证据限制 |
| --- | --- | --- |
| J/E CommunityRating映射audience | 接受服务器给的社区评分 | 不能因此写TMDB、豆瓣或IMDb来源 |
| CriticRating除10映射RT critic | 客户端归一与标签语义 | 未证明服务器实际上游 |
| Plex从ratingImage及Rating数组URI归源 | 服务器响应可携带来源标签 | 不等于客户端直连该站 |
| Simkl一次详情响应内映射多个品牌 | 一个上游响应可以含多个评分 | 多图标不等于多站请求 |
| 海报1项、详情4项展示上限 | 筛选已有模型 | 不是评分HTTP数量 |

先分清服务器返回字段、服务器上游、客户端独立补取三层。后续围绕受控首页条目关联响应、模型、控件和更新时间。准确代码位置与稳定证据在完整报告17节及 `evidence/ratings/`；无需用户继续打开详情。本轮未改产品或原型，未记录账号、媒体标题/ID或令牌。

## 研究边界与证据等级 {#scope}

本页把截图可见事实、APK取证、机制推断和Velo建议分开。正式性能测试矩阵仍待执行；已观察到的启动/方法日志与服务端写出时间均按各自口径单列，不能当完整性能基准。

@facts id=evidence-levels
| 截图 S | 布局、文案、颜色与可见播放状态 |
| APK E | 包身份、Manifest、资源、库、符号与布局声明 |
| 推断 I | 需要动态调用链或对照实验才能升级的机制 |
| 建议 P | Velo 的可实施设计和测试方案 |

## 播放与网络证据如何连接 {#evidence-path}

@architecture id=vidhub-evidence title="VidHub证据到Velo验证"
| screenshot | 四张实机截图 | external |
| apk | base与arm64 APK | backend |
| rea | REA静态证据 | backend |
| manifest | Activity、Service、权限、PiP | backend |
| media | mpv、VLC、FFmpeg、JNI桥 | backend |
| settings | 缓存、硬解、路由、字幕资源 | backend |
| runtime | 设备、网络、播放动态验证 | external |
| prototype | Velo本地高还原原型 | frontend |
| report | 完整中文报告 | frontend |
| screenshot > prototype | 视觉规格 | |
| apk > rea | 静态取证 | |
| rea > manifest | 入口与权限 | |
| rea > media | 候选播放能力 | |
| rea > settings | 产品意图资源 | |
| manifest > runtime | 待动态验证 | dashed |
| media > runtime | 默认核心、硬解、Surface待验证 | dashed |
| settings > runtime | 缓存和路由收益待验证 | dashed |
| runtime > report | 记录实测结果 | emphasis |
| prototype > report | 原型操作与限制 | |

## 原型与实测验收 {#acceptance}

@steps id=acceptance-steps
| inspect | 检查首页、电影详情、剧集详情和播放器 | 先对照截图顺序、底色、卡片、黑边和控件位置。 |
| interact | 完成首页→详情→播放→返回闭环 | 验证横滑、收藏、分页、暂停、seek、倍速、字幕面板与锁定。 |
| responsive | 检查375/390/430px与展示台 | 页面不能整体横向溢出；横向列表可局部滚动。 |
| measure | 执行首帧、seek、掉帧、内存和网络矩阵 | 固定设备、片源、版本与网络；当前所有值待测。 |
| report | 记录证据等级和未知项 | 不能把库存在写成默认内核，也不能把截图速率写成基准。 |

## 性能矩阵的正确读法 {#performance}

| 场景 | 应记录 | 当前状态 |
| --- | --- | --- |
| 冷启动首帧 | 首帧与首声时间 | 待测 |
| Seek | 目标帧延迟与位置误差 | 待测 |
| 连播 | 掉帧、缓冲、CPU、GPU、温度 | 待测 |
| 内存 | PSS峰值与连续切集增量 | 待测 |
| 网络 | 首字节、Range、重试、恢复 | 待测 |

@callout id=not-proven level=warning title="不能从静态证据推出的结论"
| 默认使用mpv还是VLC、是否命中硬解、是否有自定义libass、缓存是否启用、HTTP连接是否复用，都需要运行期证据。 |

## 交付入口 {#deliverables}

- 详细证据、实现边界、性能矩阵与Velo建议见 `report.md`。
- 可操作界面见 `prototype.html`。
- 原型中的播放、网络、投屏、搜索和媒体数据都是本地演示状态。

## 四屏如何还原 {#visual}

| 页面 | 视觉规格 | 关键顺序 |
| --- | --- | --- |
| 首页 | #333333底色、满宽海报、350×54px底栏 | 继续观看、我的媒体、动漫、其他视频、电视剧、电影、综艺 |
| 电影详情 | #7b6655底色、320×46px白播放胶囊 | 元数据、播放、轻操作、演员、类型、相关、媒体信息 |
| 剧集详情 | #a89da1底色、195px宽集卡 | 季、集卡、分页、演员、类型、相关 |
| 播放器 | 2.225:1画布、中心16:9、两侧黑边 | 顶栏、侧栏、77.5%高度时间轴、底行传输控制 |

颜色为截图像素观测；几何为390px逻辑宽下的近似。紫色评分标记与Trakt资源视觉相符，但分数请求来源仍未知；剧集分页保留原图21-32。截图里不透明媒体路径已要求脱敏。

## 哪些实现已获得静态证据 {#implementation}

| 已观察证据 | 能支持什么 | 不能支持什么 |
| --- | --- | --- |
| 播放XML同时声明MPVView与VLCVideoLayout | 双视频View布局存在 | 默认核心和切换逻辑 |
| libplayer依赖mpv、FFmpeg、EGL、GLES | JNI桥及相关动态依赖 | 零拷贝和硬解实际命中 |
| VLC布局预留Surface、Texture、字幕Surface | 候选输出布局存在 | 当前视频实际使用哪条输出路径 |
| 首页ViewPager2、PosterGradientView、RecyclerView | 轮播、渐变叠层与列表结构 | 取色算法、帧率和缓存池策略 |
| 详情HorizontalRecyclerView | 横向内容列表结构 | 内存复用收益 |
| Glide/OkHttp与Room声明 | 图片网络与数据库集成线索 | 数据表、连接池大小、请求缓存策略 |

## 网络与播放优化证据有哪些 {#optimization}

| 静态证据 | 产品意图 | 验证缺口 |
| --- | --- | --- |
| 磁盘缓存容量、时长设置与512MB展示资源 | 可设缓存预算，推荐高码率或弱网使用 | 512MB是否运行默认、实际落盘与淘汰 |
| 硬件加速、杜比视界与音频直通提示 | 性能、兼容性与设备能力之间可选择 | 命中率、CPU、功耗与音画同步 |
| 自动最快路由与手动路线资源 | 多路径选择 | 测速算法、故障切换与恢复 |
| mpv缓存选项、VLC缓存/重连/Range字符串 | 打包库包含相关能力 | 应用是否传参、实际HTTP请求 |
| ProfileInstaller与baseline.prof/profm | 有预编译优化资产 | 启动和滚动收益 |
| 字幕独立解压进程、主副字幕与ASS样式资源 | 字幕工作流与能力声明 | 渲染后端、自定义补丁与内存释放 |

## 如何复核与继续验证 {#follow-up}

- [ ] 对照详细报告的两个APK SHA256与版本318。
- [ ] 检查REA证据ID、资源partial覆盖和本地JSON。
- [ ] 使用已补齐split的隔离AVD完成权限与受控媒体播放。
- [ ] 固定设备、片源、核心与网络，区分冷/热启动。
- [ ] 比较缓存开关及容量/时长阈值对应的磁盘与缓冲变化。
- [ ] 验证后台、PiP、旋转、切集、退出后的释放与续播。

首轮ADB设备列表为空；后续已启动独立Android36 arm64 AVD并安装完整split。后续已取得受控外部URL输入、libmpv与MediaCodec日志，仍无首帧视觉验证。

ReArk GUI首轮因Mac锁屏受阻，解锁后完成base Summary核验。Agent首次查询曾因API Key要求失败；本地Magpie配置后已成功。ABI split仍被GUI拒绝，原因未定。主要取证采用REA MCP和静态ELF提取。

REA的C伪代码反编译缺少provider。后续ReArk已获得JNI方法级反汇编和PLT/GOT核验；没有动态性能结论。

## Velo优先实施什么 {#velo}

| 顺序 | 建议 | 验收依据 |
| --- | --- | --- |
|P0 {#priority-1} | 首帧、seek、缓冲建立统一时间戳 | 同会话关联UI、网络和内核 |
|P0 {#priority-2} | 保留mpv/ExoPlayer并明确回退 | 核心错误、切换、恢复可复现 |
|P1 {#priority-3} | 图片尺寸解码、并发预算、取消离屏任务 | 帧时间与PSS对照 |
|P1 {#priority-4} | 预读预算配置化、seek合并 | 首帧、重缓冲、请求量一起评估 |
|P1 {#priority-5} | 单一强播放按钮和分层技术信息 | 手机和TV焦点可达 |
|P2 {#priority-6} | 异步海报取色及实色回退 | 无图、低性能和对比度验收 |

这些是Velo建议，不是VidHub已恢复业务源码。继续保留Plex、Jellyfin、Emby、一起看、手机与TV，弹幕网关由用户配置。

## 本地素材与公开边界 {#privacy}

这是用户指定样本的本地研究。截图海报与人物保留原权利归属，不能直接成为Velo公开发行素材。APK、反编译内容、私有截图和服务器令牌不发布；本轮没有提交或推送。

## 样本身份与证据复核 {#identity}

@facts
| 包名 | com.oumi.utility.media.hub |
| 版本 | 3.0.3，versionCode 318 |
| 系统要求 | minSdk 28，targetSdk 36 |
| base大小 | 35,856,164 bytes |
| arm64大小 | 82,626,136 bytes |
| base SHA256 | b7041dc8d97844a561751da525dcff2cec45b479a695fac7b8b3b3873b111414 |
| arm64 SHA256 | 233a0997d447f5058aab4828aa3428e8847eda4403643e552cbefcea852f47bc |

详细报告保存REA Evidence ID、JNI字符串偏移与布局位置。持久本地证据放在 `evidence/`，APK本体不复制到交付目录。资源投影为partial，不能当作全部字符串清单。

播放器背景使用无控件截图区域重新铺放，构图会与整帧不同。按钮和列表为DOM重建；原型不宣称逐像素完全一致，也不宣称真实播放或投屏成功。

## ReArk GUI补充证据 {#reark-gui}

ReArk v1.2.0解锁后检查base Summary，复核包身份、EasyShield、DEX与组件统计。ReArk计30类，REA搜索计32类；统计差异原因尚未核实，两种结果均保留。Agent首次API Key阻塞已由本地Magpie配置解决；arm64配置split单独打开仍报Invalid APK file。GUI观察仍不等于业务代码恢复或动态性能实测。

| GUI观察 | 证据边界 |
| --- | --- |
| 3.0.3 / 318，com.oumi.utility.media.hub | 身份复核 |
| 1 DEX、30类、222方法、54字段 | 加固后可见摘要统计 |
| 62 Activity、5 Provider、3 Receiver、13 Service | 组件摘要统计 |
| 24权限含网络与媒体前台服务 | 权限声明，非运行调用 |
| Agent本地Magpie已连通 | 22秒完成两个只读工具及中文答复；非播放性能指标 |
| arm64 split Invalid APK file | 不能单独由GUI打开的错误，原因未定 |

ReArk使用本地端点 `http://127.0.0.1:3425/v1` 和模型 `auto/gpt-6.1-sol`。`summarize_package` 与 `inspect_entry_points` 调用成功。没有录入密钥；模型答复不升级为新的取证事实，加固与性能待测限制保留。


## 深入取证补充了哪些设置 {#deep-resources}

本轮ReArk读取本地资源，界面沿用用户选择的 `auto/gpt-6-astra`。前轮 `auto/gpt-6.1-sol` 连通验证是历史记录。本面板内容为资源声明；后续JNI面板另列通用API调用，应用业务具体参数仍未知。

| 新证据 | 能确认 | 仍未知 |
| --- | --- | --- |
| 线路资源与校验文案 | 主/备线路；名称必填、端口1–65535提示文案 | 最快算法、网络探测、超时与回退 |
| 缓存时长格式 | 以分钟显示 | 时长数组、容量档位及默认偏好 |
| 音频硬解与去隔行 | 有选项；去隔行提示可能影响非隔行视频 | 解码器、滤镜与收益 |
| 蜂窝提醒与自动PiP | 有对应设置文案 | 默认值及触发条件 |
| 网盘播放选择 | 最高分辨率流或原始文件 | URL决策、转码与带宽差异 |

稳定证据在 `evidence/reark-deep/01-network-route.txt` 和 `02-cache-playback-resources.txt`。详细报告第13节列出行号。原型设置为演示值；不伪造测速，不把512MB文本当运行预算。


## JNI反汇编新增了什么证据 {#native-methods}

同哈希libplayer.so已在ReArk完成方法级反汇编。PLT与GOT、relocation交叉核验了调用目标。这是native桥接路径，不是Java业务调用顺序。

| 方法 | 已核实路径 | 不能推出 |
| --- | --- | --- |
| create/init | mpv_create、mpv_initialize、启动事件线程 | 默认核心、Java调用先后 |
| setOptionString | 0x4bb0经PLT/GOT调用mpv_set_option_string | 实际缓存、硬解、字幕参数值 |
| attach/detachSurface | mpv_set_option；全局引用创建/删除 | 实际Surface模式；选项文本未可靠解码 |
| destroy | 请求退出、wakeup、join、terminate_destroy | Android切集/PiP释放成功或泄漏 |

@workflow id=native-destroy title="destroy函数内已核实顺序"
| exitflag | 设置退出标志 | backend |
| wakeup | mpv_wakeup | backend |
| join | pthread_join | backend |
| destroy | terminate_destroy | backend |
| clear | 清空g_mpv | backend |
| exitflag > wakeup | |
| wakeup > join | |
| join > destroy | |
| destroy > clear | |

证据在 `evidence/reark-deep/03-native-jni.txt`。详细报告第13.4节给出符号范围与精确行号。字符串乱码结果未采纳；没有C源码恢复或性能测量。

## 新增原型设置如何查看 {#prototype-deep}

首页设置与播放器更多提供线路管理、网络与缓存、播放设置演示。初始缓存值为未设置；2 GB和10分钟仅为验收输入，不是竞品默认。

增量浏览器验收记录在 `verification-deep.md`。预览图为 `previews/settings-network.png` 与 `previews/settings-playback.png`。这些是研究原型画面，没有真实测速、缓存落盘或Android播放性能数据。


## 哪些具体参数已在应用代码中确认 {#probe-parameters}

DV/HDR探测函数的两条输入分支已取得具体实参。调用经汇编、PLT/relocation及定点ASCII复核；它们不是库默认值。

| 代码参数 | 已核值 | 必须保留的范围 |
| --- | --- | --- |
| probesize | 262144 bytes，256 KiB | 媒体探测；非播放缓存 |
| analyzeduration | 1000000微秒，1秒 | 分析参数；非整个函数硬超时 |
| fflags | nobuffer | 此探测输入；非全局播放设置 |
| 自定义AVIO缓冲 | 65536 | 输入IO缓冲；非磁盘预读容量 |

单位已按FFmpeg官方文档核实，记录在 `evidence/reark-parameters/04-api-units.txt`。Java调用时机与性能收益未知，不能推导硬解默认值。稳定记录为 `evidence/reark-parameters/01-probe-options.txt`。

匹配XAPK现已提供完整split，并成功在隔离AVD安装启动。权限交接后取得外部URL输入的mpv/MediaCodec证据；没有物理硬解或最快线路算法结论。


## 动态验证已经做到哪一步 {#dynamic-status}

隔离AVD已安装base、arm64、xhdpi、en、zh五个匹配split并启动。首轮卡在权限页面，用户处理后已恢复外部URL测试。应用不可debuggable；没有root或注入。

| 观察 | 当前结论 |
| --- | --- |
| ActivityManager启动1671ms | 启动工具计时；不是首帧 |
| 合成60秒AVC/AAC与本地HTTP已备妥 | 只使用测试媒体，无私人服务器 |
| curl Range自检206、100字节 | 夹具自检；不是VidHub请求 |
| 后续媒体HTTP和解码日志 | 见运行证据面板；完整API实参与最快路线仍未知 |

稳定证据保存在 `evidence/dynamic/`。模拟器不能代表手机硬解性能，文件HTTP播放不能替代媒体服务器最快路线实验。

## 探测预算不是播放缓存 {#probe-budget}

DV探测循环观察到elapsed超过150000微秒（150ms）、目标流32包、成功总包128、匹配流累计4194304字节等比较。elapsed等于阈值时继续；时间单位已按官方API文档核实。

这些只限定已观察的探测循环，不是整个函数硬超时或播放缓存容量。目标流选择语义部分推断，NAL解析和成功分支未完整恢复。直接调用索引不包含未解析间接及运行时引用，仍不能得到实际hwdec/cache业务值。

复核记录为 `evidence/reark-parameters/02-probe-limits-xrefs.txt`。av_gettime_relative与av_read_frame身份由跨轮PLT和完整relocation映射核实。

## 最快路线仍有哪些证据缺口 {#route-unknown}

配置候选未揭示最快算法。default/2160配置只有网格列数，media_server_current是部分Lottie动画结构，线路行布局只有待绑定的文本控件。

loaded-content搜索无匹配，但只覆盖已加载或缓存内容，不证明APK没有算法。计时、排序、并发选路和失败处理调用链仍未取得；播放缓存和hwdec业务实参也未知。

稳定记录为 `evidence/reark-parameters/03-config-route.txt`。三轮有界取证已结束。本轮新增的是媒体探测参数，不能用它替代播放配置和最快算法答案。

权限交接后已恢复受控测试；结束时停止HTTP夹具并移除18879反向映射，AVD状态保留。重跑须重建服务，不承诺旧URL可用。


## 外部URL运行证据确认了什么 {#runtime-input}

2026-11-14 UTC，应用日志报告本会话hwdec=auto-unsafe、currentVo=gpu、core=MPV，原因legacy_routing。未检查API返回码或属性读回，不能称物理硬解命中。

包限定ACTION_VIEW进入VideoPlayActivity。本地合成AVC/AAC触发libmpv请求与 `c2.goldfish.h264.decoder`；后续进程出现mpv FILE_LOADED。没有首帧屏幕验证。

| 直接观察 | 必须保留的解释边界 |
| --- | --- |
| hwdec=auto-unsafe，currentVo=gpu | 应用本次日志设值，非API接受或全局默认 |
| Lavf与libmpv两次GET，Range bytes=0-，206 | 用途归属未映射，不能硬定为探测/播放 |
| 每次服务端完整写出12,068,014字节 | 不等于客户端全部消费或缓存驻留 |
| goldfish H264组件640×360 | 模拟器组件，不证明手机物理硬解 |
| max-input-size=6291456 | 解码输入上限6MiB，不是网络缓存 |
| 服务端写出155.646/72.337ms | 不是首帧或端到端下载时长 |

本路径mpv/MediaCodec已被观察，不能推出全局默认核心。证据索引为 `evidence/dynamic/parameter-evidence-index.md`。

## 延迟对照为何没有成立 {#runtime-limit}

第二次ACTION_VIEW请求/b超时，但服务端根本没有收到/b。随后出现一次焦点事件ANR，并在另一进程重读/a；这不是慢线路或最快路线测试结果。

本次hwdec/vo日志设值已取得，mpv实际属性、网络缓存业务值和服务器最快算法仍未验证。没有持续帧率、功耗或首帧测量；单点内存与单次模拟器ANR不能证明缓存容量或产品普遍缺陷。

HTTP夹具已停止、反向映射已移除，隔离AVD保留。稳定记录为 `evidence/dynamic/playback-results.md`，原型没有改动。
