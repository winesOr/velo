# Plezy 视觉差异审计与原型 V2

日期：2026-10-23。范围：分析当前工作区 Flutter 源码、现有 HTML 原型、用户手机截图以及本地 VidHub 3.0.3 APK；本轮修改仅在 `design/prototype/` 和本文，不实施 Flutter 重构。

## 结论

主要问题不是缺少一个“背景组件”，而是页面、海报、导航各自更新：取色期间先回默认色、页面底色直接赋值、详情背景未接入取色输入；图标、字重和信息密度也未形成统一标准。原型应先固定页面结构、视觉参数和功能入口，随后再按页面改 Flutter。

原型入口：`design/prototype/index.html`。涵盖首页、剧集 / 电影详情、媒体库、一起看、设置、横屏播放器；各页含 TV 版。V2 是可审阅的视觉基线，尚不能宣称与 VidHub 全部运行时行为像素级一致。

## 证据分级与旧文档纠偏

### 本轮直接确认

- 用户截图：通栏竖向主视觉、居中片名、播放大按钮、收藏 / 已看、季与分组选集、演员、类型、相关推荐、音视频字幕信息、文件信息。截图未显示独立详情页底部导航，因此原型详情页不加主导航。
- APK：`reference/apk/vidhub/vidhub-base.apk`，3.0.3 / 318，SHA-256 `b7041dc8d97844a561751da525dcff2cec45b479a695fac7b8b3b3873b111414`。
- REA `decode_android_resources`：`ev_333bc78883687596deb56a491ec69dcc841cdfe8c4428acaebaf1bc794dfb889`。
- 新安装的 JADX 经独立 REA 进程验证可用。`search-android-classes … HomeCarousel` Evidence：`ev_87edc99754f7de0a332ab0f76a070f80a190e7946f5aeb2c8b98f0c7a7286499`。完整类表 32 个，匹配 0；仅说明此加固分发包的可读类表未包含该类，不能据此断言运行时没有取色功能。
- DEX 原始表统计 30 个 class_def，55,356 字节；JADX 的解析类数 32 与原始定义数的统计口径不同。APK 有 `assets/nedata.db`，manifest 应用类是网易 NIS wrapper。
- APK 原件未改动。使用 `apktool d --no-src` 在临时目录解码后直接读取以下 XML；base 缺少 density split 的部分 drawable，因此不能凭解码警告判断图标缺失。

| 资源证据 | 实际值 / 结构 | 对原型的影响 |
|---|---|---|
| `res/values-night/colors.xml` | `view_bg_color = #ff000000`，`nav_text_color = #ffffffff` | 默认页面黑灰、白色导航 |
| `res/values/colors.xml` | 日间 `view_bg_color = #fff2f2f7`，导航黑；详情 fallback `#ff333333` | 这是日 / 夜资源，不能混写成统一默认色 |
| `res/values-night/colors.xml` | 导航边框 `#1affffff`，随机模糊覆盖 `#cc000000` | 描边很轻，默认模糊罩并不是旧文档所谓固定黑 22% 的直接证据 |
| `res/values/dimens.xml` | 工具栏高 56dp、最大宽 360dp、圆角 30dp | 手机底栏按该轮廓约束；适应 390px 预览后的内容宽度 |
| `res/layout/activity_main.xml` | 浮动底栏 + `BlurView`；两侧 margin 20dp；标签 10sp；外层 elevation 8dp | 玻璃胶囊 + 小标签，四个入口换成 Plezy 已批准的导航 |
| `res/layout/item_media_server_home_banner.xml` | 图片 / 信息两个 ViewPager，`PosterGradientView`、分页点 | 图片与文字解耦，不把全部 UI 烧进海报 |
| `res/values/dimens.xml` | 媒体服务器 banner 360dp，gradient 260dp | 这是该资源布局的静态值，不能推广到所有首页模式；本轮主首页按用户先前的大海报参考保持更高主视觉 |
| `res/layout/activity_media_server_item_detail.xml` | 主视觉 5:8、标题 26sp、元数据 12sp、Logo 容器 | 补齐详情主视觉层级，保留 Logo / 文字回退 |
| `res/values/dimens.xml` | Logo 最大宽 260dp、高 90–100dp；详情渐变 320dp；播放按钮圆角 21dp | 主标题与播放按钮保持克制 |
| `res/layout/media_server_home_section_item.xml` | 区块标题 18sp；查看全部 14sp | 主副信息明确区分 |

本轮当前聊天绑定的旧 MCP 进程仍报告缺少 `REA_JADX_MCP_JAR`；带已配置 JAR 环境的新 REA CLI 进程正常。这是进程环境未更新，不是用户没有装好工具。

### 不能继续作为“源码实测”使用的旧断言

`docs/vidhub-ui-*.md` 中的“取色类只有 68 行”“平均色统一乘 .78”“380ms”“LRU 128”“sigma 38”“默认 #16191D”没有在本轮这份受保护 APK 中重新取得方法体证据。可保留为历史设计参考，不能据此宣称已还原 VidHub 算法。

V2 的 32×32 canvas 采样、低饱和 / 过暗过滤、对高饱和色压缩、560ms 插值、异步代次保护与缓存，均是我们为原型自主实现的方案。保留海报明度，避免再用固定乘 .78 把用户参考中的浅灰氛围整体压黑。

## 当前 Flutter 与目标的差异

| 项目 | 当前源码可见行为 | 修改方向 / 文件 |
|---|---|---|
| 海报切换闪默认色 | `HomeThemeController.select` 每次先把 `_color` 设为 fallback 并通知，再等待新颜色 | 保留上一张显示色；先并行解码 / 采样；新结果仍按 generation 去重；只在首次无画面或明确清空时用 fallback。`lib/navigation/home_theme.dart` |
| 页面底色硬切 | `DiscoverScreen._buildContent` 的 `Material(color: HomeThemeScope.colorOf(context))` 直接使用目标色 | 页面背景、hero fade、导航取同一个连续动画值；避免每个消费者重新启动不同动画。`lib/screens/discover_screen.dart` |
| 详情没有实际海报取色输入 | `_buildHeroBackdropLayer` 调用 `VidHubAmbientBackdrop` 时只传图片 widget，没有传 `accentColor` / `imageProviderForExtraction` | 从当前 clean backdrop / poster 生成同一图片身份的低分辨率采样输入；把调色结果同时交给详情背景与渐变。`lib/screens/media_detail_screen.dart` |
| 动态范围只在 Hero 内 | `VidHubAmbientBackdrop` 用普通 `bgColor` 渐变到底，外层页面仍取主题 scaffold | 详情整页共享该媒体 palette；往下滚动到演员和媒体信息仍连续。`lib/widgets/vidhub_ambient_backdrop.dart`、详情屏幕 |
| 导航选中区分弱 / 样式不一致 | 手机 `FusionNavigation` 的图标和标签选中 / 未选中均白色，靠填充和胶囊区分；原生 `NavigationDestination` 又是两态实心图标 | 线性图标统一；活动白、非活动约白 65%；手机 22px / 标签 10px；控制玻璃浓度。`lib/navigation/fusion_navigation.dart`、`navigation_tabs.dart` |
| 导航表面更新节奏不同 | 底栏已有独立 380ms `AnimatedContainer`，背景却直接跳色 | 接收共享过渡后的颜色，避免底栏落后于正文；在静态页面回中性色，避免继承上一部影片染色 |
| 首页页面比例不稳定 | 手机 Hero 包含继续播放按钮，详情 / 播放入口和旧原型并不完全一致 | 首页以海报与片名为主，点影片进详情；继续观看卡承接续播；TV 才保留明显的继续 / 详情双按钮。`lib/widgets/fusion_home_hero.dart` |
| 详情信息密度不一致 | 通用详情组件与动态 `textTheme.titleLarge`、多种 chips / shelf 混用 | 详情标题 26；区块标题 18；正文 13–14；元数据 11–12；内容边距 16；版本与来源合并入口，技术信息移底部。保留字体缩放可访问性 |
| 图标语言杂糅 | 原型播放器混用 emoji、Unicode 与 SVG；Flutter 使用 Material Symbols filled / rounded 多种状态 | 本轮原型统一 SVG 1.7px 线条；正式实现统一 `AppIcon` 的尺寸 / fill / weight，而不是直接把 SVG 分散到代码 |
| 媒体库筛选挤占 | 旧原型首屏是六个 select，TV 与手机信息密度接近 | 手机三列 + 筛选 sheet；TV 七列示意 + 搜索 / 筛选 / 排序。保留音乐、跨服务器和 Plex |
| 设置首屏太重 | 旧原型直接铺弹幕参数与播放核心；与 Plezy 实际能力不一致 | 一级放类别、二级放参数；新增能力不夹进外观设置；TV 左分类右内容。`lib/screens/settings/` |
| 播放器身份与浏览主题混淆 | 旧原型用固定青绿流光假画面，emoji 控件，灰阶不一致 | 播放中以视频帧为主体，中性玻璃 HUD；弹幕 / 音轨 / 字幕 / 投屏在播放上下文操作 |

这些结论基于当前未提交工作区，不宣称已在安装包或真机上复现全部问题。

## V2 页面与功能布局

- 首页：账号 / 服务器、搜索、更多；四张真实图像取色；继续观看 / 最近添加 / 推荐；四主导航。
- 详情：海报与标题 / Logo 回退、评分元数据、主播放、收藏 / 已看、服务器版本入口、简介、季 / 分组选集 / 全集、演员、类型、相关推荐、视频 / 音频 / 字幕卡、文件位置。电影版移除选集。
- 媒体库：全部 / 电影 / 剧集 / 音乐；搜索；组合筛选、排序、空结果 / 清空；来源保留 Emby / Jellyfin / Plex。
- 一起看：创建 / 邀请加入、房间列表、房主与准备、邀请、离开 / 开始。中继配置放设置，播放状态放播放器。
- 设置：服务器账户、播放、字幕、弹幕、一起看、外观、下载离线、连接与内容服务、关于。多弹幕源初始为空；添加 / 顺序 / 删除；格式检查明确不冒充真实连通测试。VLC 标为规划且不能选择。
- 播放器：返回详情、标题、一起看、投屏、弹幕、设置、画中画；中间播放与快退快进；时间轴热力 / 缓冲 / 章节 / 跳过；底部音轨 / 主次字幕 / 倍速 / 选集；TV 侧面板。

未引入 VidHub 的云盘、刮削和账户订阅体系。文件源方向仍服从现有批准范围，不由本次视觉重画扩大。

## Flutter 实施顺序

1. 修复共享色彩生命周期：不先清空颜色、预解码、取色输入绑定当前媒体身份、整个页面共享同一插值；快切、返回、无图失败、减少动态效果均覆盖。
2. 对齐默认底色与导航、统一图标和类型字号；先完成基础 tokens，避免每页继续硬编码。
3. 首页按原型对齐比例、卡片尺寸和入口；保留真实媒体图像，不把原型素材打进 APK。
4. 详情页落地两种布局与版本 / 选集面板；正确读取 item / parent clearLogo，图片不含 baked UI。
5. 媒体库 / 设置 / 一起看按同一套组件和分类迁移；所有新增动作走 `lib/focus/`。
6. 最后细化播放器；热度继续在已有 `BufferRangePainter` 一块 canvas 中，保持章节裁剪与 `shouldRepaint`。

应用验证应跑现有 `scripts/codegen.sh --check`、`flutter analyze`、`scripts/run_tests.sh`、`scripts/ci_checks.sh`，再做 arm64 真机与 TV 遥控实测。本轮只有 HTML / 文档，不把浏览器验证冒充 Flutter 检查或真机性能验收。

## 本轮验收与限制

详见 `design/prototype/qa/verification.md`。浏览器验证覆盖初始渲染、快切主题、完整详情、筛选空结果、房间、空源添加、播放器投屏与 TV 焦点，截图位于同目录。

详情主视觉 / 演员 / 选集使用用户完整截图的 CSS 取景，素材边缘裁切不能替代正式 clean poster。示例电影使用本地保存的 TMDB 海报；不同页面的播放画面是占位，详情内部分元数据为示例。所有网络、下载、一起看与投屏仅为原型交互。

## 用户复审后的 V3 修正

本节覆盖 V2 中与新要求不一致的部分，Flutter 实施范围仍未扩展。

1. **来源身份**：不用首字符头像；直接复用 `assets/emby_icon.svg`、`jellyfin_icon.svg`、`plex_chevron.svg` 的路径。首页左上角、设置服务器、资源元数据、详情版本来源均按服务类型显示。人物 / 房间成员的头像与服务器标识分开处理。
2. **浮层**：首页菜单靠近触发点，常规弹窗居中，播放器参数浮在右侧；全部四角圆润，不再贴底。重新读取的 VidHub `res/drawable/dialog_corner_background.xml` 引用 `menu_bg_color` 和 `dialog_radius = 16dp`，可支持菜单表面 / 圆角参考，不代表取得受保护的弹窗业务代码。
3. **外观与层次**：新增浅色 / 深色 / 跟随系统，默认跟随系统，手动选择可持久化并覆盖系统变化。系统模式实时响应外观变化，其他打开的原型页面也会同步。深色导航提高表面不透明度、增加描边、独立选中区与前景差异；浅色有完整的页面、文字、表单、浮层、导航配色。
4. **轮播**：移除左右箭头，保留手指滑动与分页点。TV 可聚焦轮播后按左右键切换；普通点击标题仍进入详情。

代码落点：`appearance.js` / `appearance.css`、共享 `ui.js`、`theme.js`，以及 `hero.js` / `settings.js` / `library.js` / `detail.js`。新验证记录保存在 `design/prototype/qa/revision-3/`。
