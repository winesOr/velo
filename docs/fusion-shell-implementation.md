# 融合导航与首页实施说明

对应 change `plan-plezy-fusion-redesign` 的 5.1–5.5。视觉依据是最新
`design/prototype/home.html`、`home.css`、`hero.js`、`navigation.js`，不是旧版 PNG。

## 导航与旧入口

- 手机固定首页、媒体库、一起看、设置四个主入口。首页右上“选项”保留当前可用的搜索、下载、直播、发现等全部目的地，搜索也有直接按钮；长按媒体库保留快速选择。头像菜单保留刷新、遥控、身份管理和退出。
- TV 使用顶部居中胶囊：四主入口、搜索、选项。首页内容按上或返回回到导航，导航按下恢复内容焦点。一起看使用 `WatchTogetherScreen(embedded: true)`，复用已有房间控制器，并通过回调把返回交给外壳。
- 桌面保留原侧栏与可展开、隐藏媒体库，只增加一起看。手机横屏保留原左侧导航；平板横竖屏均使用底部居中的悬浮玻璃四入口，内容全宽显示，不为导航独占一列。平板识别沿用现有逻辑尺寸对角线规则，车机横屏仍保留左侧导航。不在首页或设置增加投屏。
- 页面继续使用延迟挂载、非当前页停用 ticker 的 `IndexedStack`，保留已访问页滚动与焦点。旧远程切页命令和快捷键仍指向原稳定 ID。
- `NavigationTabId.together` 追加在枚举末尾；启动偏好按名称序列化，不按索引。下载、设置等旧目的地仍可作为启动页；离线优先下载，只保留离线可用目的地和重连。发现与直播继续受能力/隐藏设置约束。TV 离线胶囊直接显示下载和设置。

## 真实数据与视觉联动

`DiscoverProvider` 仍是继续观看与推荐列表的唯一业务来源；没有新增生产示例标题、素材、计数或第二套目录状态。

手机 Hero 改为通栏清晰海报，不再整张高斯模糊。服务器 Logo 缺失时居中显示片名；评分、年份、播放目标及可点击分页点都来自同一选中条目。继续观看复用 `HubSection` 的播放进度、菜单、分页和更新，只提供首页专用宽度以露出下一张卡，剧集使用已有缩略图模式。其他推荐行保留用户密度偏好。

`HomeThemeController` 保存选中服务器/媒体身份及氛围色，复用现有取色器和缓存、160×90 服务器小图。每次切换递增 generation，旧图迟到结果不能覆盖当前片；无图或加载失败立即采用稳定底色。TV 监听与标题和海报相同的防抖 spotlight 控制器。播放位置更新不会重新取色。

首页是局部的 mono 暗色电影表面，即使全局选择浅色主题，也保证白色服务器 Logo、元信息、推荐标题、顶部按钮和分页点在取色背景上可读。此行为不修改用户持久主题，不改变设置/媒体库页主题。首页同时声明状态栏、系统导航栏图标亮度。

减少动态效果时停止首页自动翻页和海报轮换，用户主动选页直接切换，取色插值立即完成。原 `VidHubAmbientBackdrop` 同步补充迟到结果保护与减少动画支持。

## 布局与无障碍

- 前景操作避开安全区，海报保持通栏。
- 长片名最多两行；Logo 文字回退槽随系统字体放大，避免固定高度裁切。
- 导航最小触控高度 48dp，暴露选中语义。手机标签最多两行，仅导航文字缩放上限 1.3，沿用既有 Material 导航策略；不限制页面正文缩放。
- 新导航走 `lib/focus/FocusableButton`，TV 有明确的向下交接和稳定焦点节点。既有媒体行按身份保存焦点，详情返回与切页不重新建一套记忆。
- 内容底部预留浮动底栏空间；迷你播放器仍按实际底栏尺寸测量避让。

## 自动验证与截图

```sh
flutter test --no-pub \
  test/navigation/home_theme_test.dart \
  test/navigation/fusion_navigation_test.dart \
  test/navigation/navigation_tabs_test.dart \
  test/screens/main_screen_layout_test.dart \
  test/screens/discover_screen_test.dart \
  test/widgets/vidhub_ambient_backdrop_test.dart
```

覆盖旧启动页、离线下载、旧目的地保留、TV 确认/向下、跨服务器同 ID 取色竞争、图像失败/缺失、销毁后取色、减少动态、全局浅色下首页对比度、既有 Discover 刷新/焦点回归，以及 390×844、320×640/2 倍字体、820×1180/1180×820 平板、960×540、1280×800 的组件布局与交互。`test/widgets/mobile_navigation_rail_test.dart` 另覆盖 Android/iOS 平板横竖屏底栏选择、横屏手机/车机保留左栏、桌面/TV 不受影响。

诊断截图生成命令：

```sh
flutter test --no-pub --dart-define=UPDATE_FUSION_SCREENSHOTS=true \
  test/navigation/fusion_navigation_test.dart
```

输出 `docs/fixtures/fusion-shell-{phone,narrow,tablet-portrait,tablet-landscape,tv,desktop}.png`。这些明确属于**无图回退组件 fixture**：使用正式 `MediaItem` 模型，但字段是测试值；验证文字回退、可读性与控制，不是完整 Discover 或真实服务器截图，也不能证明网络播放。desktop fixture 仅测试共享导航组件，生产桌面仍是侧栏。

## 差异与尚待人工验收

- TV 胶囊预留顶带，不叠压内容；继续复用既有宽屏 spotlight 与横向媒体行。
- 生产海报、Logo、片名来自服务器，裁切和取色自然不同于原型用户截图与预设色板。
- 没有重复原型装饰性“和朋友一起看”卡片；四主入口中的一起看直接打开真实房间业务。
- 组件 fixture 不能证明 Android 系统边缘显示、GPU 帧耗时、TV 硬件遥控、各服务器详情返回焦点或最新 HTML 视觉验收。上述人工项单独保留，不能据自动测试勾选为已验收。
- 本部分全部复用已有 slang 键；共享启动设置和生成物由集成阶段维护，没有手改生成文件。

回滚时一起恢复首页、外壳及导航相关 widget；启动名称序列化和既有 Discover/房间/下载数据无需删除或迁移。
