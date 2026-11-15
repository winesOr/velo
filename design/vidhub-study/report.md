> 公开归档说明：历史记录和测试结果不代表当前版本；原始证据及私有截图未公开，替代插画不是研究证据。

# VidHub Android 界面、实现与性能研究

研究日期：2026-11-13。对象为用户提供的VidHub base/arm64 APK、四张实机截图，以及后续受控运行观察和Velo启动代码对照。交付包括本报告、[可视摘要](report.html) 和[可交互原型](prototype.html)。

## 1. 结论与证据口径

当前重点是首页启动资源网络。VidHub单次冷进程MainActivity计时995ms；首页日志133/135ms隐藏加载并声明ready时，各栏目itemCount仍为0。随后Views方法1120ms、Resume272ms，5个Latest方法在3ms内发起，最后成功回调距home阶段起点2168ms。这些都不等于海报显示完成，不能宣称135ms完成资源加载或已证明缓存先显。

Velo当前代码已有多服渐进、共享2秒内容预算及继续观看/hubs并行。最值得验证的是：**授权缓存更早显示、单库渐进发布、装饰/排序补全移出首批内容关键路径**。这里是代码导出的候选，不是已经测得的提速；优先级和准确位置见第16节。此前播放研究保留为历史证据，本轮暂停扩展播放测试。

更新至2026-11-14 UTC：已在隔离AVD通过本地合成媒体触发外部URL播放路径，取得应用日志自报 `hwdec=auto-unsafe`、`currentVo=gpu`，以及libmpv/Android MediaCodec运行证据和两组HTTP完整响应写出记录。日志设值未通过API返回码或属性读回确认。没有首帧视觉验证；未恢复播放缓存业务值或自动最快服务器路线算法。详见第15节。

四张截图支持较高精度还原手机首页、电影详情、剧集详情及横屏播放器。它们不能证明 UI 框架、播放核心选择或性能策略。APK 静态分析揭示已打包的能力和可见实现入口；加固或隐藏实现必须保留未知。

本报告统一使用四种证据等级：

| 等级 | 含义 | 能支持的结论 |
| --- | --- | --- |
| 观察 S | 用户截图中直接可见或像素测量 | 布局、文案、色彩、图标位置、当前状态 |
| 取证 E | 本次 APK/REA 输出中直接可复核 | 包版本、文件、符号、字符串、可见方法 |
| 推断 I | 由证据提出但缺少调用链/运行证据 | 候选模块职责或可能机制 |
| 建议 P | 为 Velo 和原型提出的设计方案 | 待实现、待测试的行为和参数 |

“捆绑某库”不等于“当前选用某库”；“存在某配置名”不等于“默认值已启用”；“库支持某优化”不等于“此 App 获得了性能提升”。报告不编造帧率、首帧、流量、功耗或内存结果。

## 2. 输入、版本与证据索引

APK 原始输入位于 `<local-path-withheld>`，未复制进交付目录。包名 `com.oumi.utility.media.hub`，版本 `3.0.3`，versionCode `318`，minSdk `28`，targetSdk `36`。

| 输入 | 大小 | SHA-256 |
| --- | --- | --- |
| vidhub-base.apk | 35,856,164 bytes | b7041dc8d97844a561751da525dcff2cec45b479a695fac7b8b3b3873b111414 |
| vidhub-config-arm64-v8a.apk | 82,626,136 bytes | 233a0997d447f5058aab4828aa3428e8847eda4403643e552cbefcea852f47bc |

base 声明 `requiredSplitTypes=base__abi,base__density`；首轮只提供两个APK时缺少density split，无法承诺两文件足以安装。后续已从匹配XAPK确认完整split，并在隔离AVD成功安装5个split；这一安装材料缺口已解决。安装成功不代表已完成媒体播放或性能验证。ABI split 为 `config.arm64_v8a`，`hasCode=false`。

实际使用 REA MCP 的 `inspect_android_package`、`search_android_classes`、`decode_android_resources`、`open_binary` 和 `inspect_artifact`。补充用 Python ZIP、ELF64 dynsym/dynamic 及 ASCII 字符串解析。ReArk 1.2.0 GUI 首轮尝试因 Mac 锁屏而阻塞；解锁后已完成 base Summary 核验。Agent 首次查询曾因端点要求 API Key 失败；用户授权配置本地 Magpie 后，真实 ReArk 查询已成功。arm64 split 被 GUI 拒绝，具体原因未定。补充记录见第12节。REA 原生方法反编译也阻塞：Ghidra 未配置且当前 JDK17 不满足工具要求的21；Hopper launcher 不存在，IDA 未配置。该 REA C伪代码反编译路径未恢复 native 方法体；后续 ReArk 已完成 libplayer JNI 方法级反汇编及 PLT/GOT 核验，见第13.4节。两者是不同工具与分析层级。

| 证据 | REA Evidence ID / 本地定位 | 覆盖范围 |
| --- | --- | --- |
| E1 base | ev_002129d53302e652ab86e647a7e7f8793e58812df11d60d6490f9ee4da3ad3c7 | 身份、Manifest、DEX |
| E2 split | ev_7f9ba1843ca678ffbb61a9cbeac66723baabd258a659aee72bb660bca12e2a75 | ABI包身份 |
| E3 资源 | ev_f93e5e207b2e1a89f3cb127171388131c3696f83648c699da75dd0484d8388e8；vidhub-rea-resources.json（原始材料未公开） | coverage=partial，受字符串投影上限限制 |
| E4 原生清单 | ev_562c6d56ee5a7a60f5a478488f45f95b2cf7b6827a69de5f0ca227326485e2be；vidhub-rea-native-inventory.json（原始材料未公开） | ZIP成员，不能代替APK签名验证 |
| E5 嵌套清单 | ev_f9c49f115da802f0f6ec9f1d6ae7010c097a7ff3fc1b2cb57153cafc15c20abb | 嵌套工件清单 |
| E6 符号/字符串 | vidhub-native-evidence.json（原始材料未公开）；`/tmp/vidhub-native/*.so.strings.json`（仅补充临时筛选文件；关键偏移已保存于持久JSON） | SHA256、DT_NEEDED、dynsym、文件偏移；不是调用轨迹 |
| E7 阻塞 | vidhub-rea-native-blocker.json（原始材料未公开） | native provider不可用 |

证据交接索引为 `/tmp/velo-vidhub-brief.md`，视觉测量索引为 `/tmp/velo-vidhub-visual-brief.md`。这些是本地临时取证文件，不是可公开链接。

| 编号 | 输入 | 图片尺寸 | 用途 |
| --- | --- | --- | --- |
| S0 | 1000025030.jpg | 1200×6981 | 媒体库首页长截图 |
| S1 | 1000025031.jpg | 1200×5375 | 电影《仙逆剧场版：弑仙之战》详情 |
| S2 | 1000025032.jpg | 1200×4321 | 剧集《尚公主》详情 |
| S3 | 1000025033.jpg | 2670×1200 | 《后会友期》第1季第5集横屏播放 |

截图原件保留在本机 Downloads。截图中的年份、评分、用户名与媒体路径仅为当时画面内容，不是实时影视资料，也不是客户端性能测量。

## 3. 高还原视觉规格

### 3.1 共用视觉语言

手机按 390 CSS px 作为原型基准；原图 1200 px 到该基准的比例约 3.077。几何为视觉近似，颜色由像素读取，不能视作原生代码中的设计 token。

| 项目 | 观察/测量 | 原型应用 |
| --- | --- | --- |
| 首页底色 | #333333 | 中性深灰整页 |
| 首页底栏 | #4d4d4d 附近 | 半透明胶囊导航 |
| 电影底色 | #7b6655 | 顶部海报向暖褐色融合 |
| 剧集底色 | #a89da1 | 顶部冷蓝海报向灰粉色融合 |
| 文本层级 | 主白、副文半透明白 | 章节约16 px，片名约13 px，元数据11–12 px |
| 圆角 | 海报/横卡约11–15 px | 播放按钮与底栏完全圆角 |
| 演员头像 | 约69×69 px，圆角约15 px | 姓名、角色在图片下方 |
| 横向列表 | 下一项部分露出 | 列表内部滚动，不使整个页面溢出 |

字体外观接近系统无衬线；原型使用系统字体栈。无法由图片确定原生字体文件。不同影片背景色并不证明客户端采用了动态取色；也可能来自元数据、预处理或固定配置。

### 3.2 首页 S0

满宽人物海报从顶端延续到约 600 CSS px，没有四边卡片圆角。账号胶囊、搜索、更多按钮浮在海报上方。艺术标题位于下部，评分/年份/类型居中，轮播点置于其后。首页 Hero 没有大播放按钮。

内容顺序必须保留：继续观看 → 我的媒体 → 动漫 → 其他视频 → 视频库-电视剧 → 视频库-电影 → 综艺。继续观看为约218 px宽的16:9卡片，带中心播放圈、右上已看标记、底部进度与双时间。普通海报约98×147 px，右下黑底评分，片名一行省略。无竖海报内容保留灰底与横图组合。

底部导航为媒体库、文件库、影视服务器、设置，约350×54 px，距两侧20 px。此处是 VidHub 研究页导航；它不改变 Velo 正式产品既有的一起看等导航与能力。

### 3.3 电影详情 S1

海报艺术标题以下依次是评分/日期/类型、时长/文件体积/编码摘要、宽白播放胶囊、收藏/旗形轻操作、紫色评分标记、演职人员、类型、相关影片、音视频字幕信息、文件块。播放胶囊约320×46 px，左右35 px，黑字白底。紫色标记无法仅凭图片确定供应商，不标成豆瓣或其他平台。

视频信息原样记录为截图事实：HEVC/Main、等级150、3840×1598、宽高比1920:799、非隔行、25.000 fps、7837 kbps、SDR、bt709、8 bit、yuv420p、参考帧1。音频显示AAC stereo、2 ch、48000 Hz、LC、125 kbps。它们描述截图媒体，不能证明解码是否由硬件完成。

最下方截图含不透明服务器路径标识。原型仅展示脱敏演示路径，不复用完整服务器地址或令牌式片段。

### 3.4 剧集详情 S2

复用详情主结构，海报柔和过渡到灰粉色，不用厚黑遮罩。“共1季”置于元信息下方。“第1季”选择器左对齐，“查看全部”右对齐；集卡约195 px宽、16:9。第2集原图缺图，应保留带数字的柔和占位。

分页原样为1-10、11-20、21-32、33-40。第三组不擅自改为21-30。演职人员、类型、相关影片接在选集之后。截图所见不能确认实际分页算法；原型选中态和切换反馈属于模拟。

### 3.5 播放器 S3

画布比例为2.225:1。中心视频约2140×1200，左右约270 px黑边。顶部与底部覆盖暗渐变；顶行网络速率、时间、电池是截图状态，不在原型中冒充实时遥测。

顶栏为返回/片名及右侧投屏/更多；左侧锁定与绿色旋转图标，右侧截图/PiP。时间轴在高度约77.5%，左右分别是00:15与1:19:50。底行左侧列表，中心上一集/快退/暂停/快进/下一集，右侧1.0x/字幕轨道/画幅。保持细线白图标，不添加默认常驻音量条或复杂设置卡片。

## 4. APK 实现结构及分析限制

### 4.1 加固边界

DEX仅能搜索到32个可读类，主要为 `com.netease.nis.wrapper.*`、`a.auu.a`、R和DebugProbesKt；Application为 `com.netease.nis.wrapper.MyApplication`。搜索播放器、网络、缓存、首页等业务关键词没有匹配。这证明本次静态可见面受网易加固壳限制，不证明这些业务或依赖不存在。无法由此恢复全套源码，也未绕过加固。

### 4.2 可见页面与生命周期入口

| 证据入口（Manifest原样类名） | 可确认范围 |
| --- | --- |
| `com.mac.utility.media.hub.ui.main.MainActivity` | MAIN/LAUNCHER；VIEW video/*与http/https/content/file入口 |
| `com.mac.utility.media.hub.ui.external.ExternalPlaybackActivity` | open-vidhub / x-callback-url / /play外部播放入口 |
| `com.mac.utility.media.hub.ui.mediaserver.activity.MediaServerItemDetailActivity`、`MediaServerEpisodesListActivity`、`MediaServerBrowserActivity`、`MediaServerRoutesListActivity`、`AddBackupRouteActivity` | 媒体服务详情、集列表、浏览和路由页面声明 |
| `com.mac.utility.media.hub.ui.media.activity.MediaItemDetailActivity`、`MediaItemListActivity`、`MediaEpisodesListActivity` | 本地媒体详情/列表/集列表页面声明 |
| `com.mac.utility.media.hub.ui.videoplay.activity.VideoPlayActivity` | singleTask、PiP、可调整大小、方向和尺寸变化处理声明 |
| `com.mac.utility.media.hub.service.KeepAliveService` | 非导出，dataSync与mediaPlayback前台服务类型 |
| `core.scrapper.MediaScrapeService`、`RefreshOnlineDataService` | dataSync服务声明，非已运行证明 |
| `com.example.omisubtitlemanager.subhd.archive.SubHdArchiveService` | 非导出，字幕解压独立进程 `:subtitle_archive` |

Manifest同时包含INTERNET、网络/Wi-Fi状态、WAKE_LOCK及媒体播放/数据同步前台服务权限，`usesCleartextTraffic=true`。明文流量许可不证明所有请求使用HTTP；为Velo设计时应逐源确定必要性。

### 4.3 原生播放组件

arm64包同时包含 `libmpv.so`、`libvlc.so`、`libvlcjni.so`、`libplayer.so`、FFmpeg系列库及 `libarchive-jni.so`。这足以确认分发包具备mpv/VLC两套候选核心，不能判断默认核心或单次媒体路径。

`libplayer.so` SHA256为 `6d4a05854f571ee40bf91710e7b92dac9e2785d9cc734a376f8ad1636bee9907`。DT_NEEDED包括mpv、avcodec、avformat、avutil、swscale、GLESv3与EGL。可见JNI入口前缀 `Java_com_omi_omimpv_wrapper_MPVLib_` 对应 `create`（0x1479）、`init`（0x1534）、`destroy`（0x15bc）、`attachSurface`（0x1678）、`detachSurface`（0x16c9）、`setOptionString`（0x18c7）、`observeProperty`（0x1b0d）、`grabThumbnail`（0x1bad）与 `nativeGetDolbyVisionAndHDRType`（0x1cb8）。偏移为字符串文件偏移，不能当作执行地址或调用证据。

`libvlcjni.so`依赖libvlc，暴露LibVLC创建和MediaPlayer播放/停止/设置媒体/renderer/速度/时间/位置接口。资源记录libvlc revision `965e864`、VLC revision `2eeb298f00`。libmpv含ANativeWindow、MediaCodec Surface和libass源码路径字符串，VLC也含相关能力；这不能证明自定义libass补丁、默认硬解或零拷贝实际命中。

补充布局证据显示，`res/layout/activity_video_play.xml` 同时声明 `com.omi.omimpv.MPVView` 与 `org.videolan.libvlc.util.VLCVideoLayout`。VLC布局预留视频 Surface/Texture 与独立字幕 Surface。播放器设置布局中，VLC磁盘缓存容器初始 `visibility=gone`、开关 `checked=false`，缓存滑块为0–11且初值3，XML初始值可能被偏好覆盖。首页布局包含 `ViewPager2`、`PosterGradientView` 和 `RecyclerView`；详情布局包含多个禁用nested scrolling的`HorizontalRecyclerView`。这些是布局声明，不是运行期选择和帧率证据。

### 4.4 持久布局证据定位

以下为 apktool --no-src 从本次 base APK 解码的相关布局原文，仅供本地私有复核。该次解码发生在仅提供base与ABI时，未解析drawable引用仍可能存在；后续完整split安装不代表已重新解码这些历史文件或恢复全部资源。文件保持原行号，未复制业务代码或 APK 本体。

| 结论 | 本地持久证据与精确位置 |
| --- | --- |
| 同页声明 MPVView 与 VLCVideoLayout | activity_video_play.xml（原始材料未公开） 第4行 `com.omi.omimpv.MPVView`，第5行 `org.videolan.libvlc.util.VLCVideoLayout` |
| VLC预留视频Surface、字幕Surface与Texture | vlc_video_layout.xml（原始材料未公开） 第4–6行 `surface_stub`、`subtitles_surface_stub`、`texture_stub` |
| VLC磁盘缓存布局初始状态及滑块 | activity_playback_settings.xml（原始材料未公开） 第64行容器gone、第67行checked=false、第73行512MB资源、第75行滑块0–11初值3 |
| 首页裁图与列表 | fragment_media_server_home.xml（原始材料未公开） 第5行RandomCropImageView、第10行RecyclerView |
| 首页双轮播与渐变层 | item_media_server_home_banner.xml（原始材料未公开） 第4行图片ViewPager2、第5行PosterGradientView、第8行信息ViewPager2 |
| 详情横向列表结构 | media_server_detail_content.xml（原始材料未公开） 第22/24/29/33/37/41行，分别为集、快速选集、演员、类型、相关、媒体流列表 |

运行期选择、偏好覆盖、色彩采样和缓存池复用仍未知；布局声明不升级为运行结果。

## 5. 网络与播放优化：应如何读证据

网络链路需要分清元数据请求、图片请求、媒体字节请求、播放事件回报。某 HTTP 库存在不能说明这四条路径共用连接池。媒体流可能由播放器自己的输入模块读取，需调用链或受控抓取证明。原生字符串还出现mpv的`demuxer-max-bytes`、`cache-secs`、`cache-on-disk`，VLC的`file-caching`、`network-caching`、`http-reconnect`、`Range`和`Accept-Ranges`；它们只能证明库带有这些能力，不能证明应用实际设置或发送这些请求。

播放链路需要分清源选择、鉴权/重定向、探测、解复用、解码、字幕、视频输出、音频输出。库文件、导出符号与字符串只能证明某环节的候选能力；默认内核、硬件解码命中、零拷贝路径、字幕字体回退和 seek 行为均需运行验证。

### 5.1 可核验优化相关证据

| E级证据 | 可解释机制/产品意图 | 仍未知 |
| --- | --- | --- |
| `settings_playback_cache_to_disk`、`settings_playback_cache_duration`；提示容量或时长满足条件后停止缓存 | UI暴露磁盘缓存与双条件预算概念；可能平滑网络抖动 | 实际落盘代码、阈值组合、淘汰和预读实现 |
| `settings_playback_cache_size_default_value = 512 MB` | 资源中的默认值展示文本 | 持久默认值、运行期上限是否为512MB |
| VLC磁盘缓存描述推荐高码率/不稳定网络使用 | 产品提供对应建议 | 实际缓冲率收益与适用设备 |
| Hardware acceleration / Dolby Vision Hardware Decoding提示 | 提供硬解选择；文案说明设备能力与兼容性取舍 | 硬解命中、回退、支持格式及CPU变化 |
| Audio Passthrough及硬件能力限制描述 | 提供音频直通设置意图 | 实际输出链路及接收端兼容性 |
| Automatically Select Fastest Route、Switch Route、Route Management | 存在自动最快/手动切路线功能资源 | 探测速率算法、时间窗、回退条件、会话复用 |
| WebDAV/Alist与SMB连接资源 | 支持相关文件来源的产品表述 | 请求实现、Range、重试和连接池策略 |
| Manifest `com.bumptech.glide.integration.okhttp3.OkHttpGlideModule` | 图片加载层声明Glide/OkHttp集成 | 连接参数、图片缓存大小、是否与媒体流共用 |
| `androidx.room.MultiInstanceInvalidationService` | 数据库相关集成声明 | 数据表、索引、查询分页、缓存一致性策略 |
| `androidx.profileinstaller.ProfileInstallerInitializer`、baseline.prof 9888 bytes、baseline.profm 383 bytes | 包含Profile安装与预编译优化资产 | 对本设备启动/滚动的实际收益 |
| 主/副字幕、同名/全部外置字幕、强制覆盖ASS样式资源 | 暴露字幕选择与样式功能 | 字幕后端实现、libass补丁与字体缓存策略 |
| TV高性能模式提示可能失去外置字幕且部分格式解码失败 | 存在性能与能力取舍的产品说明 | 当前手机路径是否使用该模式、实际收益 |

### 5.2 只能作为假设的性能机制

磁盘缓存可能减少弱网抖动；硬解可能降低CPU；Surface路径可能减少拷贝；Profile资产可能改善启动。这些都是机制层推断（I级），没有性能测量支持。不能用“更流畅”“提升X%”替代实测，也不能把Velo建议中的有界队列、请求取消、连接复用当作VidHub实现结论。

## 6. 未证实事项与复核计划

| 未证实项 | 为什么现有证据不够 | 下一步如何确认 |
| --- | --- | --- |
| 默认播放核心 | 多库并存不代表优先级 | 在设置/播放时记录核心选择与已加载库，关联播放日志 |
| 硬件解码与零拷贝 | 编解码库/MediaCodec 字符串只证明候选能力 | 同片源记录解码器名称、Surface 路径、CPU/GPU与掉帧 |
| libass 是否定制 | 库/渲染字符串不能证明源码补丁 | 对应版本、构建信息、行为差异与可追溯补丁证据 |
| HTTP连接池/并发上限 | 不能由协议支持推导策略 | 受控服务端统计连接、请求时序和取消行为 |
| 预读与磁盘缓存 | 缓存选项不等于实际启用 | 冷/热缓存、断网续播、文件增量、网络字节对照 |
| 自动取色算法 | 不同详情背景只能证明颜色不同 | 更换海报，观察缓存失效、计算时机和色彩稳定性 |
| 投屏协议与成功率 | 可见图标不能证明实现 | 同一局域网受控接收端记录发现、传输与恢复过程 |
| 性能优势幅度 | 缺少同设备同片源对照 | 执行下一节测试并公开样本/分位数/失败率 |

## 7. 性能测试矩阵（全部待测）

以下是建议试验计划，不是 VidHub 测试结果。固定设备型号、SoC、系统、应用版本、刷新率、温控状态、片源哈希、服务端版本和网络工况。每组至少记录原始样本、失败原因与冷/热条件，避免仅报最佳值。

| 场景 | 观测指标 | 操作与控制变量 | 当前结果 |
| --- | --- | --- | --- |
| 本地1080p AVC与4K HEVC首次播放 | 点击到首个呈现帧，ms；首声时间，ms | 清应用进程；固定片源、字幕关闭，再开ASS对照 | 待测 |
| 局域网HTTP/远程HTTPS | DNS/TCP/TLS/请求至首字节、首帧，ms | 同服务、同文件，冷连接与复用连接分组 | 待测 |
| 高延迟/低带宽/丢包 | 缓冲次数、缓冲总时长、播放失败率 | 网络整形参数写入记录；不要改变片源 | 待测 |
| 拖动到前/后/未缓冲区域 | 手指释放到目标帧，ms；位置误差，ms | 相同关键帧间距，固定目标点，多次seek | 待测 |
| 连续播放30分钟 | 丢帧数/呈现帧数、CPU/GPU、温度、耗电 | 屏幕亮度、音量、字幕、网络固定 | 待测 |
| 复杂ASS字幕与多音轨 | 主线程帧耗时、字幕同步误差、内存 | 同片同时间段，简单SRT/复杂ASS/关闭字幕 | 待测 |
| 首页冷/热加载及高速滚动 | 首内容时间、帧时间P50/P95、内存峰值 | 固定海报数量和尺寸，区分图片缓存状态 | 待测 |
| 切后台/PiP/旋转/恢复 | 恢复首帧、位置漂移、音画同步、崩溃率 | 固定切换次数和停留时间 | 待测 |
| 断网/恢复/鉴权过期 | 重试次数、恢复时长、重复字节 | 受控服务端返回错误，不采集真实凭据 | 待测 |
| 长时间连续切集 | 内存/PSS增量、句柄/线程增长、首帧趋势 | 相同集数循环，记录资源释放与播放状态 | 待测 |

采集方法建议：Perfetto观察调度与渲染；系统帧统计用于UI，播放器自身统计用于视频帧，二者不可混用；系统内存统计追踪PSS；受控服务端或本地代理记录脱敏请求与Range；解码日志关联系统媒体组件。不能用截图上6.4 MB/s代表吞吐基准，也不能把视频标称25 fps当作实际呈现帧率。

判定原则：同条件比较P50/P95及失败率，保留离群样本。优化目标值尚未由用户确定，建议通过配置项设定并标记 `TODO(VIDHUB-PERF-01)`，不得将临时阈值写成验收承诺。

## 8. 对 Velo 的实施建议（P级，尚未实现）

| 优先级 | 建议 | 对应问题 | 验收方式 |
| --- | --- | --- | --- |
| P0 | 统一首帧、seek、缓冲事件时间戳 | 先能测量才可判断优化收益 | 同一播放会话可关联UI、网络、内核事件 |
| P0 | 保留mpv与ExoPlayer，明确核心选择及失败回退 | 多核心调度不能从竞品库列表照搬 | 核心切换/错误/恢复状态可复现 |
| P0 | 分离元数据、图片、媒体请求策略，按服务保留鉴权 | 避免连接策略混用或令牌泄漏 | 跨源重定向与取消请求测试 |
| P1 | 详情采用单一强播放按钮，轻量收藏/已看，分层技术信息 | 降低首屏干扰 | 390px与TV可达性验收 |
| P1 | 图片按显示尺寸解码、限制并发与内存缓存 | 海报列表易出现内存峰值与掉帧 | 冷/热列表帧时间与PSS对照 |
| P1 | 取消离屏任务，复用列表单元，先呈现可见分组 | 大库加载与滚动响应 | 快速滚动后后台请求量稳定 |
| P1 | 将预读/缓冲预算设为配置，按源与设备测量 | 防止缓存过大或弱网频繁中断 | 首帧、重缓冲、内存一起评估 |
| P1 | seek结束后提交，拖动中只预览；连续seek合并 | 降低无效媒体请求 | 服务端Range请求和目标帧延迟对照 |
| P1 | 字幕字体/渲染缓存与生命周期明确，复杂ASS单独测试 | 字幕可能是CPU与内存热点 | 特效字幕、字体回退、切集释放测试 |
| P2 | 海报取色异步计算并缓存，低性能设备保留实色回退 | 背景变化与模糊效果可能增加开销 | 帧耗时/对比度/无图状态验收 |

这些建议是可实施方向，不是已经从 VidHub 业务代码提取的配方。保留 Plex/Jellyfin/Emby、Watch Together、手机/TV；弹幕网关由用户配置；新增可选核心也不能替换现有mpv/ExoPlayer。业务参数需要配置项与TODO编号，原型数值不直接写入正式产品。

## 9. 原型操作与验收

在本目录使用静态服务器打开 `prototype.html`，通过展示台选择首页、电影、剧集、播放器。首页点击电影/剧集进入详情，点击播放进入模拟播放器，返回恢复浏览路径。横向列表可滚动；收藏、分页、进度、倍速与面板使用演示状态。

原型以真实DOM重建布局、按钮、卡片与滚动结构。截图中的海报与人物仅作局部视觉资产；不将整张长截图作为唯一界面。素材中可能携带原图艺术标题，须与DOM按钮区分。媒体路径使用脱敏演示文本。

设计验收：375/390/430px页面不整体横向溢出；横向卡片允许局部滚动；播放器按2.225:1比较黑边、顶部、时间轴与底行；检查首页→详情→播放→返回、搜索、收藏、分页、暂停、seek、倍速、字幕面板及锁定。浏览器不保证自动强制旋转；横屏布局通过独立画布/全屏入口表达。

实际验收结果以独立验证记录为准。本报告不把设计清单当作测试通过；原型没有真实播放、刮削、投屏或网络优化能力，也不构成Dart/native代码交付。

## 10. 版权、隐私与本地交付

本交付是用户指定样本的本地研究。VidHub品牌、图标、影视海报、人物及截图内容归各权利人。Velo是Plezy衍生社区项目，保留上游归属和GPL-3.0，和VidHub无官方隶属关系。

不发布APK、反编译文件、私有截图、服务器路径/令牌或未脱敏日志。原型素材仅供本地对照，不能直接成为Velo公开发行资源；公开前需替换为授权或原创素材。报告中的架构建议不复制受保护实现代码。

本轮不修改正式Flutter、Android、数据库、服务接口或生成Dart；不构建/打包/提交/推送。没有共享产品源码改动；项目原有原型保留。普通原型验证不触发版本号递增。

### 原型还原的已知差异

播放器背景取自实机截图的无控件中央区域，并重新铺放为视频画面。这样避免把截图中的按钮重复叠在DOM控件下方，但人物与画面构图会与实机整帧不同。首页与详情也使用裁剪资产，属于视觉研究复用；按钮、标题、列表与交互为DOM重建。原型不能作为逐像素完全一致的宣称。

本地持久证据在 `evidence/`，已将个人目录前缀替换为占位符；工件哈希与关键符号/资源保留。原始APK仍在用户指定位置。

## 12. ReArk GUI 补充取证（2026-11-13）

macOS 解锁后使用本机 ReArk v1.2.0 对 base APK 做了 GUI Summary 检查。Summary 复核包名 `com.oumi.utility.media.hub`、版本 `3.0.3`、versionCode `318`、minSDK `28`、targetSDK `36`，并显示 NetEase EasyShield、1 个 DEX、30 个类、222 个方法、54 个字段、62 个 Activity、5 个 Provider、3 个 Receiver、13 个 Service。ReArk 的30类与前述 REA 搜索得到的32类属于工具统计差异；统计口径或过滤原因尚未核实，保留两种观察，不相互替换。权限计数为24，包含 `INTERNET`、`ACCESS_NETWORK_STATE`、`FOREGROUND_SERVICE_MEDIA_PLAYBACK`。

ReArk Agent 首次查询曾因端点要求 API Key 失败，此阻塞现已解决。用户授权配置本地 Magpie：`http://127.0.0.1:3425/v1`，选中模型 `auto/gpt-6.1-sol`，无须录入密钥。真实 ReArk 请求耗时22秒，`summarize_package` 与 `inspect_entry_points` 均完成并返回中文答复。这验证了连接及只读工具调用；模型答复不作为新增静态取证事实，22秒也不是媒体播放性能指标。打开 arm64 配置 split 时 GUI 报 `Invalid APK file`。它可能只是 split APK 不能单独作为完整应用打开；该报错不作为 split 内容损坏的结论。

完整的本地观察记录在 reark-gui-observations.md（原始材料未公开）。GUI Summary 仍不能恢复加固业务 DEX、证明默认播放内核或提供网络/性能实测；前述静态 REA 证据和未知项仍然适用。


## 13. ReArk 深入取证：网络、缓存资源与JNI反汇编

本轮使用 ReArk 1.2.0 GUI 和本地 Magpie。界面模型显示 `auto/gpt-6-astra`（沿用用户现有选择）；前轮 `auto/gpt-6.1-sol` 连通记录仍作为历史保留。本轮读取本地样本资源，并反汇编libplayer JNI方法；不执行APK、不连接媒体服务器。13.1–13.2依据资源工具原文，13.4依据汇编与PLT/GOT映射；模型概括本身不作为证据。

### 13.1 路线管理与校验规则

01-network-route.txt（原始材料未公开） 第2–4行记录 `query_resource_table` 的call ID、输入及36/36返回计数，第6–18行保存相关资源ID、key与原文。可确认主线路、自动最快、手动切换、刷新线路、添加/编辑备份线路的资源声明。

新增可复核校验提示文案：第17–18行对应资源 `0x7f12057e` / `0x7f12057f`，文案要求名称不能为空，端口范围为1–65535；资源文案尚不能证明运行期校验逻辑。服务器地址字段存在，但本轮未确定其必填规则。原型可以模拟这些表单与切换，不能显示伪造的真实测速值或声称进行了网络探测。

自动最快的探测算法、排序时间窗、连接池/并发/超时、HTTP Range应用参数和失败回退仍未取得。资源表及Manifest入口不是应用调用实现。

### 13.2 缓存与播放选项新增事实

02-cache-playback-resources.txt（原始材料未公开） 第2–4行记录 `query_resource_table("settings_playback")` 及34/34原工具返回计数；第6–26行是明确标注的摘录，不能把摘录称为全量输出。

| 新增资源事实 | 支持的产品意图 | 未知项 |
| --- | --- | --- |
| `settings_playback_cache_duration_format = %1$d min` | 缓存时长以分钟显示 | 可选时长数组、默认值及落盘预算逻辑 |
| `settings_playback_audio_hardware_decode` | 音频硬件解码选项 | 实际解码器、默认开关和硬件命中 |
| `settings_playback_auto_deinterlance` 及风险提示 | 自动去隔行；提示可能影响非隔行视频 | 选用滤镜、启用条件、画质和性能影响 |
| `settings_playback_cellular_switchover_alert` | 蜂窝播放提醒 | 触发检测、提醒持久状态和默认值 |
| `settings_playback_resolution_high` / `settings_playback_resolution_orignal` | 网盘选择最高分辨率视频流或原始视频文件 | 是否转码、实际URL选择、带宽与首帧差异 |
| `settings_playback_auto_enter_pip` | 自动切换PiP选项 | 自动触发条件和运行期行为 |

512MB仍只是默认值展示资源。缓存容量档位映射和时长候选数组未取得，不把128/256/512/1024等序列写成竞品真实档位。原型新增设置初始值必须写为未设置或演示。

ReArk对XML `stepSize` 的展示为空，前轮apktool原XML为1。两者属于解析器表示差异；不据此改写原XML事实，也不推断运行滑块失效。实际档位和覆盖逻辑仍需实现或设备证据。

### 13.3 对此前结论的影响

资源取证增加可见设置和表单校验提示，JNI反汇编补充通用API调用和native生命周期。截至该轮尚未取得应用业务层具体播放实参、持久默认值或性能收益证据；后续第14.1节新增媒体探测实参，不改变播放配置仍未知的范围。第5节资源/库能力边界、第6节未知项及第7节全部待测的性能矩阵继续适用。新原型互动属于模拟产品流程，不代表APK动态分析通过。


### 13.4 libplayer JNI 方法级反汇编

稳定记录：03-native-jni.txt（原始材料未公开）。第1–4行记录从ABI包提取的约35KB `libplayer.so` 与ReArk GUI哈希一致：`6d4a05854f571ee40bf91710e7b92dac9e2785d9cc734a376f8ad1636bee9907`。本轮8次静态工具操作，没有执行APK或连接服务器。此次取得的是AArch64反汇编，不是C源码或C伪代码反编译。

下面地址为ELF虚拟地址，和符号 `st_value` 相合，不是设备运行地址，也不同于第4.3节的字符串文件偏移。JNI符号统一前缀为 `Java_com_omi_omimpv_wrapper_MPVLib_`。

| 方法与符号范围 | 可复核指令/调用证据 | 静态可确认行为 | 证据定位 |
| --- | --- | --- | --- |
| `create` 0x41b0，长度0xcc | 0x4240调用mpv_create；0x4260请求日志 | 创建实例并存入共享g_mpv；设置JavaVM/Android app context及JNI缓存 | 第27–35行 |
| `init` 0x427c，长度0x88 | 0x4294调用mpv_initialize；非负结果后0x42c0调用pthread_create | 初始化成功路径清退出标志并启动event_thread；随后设线程名 | 第27–35行 |
| `setOptionString` 0x4b3c，长度0xec | 0x4bb0→PLT 0x78a0→GOT 0xbf90→mpv_set_option_string | JNI转换的两个字符串传x1/x2，g_mpv传x0；调用后释放字符串并返回结果 | 第8–17行、第41–50行 |
| `attachSurface` 0x456c，长度0xc8 | 0x45d0→PLT 0x7860→GOT 0xbf70→mpv_set_option | JNI槽0xa8创建全局引用并存0x10140；选项name地址0x2c56、format=4，data指向该引用值 | 第18–26行、第41–50行 |
| `detachSurface` 0x4634，长度0xc4 | 0x4680→同一mpv_set_option入口 | 提交零值地址后，经JNI槽0xb0删除全局引用并清零 | 第18–26行 |
| `destroy` 0x4304，长度0x78 | 0x4330→mpv_wakeup；0x4340→pthread_join；0x4348→mpv_terminate_destroy；0x434c清g_mpv | 请求事件线程退出，唤醒，等待线程，然后释放实例 | 第36–40行、第41–50行 |

上述调用身份由PLT反汇编与99条完整relocation交叉核验，不是仅看到库导入名字。共享g_mpv、退出标志和event_thread的GOT定位分别为0xbe10、0xbe18、0xbe20，支持这些native方法共享状态的结论。它仍不提供Java业务层调用顺序。

**参数证据的边界：**`setOptionString`是通用桥接，在观察范围内没有硬编码hwdec/cache/subtitle值。故“JNI把调用方字符串传给mpv”已获得方法级证据，而“VidHub实际传入某个缓存容量/硬解默认值”仍未知。Surface选项name指向0x2c56，但本轮字符串未可靠解码，不能把它写成已核实的 `wid`。日志name地址0x2978同样不猜测文本。

**资源释放的边界：**完整destroy函数未包含Surface全局引用删除，detach函数承担了该步骤。这只证明native职责分离；Java是否总在destroy前调用detach尚未恢复，不据此指控内存泄漏，也不宣称旋转、PiP、切集释放已经通过。

**工具质量限制：**记录第51–53行说明第7次工具将0x2977长段误作UTF-16LE而返回乱码；第8次只确认UI完成状态，未查看原文。本报告不采纳这些模型解释。深层业务选择、网络客户端、Range/最快路由算法、缓存档位/淘汰、seek预读、DV/硬解完整API实参（后续单会话日志设值见第15节）、字幕字体缓存、自定义libass及真实Surface/Texture命中仍未知。第7节性能矩阵仍全部待测。

### 13.5 新增设置原型与验证入口

[打开可交互原型](prototype.html)：首页“设置”与播放器“更多”可进入新增的线路管理、网络与缓存、播放设置模拟面板。可以演示主/备线路、名称与端口校验、缓存容量/分钟、磁盘与蜂窝开关、去隔行、音频硬解、网盘原文件选择；没有真实测速、缓存落盘或核心切换。

初始缓存值为未设置，容量MB/GB和时长编辑均为演示输入，不能当作VidHub实际档位。复核记录中的2 GB/10分钟是验收操作选值，不是APK默认。

独立增量验收见 [verification-deep.md](verification-deep.md)，包含入口、状态共享、字段校验、重置与最小播放闭环。预览：网络与缓存（原始材料未公开）、播放设置（原始材料未公开）。它们是本地原型截图，不是VidHub实机设置截图。该浏览器验收不升级为Android播放/网络性能实测。


## 14. 实际参数补证与动态验证进展

### 14.1 DV/HDR媒体探测的实际native参数

本轮稳定证据：01-probe-options.txt（原始材料未公开）。ReArk汇编的调用实参、PLT与已有relocation映射相互核验，并在同哈希二进制对字符串做定点ASCII字节补核。因此以下值已经超出“库有该选项名”的证据等级：它们是应用native探测函数中的静态调用实参。

| native路径 | 已核实际调用参数 | 结论范围 |
| --- | --- | --- |
| `nativeGetDolbyVisionAndHDRType` 的两个输入分支 | `av_dict_set_int(probesize, 262144)`，256 KiB | DV/HDR媒体探测参数，非播放器缓存预算 |
| 同上 | `av_dict_set_int(analyzeduration, 1000000)`，1秒分析预算 | 不能当整个函数硬超时或首帧实测 |
| 同上 | `av_dict_set(fflags, nobuffer)` | 此探测输入的格式选项，非播放会话全局低延迟配置 |
| 自定义AVIO分支 | 缓冲65536；read回调0x6804，seek回调0x689c，write为NULL | 自定义输入IO缓冲，不是影片预读/磁盘缓存容量 |

两分支随后进入 `avformat_open_input` / `avformat_find_stream_info`。这些实参来自应用自己的native探测代码，不能被表述为FFmpeg库默认值。原始整数仍保留。官方文档补核见 04-api-units.txt（原始材料未公开） 第1–6行：[FFmpeg formats](https://ffmpeg.org/ffmpeg-formats.html) 定义probesize为bytes、analyzeduration为microseconds，并将nobuffer限定为减少初始流分析阶段引入的缓冲。故262144 bytes为256 KiB，1000000微秒为1秒；这不是整个函数硬超时。

Java何时调用此函数、是否对每次播放都调用、所探测输入与实际播放内核如何关联，以及参数对首帧和网络字节的实际影响仍未知。没有从这些值推导缓存档位、`hwdec`或硬解命中；也没有把65536写成“播放缓存64KB”。

### 14.2 安装材料与运行边界

首轮缺density split是历史状态。现已从匹配XAPK确认完整split，并在隔离Android AVD成功安装5个split、启动应用。安装材料与启动就绪不等于媒体播放就绪。该阶段界面曾停在Android权限页面；随后用户处理页面并恢复本地测试，现已取得第15节的媒体HTTP与解码日志。这一权限交接阻塞已解除；应用非debuggable和API实参观测限制仍在。


动态中间记录见 execution-notes.md（原始材料未公开）、installed-artifacts.json（原始材料未公开）、isolated-install-probes.json（原始材料未公开）、launch-observation.json（原始材料未公开）。使用独立AVD `vidhub_research_20261113`（Android36 AOSP arm64），安装base、arm64、xhdpi、en、zh共5个匹配split；base/ABI哈希与用户原样本相同。已有 `plezy_api36` 数据未擦除，也未替换其应用。

`am start -W` 返回Status ok，前台为GrantPermissionsActivity；启动记录1671ms仅是ActivityManager时长，不是播放首帧或性能基准。`run-as` 返回package not debuggable；未安装Frida、root或注入环境。CUA未能识别模拟器窗口，首轮因此交接用户处理权限；后续通过包限定外部URL测试继续，没有采用未授权UI控制替代。

已生成60秒640×360 AVC测试图+AAC正弦音频并建立回环HTTP源，媒体信息/哈希见 media-fixture.json（原始材料未公开）。服务代码 controlled_http.py（原始材料未公开），运行地址为本机127.0.0.1:18879，通过ADB反向端口映射访问。curl的Range自检得到206/100字节只是夹具自检，不是VidHub媒体请求；该准备阶段尚无应用请求；后续实际应用请求记录见第15节。

应用日志 vidhub-process-log.txt（原始材料未公开） 中出现CoreComponentFactory ClassNotFoundException后仍进入权限Activity，不能仅凭该条异常断言致命崩溃。直接文件HTTP夹具不等于兼容的本地媒体服务器，因此不能据其推断“自动最快服务器路线”算法。模拟器结果也不能直接代表手机硬件解码性能。

首轮曾以权限页面交接结束；用户处理后已恢复受控测试，见第15节。测试结束后HTTP夹具与18879反向映射已清理，AVD保留。旧服务地址不是长期可用播放入口；重跑前须确认设备、端口与媒体哈希。

### 14.3 探测循环预算与调用索引的范围

进一步记录见 02-probe-limits-xrefs.txt（原始材料未公开）。第2–7行的直接调用索引中，`mpv_set_option_string`仅列0x4bb0，`mpv_set_option`列0x45d0/0x4680；该索引明确排除未解析间接引用和运行时引用。因此不能以这些结果声称不存在其他配置路径，也不能还原实际 `hwdec`/`cache` 业务值。

第8–24行的DV探测循环反汇编观察到以下比较预算：

| 观察到的比较 | 原始数值 | 解释边界 |
| --- | --- | --- |
| elapsed超过阈值 | 150000微秒，即150ms；相等时继续 | 该循环的经过时间检查，不是整个探测函数硬超时 |
| 目标流包数 | 32 | 已观察循环包数预算，不是播放器解码队列或缓存包数 |
| 成功读取总包数 | 128 | 探测读取预算，不是并发请求数 |
| 匹配流累计字节 | 4194304 | 该循环数据预算，不是播放/磁盘缓存容量 |

PLT 0x7b70/0x7b80经先前工具原文与完整relocations交叉核实为 `av_gettime_relative` / `av_read_frame`。某一轮模型说明“未复核名称”属于该单轮上下文限制；报告采用跨轮工具原文闭环，而不是选择相信模型措辞。“目标/匹配流”选择语义仍有部分推断，NAL解析及成功分支尚未完整恢复；上述只是观察到的循环路径，不能推成完整探测算法。时间单位经 [FFmpeg av_gettime_relative文档](https://ffmpeg.org/doxygen/trunk/time_8h.html) 核实为microseconds；150000微秒=150ms，只是循环检查预算，不是整个函数硬截止或性能测量。

第14.1节的精确复核位置补充如下：01-probe-options.txt（原始材料未公开） 第4–9行为两分支字典实参，第10–11行为自定义AVIO，第15–18行为PLT映射，第19行为定点原始字节，第20–22行为结论边界；同文件第1行记录二进制hash。

### 14.4 最快路线与配置候选：有界查询后的未知

最后一轮证据：03-config-route.txt（原始材料未公开）。只采用逐个打开核对的工具原文，未采用仅有模型概述而未核对原文的Manifest/列表结果。

| 候选对象与证据行 | 实际观察 | 排除的误读 |
| --- | --- | --- |
| config_default.json / config_2160.json，第2–6行 | 三个网格列数分别3/1/3与10/8/12；配置选择器未追踪 | 不是网络并发、缓存大小或硬解配置；不能猜屏幕选择逻辑 |
| media_server_current.json，第7–10行 | 文件4380字节，仅返回2500字符；版本、帧率、尺寸、layers/shapes/关键帧符合Lottie动画结构 | 不能因文件名把它当媒体服务器连接/最快路线配置；未宣称读全文件 |
| item_media_server_route.xml，第11–13行 | root可点击/聚焦；两个TextView无text属性；无onClick或业务类声明 | 静态布局不能揭示测速值、状态绑定或程序事件注册 |
| search_loaded_content，第14–17行 | 查询media_server_route_auto_fastest无匹配；工具明确不搜索每个未打开源文件 | 只是有限覆盖负结果，不证明APK不存在最快算法 |

本轮没有取得“计时→比较/排序→并发选路→失败处理”调用链，也没有新增播放缓存/硬解实参。加固可见性边界仍在；三轮有界取证就此结束，不继续重复同一有限搜索。原型不能据这些候选填真实延迟、最快路线算法或默认缓存/硬解值。

### 14.5 本轮结论与剩余工作

本轮实质新增是**DV/HDR探测路径**的应用实参及局部循环预算，并非用户期望的播放缓存/hwdec运行值。完整split安装和合成HTTP夹具已经用于第15节外部URL测试。部分运行日志与HTTP行为已观测；因应用非debuggable等限制，完整API实参和实际属性读回仍未完成。最快路线算法仍未恢复。

后续验证依 [动态试验计划](dynamic-test-plan.md) 的可证伪标准开展：必须观察实际设置调用、内核运行解码状态、路线请求/选择/失败时序。没有这些记录时维持未知；不把静态探测数值、开关状态或curl自检当作答案。计划为本地可执行方案，不是测量结果。


## 15. 受控外部URL测试：运行证据与边界

本轮观察日期为2026-11-14 UTC，仅在隔离AVD `vidhub_research_20261113` 上进行。使用此前生成的60秒640×360 AVC/AAC本地测试媒体，没有新增或修改账户媒体服务器、使用私人URL或记录账户信息。正式记录：playback-results.md（原始材料未公开），精确索引：parameter-evidence-index.md（原始材料未公开）。本轮无root、注入或安全配置弱化。

### 15.1 本次路径可以确认什么

action-view-attempt.json（原始材料未公开） 第1行记录包限定 `ACTION_VIEW` 打开回环HTTP测试源，返回Status ok并进入 `VideoPlayActivity`。1242/1253ms为Activity启动工具计时，不是视频首帧。该Activity的exported=true可由已保存Manifest核对。

本会话取得libmpv请求和Android MediaCodec组件运行日志；后续恢复进程还出现mpv `file-loaded` / `MPV_EVENT_FILE_LOADED`。这支持“此外部URL输入走到mpv及MediaCodec处理路径”，不证明全局默认核心、所有媒体路径或画面已经呈现。CUA仍不能识别模拟器应用，没有录屏、屏幕截图或首帧视觉证据。

### 15.1.1 本次硬解、输出及核心选择的日志值

这是本轮相较资源/库能力层的关键进展：应用运行日志明确报告了此会话的设置，而不再只是APK包含选项文案。但证据等级仍是**应用日志自报**，未捕获对应API返回码或内核属性读回。

| 本次日志值 | 稳定原文定位 | 能说明与不能说明 |
| --- | --- | --- |
| `hwdec set to auto-unsafe` | synthetic-playback-filtered-log.txt（原始材料未公开） 第18行；delayed-playback-filtered-log.txt（原始材料未公开） 第3行 | 应用报告此会话设值；不证明API接受或物理硬解命中 |
| `currentVo set to gpu` | delayed日志第5行 | 应用报告输出配置值；不证明具体GPU输出路径或零拷贝命中 |
| `core=MPV reason=legacy_routing` | synthetic日志第19行；delayed日志第6行 | 此外部URL场景的核心选择日志；不代表所有片源或全局默认 |
| `player_2/is_strm/is_iso/is_DV/is_hdr=false`；`dolby_hw_enabled/vlc_hw_enabled=true` | 同一核心选择日志 | 本会话条件标志；不能据此恢复完整核心路由条件树或全局偏好 |

这些值与实际MediaCodec组件日志应分开读取：前者报告设置意图，后者记录组件创建/configuration。两者仍不足以取代mpv实际解码属性。没有取得应用网络缓存数值；定向日志检索未命中也不能证明没有设置缓存，因为保存的是筛选日志，并非完整全量捕获。

### 15.2 HTTP请求：两次完整写出，不推定两次用途

原始记录：http-observations.jsonl（原始材料未公开） 第2–3行；量化汇总：request-timing-summary.json（原始材料未公开）。第1行curl `bytes=0-99`属于早期服务自检，排除在应用请求之外。

| 首次会话请求 | Range / 状态 | 服务端成功写出字节 | 服务端响应头/全文件写出耗时 |
| --- | --- | --- | --- |
| UA `Lavf/62.8.102` | GET bytes=0- / 206 | 12,068,014 B | 2.163ms / 155.646ms |
| UA `libmpv` | GET bytes=0- / 206 | 12,068,014 B | 0.646ms / 72.337ms |

两请求开始时间间隔11.691秒。双UA和双请求是直接观察；“先探测、后播放”只是候选解释，未有请求与探测函数/播放加载事件的确切关联，不能作为已恢复实现。

服务端完整写出且disconnected=false，不等于客户端已消费全部数据或全部驻留内存/磁盘缓存。上述时间只度量服务端写出过程，不是实际端到端下载时长、网络带宽、缓冲时长或首帧；不能由12MB响应推导缓存容量。

### 15.3 解码组件与输入缓冲

synthetic-playback-filtered-log.txt（原始材料未公开） 第20/22行显示目标PID2087实际创建 `c2.goldfish.h264.decoder`；第65/66行显示高度360、宽度640，第71行显示 `max-input-size=6291456`（6 MiB）。这些是Android MediaCodec组件配置的运行观察。

`goldfish`是此模拟器环境中的组件名，不构成手机物理解码器硬解成功证明，也不是mpv运行属性 `hwdec-current` 的读回。`max-input-size`为解码输入上限，不能当网络缓存、预读量或整个播放器内存预算。第41行的 `output.delay.value=8` 保留原值，不解释为8毫秒、8帧或应用缓冲时长。

### 15.4 第二条URL尝试无效及ANR边界

delayed-action-view-attempt.json（原始材料未公开） 第1行记录再次打开配置500ms服务端延迟的 `/b` 路径，Activity调用超时并报告MainActivity，计时10519ms。服务没有收到任何 `/b` 请求，所以该条件没有真正进入HTTP测试；不能称为“500ms慢线路结果”、连接取消验证、最快选择或回退算法证据。

target-exit-info.txt（原始材料未公开） 第6行起记录PID2087在设备时间12:06:38.542发生reason=6（ANR），VideoPlayActivity等待 `FocusEvent(hasFocus=false)` 5000ms；description为user request after error。测试脚本未重启目标进程，无法据该描述断定由谁关闭；单次模拟器事件不推广为手机产品稳定性缺陷，也不把它归因于未发生的 `/b` 网络请求。

后续PID2527重新请求 `/a`，原始HTTP第4–5行分别出现Lavf/libmpv完整写出，时长42.619/102.983ms。delayed-playback-filtered-log.txt（原始材料未公开） 第95–96行确认mpv FILE_LOADED。它证明后续输入加载，不能解释为 `/b` 自动回退，也不能从重复读取宣称全局没有缓存。

### 15.5 本轮仍无法回答的内容与清理

本轮没有操作应用服务器最快线路选择流程；A/B文件URL不是该业务流程。没有完整mpv选项API返回码/属性读回，不能恢复缓存容量/时长对应的 `network-caching`、`cache-secs`、`demuxer-max-bytes` 实际值。物理设备硬解、首帧、缓冲、持续帧率、功耗和稳定内存曲线仍未测。

target-memory-after.json（原始材料未公开） 是单点内存快照，不是缓存大小。前后PID不同，不能用两个进程快照计算优化收益或泄漏趋势。

post-playback-cleanup.json（原始材料未公开） 记录04:08:34 UTC停止本次HTTP夹具并移除18879 reverse：四个全文件响应均已完成，距最后请求超过60秒。保留隔离AVD既有状态，不再重复ANR后的测试。未来重跑需要重新建立合成源和端口映射，当前回环URL不可作为交付服务承诺。

## 16. 首页启动资源网络：VidHub观察与Velo优化候选

当前任务焦点转为首页启动与资源网络，播放实验暂停。本节区分单次运行观察、APK静态证据、Velo代码路径和待测优化；不修改产品源码或现有原型，不用不同环境数据计算“快几倍”。

### 16.1 试验口径与时间锚点

本次仅一次进程冷启动、一次暖返回，没有P95统计或Velo同环境实测。恢复已有研究AVD数据，不清数据、不重装；因此“COLD”指进程启动，不是首次安装或磁盘缓存全冷。稳定摘要：runtime-brief.md（原始材料未公开）。

cold-launch.json（原始材料未公开） 记录MainActivity `TotalTime=995ms`、`WaitTime=998ms`；这不是媒体资源完成或首张海报显示时间。CUA未能识别模拟器，无法做首页画面完成的视觉确认。

日志阶段时间以 `home_load_started` 为零点，设备日志墙钟为12:14:43.085；clock-basis.json（原始材料未公开） 记录设备CST、宿主UTC。下表的日志墙钟差与应用自报elapsedMs分开，不跨时钟相减，也不把Activity启动计时加进表中得到伪造总耗时。

### 16.2 单次冷启动可观察时序

详细表：startup-timeline.md（原始材料未公开）、cold-timeline.json（原始材料未公开）、cold-stage-disambiguation.json（原始材料未公开）。

| 阶段/方法 | 相对home_load_started | 本次能确认什么 | 不能确认什么 |
| --- | --- | --- | --- |
| home_load_started | 0ms | 日志阶段零点 | Activity进程真正开始时点 |
| loading_hidden | 应用自报elapsed=133ms | 加载遮罩隐藏事件 | 海报已显示或媒体数据已齐 |
| all_enabled_sections_ready | 应用自报elapsed=135ms | 日志声明栏目ready，但相应section.*计数均zero | 有内容首页已经完成；缓存先显 |
| getMediaViews | +165→+1285ms，方法区间1120ms | 媒体视图方法日志起止 | DNS/TLS/TTFB或具体协议耗时 |
| getResumeItems | +1289→+1561ms，272ms | 在上条完成日志之后开始 | 所有场景都会串行或由上条直接调用 |
| getSystemInfo | +1811ms发起 | 有该方法事件 | 后端是Emby/Jellyfin/Plex哪一种 |
| 5个getLatestItems | +1812…+1815ms发起 | 3ms窗口内出现5个方法发起日志 | socket实际并发数、连接复用和请求池大小 |
| getLatestItems成功回调 | 首个+2108ms，最后+2168ms | 本次最后一条Latest成功距home阶段起点2168ms | 图片完成、单库UI逐步提交或全屏资源完成 |

`first_file_sources_ready`、`ui_file_sources_committed`、`home_resource_flow`中的列表positive只证明文件来源列表非空，不证明缓存影片、海报已绘制。135ms的“ready”与后续2168ms的媒体回调是不同范围的阶段事件，不能将前者作为VidHub资源加载完成时间。

### 16.3 暖返、失败和静态证据的解释边界

warm-return.json（原始材料未公开） 记录返回同PID2056，`WaitTime=166ms`，无TotalTime，系统明确将既有task置前；warm-log-derived.json（原始材料未公开） 未出现新的首页/媒体方法日志。这是暖任务返回，不是一次新的资源加载，不能与冷启995ms直接相除得启动提升倍数。

backend-and-failure-derived.json（原始材料未公开） 记录+30147ms的MediaServerFileProvider SocketTimeoutException，未能归属具体端点；它既不是首页完成时刻，也不足以把先前Latest归为失败。后端枚举/client类白名单未匹配，API名称不足以认定服务器产品。

本轮APK静态核查对应 01-startup-manifest.txt（原始材料未公开） 第2–12行、02-home-layout-and-search.txt（原始材料未公开） 第2–17行。可见Startup初始化器、Glide/OkHttp集成、Room服务、Profile资产及刷新/纵横列表结构；这些不证明缓存命中、批量请求或启动收益。HomeStartupPerf等loaded-content搜索负结果仅覆盖已加载/缓存内容，不否定运行日志。`nedata.db`未读schema，不把文件名当作首页缓存数据库。

仍缺DNS/TLS/TTFB、实际cache命中/TTL、图片尺寸请求、首张海报及首行显示时间。日志仅在内存按白名单抽取阶段/方法/时间与zero/positive分类，未保存账户、媒体名称、库ID、完整URL或令牌，也没有送入ReArk模型。


### 16.4 Velo当前代码：已经并行的部分与剩余屏障

代码核查基于HEAD `c41732f`，仅只读追踪，无Velo动态测量或测试。完整原样签名、请求和边界见 velo-code-trace.md（原始材料未公开）。以下源码链接指向当前工作区，后续提交可能改变行号，应以该证据快照为准。

| 路径 | 已有机制与准确定位 | 对首页可见时间的含义 |
| --- | --- | --- |
| 启动身份/内容门 | [main.dart:1263](../../lib/main.dart#L1263) `awaitStartupContentReady`；[profile_session_screen.dart:249](../../lib/navigation/profile_session_screen.dart#L249) 的Discover门为 `isBinding && !isStartupIdentityReady`；[home_startup_gate.dart:47](../../lib/widgets/home_startup_gate.dart#L47) `_prepare` | 身份授权先完成；首online或剩余内容预算放行。2秒是共享预算，不是两次固定等待；有网时身份阶段不受此2秒限制 |
| 连接绑定 | [active_profile_binder.dart:656](../../lib/profiles/active_profile_binder.dart#L656) `_bindJoinRows` 并行连接；[main.dart:2276](../../lib/main.dart#L2276) 发起binder | 不是全部服务器连接完成才可进入Discover |
| 授权磁盘快照 | [discover_provider.dart:163](../../lib/providers/discover_provider.dart#L163) `_homeClients`仅取online；`:167 _restoreHomeSnapshot`，`:189`读取并发布；[home_snapshot_store.dart:64](../../lib/services/home_snapshot_store.dart#L64) 24h TTL，`:69 read` | 已有缓存首屏，但快照仍在身份/online及auth scope、epoch、隐藏库校验之后；不是无需网络的无条件快照 |
| online前置健康检查 | [multi_server_manager.dart:887](../../lib/services/multi_server_manager.dart#L887) checkHealth后online；[jellyfin_client.dart:574](../../lib/services/jellyfin_client.dart#L574) 请求currentUser并可能等待权限/头像持久化 | 可能延迟online以及快照读取；需量化，不得绕过身份权限 |
| Continue与Hubs | [discover_provider.dart:390](../../lib/providers/discover_provider.dart#L390) `ensureLoaded`复用inflight；`:559 getOnDeckProgressively` 与 `:571 getHubsProgressively(includePlaybackHubs:false)` 同时发起 | 后面依次await不等于网络串行；无需重做已有并行 |
| 多服/单服发布 | [data_aggregation_service.dart:160](../../lib/services/data_aggregation_service.dart#L160) `_homeProgressively`按已完成服务器发布；`:664`库列表后进入`:788 _fetchLibraryHubsForClient`；`:849`等所有worker | 多服已渐进，但同服Latest滑窗并发3，等全库结束才返回该服；慢一库可挡住同服先完成栏目 |
| J/E Views | [browse.dart:323](../../lib/services/jellyfin_client/parts/browse.dart#L323) `fetchLibraries`只合并inflight；`:1758`隐藏库Continue分支可能直调`_fetchLibraries` | 同时请求可合并，错开会重新请求；是否实际重发需运行确认，不宣称已有TTL复用 |
| Jellyfin Continue | [browse.dart:1807](../../lib/services/jellyfin_client/parts/browse.dart#L1807) 并行Resume/NextUp；`:1824`仍await `:2305 _attachSeriesLastPlayed`，`:2609`单系列补全 | 最多24系列、并发4、单请求3秒、整pass4秒已有边界，但排序补全仍在首排返回前 |
| Plex装饰数据 | [plex_client.dart:1677](../../lib/services/plex_client.dart#L1677) 等待`:1689 _backfillMissingLogos`；`:1705`等合并owner metadata返回 | 缺logo时一个合并请求可延迟首批内容，不是每卡一次全详情请求 |
| 去重附加请求 | [data_aggregation_service.dart:443](../../lib/services/data_aggregation_service.dart#L443) 仅重复title bucket进入；`:575 fetchExternalIds`合并 | 只在特定重复标题路径产生等待，不能泛化为每张卡补元数据 |
| 图片与Skeleton | [optimized_media_image.dart:300](../../lib/widgets/optimized_media_image.dart#L300) 按slot尺寸加载，`:583`内存命中可画；[image_cache_service.dart:20](../../lib/services/image_cache_service.dart#L20) 并发3/6；[discover_screen.dart:1186](../../lib/screens/discover_screen.dart#L1186) | 图片异步独立；门退出仍可能skeleton。图片缓存14天/3000条也不等于当前已命中 |

J/E Latest使用每行limit20并且首页 `includePlaybackHubs:false`，当前每库不会重复请求Resume/NextUp。Emby的有界Resume window=300承载隐藏/下一集语义，不能简单减成20声称等价提速。Plex provider初始化与global合并也有独立路径，不能套用Jellyfin的请求链。

### 16.5 可比较与不可比较的结论

VidHub单次记录中5个Latest方法在3ms内出现；Velo源码中同服Latest滑窗3。它支持设计调度实验，但不证明VidHub网络并发一定为5，也不证明把Velo改5会提速。两者服务器类型、数据、磁盘/HTTP缓存、图像资源与完成定义尚未对齐。

同样，VidHub的空栏目ready135ms不是非空模型提交，更不是首海报。Velo的2秒内容门是身份就绪后的共享内容等待预算，非整个启动或资源加载的上界。比较这两个数会混淆实现门槛和完成事件。当前没有可辩护的“快X倍”或“节省X%”结果。

### 16.6 优化优先级与验证条件（建议，未实现）

| 优先级 | 候选改动 | 预期机制而非实测收益 | 验证与保护条件 |
| --- | --- | --- | --- |
| P0：先补观测 | 拆分identity、online、snapshot读/发布、Views、Resume/NextUp、各Latest、首非空模型、首图和图齐时间戳 | 避免把ready空态或Activity显示误当资源完成 | 同会话相同时间基准，记录缓存命中与计数；不记录私有媒体/凭据 |
| P1-A：单库渐进 | 在同服Latest worker完成时逐库提交，保留既有多服渐进 | 慢库不再挡住同服已完成的栏目 | 人为延迟一库，验证其他行提前出现；保留取消、epoch、隐藏库、去重和失败保旧语义 |
| P1-B：补全延后 | Plex logo装饰后补；Jellyfin LastPlayed排序分阶段提交 | 元数据/排序补充不挡住首批可用内容 | 验证logo迟到/失败、排序移动与焦点稳定；不可丢失NextUp/Emby隐藏语义 |
| P1-C：Views合并 | 统一隐藏库分支与首页inflight，评估短期复用策略 | 减少同启动窗口重复库列表请求 | 先证明重发存在；检查切号、隐藏库变化、刷新和库变更失效 |
| P2：授权快照更早显 | 探索在身份授权明确后、在线健康检查未结束时读取已授权scope快照 | 让磁盘已有非空内容可能更早可见 | auth epoch、PIN、注销、权限撤销、隐藏库必须正确；不是跳过授权，也不保证离线旧数据可见 |
| P2：并发调参实验 | Latest并发3/5/6集中配置对照 | 可能减少尾部等待，也可能增加服务器压力 | 同机同服同库，观察总字节、错误/超时、首行及图齐；不把VidHub方法日志数量当推荐常量 |

这些候选的共同方向是“缓存先显、单库渐进、装饰补全移出关键路径”，不是复制未证实的VidHub缓存方案。先以单库渐进与可拆分补全做有界实验；缓存提前涉及授权边界，需先做scope/epoch验证。

### 16.7 对照测试方案与交付边界

同机、同服、同账户权限配置和测试库，分为进程冷启但磁盘温、清测试缓存、暖返回三组，各至少5次用于初步复现。统计全部样本及中位数，尾部指标需足够样本并披露算法。记录请求方法与HTTP真实起止、首非空模型、首张海报、首行完成、图齐和错误；工具启动计时单列。

额外覆盖：延迟单库、部分失败保旧、隐藏库、重复标题、切号/注销/PIN及权限变化。缓存先显应验证“授权一致的非空缓存提交早于在线请求完成”，不能只看到Room或快照文件存在就判定。测试只使用授权测试数据并脱敏。

本轮新增报告和证据，没有修改Velo正式源码、原型或服务器配置，也没有执行Velo性能测试。若之后批准实现，须单独完成 `flutter analyze`、`scripts/run_tests.sh` 等项目检查；当前报告不声称这些检查通过。


## 17. 首页与详情评分：显示了什么，来源证据到哪一步

### 17.1 先回答首页问题

**首页轮播和海报角标已经显示评分；本轮无需先打开详情才能研究这些评分。当前还不能确认首页的分数来自哪个响应字段、哪个评分提供方，或是否由VidHub另发请求补取。** 第16节的 `getMediaViews`、`getResumeItems`、`getLatestItems` 只保留方法阶段与成功回调，没有响应body，不能把方法成功升级为“已证实其中携带评分”。

评分归源需拆开三层：①客户端收到的服务器字段；②该服务器字段的上游元数据提供方；③客户端是否另外访问评分服务。知道其中一层不能自动补齐另外两层。品牌资源与界面显示也不足以证明网络链路。

| 界面位置 | 画面分数 | 当前可确认来源或含义 | 请求链证据 | 未知部分 |
| --- | --- | --- | --- | --- |
| 首页轮播黄星 | 示例8.0 | 用户截图确认此处已有评分；星形是表现形式 | 只有首页加载方法阶段，没有对应响应或UI字段绑定 | 服务器字段、上游提供方、独立补取、尺度与缓存 |
| 首页海报右下角标 | 多个条目各有不同分数 | 截图确认角标；APK有同类右下角布局候选，但未追到首页Adapter关联 | 没有已绑定角标的请求/响应证据 | 是否与轮播共用字段、实际来源、刷新时机 |
| 电影详情黄星 / 剧集详情黄星 | 7.5 / 8.0 | 对应星形评分视觉；详情XML声明星形detail_rating | 未取得响应字段与控件赋值链 | 是否同首页字段、提供方、换算方式 |
| 电影详情紫色标记 / 剧集详情紫色标记 | 8.5 / 9.4 | 图形和紫白配色与APK的Trakt图标相符，属于视觉对应推断 | 未证明这些值来自Trakt HTTP响应，也未证明客户端直连Trakt | 服务器聚合、代理、本地缓存或客户端独立请求均未区分 |

分数仅记录用户截图中的画面值，不校验作品实时评分，不写入媒体标题或ID。详情图标的新增证据使“紫色标记视觉上对应Trakt”成为有依据的推断，**仍不能把首页星分认定为Trakt，更不能把任一紫色分数认定为已验证的Trakt请求结果**。

### 17.2 APK确认的是哪些资源与控件

- 评分品牌标签资源包含IMDb、Rotten Tomatoes audience、Rotten Tomatoes critics、Trakt，以及“Show More Ratings”设置文案；实际开关默认值未知。这证明包内支持这些品牌的显示资源，不证明本次展示了全部来源或向各站发起请求。稳定原文：第一轮资源记录（原始材料未公开）:2–13。
- `media_list_item.xml` 的 `rating_image` 静态引用星形图标，`rating_text` 没有text属性。值必须由其他路径填充，但本轮未取得该路径；不能从空XML文本推断没有评分。记录：同文件15–18行。
- `detail_display_media_item.xml` 声明2:3海报、底部end角 `rating_view`、圆角角标背景及白色粗体 `rating_text`，没有静态文本或图标。这是与首页海报角标相似的布局候选，尚未证明首页Adapter实际使用它。稳定原文：第二轮绑定与边界（原始材料未公开）:13–15。
- `ic_more_ratings_trakt.xml` 的圆形、多线check路径，与已有apktool同路径的20dp、白底 `#ffffff` / 紫色 `#9f42c6` 相互核对；截图紫标与此形状配色相符。ReArk的fillColor解析为空，颜色补证来自已有apktool资源，不将解析空值当真实透明色。记录：同文件2–5行。
- 普通详情声明星形 `detail_rating`；服务器详情另声明好/差番茄评分控件。两者的 `more_ratings` 类型均为 `com.mac.utility.media.hub.common.view.MediaRatingsView`。XML的visibility原值2不代表运行时必定隐藏。记录：同文件6–10行。
- 对该自定义控件精确读取源码返回 `file_not_found`，有限已加载内容搜索没有补齐模型映射。加固与可见材料限制仍存在；无代码返回不能证明没有实现。记录：同文件11–12、16–17行。

已排除一条假阳性：`rating_feedback_url` 指向软件支持页面，是应用评价入口，不是影视评分API。第一轮记录（原始材料未公开）:14。

### 17.3 首页运行记录能证明和不能证明什么

本轮只读同一AVD的前台MainActivity，没有切详情、播放、刷新、强停、重装、清数据或变更账号/媒体源。先前417行包日志的评分白名单检查，仅命中MediaScrapper初始化、AppCompatDelegate元数据关键词与HomeStartupPerf的ByRating栏目。这些是初始化或栏目名称，不是评分请求证据。

新增时间窗口内目标进程新日志为0行，不能据此断言没有网络请求。当前未捕获能够归属首页评分的HTTP方法/路径/状态、响应rating字段、source枚举或cache-hit。它不能区分“服务端透传”“客户端补取”“本地缓存”“混合来源”，也不能证明评分请求已合并或不存在独立请求。用户不需要为了填补这一证据缺口继续打开详情。

稳定依据：运行简报（原始材料未公开）:1；已有日志白名单派生（原始材料未公开）:1；新增窗口派生（原始材料未公开）:1。第16节启动方法时序仅作上下文，不作评分字段证明。本轮未抓包/MITM/root，未使用账户key访问服务器，没有新增后台监听。

### 17.4 Velo对照：现有代码如何获取与展示评分

下表是**Velo当前代码事实，不是VidHub实现推断**。稳定字段映射与接口基线：Velo评分字段映射（原始材料未公开）。

| Velo入口 | 数据映射或请求链 | 代码位置 | 解释边界 |
| --- | --- | --- | --- |
| Jellyfin / Emby映射 | `CommunityRating` → `audience`（0–10）；`CriticRating ÷ 10` → `rottenTomatoesCritic` | `lib/services/jellyfin_mappers.dart:428`，`_ratingSources` | audience是通用分类，不能据字段名认定TMDB/豆瓣/IMDb；RT是该客户端映射语义，未核服务器实际上游 |
| Jellyfin / Emby详情 | `fetchItem` 请求 `<local-path-withheld>`，带详情Fields；同ID进行中请求合并 | `lib/services/jellyfin_client/parts/browse.dart:772,811` | 评分随条目响应读取，不等于客户端独立访问评分站；模板占位符不是实际账号/作品ID |
| ProviderIds | `fetchExternalIds`复用 `fetchItem` 再读取ProviderIds | `lib/services/jellyfin_client/parts/playback.dart:1112` | 有外部ID不证明评分来自相应网站 |
| Plex评分映射 | 合并 `rating/ratingImage`、`audienceRating/audienceRatingImage`、`Rating[]`；按URI识别IMDb/TMDB/RT；无源则保留泛称 | `lib/services/plex_mappers.dart:970`，`plexRatingSources` | URI可提供服务器返回的来源标签，不代表客户端已直连该提供方 |
| Plex详情请求 | `_getMetadataWithImages` 访问 `/library/metadata/{ratingKey}`；外部ID请求增加 `includeGuids=1` | `lib/services/plex_client.dart:1245,4708` | 返回条目可包含评分；外部ID与评分归源是两件事 |
| 详情补充探测 | 350ms后触发 `fetchItem`，复用结果记录ratings | `lib/screens/media_detail/playback_tracks_status.dart:46,77,165` | 是详情条目探测，不是已证明的专用评分HTTP |
| Simkl目录 | `fetchDetail` 访问 `/{type.detailPath}/{simklId}`；同一响应中映射simkl/imdb/mal | `lib/services/catalog/simkl_catalog_source.dart:216,553` | 显示三个品牌不等于分别请求三个网站 |
| AniList目录 | `fetchDetail` → `getAnimeDetail`；`meanRating` → `anilist` | `lib/services/catalog/anilist_catalog_source.dart:162,181,222` | 此处有明确目录来源；不能推广到J/E服务器CommunityRating |
| 展示策略 | 对已有模型按来源顺序/隐藏策略筛选，海报最多1项、详情最多4项 | `lib/widgets/media_rating_badge.dart:30`；`lib/utils/rating_display_policy.dart:19` | 展示限制不是请求数量，也不是VidHub的评分策略 |

### 17.5 下一步怎样确认首页评分链路

优先针对首页本身取证，不以详情导航作为前提。需要在获授权的受控测试库中，把同一测试条目的四个环节连起来：服务器或目录响应的字段 → VidHub模型赋值/换算 → 首页轮播或角标的控件赋值 → 更新时点。只有出现独立提供商请求并能与该分数关联，才升级为“客户端独立补取”；若只见服务器字段，则保留其上游提供方未知。

| 可证伪问题 | 所需最小观测 | 当前状态 |
| --- | --- | --- |
| 首页分数随Latest/Resume条目返回吗 | 脱敏响应中确切字段与UI赋值关联，不能仅凭方法名 | 未验证 |
| 首页轮播与海报角标同源吗 | 同测试条目两处模型字段与格式化路径 | 未验证 |
| VidHub另向评分服务发请求吗 | 请求目的类别、路径模板、时序与响应分数关联；不保存凭据/私有URL | 未验证 |
| 紫色详情标记的值确来自Trakt吗 | 已识别图标之外，还需值的来源链和尺度 | 仅视觉对应推断 |
| 是否有评分缓存或TTL | 明确缓存命中/键范围/有效期及受控更新前后结果 | 未验证 |

当前完整的是调查边界与验证路线，并非已还原评分请求算法。**可向用户确认：首页确实有分；APK有多来源评分资源；紫色详情标记视觉上对应Trakt。不能确认：首页分数来自哪家、是否独立补取、是否缓存及TTL。** 没有修改Velo产品源码或原型，没有新增默认值、提交或推送，也没有向第三方发送用户媒体信息。
