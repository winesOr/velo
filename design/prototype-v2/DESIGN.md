> 公开归档说明：历史记录和测试结果不代表当前版本；原始证据及私有截图未公开，替代插画不是研究证据。

# Velo Cinema：全界面交互原型设计说明

版本：2026-11-13。交付类型：可操作的浏览器设计原型。

用户在调研过程中明确收敛范围：“这些先不管，先专注核心功能”。本轮覆盖首页、媒体库、搜索/探索、影视详情、播放器与字幕/弹幕/投屏、一起看、账号连接、核心设置。音乐、直播/录制及其他周边能力暂缓，不以源代码中的类名推断产品已上线或入口可见。本轮重做信息层级、内容密度、布局和交互反馈，保留现有核心媒体服务与播放能力。这里的媒体、账号、联网、投屏和房间状态均为演示，不是 Flutter 实现或真机测试结果。研究依据是公开页面和官方截图；项目范围依据本轮静态代码简报。历史测试结果不能代替本原型验收。

## 1. 调研依据与设计取舍

| 参考对象 | 已观察到的视觉事实 | Velo 采用的原则 | 不作出的推断 |
|---|---|---|---|
| [VidHub 官方 App Store](https://apps.apple.com/cn/app/vidhub-video-library-player/id1659622164) | 电影大图与下方渐暗文字；详情页宽白播放按钮；收藏等次动作更轻；画质、字幕、选集以局部覆盖层展示 | 影片内容建立氛围；详情页一个明确主动作；播放器工具逐层展开 | 不推断 Android/TV 与 iPhone 截图一致，不推断实际渲染技术或动画曲线 |
| [SenPlayer 官网](https://www.senmuse.com/)与[官方 App Store](https://apps.apple.com/cn/app/senplayer-%E5%85%A8%E8%83%BD%E8%A7%86%E9%A2%91%E6%92%AD%E6%94%BE%E5%99%A8-%E7%BD%91%E7%9B%98%E7%9B%B4%E8%BF%9E/id6443975850) | 资源库按图标与名称识别来源；文件双列缩略图；设置采用分组行；播放控制沿画面边缘排列 | 复杂功能分组、当前值就地展示、技术设置渐进披露 | 不把云盘、AI 超分等宣传功能变成 Velo 新需求；官网所述手势未由本次原生实测验证 |
| [网易爆米花官网](https://bmh.163.com/) | TV 使用深灰海报横排，标题与日期精简；播放画面底部放置长时间轴和少量工具；手机与 TV 密度不同 | 内容组织优先；跨设备共享视觉语言，各自适配观看距离与输入方式 | 不把营销截图当作错误状态、遥控焦点或性能证据 |

公开参考材料观察于 2026-11-13。没有复用竞品整屏、品牌、影视海报为 Velo 正式资源；竞品截图只用于研究。原型素材应为原创示意或已有合法演示资源。没有读取用户媒体资料。

**与项目材料的取舍：**首页 `Discover` 和外部目录 `Explore` 是不同入口。首页头图整体进入详情，不在头图上重新增加“播放 + 详情”两颗按钮，不堆音轨和版本徽标。VidHub 的强播放按钮用于详情页。投屏只从播放器进入，展示 DLNA handoff 的演示过程；不能宣称所有平台已可用。

## 2. 视觉方向

“安静的私人影院”：默认使用真正中性的黑、灰、白，基础背景与表面不带绿色偏色；青绿仅作为可切换候选对照。青绿是 Velo 暂拟设计色，不是本次已核实的 VidHub 官方主题色。视觉重点交给影片画面、文字比例与留白，减少发光、重复描边、玻璃叠层和工具卡片堆叠。

- 首页先回答“接着看什么”；媒体库先回答“如何找到这部片”；详情页先回答“播放哪一版、哪一集”；播放器优先保留画面。
- 标题、元信息、说明文字分三级；同一内容区只出现一个强主动作。图标需要名称、提示或明确上下文。
- 海报比例、文字基线、行距与间距一致；电影/剧集共享卡片结构，保留各自的信息字段。
- 内容列表使用轻表面；确认、选择、设置使用统一圆角容器。危险动作单独分组，不与确认按钮并排同等强化。
- 采用内容自适应网格和留白；窄屏不压缩成桌面微缩版，TV 不照搬手机底部栏。
- 播放器始终深色。外观选择可以预览明亮、深色、纯黑或跟随系统；视频画面上的控制对比不随浅色主题降低。

## 3. 导航与跨设备布局

| 平台 | 主结构 | 内容/操作差异 | 输入与返回 |
|---|---|---|---|
| 手机，基准 390×844 | 首页、媒体库、一起看、设置底部导航；独立搜索动作 | 两列为主要海报密度；详情纵向叠放；普通应用选择器为底部面板；播放器保留锚定 popover 与侧浮抽屉；长表单分组 | 点击目标至少 44×44；手势均有按钮替代；面板关闭后回触发器 |
| 平板/桌面，基准 1440×900 | 侧栏、顶部上下文和宽内容区 | 网格随宽度扩展；详情图文可并排；设置为目录/内容双栏；侧边抽屉不抢占整屏 | Tab 顺序与视觉顺序一致；Enter 执行；Escape 先关最上层 |
| TV，基准 1920×1080 | 大字号导航、横向内容组、背景聚光 | 同屏更少更大卡片；焦点高亮不只改变颜色；远距离可辨文字 | 方向键移动、Enter 确认、返回逐层关闭；返回列表恢复卡片焦点和滚动位置 |

额外验收：320px 宽、手机横屏、200% 字号、长片名、字幕长语言名、无海报、低性能实色回退。Explore 按能力显隐；不得因切换 TV 预览而引入新的产品功能。下载、音乐、直播/录制暂不纳入本轮验收。

## 4. 界面家族与完整交互设计

以下是每类界面的设计验收目标。实际实现映射以文末覆盖矩阵为准；“要求”不等于“已通过测试”。

### 4.1 启动、首次设置与恢复

- 布局：Velo 标识、简短进度说明、单一下一步；首次进入解释连接自己的媒体服务，不摆放假推荐内容。
- 主动作：添加服务器或恢复进入；次动作：离线进入、查看恢复详情。
- 状态：启动加载 → 数据恢复中 → 成功进入；恢复失败显示原因与重试；离线只开放可用内容。
- 反馈：进度文字可读，按钮加载中防止重复触发；失败保留选择，不要求从头开始。

### 4.2 服务连接与授权

- 布局：Plex/Jellyfin/Emby 三类来源入口、各自清晰标识；服务器表单按地址、账号、密码分组。
- Plex 用设备码/浏览器授权路径；Jellyfin/Emby 使用 URL 与账号密码。表单显示密码按钮有独立状态。
- 主动作：测试并连接；次动作：返回、编辑已有连接。删除连接须明确确认对象。
- 状态：未填、字段校验、检测中、连接成功、离线、授权过期、拒绝访问；错误在相关字段或表单附近展示。
- 反馈：成功出现连接名称与下一步；失败可修改重试；不将密码、令牌或真实服务器数据写入演示资料。

### 4.3 用户、PIN 与借用连接

- 布局：头像与名称构成用户选择网格；用户详情分基础信息、连接、偏好、安全操作。
- 主动作：选择/创建本地用户；次动作：编辑、借用已有连接。PIN 使用数字键盘与清晰输入位，退格、取消可达。
- 状态：正常选择、PIN 必填、错误 PIN、借用连接不可用、退出/删除确认。
- 反馈：用户切换后顶部身份同步；错误 PIN 保留当前对象，允许重试；危险操作前清晰展示影响。

### 4.4 首页与分组详情

- 布局：保留原有手机沉浸大海报，全宽铺开；首图高度约视口 65%，最低 500px 并加顶部安全区。片名、评分和简介位于下部居中，底部渐暗自然融入页面；继续观看紧随其后，再按已有服务内容分组；进度条属于继续观看卡片。
- 手机首图不改成桌面式小卡或左右分栏，不加播放按钮；整图点击进入详情。该要求来自用户本轮明确纠正，最终视觉以独立 QA 截图为依据。
- 主动作：点击头图进入详情；卡片进入对应详情/续播入口；次动作：查看更多、切换来源与用户。
- 状态：骨架、正常、空库、服务离线、部分分组加载失败；一组失败不清空已加载内容。
- 反馈：卡片按压、焦点轮廓和返回定位一致；“查看更多”打开可筛选的完整组，而非重复静态首页。

### 4.5 探索、目录与搜索

- 布局：探索展示目录片单；全库搜索与目录搜索在标题/范围选择器上明确区别；搜索历史与结果分区。
- 主动作：输入关键词、打开结果；目录详情本轮以查看为主；媒体请求与 Seerr 深层流程暂缓；次动作：清除输入、清除历史、切换范围。
- 状态：未输入、搜索中、有结果、无结果、部分来源失败。
- 反馈：搜索后结果和数量变化，清除恢复默认内容；不暗示已向外部服务下发媒体请求。

### 4.6 媒体库、筛选、合集与文件夹

- 布局：库选择器、搜索/排序/视图切换、已选条件条、海报网格或列表；合集、播放列表、分组/文件夹可定位；音乐暂缓。
- 主动作：选择内容；次动作：多筛选、排序、网格/列表、管理库。
- 筛选细分：文本、值多选、日期范围、数值范围。应用后以 chip 展示，可删除单个条件或清空全部。
- 状态：默认、有筛选、无匹配、无媒体库、离线、无法访问；不要把“无匹配”误写成“服务器无内容”。
- 反馈：排序改变顺序、视图切换保留条件、清空恢复结果；关闭筛选时有一致的提交/取消规则。

### 4.7 电影、剧集、人物、合集与播放列表详情

- 布局：背景/海报、片名、必要元信息、唯一主播放/续播按钮；轻量收藏/已看/更多；简介、版本、季集、演员向下展开。
- 电影展示版本与文件信息；剧集有季选择和集列表、进度/已看状态；人物显示作品；合集和播放列表显示成员及排序。
- 主动作：播放/继续播放、选择集；次动作：收藏、已看、下载、评分、更多，按服务能力显示。
- 编辑相关：元数据编辑、标签、Plex 匹配、合集/播放列表选择、文件信息应有对应独立面板，不能全映射成同一个 toast。
- 状态：多版本、无可播版本、元数据缺失、权限不足、下载中、动作成功/失败；失败回滚已乐观改变的收藏等状态。

### 4.8 视频播放器与 HUD

- 布局：沿用旧 V4：左上返回/片名，右上弹幕/投屏/横竖/更多，左侧锁、右侧截图/PiP；底部长时间轴和精简单行控件，中心无常驻播放/快进退按钮。完整保留矩阵见第 13 节。
- 主动作：播放/暂停；次动作：前后跳转、拖动、选集、章节、队列、跳过片头/片尾、下一集。
- 状态：加载、播放、暂停、自动隐藏、缓冲、失败/重试、锁定、播放结束；锁定时保留明确解锁入口。
- 时间轴：拖动显示时间与预览；结束拖动再提交；热力与已播/缓冲进度有可辨层级；键盘有调整方式。
- 手势设计：双击前后跳、长按倍速、边缘亮度/音量，都有明确反馈与按钮替代；原型如仅提供按钮须在覆盖状态中说明。
- 核心与版本：保留 mpv/ExoPlayer；版本、画质、比例、速度属于上下文选择。切换可能需重新加载，明确展示演示状态。

### 4.9 播放设置：视频、音频、字幕、弹幕

- 容器：视频/音频/字幕/弹幕四 tab 采用播放器专用四角圆侧浮抽屉，横屏右侧留边，手机也不改为通用贴底大面板；每行有名称、当前值、范围/选项。倍速、字幕、选集保留锚定 popover；TV 适配焦点与字号。
- 视频：画面比例、版本/画质、核心选择与进阶设置。
- 音频：音轨名称、语言、声道；选中标记清晰。
- 字幕：主/副字幕、关闭、语言/来源、偏移、样式预览、本地导入；在线搜索仅在服务能力允许时出现。
- 弹幕：开关、热力、匹配搜索与集选择、过滤、密度、速度、区域、透明度、字号、偏移、本地导入。
- 状态：加载轨道、无轨道、搜索无结果、导入错误、配置无效；设置调整即显示数值与示意变化。

### 4.10 弹幕源管理

- 布局：用户已配置来源列表、状态与排序；新增/编辑表单包括名称、URL 和可选凭据。
- 主动作：新增或保存；次动作：测试连接、调整顺序、删除。
- 状态：无源、检测中、连接成功、失败、禁用；空态说明需用户自行配置。
- 反馈：测试结果留在来源附近；不预填第三方网关、AppId 或秘密；演示不会向任意地址真实发送请求。

### 4.11 投屏面板

- 入口：仅播放器；当前能力为 DLNA handoff 的设计演示。
- 布局：当前播放项目、设备扫描状态、设备列表、刷新与关闭；不制造全局投屏导航。
- 状态：扫描中、发现设备、无设备、发送中、成功、失败、当前平台不可用。
- 反馈：选择设备后明确展示目标和发送状态；失败可重试/重扫；成功明确标为演示，不声称真实视频已经到达设备。

### 4.12 一起看

- 层级：大厅/最近房间 → 创建或输入房间码 → 房间 → 同步播放；成员、准备、媒体匹配、控制模式分组。
- 主动作：创建/加入/准备；房主在就绪后开始；次动作：复制邀请、匹配本地媒体、查看成员、离开。
- 权限：`host`/`guest` 与 `hostOnly`/`anyone` 控制能否暂停、跳转、切换媒体；禁用时解释原因。
- 状态：连接、等待、缺少媒体、部分成员未准备、缓冲等待、同步中、重连、错误、离开确认。
- 反馈：准备状态、邀请复制与成员变化各自有对应反馈；模拟房间与网络同步保持演示标记。

### 4.13 暂缓的周边界面

依用户最新指示，下载与同步规则、音乐、直播/录制、设备遥控与扫码同步不进入本轮核心原型验收，也不新增一级导航。

用户指出实际界面没有音乐和直播录制入口，本轮据此纠正“有类即有可用界面”的错误判断。补充静态查证显示：音乐属于媒体库中的 artist 类库链路；直播需在线服务探测后在更多菜单出现，录制还受 DVR 能力限制；这些是条件代码路径，不是本轮确认用户已可使用的功能。

暂缓不等于移除正式产品能力。后续如单独启动任务，应重新确认入口可达性、服务能力、平台差异及用户需求。

### 4.14 核心设置

- 结构：总览显示本轮核心分类；常规、外观、播放、字幕、弹幕源、连接与关于各有标题和当前值，返回保留分类位置。
- 常规：语言、启动行为等已有常规项。外观：主题、密度及无障碍演示。播放：核心与已有播放偏好。字幕：样式、预览和偏移。
- 外部播放器、mpv 配置与快捷键已有对应原型页，作为核心设置的附属页保留；已有核心播放选项以简洁分组呈现，不将页可达等同于所有进阶状态均验证。
- 账号偏好保留核心账户选择与连接管理。Trakt/追踪器、Seerr 深层集成与管理页暂缓，不作为核心验收缺失。
- 评分按服务能力显示；关于保留 Velo/Plezy/GPL-3.0。日志、许可列表及单项许可有对应原型路由；是否完成特定操作以 QA 记录为准。
- 状态：未连接、连接过期、保存中、成功、失败、不可用；日志/许可允许长文本滚动而不挡关闭入口。

### 4.15 公共组件、异常与交互实验室

- 组件：普通/危险确认、单选/多选、下拉、toast、tooltip、表单、进度、骨架、空状态、错误重试。
- 实验室逐一展示 hover、focus、press、release、selected、loading、disabled、error、success；用户点击后能看到局部状态变化。
- loading 防重复提交；disabled 必须有原因且不执行；错误必须有恢复动作；成功尽量就地确认，toast 不滥用。
- 模态要求：标题语义、关闭入口、焦点进入/约束/恢复，Escape 只关闭最上层；后台不应可误操作。
- 减少动效移除位移、缩放、循环动画；高对比保证选中/焦点/错误不只靠颜色；模糊不可用时使用实色。

## 5. 能力与角色边界

原型沿用客户端能力名称，不新增后台接口或权限码。已有服务能力并非完全相同：Plex 的个人数字评分写入、在线字幕搜索、移除继续观看可以存在；Jellyfin 的个人数字评分写入/在线字幕搜索不可一视同仁启用，收藏可用；Emby 收藏与移除继续观看可用。这里的 `numericUserRating` 仅限制“我的评分”的写入，不限制影片已有的外部/服务端评分展示；来源评分与个人评分必须分开，详见第 12 节。

相关能力：`liveTv`、`liveTvDvr`、`videoTranscoding`、`richHubs`、`numericUserRating`、`userFavorites`、`continueWatchingRemoval`、`externalSubtitleSearch`、`richMetadataEdit`、`scrubThumbnails`、`folderGrouping`、`instantMix`、`libraryChangeEvents`。

连接状态：`online / offline / authError / accessDenied`。一起看角色：`host / guest`；控制模式：`hostOnly / anyone`；连接状态：`connecting / connected / error`；播放阶段：`loading / waitingForPeers / paused / playing`。这些值仅供设计对照，不是新增 API。

## 6. 动效、反馈与可调默认值

以下数值是新原型设计建议，不是竞品测量或真机性能结论。最终运行值以集中配置为准。前端阶段性交接确认 `config.js` 使用 press=90、release=160、card=180、panel=260、hud=3600、simulation=900、toast=2600（毫秒）；因此面板采用 260ms，HUD 自动隐藏采用 3.6 秒，模拟延迟 900ms，toast 2.6 秒。它们均为可调演示默认值，尚未真机验证。

| Token/行为 | 建议默认值 | 反馈规则 | 调整编号 |
|---|---|---|---|
| 按压 | 90ms，缩放 0.97 | 按下立即响应；释放恢复；disabled 无缩放 | TODO(PROTO-MOTION-01) |
| 释放 | 160ms，ease-out | 避免过度弹跳；连续点击不累积动画 | TODO(PROTO-MOTION-01) |
| 海报 hover | 180ms，上移 3px | 仅指针设备；选中与 hover 不混淆 | TODO(PROTO-MOTION-02) |
| TV focus | 180ms，2px 轮廓，可选 1.035 缩放 | 焦点立即可辨，动画完成与否不影响操作 | TODO(PROTO-TV-01) |
| 面板进入 | 260ms | 手机向上、桌面从侧边；遮罩同步 | TODO(PROTO-MOTION-03) |
| tab/筛选 | 180ms | 指示器与结果状态保持一致 | TODO(PROTO-MOTION-04) |
| 收藏反馈 | 180ms | 图标填充与状态文字同步，可撤销 | TODO(PROTO-MOTION-05) |
| 播放中心提示 | 500ms 后淡出 | 底栏状态持续，缓冲另行显示 | TODO(PROTO-PLAYER-01) |
| 减少动效 | 取消位移/缩放；淡变 ≤80ms | 状态立即改变，不取消焦点/错误反馈 | TODO(PROTO-A11Y-01) |
| 模拟网络等待 | 900ms | 始终标示演示；失败/重试可复现 | TODO(PROTO-DEMO-01) |
| 基础色 | 默认黑灰白；青绿对照为可切换提案 | 青绿不是已确认竞品主题；最终以样式配置为准 | TODO(PROTO-VISUAL-01) |
| 布局基准 | 手机 390×844、桌面 1440×900、TV 1920×1080 | 另验 320px/横屏/200% 字号 | TODO(PROTO-RESPONSIVE-01) |

现有产品按压时间为 120ms/180ms、浮层 180ms；本轮可提出新默认值，不直接更改 Flutter token，也不替代已有 `TODO(VELO-P8-01)` 的真机调优。

## 7. 用户任务逐条验收

| 用户要求 | 可审查交付 | 验收操作 | 通过依据 |
|---|---|---|---|
| 重新网上调研 VidHub、SenPlayer、爆米花 | 本文研究表、官方来源与边界 | 打开来源，对照视觉事实与设计取舍 | 公开截图观察；不涉及原生测试 |
| 结合当前已有能力 | 源页面覆盖矩阵、能力/角色说明 | 对照 Plex/Jellyfin/Emby、一起看、弹幕、核心与设备类型 | 静态覆盖 + 实际页面行为；待 QA |
| 新布局和样式 | 可操作原型、多端布局 | 浏览首页、媒体库、详情、播放器、设置 | 真实截图与用户审阅；待 QA |
| 覆盖本轮核心界面 | 文末核心路由、关键 sheet 映射 | 逐项进入核心路由/面板；周边界面明确暂缓 | 路由覆盖检查与人工抽验；待 QA |
| 包含按钮动效 | 组件实验室和动效配置 | 指针按压、键盘焦点、TV 焦点、减少动效 | 浏览器状态与视觉检查；待 QA |
| 包含点击反馈 | 每类操作结果与错误/空状态 | 收藏、筛选、选择音轨、加入房间、投屏失败等 | 状态真实改变，按钮无假成功；待 QA |
| 原型详细 | 核心界面家族、状态与迁移说明 | 使用主要流程并返回原入口 | 浏览器交互记录；待 QA |

## 8. 验证边界与交付风险

- 本文编写时没有把设计目标计作已通过。浏览器 QA 在独立的 [VALIDATION.md](VALIDATION.md) 记录环境、路由、操作、结果及截图证据；本说明不提前推断其结论。
- 原型验证不等于 Flutter 编译、单测、lint、真机播放、字幕渲染、网络投屏或跨用户同步验证。
- 本轮不修改 SQL、后台、正式 Flutter UI、生成 Dart、凭据、签名或用户媒体。不提交/推送；若未来提交，须完成项目规定检查。
- 本轮没有共享源码修改；新增原型目录的多个交付文件由各责任代理独立维护。既有未跟踪验收文档不覆盖。
- 产品图像、长文本和无图场景仍需在真实内容上验证；动效时长、TV 焦点幅度、布局密度均保留 TODO。
- 本说明定义详尽目标；最终覆盖清单可能揭示占位/复用/未验证项，必须如实保留，不用“页面数量”替代完成质量。

## 9. 核心页面与关键浮层覆盖矩阵

以下根据本次读取的 [coverage.json](coverage.json) 逐项列出静态映射；核心条目的状态为 `implemented-unverified`，意为作者声明已有原型入口，不能当作测试通过。原作者随后确认 Seerr/Trakt/Tracker 五项已改为 `deferred-draft`。源路径与行号来自覆盖文件和本轮简报，未重新通读原文件。

**范围口径：**Seerr、Trakt、Tracker 五项已在覆盖文件中标为 `deferred-draft`，与用户后续“先专注核心功能”的范围一致；这些现有延伸草稿单列、不计核心验收。音乐、直播/录制、下载、设备同步同样不计核心通过率。

### 9.1 核心 Screen / Page 映射

表内状态均为“原型映射已声明，行为以独立 QA 为准”。同一路由可复用产品中的多个类，不表示这些类新增了独立产品入口。

| 源类 | 源文件:行 | 原型路由 / 面板 |
|---|---|---|
| SetupScreen | lib/main.dart:2062 | `#welcome` |
| ProfileSessionScreen | lib/navigation/profile_session_screen.dart:72 | `#restore` |
| ActorMediaScreen | lib/screens/actor_media_screen.dart:25 | `#actor` |
| AuthScreen | lib/screens/auth_screen.dart:43 | `#connect` |
| CatalogItemDetailScreen | lib/screens/catalog_item_detail_screen.dart:64 | `#catalog-detail` |
| CatalogSearchScreen | lib/screens/catalog_search_screen.dart:22 | `#catalog-search` |
| CollectionDetailScreen | lib/screens/collection_detail_screen.dart:47 | `#collection` |
| DiscoverScreen | lib/screens/discover_screen.dart:79 | `#home` |
| ExploreScreen | lib/screens/explore_screen.dart:50 | `#explore` |
| HubDetailScreen | lib/screens/hub_detail_screen.dart:38 | `#history` |
| LibrariesScreen | lib/screens/libraries/libraries_screen.dart:48 | `#libraries` |
| MainScreen | lib/screens/main_screen.dart:376 | `#home`（共用导航壳） |
| MediaDetailScreen | lib/screens/media_detail_screen.dart:271 | `#detail` |
| MetadataEditScreen | lib/screens/metadata_edit_screen.dart:34 | `#metadata` |
| PlaylistDetailScreen | lib/screens/playlist/playlist_detail_screen.dart:39 | `#playlist` |
| PlexMatchScreen | lib/screens/plex_match_screen.dart:29 | `#plex-match` |
| AddLocalProfileScreen | lib/screens/profile/add_local_profile_screen.dart:25 | `#profile/new` |
| BorrowConnectionScreen | lib/screens/profile/borrow_connection_screen.dart:43 | `#profile/borrow` |
| ProfileDetailScreen | lib/screens/profile/profile_detail_screen.dart:43 | `#profile/detail` |
| ProfileSwitchScreen | lib/screens/profile/profile_switch_screen.dart:38 | `#profiles` |
| SearchScreen | lib/screens/search_screen.dart:40 | `#search` |
| AboutScreen | lib/screens/settings/about_screen.dart:11 | `#settings/about` |
| AccountPreferencesDetailScreen | lib/screens/settings/account_preferences_detail_screen.dart:51 | `#profile/detail` |
| AccountPreferencesScreen | lib/screens/settings/account_preferences_screen.dart:21 | `#settings/accounts` |
| AddConnectionScreen | lib/screens/settings/add_connection_screen.dart:27 | `#connect` |
| AddJellyfinScreen | lib/screens/settings/add_jellyfin_screen.dart:87 | `#connect/jellyfin` |
| AddPlexAccountScreen | lib/screens/settings/add_plex_account_screen.dart:37 | `#connect/plex` |
| AppearanceSettingsScreen | lib/screens/settings/appearance_settings_screen.dart:23 | `#settings/appearance` |
| EditJellyfinConnectionScreen | lib/screens/settings/edit_jellyfin_connection_screen.dart:19 | `#settings/account-detail` |
| ExternalPlayerScreen | lib/screens/settings/external_player_screen.dart:24 | `#settings/external` |
| GeneralSettingsScreen | lib/screens/settings/general_settings_screen.dart:22 | `#settings/general` |
| KeyboardShortcutsScreen | lib/screens/settings/keyboard_shortcuts_screen.dart:18 | `#settings/shortcuts` |
| LicensesScreen | lib/screens/settings/licenses_screen.dart:17 | `#settings/licenses` |
| _LicenseDetailScreen | lib/screens/settings/licenses_screen.dart:100 | `#settings/license` |
| LogsScreen | lib/screens/settings/logs_screen.dart:101 | `#settings/logs` |
| MpvConfigScreen | lib/screens/settings/mpv_config_screen.dart:29 | `#settings/mpv` |
| PlaybackSettingsScreen | lib/screens/settings/playback_settings_screen.dart:28 | `#settings/playback` |
| RatingSettingsScreen | lib/screens/settings/rating_settings_screen.dart:19 | `#settings/rating` |
| SettingsScreen | lib/screens/settings/settings_screen.dart:85 | `#settings` |
| SubtitleStylingScreen | lib/screens/settings/subtitle_styling_screen.dart:13 | `#settings/subtitles` |
| VideoPlayerScreen | lib/screens/video_player_screen.dart:482 | `#player` |
| WatchTogetherScreen | lib/watch_together/screens/watch_together_screen.dart:44 | `#together` |
| FilterNumberPage | lib/screens/libraries/filters/filter_range_page.dart:20 | `#libraries` → `filters` |
| FilterDatePage | lib/screens/libraries/filters/filter_range_page.dart:142 | `#libraries` → `filters` |
| FilterTextPage | lib/screens/libraries/filters/filter_text_page.dart:17 | `#libraries` → `filters` |
| FilterValuePage | lib/screens/libraries/filters/filter_value_page.dart:22 | `#libraries` → `filters` |

筛选四类共用 `filters` 面板，触发器为 `[data-action="modal:filters"]`。覆盖文件说明以年份 chip 代表日期范围提案、搜索输入承接文本；因此不能把此映射称为完整任意日期/数值区间编辑器。

### 9.2 核心浮层与复用组件

| 源组件 | 原型入口 | 面板 / 形态 |
|---|---|---|
| FiltersBottomSheet | `#libraries` | `filters` |
| SortBottomSheet | `#libraries` | `sort` |
| LibraryQuickPickerSheet | `#libraries` | `library-picker` |
| PinEntryDialog | `#profiles` | `pin` |
| JoinSessionDialog | `#together` | `join-room` |
| LocalMediaMatchDialog | `#room` | `match-media` |
| FileInfoBottomSheet | `#detail` | `file` |
| MediaContextMenu | `#detail` | `media-more` |
| RatingBottomSheet | `#detail` | `rating`，按服务能力 |
| TagEditDialog | `#metadata` | `tags` |
| ChapterSheet | `#player` | `chapters` |
| DanmakuSettingsSheet | `#player` | `player-settings` 的弹幕页签 |
| DanmakuSourcesSheet | `#player` | `sources` |
| DanmakuSourceEditor | `#player` | `source-editor` |
| DlnaCastSheet | `#player` | `cast`，仅播放器入口 |
| PlayerSpeedPopover | `#player` | `speed` |
| PlayerEpisodesPopover | `#player` | `episodes` |
| PlayerSettingsDrawer | `#player` | `player-settings` |
| PlayerSubtitleAppearance | `#settings/subtitles` | 内嵌页面，非独立浮层 |
| QueueSheet（视频） | `#player` | `queue` |
| SubtitleSearchSheet | `#player` | `subtitle-search`，按服务能力 |
| TrackSheet | `#player` | `audio` |
| VersionQualityPicker | `#player` | `versions` |
| VideoSettingsSheet | `#player` | `player-settings` |
| DeviceCodeDialog | `#connect/plex` | 内嵌授权页 |
| PendingAuthDialog | `#connect/plex` | 内嵌等待授权状态 |
| CollectionSelectionDialog | `#detail` | `choose-collection` |
| PlaylistSelectionDialog | `#detail` | 复用 `choose-collection` |

公共组件在 `#lab` 映射：`AppDialog`、`AppAlertDialog`、`AppMenu`、`AppSelectField`、`OverlaySheetHost`、`BottomSheetHeader`、`PlayerDrawerChoice`、`PlayerDrawerToggle`、`PlayerDrawerRange`。这是视觉/交互组件复用关系，不等于逐个 Flutter 类已经替换或测试。

补充路由：`#series` 为剧集详情；`#connect/emby` 为 Emby 连接；`#settings/danmaku` 为弹幕设置；`#atlas` 为原型导航；`#lab` 为交互实验室。房间相关面板使用 `#room` 作为上下文入口。

### 9.3 状态声明与验收证据

| 状态族 | coverage.json 声明 | 本轮验收含义 |
|---|---|---|
| 页面状态 | `normal / loading / empty / error / offline / denied` | 为统一演示状态标签；不据此断言每个页面都有独立业务状态实现 |
| 筛选页 | 四类映射至统一面板，未逐项列状态 | 验证输入、筛选结果、清除和返回；日期/数值表达以现有提案为限 |
| 浮层 | `implemented-unverified` | 验证可打开、可关闭、选择结果、焦点回归；不是原生 sheet 验证 |
| 组件实验室 | `hover / focus / pressed / selected / loading / disabled / error / success` | 看得见并可触发的状态才算覆盖；不能以列表名称代替测试 |
| 真正网络/媒体状态 | 不连接实际后台 | 所有连接、解码、投屏、房间同步只作模拟；禁止宣称设备或服务真实执行 |
| 浏览器 QA | 独立报告 | 以 [VALIDATION.md](VALIDATION.md) 的具体检查、截图与限制为准，不从覆盖文件推导通过率 |

### 9.4 延伸草稿与暂缓项

| 类/功能 | 已有原型映射或状态 | 本轮范围处理 |
|---|---|---|
| SeerrConnectScreen、SeerrSettingsScreen | `#settings/seerr` | 延伸草稿，不计核心验收 |
| ServicesSettingsScreen | `#settings/services` | 服务管理延伸页，不扩展本轮核心要求 |
| TrackerLibraryFilterScreen | `#settings/tracker-filter` | 延伸草稿，不计核心验收 |
| TrackerSettingsScreen、TraktSettingsScreen | `#settings/trakt` | 延伸草稿，不计核心验收 |
| SeerrRequestSheet | `#catalog-detail` → `request` | 目录请求演示，外部提交能力不在核心验收内 |
| DownloadsScreen | `#downloads` | optional draft，不计核心验收 |
| SyncRulesScreen | `#sync-rules` | optional draft，不计核心验收 |
| MobileRemoteScreen、SyncReceiveScreen、SyncScanScreen | deferred | 遥控与设备同步暂缓 |
| LiveTvScreen、LiveTvShowScheduleScreen、节目表/录制/收藏面板 | deferred | 直播与录制暂缓 |
| AlbumDetailScreen、ArtistDetailScreen、NowPlayingScreen、音乐队列/迷你播放器 | deferred | 音乐暂缓，不新增一级导航 |

## 10. 交付清单与最终验收口径

| 交付物 | 用途 |
|---|---|
| [index.html](index.html) | 本地浏览器原型入口 |
| [app.js](app.js) | 核心页面、面板与演示交互 |
| [player.js](player.js)、[player.css](player.css) | 独立 V4 播放器、局部 popover、侧浮抽屉、手势与能力模拟；资源版本 player2 |
| [styles.css](styles.css) | 多端布局、中性黑白默认、青绿候选、焦点及反馈样式 |
| [config.js](config.js) | 集中可调时长和演示默认值 |
| [art.js](art.js) | 原型视觉素材绘制 |
| [coverage.json](coverage.json) | 源页面/浮层到原型的机器可读映射 |
| [README.md](README.md) | 本地启动与使用说明 |
| [DESIGN.md](DESIGN.md) | 研究、设计规范、用户要求对照、覆盖边界与遗留事项 |
| [VALIDATION.md](VALIDATION.md) | 独立 QA 证据入口；结果由该报告负责，本文件不预设通过 |

本轮交付逐项对应：竞品调研见第 1 节；新布局及手机大海报见第 2～4 节；核心界面覆盖见第 9 节；按钮动效与点击反馈见第 4、6 节及 `#lab`；多端/键盘/减少动效见第 3、4.15 节；测试证据以独立验证报告为准。

采用的可调默认值：默认中性黑白、青绿可选；按压 90ms、释放 160ms、卡片反馈 180ms、面板 260ms、HUD 自动隐藏 3600ms、模拟等待 900ms、toast 2600ms。手机首页保持全宽首图约 65% 视口高度，最低 500px 加安全区；下部文字居中、渐暗融底，整图进入详情，无播放按钮。配置中的 `TODO(PROTO-01)` 以及第 6 节设计 TODO 均用于后续原生适配和真机调优，不是当前测量结论。

共享文件改动：本任务仅新增独立原型目录，不改正式 Flutter、Android、后端、SQL、生成文件、已有共享文档或其他贡献者未提交文件。本代理只维护本 `DESIGN.md`。

与材料不一致的地方：最初全页面扫描包含音乐、直播/录制等条件代码路径；用户后续明确暂缓，最终范围以核心功能为准。Seerr/Trakt/Tracker 五项已标为 `deferred-draft`，与本说明的延伸草稿口径一致；统一筛选面板不是四个原生筛选页的完整逐状态等价实现。青绿不归因于 VidHub 官方设计。手机首页保留用户指定的大海报结构。

遗留与限制：真实网络连接、视频解码、字幕渲染、投屏、跨用户房间同步仍须后续产品实现/真机验证；原型模拟不能证明这些能力。手机首图、320px、横屏、200% 字号、TV 焦点和减少动效的浏览器结果以 QA 报告具体证据为准。纯原型任务未要求提交，本轮不运行 Flutter 检查、不提交、不推送，也不把浏览器验证描述成 Flutter 编译或真机测试。

## 11. 旧 Plezy 本机原型的确认与继承

### 11.1 找到的旧稿与证据身份

完整旧稿位于 <local-path-withheld>），包含 `home.html`、`detail.html`、`library.html`、`together.html`、`settings.html`、`player.html` 六页，以及 `hero.js`、`detail.js`、`ui.css`。Velo 当前仓库没有带入这批文件，不等于旧稿不存在。旧目录是 Plezy 本机未跟踪工作稿，未找到对应提交历史；不能称作已提交发布版本。

本轮历史核查代理已经实际查看以下保存截图，不是仅根据 CSS 推测画面：

- 旧手机首页：home-phone.png（原始材料未公开）：全宽真人海报；顶部账户、搜索、更多叠在图上；下部居中书法片名与星号分数/年份/类型；暖灰背景延续；继续观看横卡露出下一张；底部浮动灰玻璃四入口。
- 旧电影详情：detail-movie.png（原始材料未公开）：全宽《沙丘》海报与橙褐环境色；居中片名、含 8.3 裸分的元信息；全宽浅色播放按钮；下一行收藏/已看；下方服务器、画质、版本、简介、演员。

这两张图片只证明保存截图的形态，不证明旧 HTML 的全部交互目前仍可用。旧稿引用的用户截图裁切与第三方影视图片只用于本机设计对照，不复制进本次交付目录，不作为可再发布的项目自有资产。新版继续使用原创演示画面。

### 11.2 必须归属旧设计的部分

| 旧稿事实与依据 | 新版继承规则 | 当前确认边界 |
|---|---|---|
| `home.html`、`hero.js`、`ui.css`：通栏大图、下部居中片名/原名/分数/年份/类型；390×844 预览首图约 548px | 保留全宽沉浸首图、约 65svh / 最低 500px 加安全区、下部居中信息、评分、渐暗融底；整图进入详情，不增加播放按钮 | 大海报结构已有前轮原型落点；新增具名评分的本轮专项检查已由独立 QA 确认，具体范围见第 12.4 节，不扩展为全状态通过 |
| `ui.css` 与旧首页截图：浮动胶囊四入口，宽约 336px、高 58px、距底约 18px、半透明深玻璃 | 手机保留首页/媒体库/一起看/设置四入口，浮动与安全区关系以旧稿为继承基准；不能只保留四个名称就称完整恢复了旧浮动形态 | 旧稿形态已证实；新版是否完成浮动导航恢复，以本轮实现和 QA 截图为准 |
| `detail.html`、`detail.js` 与旧详情截图：手机全宽浅色播放按钮，收藏/已看位于下方居中，片源/画质/版本随后 | 手机详情保持主播放独立宽按钮，次操作降级且独立成组，避免主次按钮挤在一行 | 归属旧设计继承；本轮评分布局专项及其修订后的复验已通过，具体范围见第 12.4 节，不代表详情页所有交互均验证 |
| 旧稿海报与背景连续过渡，并有取色/亮度处理和过渡说明 | 延续“画面与页面融为一体”的结构；新稿默认中性黑白，青绿只作为可切候选 | 不声称已经复刻旧稿像素取色算法或 560ms 切图机制，也不把它归因于竞品内部实现 |
| 旧 V4 播放器已有四 tab 抽屉、锚定倍速/字幕/选集工具、一起看流程 | 保留项目自己的播放工具组织与一起看能力，研究只用于梳理层级 | 前一轮新稿的中心播放控件偏离旧 V4；本轮明确恢复“无常驻中心按钮”，并按第 13 节保留矩阵补齐可体验交互，验收结果不预先推定 |

旧首页的单一星号分数、旧电影详情里的裸分，不是 IMDb/豆瓣等多来源评分条。多来源条的依据来自当前 Velo 评分模型、展示代码及后续任务卡，不能为了说明“继承”而虚构旧稿已有的界面。

### 11.3 竞品事实到当前落点，以及未落实的边界

以下研究已在此前观察公开页面完成，本轮没有重访网页或亲测原生客户端。“有原型落点”指结构可在浏览器原型中定位，不等于真实播放、网络能力或所有状态均经过测试。

| 参考来源与可观察事实 | 当前原型落点 | 可以说吸收了什么 / 不能说什么 |
|---|---|---|
| [VidHub 官方商店](https://apps.apple.com/cn/app/vidhub-video-library-player/id1659622164)：详情主播放强于次动作，管理项收进菜单，画质/字幕/选集在画面上展开 | `#detail`、`#series` 的主次层级和更多菜单；`#player` 的画质、速度、音轨、选集面板 | 可说借鉴层级与渐进披露；手机大海报及详情宽播放/独立次动作同时有 Velo 旧稿证据，优先注明继承，不能独占归因于 VidHub |
| 同一 VidHub 商店截图：历史关键词胶囊，下接推荐海报 | `#search` 的历史 chip、清除记录、结果与空状态 | 视觉组织有落点；没有由此实现真实跨服务器聚合搜索 |
| [SenPlayer 官方商店](https://apps.apple.com/cn/app/senplayer-%E5%85%A8%E8%83%BD%E8%A7%86%E9%A2%91%E6%92%AD%E6%94%BE%E5%99%A8-%E7%BD%91%E7%9B%98%E7%9B%B4%E8%BF%9E/id6443975850)：设置分组行、名称/当前值/箭头，来源以标识与名称识别 | `#settings` 分组和行式设置；`#connect` 的 Plex/Jellyfin/Emby 识别卡 | 可说吸收整理复杂功能的方法；旧设置也有分组，不把它包装成这次首次发明；没有增加竞品云盘/FTP 功能或照搬完整浅色主题 |
| [SenPlayer 官网](https://www.senmuse.com/)和商店截图：工具靠画面边缘，字幕/弹幕按需展开 | `#player` 的边缘工具、音轨/字幕/弹幕设置 | 工具分层有落点；四 tab、mpv/ExoPlayer、弹幕热力和用户网关是项目自身组合；官网所述长按/双指/边缘手势不等于本原型已完整实现 |
| [网易爆米花官网](https://bmh.163.com/)：TV 深色海报墙、短标题/日期，底部时间轴与必要工具 | `#home`、`#libraries` 的封面与精简信息；`#player` 的底部控制带 | 内容优先原则有落点；当前响应式网格不等于复刻其横向 TV 海报墙，中心控制和热力层仍是 Velo 自己的取舍 |
| 同一爆米花官网：手机与 TV 示意采用不同内容密度 | 手机、桌面、TV 三种原型预览，导航/面板/焦点大小有差异 | 已有浏览器布局分支；不声称实测了竞品 TV 遥控焦点，也不代表原生多端全部完成 |

VidHub 官方主题色本次未确认。青绿是 Velo 的候选对照，默认仍为中性黑灰白。按钮按压比例、时长、面板过渡、焦点与减少动效参数是本轮自己的提案，不是竞品原生动画测量结果。

## 12. 影片评分补回规范与真实性边界

### 12.1 外部评分与我的评分分开

本轮补回的是影片已有的具名来源评分展示，不能只留下一个无来源数字，也不能用“当前服务不能写个人数字分”解释评分消失。

- `MediaItem.rating` 是服务 headline 分数；`MediaItem.userRating` 是用户自己的分；`MediaItem.ratings` 是带来源的 `MediaRatingSource` 集合。
- `MediaRatingSource` 使用 `source`、`value`、可选 `votes`；内部 `value` 统一为 0–10。品牌百分比显示按既有规则转换，不能把百分数当成十进制原值。
- `numericUserRating` 只控制个人评分写入。Plex 可提供“我的评分”入口；Jellyfin/Emby 使用收藏能力时，不影响已有服务端评分条的可见性。
- 个人评分独立 chip/控件和状态，不写回示例外部评分，不共用一个全局数字覆盖所有影片。保存、修改、清除后应影响当前影片的个人状态。
- 所有原型分值明确标为“示例评分”；没有真实服务器请求、评分抓取或账号写入。

### 12.2 展示目标与默认规则

| 位置 | 默认设计规则 | 不能出现的误导 |
|---|---|---|
| 手机首页首图 | 最多 2 个有效且启用的来源 badge，放在居中信息区，来源可辨 | 不使用无来源裸分冒充 IMDb/豆瓣，不新增播放按钮挤占首图 |
| 影片/剧集详情 | 元信息后、个人 chip 和主动作之前，最多 4 个来源；每格第一行图标+数值，第二行来源名 | 不用个人评分权限隐藏整条；不把不同级别影片/单集来源混拼 |
| 无来源数据 | 整条收起，无空白占位 | 不填 0.0、不猜分、不自动编品牌 |
| 1/2/4/5 个来源 | 按实际有效数量排版；最多 4 个，第 5 个隐藏；窄屏/200% 字号可换行 | 不为缺失的第 3、4 列预留多余高度 |
| 海报角标 | 优先当前影片有效个人分；否则首个实际可用、启用的来源分 | 个人分与客观来源须可区分，不把评分设置写成无效开关 |
| 继续观看 | 不显示评分角标，保留进度与片名 | 不让评分盖住续播信息 |
| 个人数字评分 | 有服务能力且允许编辑时出现，TV 可聚焦；来源评分条本身不增加无意义焦点 | 不把 Jellyfin/Emby 收藏称作数字评分写入 |

有效值应有限、严格大于 0 且不超过 10；先按启停过滤、去重、排序，再按位置截断。默认限制沿用 `heroLimit=2`、`detailLimit=4`，属于现有项目展示策略；真实设备布局仍保留 `TODO(VELO-P3-01)` 的确认空间。本轮不改正式 Dart 策略。

默认来源顺序参照当前项目：RT 影评、RT 观众、IMDb、TMDB、critic、audience、Simkl、MAL、AniList、Trakt、other。**顺序不等于接入承诺**：只有当前影片示例中真实声明为可用的来源才显示；缺失来源不自动补值。当前服务来源展示与下面的真实性规则共同生效。

### 12.3 服务来源、材料冲突与豆瓣

| 数据路径 | 核查结果 | 原型采用的口径 |
|---|---|---|
| Plex 来源集合 | mapper 根据 `ratingImage` / `audienceRatingImage` / `Rating[]` 的 image scheme 识别来源，可包含 IMDb、TMDB、RT 影评/观众；无品牌时回退 critic/audience | 可用具名多来源的**演示组合**检查布局，不把示例视为此次真实取回的媒体分数 |
| Jellyfin/Emby 社区评分 | `CommunityRating` 的 0–10 值映射为 audience；Provider ID 不是分数来源证明 | 使用“社区评分”与中性图标，不擅自标 IMDb/TMDB |
| Jellyfin/Emby 影评 | 当前查到的 mapper 将 `CriticRating / 10` 标成 `rottenTomatoesCritic`；但历史 R2 任务卡认为 RT 来源尚未官方核验，要求未确认时用 generic critic，并留 `TODO(VELO-R2-04)` | 保留材料冲突；原型使用“影评”中性标签并标示例，不声称已核验 RT 来源。产品 mapper 不在本任务修改范围 |
| 豆瓣 | 当前核查未见数据源或既有评分图标，R05 任务卡明确不在范围 | 不伪造接入或分值；将来若讨论可标“未接入”，不能计作本轮已实现来源 |

IMDb 的一位小数、TMDB/RT 的百分比、RT 状态图标阈值等应按项目已有显示规则处理；无品牌 critic/audience 使用中性图标，不能因为同样是百分比就贴 RT 品牌。评分存在与否、分值单位和品牌来源是三件独立的事。

### 12.4 设置生效与验收状态

评分设置需要包含海报角标开关、来源启停、来源上下排序；调整后立即反映到首图、详情与海报角标，并保持来源数量限制。来源被禁用时从展示中移除；全部禁用或全部无效时收起评分条。个人评分输入与清除需保存到当前原型影片状态，并且和外部评分互不覆盖。

本轮评分修订已完成专项浏览器验证；独立 QA 已确认以下结果，详细操作与证据见 [VALIDATION.md 的评分专项增补记录](VALIDATION.md)：

- 详情来源输入数量 0 / 1 / 2 / 4 / 5，实际显示数量为 0 / 1 / 2 / 4 / 4。
- 个人评分按影片保存，不串分；Jellyfin/Emby 展示“社区评分/影评”两种通用来源，不开放个人数字评分写入。
- 来源排序、禁用与海报角标设置即时影响展示；继续观看不出现评分角标。
- 320px 宽无横向溢出；200% 字号时四来源为 2×2，未出现压叠。
- 1920px TV 预览中，来源评分条不进入焦点序列，个人评分控件可聚焦。
- 两项评分排版修订已复验通过；`detail-plex-four-mobile.png`、`detail-jellyfin-two-mobile.png`、`home-mobile.png` 已更新。

这些结论仅覆盖此次评分修订与列明的浏览器布局/交互，不代表全站、所有状态或真机测试通过；真实评分抓取与服务器写入仍未发生。

评分专项验收目标还包含 Plex 4 来源、Jellyfin/Emby 社区+影评、无评分、个人分优先与修改/清除、手机 320/390、桌面、TV、200% 字号及三种主题。已确认通过的范围以上述 QA 回报和独立验证记录为准，未逐项列明的组合不自动视为通过；不援引不存在的历史测试文件。

新增默认值与待确认项：首图最多 2、详情最多 4；无数据不占位；原型分值为明确示例；JF/Emby 使用中性“社区评分/影评”；豆瓣不接入。动效仍沿用第 6 节可调提案，保留 `TODO(PROTO-01)`。来源真实性冲突保留 `TODO(VELO-R2-04)`，需要后续单独核验，不能在本次视觉任务中顺手改产品接口或 mapper。

本轮范围仍为浏览器核心原型与设计文档。音乐、直播录制、遥控等周边继续暂缓；本次不修改 Flutter 产品代码、后端、数据库、生成文件、凭据或其他贡献者改动，不提交、不推送。网络连接、媒体播放、投屏、一起看和评分写入均为演示，不能称作真机完成。

## 13. 本轮播放器 V4 继承与细化包

### 13.1 裁决依据与纠正

用户要求保留以前播放器的布局与交互。本轮裁决顺序为：用户明确要求 → 当前 Flutter 已落地的 V4 结构/能力 → 旧 `player.html` 最新 DOM 与 README V4 约定 → 更早保存截图 → 竞品研究建议。当前 Flutter 的 `mobile_video_controls.dart` 同样采用无中心运输控件、顶四工具、右侧截图/PiP、底部短 chip 的 V4；“保留旧稿”不是把产品退回更早截图。

旧 `<local-path-withheld>`、`player-tv.png` 保存时间早于旧 `player.html` 最新 V4 文件。较早手机截图带中心三按钮，旧 HTML 又留有 `.center` 残余 CSS，但最新 `base()` 实际 DOM 与迁移说明明确没有常驻中心快退/暂停/快进。**截图中的中心按钮不能作为恢复目标，孤立残留 CSS 也不能推翻最新 DOM。**旧 TV 截图只证明当时四 tab 与底栏示意，不证明最新版 V4 已逐平台运行验收。

旧 V4 的单击/双击、锁屏、截图、PiP、横竖切换、长按/滑动等部分仅有布局、文字说明或静态反馈；本轮要把这些约定补成可操作的浏览器演示，不能声称旧 HTML 已真实执行这些能力。旧 popover、tab、部分开关和滑杆有交互，也不能因此推定所有选中值已经保存。

前期研究曾建议“中心只留播放”和“手机底部面板”，与用户既有 V4 决定冲突，本任务明确不采纳。播放器没有常驻中心播放按钮；选择器继续分为锚定 popover 和四 tab 侧浮抽屉，不统一改成贴底大 sheet。普通应用页面的底部面板不受此播放器局部规则影响。

**长按临时倍速确有旧约定，必须保留。**早期细化提案中“不添加长按倍速”的判断被本轮历史证据覆盖：本轮需实现长按开始、松手、取消和离开页面后恢复原倍速。双指缩放未被本包确认纳入，不因 SenPlayer 官网有介绍就新增或宣称继承。

### 13.2 保留矩阵 P01–P18

本轮已接入独立 [player.js](player.js) 与 [player.css](player.css)，`#player` 使用 V4 播放器实现，资源版本标识为 `player2`；[coverage.json](coverage.json) 已记录 P/N 映射。下表为已实现的设计落点，**映射已实现不等于每项全部测试通过**。本轮操作、截图、失败项和限制统一以 [VALIDATION.md](VALIDATION.md) 的播放器专项记录为准，不套用上一轮评分或旧截图结果。

| ID | 保留项与已实现映射 | 本轮验收条件 | 当前验收状态 |
|---|---|---|---|
| P01 | `#player` 顶栏：左返回/片名/季集；右弹幕开关、投屏、横竖屏、更多 | 四入口可达；弹幕快开关与抽屉同步；一起看人数仅在对应上下文出现 | 已实现映射；验证见 VALIDATION |
| P02 | 左侧仅锁，右侧截图上/PiP 下；画面中心无常驻运输控件 | 中央只允许短暂反馈；锁/截图/PiP 有可解释结果，不放回三按钮 | 已实现映射；验证见 VALIDATION |
| P03 | 底部时间轴行 + 一行精简控件，靠渐暗而非大块面板 | 播放/下一集与倍速/字幕/选集/弹幕清楚分组；横屏不溢出、不堆图标墙 | 已实现映射；验证见 VALIDATION |
| P04 | 倍速、字幕、选集的播放器专用锚定 popover，位于触发 chip 与整底栏上方 | 不遮时间轴/顶栏；边界夹取、内部滚动；选中勾/值保存，关后焦点返回 | 已实现映射；验证见 VALIDATION |
| P05 | 选集 popover 按剧集/电影上下文呈现季集、章节或队列 | 不显示冗长文件名；电影有章节替代；队列仍可导航，不恢复多个常驻按钮 | 已实现映射；验证见 VALIDATION |
| P06 | 字幕 popover：主轨、关闭、音轨入口、搜索/本地导入；完整主副配置仍在抽屉 | 当前轨可辨、空轨可解释；在线搜索按服务能力，选择保存而非只关闭 | 已实现映射；验证见 VALIDATION |
| P07 | 更多进入视频 tab，底部弹幕进入弹幕 tab；视频/音频/字幕/弹幕固定顺序 | tab 切换、返回上下文及当前值保持；不是纯 on 样式变化 | 已实现映射；验证见 VALIDATION |
| P08 | 视频 tab：比例、自动跳片头片尾、核心、版本画质、缩放、睡眠定时 | 选项与状态保存/重置可演示；保留 mpv/ExoPlayer，不宣称接入 VLC | 已实现映射；验证见 VALIDATION |
| P09 | 音频 tab：音轨、音画同步、增益、声道 | 数值变化、重置和当前选中保持；不冒充真实解码输出改变 | 已实现映射；验证见 VALIDATION |
| P10 | 字幕 tab：主/副轨、关闭、延迟、字号、位置、在线搜索与本地导入 | 不回退既有双字幕显示与关闭；能力不足可解释；样式/偏移有可见演示结果 | 已实现映射；验证见 VALIDATION |
| P11 | 弹幕 tab：匹配标题/季集、换匹配/搜索/本地、开关/热力、样式/上限/偏移、源/屏蔽 | 快捷与抽屉状态一致；用户配置源的增删改/测试/排序保留，不内置真源或秘密 | 已实现映射；验证见 VALIDATION |
| P12 | 播放画面：单击 HUD；三分区双击 −10 秒/暂停/+10 秒；连续累加；横滑进度；长按临时倍速 | 单双击互斥；倍速松手/cancel/离页恢复原值；一次手势不触发两项操作 | 已实现映射；验证见 VALIDATION |
| P13 | 左半竖滑亮度、右半竖滑音量，对应边浮动值条 | 数值边界正确；不误 seek 或呼出章节；手势完成反馈退出，状态保留 | 已实现映射；验证见 VALIDATION |
| P14 | 同一时间轴中保留平滑面积热力、缓冲、已播、片头片尾区与播放头 | 层级可辨；不使用随机柱替代已确认平滑热峰；热力开关不影响进度操作 | 已实现映射；验证见 VALIDATION |
| P15 | 时间轴 hover/长按显示时间与此刻弹幕数；热点辅助、精准拖动、键盘可用 | 长按后 click 不误 seek；取消清理定时器；左右 5 秒；热点辅助可解释，不丢热峰交互 | 已实现映射；验证见 VALIDATION |
| P16 | 仅播放器右上投屏，DLNA handoff 设备/发送/失败/不可用状态 | 扫描、空、重扫、失败重试、移交结果可演示；关闭恢复焦点，不恢复旧稿虚假多协议能力 | 已实现映射；验证见 VALIDATION |
| P17 | 播放器 popover/抽屉四角圆、浮动留边；侧抽屉顶部 tab；空白遮罩可关闭 | 活动层互斥；Esc 逐层返回；焦点约束/恢复不退化；不改应用其他页面 sheet | 已实现映射；验证见 VALIDATION |
| P18 | 视频 HUD 永远深色白字；菜单可按明/暗主题；实色、高对比、减少动效保留 | 浅色菜单不染白视频 HUD；减少动效无位移/缩放仍能识别状态与焦点 | 已实现映射；验证见 VALIDATION |

### 13.3 新版已有可靠性保留矩阵 N01–N08

这些上一轮已存在的演示逻辑已映射到本轮独立播放器模块，重排入口时保留；不能因旧稿功能较少而退回纯样式。每项回归结果以本轮 VALIDATION 专项记录为准，代码存在不算行为验证通过。

| ID | 保留的新版能力 → 已实现映射 | 本轮验收条件 | 当前验收状态 |
|---|---|---|---|
| N01 | 返回历史、Tab 约束、Esc 分层、焦点恢复、TV 唤醒 → 全部播放器浮层与返回路径 | 关层先于退播放器；焦点不丢到背景或隐藏控件 | 已实现映射；验证见 VALIDATION |
| N02 | 播放/暂停、进度、快进退、片头跳过、锁定 → 新 V4 控件与手势共享状态 | 一个权限/状态入口，手势与按钮一致；锁态只允许解锁 | 已实现映射；验证见 VALIDATION |
| N03 | 缓冲、结束、失败重试、版本选择 → `#player` 状态演示 | 不只保留正常画面；播放结束后再次播放进度/状态一致 | 已实现映射；验证见 VALIDATION |
| N04 | mpv/ExoPlayer、版本、比例、速度、音轨、章节、队列、季集 → 对应 popover/四 tab | 所有入口仍可达；选中值、勾选和标题同步，不只提示“成功” | 已实现映射；验证见 VALIDATION |
| N05 | 主/副字幕、关闭、颜色、偏移、外观、Plex 搜索、本地导入 → 字幕 popover/tab | 保持服务条件、关闭与主副文本正确；不丢原有演示状态 | 已实现映射；验证见 VALIDATION |
| N06 | 弹幕/热力、匹配/搜索/导入、网关管理、过滤/样式 → 顶栏快捷与弹幕 tab | 快捷开关不与面板脱节；源保存/编辑/删除/排序有相应结果 | 已实现映射；验证见 VALIDATION |
| N07 | DLNA 扫描/空/重扫/失败/不可用/发送/移交并暂停本地 → 顶右投屏 | 保留完整演示状态，不宣称支持未接入的 Velo TV/Google Cast | 已实现映射；验证见 VALIDATION |
| N08 | 亮度/音量数值替代操作、TV 键盘、减少动效/高对比/实色、全局服务/状态和演示标记 | 新手势不删除无手势替代；状态切换不影响评分/首页/库等已有工作 | 已实现映射；验证见 VALIDATION |

### 13.4 竞品优点只用于细化 V4

| 公开观察 | 本轮采用的细化 | 保留骨架与证据限制 |
|---|---|---|
| [VidHub 官方商店](https://apps.apple.com/cn/app/vidhub-video-library-player/id1659622164)的紧凑播放控制与局部画质/字幕/选集层 | P03/P04/P17：统一局部 popover 的当前值、选中勾、内边距、边界和操作反馈 | 不恢复中心按钮、不统一改底 sheet；未测其 Android/TV、材质参数或动画曲线 |
| [SenPlayer 官网](https://www.senmuse.com/)与[官方商店](https://apps.apple.com/cn/app/senplayer-%E5%85%A8%E8%83%BD%E8%A7%86%E9%A2%91%E6%92%AD%E6%94%BE%E5%99%A8-%E7%BD%91%E7%9B%98%E7%9B%B4%E8%BF%9E/id6443975850)的边缘工具、分组行/当前值，官网描述的手势 | P01/P02/P07/P12/P13：统一边缘工具热区、四 tab 当前值和短暂手势反馈 | 位置与手势来自旧 V4；长按是旧约定，不是本次新抄功能；不添加未授权云盘、AI、双指手势等 |
| [网易爆米花官网](https://bmh.163.com/)的 TV 长时间轴、精简底部工具、画面为主 | P03/P14/N08：减弱底栏大块背景，时间/工具对齐，TV 焦点与热区适配 | 不牺牲章节/队列/热力等功能，不将手机图标机械放大；未实测其遥控焦点 |

青绿不是已确认的 VidHub 官方主题色；默认中性黑灰白与青绿候选仍属 Velo 提案。以上公开证据不能支持“测得竞品原生动效”，所有时间、反馈与焦点规则均是本轮适配提案。

### 13.5 手势、状态、权限与能力边界

- 单击等待双击窗口；按 active pointer 识别一次手势，横向 seek、竖向亮度/音量、长按临时倍速互斥。第二指不引发第二个动作。拖动/长按/竖滑结束不能额外触发 HUD 单击。
- 三分区双击的快进退复用按钮/键盘同一进度状态与 `canControl`；连续双击累计展示。长按必须保存用户原速度，如 1.25×，松手/cancel/路由离开恢复 1.25×，不能一律重置 1×。
- 浮层打开取消自动隐藏，关闭后恢复计时；焦点/面板/拖动/暂停/缓冲期间不自动藏 HUD。画面手势不得穿透活动面板，输入框不得被播放快捷键劫持。
- 锁定只允许解锁；触摸可唤出锁图标，但进度 range、方向键、快捷键及手势都不能修改播放。解锁必须可达，且不丢原状态。
- 一起看 `guest + hostOnly` / `canControl=false` 时，seek、速度、换集等控制不能绕过限制；显示原因或请求动作。切回房主恢复可用，不新建伪权限码。
- 截图在当前 Flutter 仅 Android 绑定，复制的是视频面、不含弹幕 HUD；原型提供明确的模拟成功/失败，不调用真实系统截图。不能在所有平台宣称可用。
- PiP 由 Android/iOS/macOS 的支持探测和回调决定；原型只提供示例窗口、返回和不可用状态，不冒充真正系统 PiP。横竖按钮切换播放器演示布局，不伪称旋转了物理设备。
- 投屏保持当前 DLNA handoff 边界。旧稿列过的 DLNA/Velo TV/Google Cast 是模拟内容，不能当作当前产品真实多协议能力。
- 保留正常、隐藏、暂停、缓冲、结束、失败重试、锁定、无轨/空选集、访客受限、投屏各状态、截图失败/PiP 不支持；全局演示切换仍可使用。

### 13.6 集中默认值与未验项

以下记录本包的集中默认规则与 TODO，运行值以原型集中配置和播放器模块为准，不散写独立阈值；这些值不是竞品测量或真机调优结果。早期统一 HUD 3600ms 的说明由本节触控/鼠标分开计时规则覆盖。

| 参数 | 本轮默认/继承规则 | TODO / 验收约束 |
|---|---|---|
| 可触热区/图标 | 触控至少 44×44，图标 20–22；TV 至少 52×52 | `TODO(PROTO-PLAYER-01)`：视觉图标可小，热区不重叠 |
| 按压与释放 | 90ms / 0.97；160ms 恢复 | `TODO(PROTO-PLAYER-02)`：减少动效取消缩放 |
| 浮层 | popover 160ms；侧抽屉 220–260ms | `TODO(PROTO-PLAYER-03)`：保留锚定/侧浮方向，不采用贴底大 sheet |
| HUD 计时 | 按现产品触控 5000ms、鼠标 3000ms；TV 焦点/面板/拖动/暂停/缓冲保持显示 | `TODO(PROTO-PLAYER-04)`：取代早前统一 3600ms 提案，需真实计时验收 |
| 单双击 | 等待 240ms；三分区各 1/3；进退 10 秒；连续累计窗口 800ms | `TODO(PROTO-PLAYER-05)`：不能单击/双击同时执行 |
| 手势判定 | 位移阈值 8px；长按 450ms 临时 2× | `TODO(PROTO-PLAYER-06)`：松手/取消/离页恢复原倍速；原范围 0–100 的边界仍需验证 |
| 热力长按/热点辅助 | 长按 450ms；旧热点阈值 smooth>0.6、附近 ±6 桶；键盘左右 5 秒 | `TODO(PROTO-PLAYER-07)`：辅助与精准拖动分开，取消清定时器；不把热峰功能删成装饰 |
| 反馈/减少动效 | 进退在对应侧、倍速/暂停仅短暂中心反馈、亮度/音量在对应边 | `TODO(PROTO-PLAYER-08)`：反馈时长集中配置；减少动效下状态仍清楚 |

本轮验收需覆盖 844×390 横屏、390×844 竖屏、320px、1920×1080 TV、200% 字号、明/暗/纯黑、减少动效、高对比，以及 P/N 每项行为和权限场景。已交付独立播放器实现与 P/N 映射；具体测试覆盖及限制以本轮 VALIDATION 为准，本文件不将所有组合一并标为通过。

范围仅 `design/prototype-v2/` 的播放器原型及说明，本文只改 `DESIGN.md`。不修改 Flutter/native、后台、真实媒体/系统能力，不提交推送；已完成评分、首页、媒体库等不可回退。网络、播放、投屏、截图、PiP、旋转与房间状态仍为演示，浏览器 QA 不能替代真机测试。


### 13.7 本轮实现与验证证据边界

旧 V4 中仅有文字/静态示意的 HUD 单击、三区双击、临时倍速、亮度/音量竖滑、横滑进度、锁屏、截图/PiP/横竖切换，已在 `player.js` / `player.css` 中补充为浏览器交互或明确的能力模拟。popover 选项由旧“点选只关闭”细化为保存当前值、显示选中项与恢复焦点；四 tab 侧浮抽屉、无常驻中心按钮、顶右/侧边/底栏结构继续遵守最新 V4，而非较早三按钮截图。

当前已收到的专项证据按验证方式区分：

| 验证方式 | 已确认范围 | 证据限制 |
|---|---|---|
| 真实浏览器鼠标输入 | 单击显隐 HUD、三区双击、长按临时 2× 后松手恢复原 1.25×、自动隐藏 | 不等于真实手机触屏；多指、触摸驱动及原生播放器仍未验证 |
| 合成 pointer 事件 | 左右竖滑亮度/音量、横滑进度的数值变化和手势互斥 | 仅验证事件路径与状态结果，不能称真触屏手势体验通过 |
| 浏览器面板/状态检查 | popover 锚定、四 tab 侧浮抽屉、锁定、字幕回焦、弹幕热力、DLNA 模拟、截图演示 | 不代表真实字幕解码、网络投屏或系统截图已执行 |
| 独立代码审查 | 旧键盘路径隔离、主副字幕同轨处理、结束态、独立手动跳片头、访客恢复/重播五项最终通过 | 审查通过不能替代每项端到端操作或真机验证 |
| 其他组合 | guest 场景、TV、320px、字号等最终结果 | 以 [VALIDATION.md](VALIDATION.md) 最新播放器专项为准；本次文档交接未取得最终结论的项目不标通过 |

VidHub 的局部选择层、SenPlayer 的边缘工具与行内当前值、爆米花的长进度与精简底栏只用于细化 V4；没有改变其入口位置、popovers/侧浮抽屉家族或删减原功能。动效参数与青绿候选仍是 Velo 自定提案，不归因为竞品原生实测。

正式 Flutter/native、真实播放、系统亮度/音量、PiP、截图、投屏与房间权限同步均未由本轮改动或真机验证。文档仅更新本轮交付口径；实现、截图和测试文件由各责任代理维护，本代理不改动，也不提交推送。
