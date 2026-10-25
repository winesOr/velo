# Velo 客户端逐页复核与交付

日期：2026-10-24。基线：本工作区当前代码，以及 `design/prototype/` 的首页、搜索/媒体库、剧集/电影详情、一起看、设置、播放器 V4。保留原工作区已有改造，没有自动提交混合工作区。

## 本轮修改

- 应用显示名称统一为 **Velo**。登录、启动、关于、资料切换、错误恢复、日志标题、各语言提示，以及 Plex / Jellyfin / Emby 显示的客户端名称同步更新。
- 标识以 `design/branding/velo/velo-icon.svg` 和 `velo-icon-1024.png` 为准。新生成 Flutter 图片、Android 普通/自适应/单色图标、通知图标、启动标识、TV 横幅、Apple Icon Composer / tvOS、Windows ICO / MSIX 资产。使用 `scripts/codegen/generate_velo_branding.py` 可重建。
- Android、iOS、macOS、tvOS、Linux、Windows 的显示名称、相应打包资产来源与 Apple 产品路径已同步。此次实际构建、安装的是 Android arm64；其他系统没有进行二进制运行验收。
- 包名、数据库、已有账户/偏好存储、协议字段与 deep link 保持兼容。Jellyfin 的历史 DisplayPreferences 客户端命名空间、第三方 OAuth 应用身份继续保留，避免更名导致已存配置或认证失效。
- 最新媒体库原型采用横向标签行；应用新增真实排序、类型/地区/年份快捷条件。值来自服务器 filter discovery / value endpoint，继续走原有查询、保存、分页和重置。只展示后端实际支持并返回的条件，不用当前已加载海报推断全库条件，不内置示例类型/国家/年份；复杂筛选仍由原编辑器处理。
- 长标签限制宽度并省略，完整值保留在语义标签中；窄屏大字体增加标签行高度；横屏或键盘弹出时回到原有紧凑筛选/排序入口，给海报列表留出空间。搜索框改用与页面混合后的实色深浅表面，修正黄金截图中的白色输入框。
- 删除一级设置重组后已不用的两个说明键。更新更名和设置字号的旧断言，修复文件系统探测测试只等一个事件循环造成的不稳定等待。

## 逐项功能复核

下面的“回归”指本轮实际执行的单元 / widget / 协议测试，不等于真实外部服务或硬件验收。

| 页面 / 功能 | 样式与交互核查 | 验证方式 / 边界 |
|---|---|---|
| 启动与登录 | Velo 名称和图、窄横屏启动布局、连接/修复/重试入口 | 启动、认证、数据库恢复测试；模拟器沿用已有账户启动 |
| 主导航 | 首页、媒体库、一起看、设置；手机胶囊、横屏侧栏、TV 导航；返回与焦点恢复 | navigation / focus / main screen 回归；实际手机导航 |
| 首页 | 大幅海报、清晰 Logo / 文字回退、真实图片取色、切片代次隔离、连续补间、分页点 | home theme / backdrop / discover 回归；实际 Emby 海报截图 |
| 首页来源与账户 | 来源 Logo、来源过滤、搜索、更多、刷新、账户切换、退出 | 菜单与 profile / source 回归；来源范围仍是已加载推荐 |
| 继续观看与推荐 | 宽卡、进度、详情/播放入口、标题/集号、全部与后续加载 | hub / media card / episode title 回归；实际列表可见 |
| 单库浏览 | 搜索、服务端排序与方向、真实类型/地区/年份标签、完整筛选、清空 | library browse / query translator / quick filters 回归；实际服务器查询 |
| 全部来源 | 按来源分组、独立分页、相同 item ID 隔离、失败重试 | grouped library controller / browse 回归；不宣称跨服具有完全相同筛选能力 |
| 媒体库扩展入口 | 文件夹、推荐、合集、播放列表、显示密度、管理/隐藏库 | libraries / folders / collections / playlists 回归；保留更多菜单入口 |
| 剧集详情 | 通栏主图、Logo、元数据、播放、收藏/已看、季/集/分组/全部 | media detail / episode / track status 回归；实际 Emby 详情截图 |
| 电影详情 | 不显示剧集选择、来源版本、简介、演员、推荐、文件信息 | detail / technical info / action tests；HTML 电影与剧集分支核查 |
| 技术信息与版本 | 真实来源/编码/音轨/字幕；切换条目或版本不复用旧结果 | technical info / playback reload / version guard 回归 |
| 手机播放器一级 | 返回与 Logo、弹幕开关、投屏入口、旋转、更多；锁屏、截图、PiP、底部播放/下一集与芯片 | mobile controls / header / gesture 回归；实际 Emby H.264 起播和弹幕截图 |
| 手势与时间轴 | 左右双击、中间双击、亮度/音量、拖动进度、长按倍速、章节/缓冲/片头片尾 | player / timeline / gestures / marker / skip undo 回归 |
| 播放器二级 | 倍速、字幕、选集浮卡；视频/音频/字幕/弹幕抽屉；返回与焦点恢复 | popover / settings sheet / track / overlay 回归 |
| 播放链路 | mpv / ExoPlayer 原路径、初始化失败/重试、重载、首帧、下一集、PiP 生命周期 | video player / backend / first frame 回归；不替代全编码硬件测试 |
| 弹幕源 | 默认空源、多源、URL/路径前缀、顺序、移除、持久化、首次引导 | danmaku source / repository / sheet 回归；未写入任何内置网关 |
| 弹幕匹配 | anime → bangumi → comment、旧接口兜底、季集偏移、记忆与过期请求隔离 | danmaku API / session / playback binding 回归；签名只针对官方源 |
| 弹幕展示与热力 | 字号、透明度、速度、区域、屏蔽/重复、偏移；分桶/P95/空/单桶、峰值交互 | danmaku / buffer painter / timeline / TV keyboard 回归 |
| 一起看入口 | 创建/邀请码加入、最近房间、复制、取消、窄屏和 TV 布局 | watch_together 全套回归；原型邀请流程点击 |
| 一起看生命周期 | 资源不可用、显式跨服匹配、版本核对、准备、离开、结束、断网/重连 | Provider / loopback 协议测试；未实际双设备看片 |
| 设置一级与二级 | 分组、身份摘要、右侧值/大字回退、深浅色、分类层级、TV 左右交接 | settings / theme / golden / focus 回归；实际手机设置 |
| 播放与字幕设置 | 核心、画面、音频、字幕语言/样式/延迟、按条目偏好、mpv 配置、外部播放器 | playback / settings / scoped prefs / external player 回归 |
| 服务器与资料 | Plex / Jellyfin / Emby 连接、地址切换、资料/PIN、账户设置与隔离 | auth / profiles / connection / account preferences 回归 |
| 下载与离线 | 队列、存储、恢复、同步规则、离线播放、个人资料所有权 | downloads / storage / ownership / offline 回归 |
| 音乐 | 专辑/歌手、播放队列、历史、迷你播放器、主播放页、相关菜单 | music / queue / mini player / playlist 回归 |
| 直播 | 节目表、搜索、收藏排序、节目详情、录制/计划、切台与错误恢复 | livetv / DVR / tune / grouping 回归；无真实电视信号验收 |
| 发现与服务 | 目录搜索、详情、Trakt / MAL / AniList / Simkl / Seerr / MDBList 入口与账户状态 | explore / catalog / trackers / service 回归；未创建外部写入或购买 |
| 遥控与系统功能 | Companion Remote、快捷键、下载通知、后台/系统生命周期 | companion_remote / hotkey / lifecycle / native checks |
| 应用维护 | 关于/许可证、日志查看/选择复制、导入导出、缓存、更新、失败恢复 | logs / settings / startup 回归；57 项发布脚本测试通过 |

完整页面清单覆盖 **55 个页面源文件**，逐页列出对应测试或共享组件检查边界：
`docs/qa/velo-final-2026-10-24/screen-coverage.md`。

## 视觉证据与运行记录

- HTML 逐路由读取及交互：`prototype-structure.json`、`prototype-library.json`。六大界面及电影/剧集分支未发现残留 Plezy 显示文案或已完成加载的坏图。核查了搜索空结果、电影过滤、源管理、详情版本、播放器芯片、一起看邀请码加入。
- 本次浏览器截图接口两次超时，因此没有把历史 HTML 截图冒充本次新截图。视觉比对使用仓库既有原型图、当前 computed style、重新运行的 Flutter 黄金截图，以及本次安装包截图。
- 实际 Android 记录：`shipping-home.png`、`android-library.png`、`android-detail.png`、`android-portrait.png`、`android-about-brand.png`、`android-player-running.png` 等，均来自模拟器安装包。设置 / 媒体库深浅色、TV、大字等其余布局由真实 Flutter 生产组件的 golden fixture 覆盖。
- 首次同时运行构建与全量回归时出现 Android 输入焦点 ANR，已保存 `android-last-anr.txt`。重启后可进入首页、媒体库、详情及设置，随后实际播放 Emby H.264 资源并显示弹幕。最终交付文件再次覆盖安装和启动成功；系统 last-anr 仍为首次那条记录，没有出现新的 ANR。模拟器旋转设置已还原，且已关闭本轮启动的模拟器。不能将该次重试当作真机性能验收。

- 实际 H.264 播放时日志出现 FFmpeg `dolby_vision` / `dv_p7_mode` AVOption 不存在的警告，基本播放仍成功；因此没有将杜比视界选项或画质效果写成已通过。

## 验证与交付状态

- `flutter analyze --no-pub`：无问题（`analyze-shipping.log`）。
- 类型/年份/重置/排序方向、大字/横屏/键盘布局与相关媒体库回归：最终集中 38 项通过。发布符号路径 11 项、发布脚本 57 项通过。
- 翻译严格检查、格式、硬编码文案、用户错误文本、图标规范、原生格式、未使用代码/文件检查通过。
- `scripts/codegen.sh` 经 clean 后完整重新生成；隔离副本重新生成的内容比较通过（`generated-content-final.log`）。标准 `scripts/codegen.sh --check` 仍返回 1，仅列出 23 个未提交的 slang 生成文件；它同时要求提交生成文件，故不将标准 CI 标为全绿（`codegen-check-final.log`）。
- 最终全量回归：**8,221 项通过，6 项跳过，零失败**，用时 15 分 44 秒（`flutter-tests-final.log`）。最终横屏/键盘布局增量另由集中 38 项通过覆盖（`last-layout-tests.log`）。
- 交付包：`dist/android/Velo-2.23.7-20261024-arm64-v8a.apk`，95,373,164 bytes（约 95.4 MB / 91.0 MiB）。包名 `com.wines.plezy`，版本 `2.23.7`，arm64 split 的实际 versionCode 为 `4160`。
- APK 签名校验通过，仅包含 `arm64-v8a`；实际资源标签为 Velo，包内有 Velo 图，未打入旧 `assets/plezy.png`。
- SHA-256：`45d5865f3e744856c3f627411e25205c08737a2748212aa6c35fe009c553934f`。
- 微信交付：**已通过 Hermes 发送至配置的默认微信私聊**。工具返回 success=true；消息回执 `hermes-weixin-313d351360d14d59ab3126eb9f83111b`（`wechat-delivery.json`）。

## 未完成的产品能力与验收

- **真实 DLNA / Google Cast 投屏尚未实现**；播放器保留明确状态的入口。
- **VLC 第三核心仍未实现**；默认继续使用现有 mpv / ExoPlayer。
- TV 遥控器与 arm64 真机、HDR / 杜比视界 / 音频直通的全媒体矩阵、双设备一起看同步和 GPU 帧耗时未在此次硬件环境验收。
- 其他平台名称与资产已更新，但没有编译/运行 iOS、macOS、tvOS、Windows、Linux 客户端。

以上项目不因 HTML 原型、widget fixture、静态分析或构建成功而被标为真实功能通过。
