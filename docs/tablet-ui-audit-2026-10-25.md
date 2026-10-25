# 平板界面逐页调整记录

2026 年 10 月 25 日。对照 `design/prototype/` 的新版手机和 TV 视觉，补齐 Flutter 平板布局。原型没有独立平板版；本轮将现有视觉适配到触控大屏，保留首页、媒体库、一起看、设置四个底部入口。

## 逐页对照

| 页面 | 原有问题 | 调整结果 |
| --- | --- | --- |
| 首页 | 宽度达到 900 后进入另一套 Hero；平板文字、海报和标题边距不统一 | 平板使用 `FusionHomeHero`，竖屏居中、横屏靠左；保留海报取色和连续渐变。统一 32 dp 内容边距，放大标题与卡片文字，限制 Hero 高度。 |
| 详情 | 600 以上进入旧的胶囊信息与操作布局，与新版手机详情分离 | 平板复用新版片名、简洁信息、播放按钮和操作图标；内容宽度最多 560 dp。竖屏居中、横屏靠左；横屏使用横向背景素材，季集选择和演员保持新版样式。 |
| 媒体库 | 搜索、筛选、来源标题和海报墙贴边程度不同 | 单库及跨来源页面统一平板间距；保留密度偏好、字母导航、搜索、筛选、排序和分页。 |
| 搜索 | 结果行随屏幕无限拉长 | 搜索内容居中，最大宽度 1000 dp；输入框、筛选和结果使用相同边距，统一页面标题样式。 |
| 设置 | 平板仍是手机式单列导航 | 可用宽度达到 760 dp 时使用分类与内容双栏，点击左侧分类直接显示真实设置；大字号及窄分屏回到单列。二级设置页最大宽度 900 dp，平板分类栏支持键盘焦点恢复。 |
| 一起看 | 页面边距较小，内嵌页底部没有预留悬浮导航空间 | 统一平板边距；继续使用可用空间决定房间双栏，大字号保留单列；底部预留 100 dp，最后一项可滚动到导航上方。 |
| 播放器面板 | “更多”内部及外层都按手机的 318 dp 限宽 | 更多面板与打开入口共享宽度：手机 318 dp，平板 400 dp。平板面板高度上限 680 dp；投屏面板同步扩宽。设置行适当增高，标签切换保持尺寸。 |
| 加载状态 | 首页及详情骨架屏与平板加载后的高度、对齐方式不同 | 使用共同的平板 Hero 高度规则，详情骨架屏随横竖屏对齐。 |

平板视觉按当前触控窗口的最短边至少 600 dp 判断。桌面窗口和 TV 使用各自的布局；520 dp 分屏和 600 dp 窄平板设置保留单列。

## 截图

以下是正式 Flutter 组件使用测试数据生成的截图。首页使用本地原型素材；无图详情和媒体库使用占位图。播放器使用测试播放器，房间使用测试状态，截图不代表真机播放或双端同步验收。

| 页面 | 竖屏 820 × 1180 | 横屏 1180 × 820 |
| --- | --- | --- |
| 首页 | [竖屏](fixtures/tablet/home-820.png) | [横屏](fixtures/tablet/home-1180.png) |
| 详情 | [竖屏](fixtures/tablet/detail-820.png) | [横屏](fixtures/tablet/detail-1180.png) |
| 媒体库 | [竖屏](fixtures/tablet/library-820.png) | [横屏](fixtures/tablet/library-1180.png) |
| 搜索 | [竖屏](fixtures/tablet/search-820.png) | [横屏](fixtures/tablet/search-1180.png) |
| 设置 | [竖屏](fixtures/tablet/settings-820.png) | [横屏](fixtures/tablet/settings-1180.png) |
| 一起看 | [竖屏](fixtures/tablet/together-820.png) | [横屏](fixtures/tablet/together-1180.png) |
| 播放器更多入口 | [竖屏](fixtures/tablet/player-settings-820.png) | [横屏](fixtures/tablet/player-settings-1180.png) |

另有 [600 dp 首页](fixtures/tablet/home-600.png) 和 [600 dp 详情](fixtures/tablet/detail-600.png)。播放器截图从真实“更多”按钮打开面板，覆盖外层限宽。

## 验证范围

`flutter analyze --no-pub` 无告警；本轮相关回归共 408 项通过。

新增检查覆盖平板横竖屏首页与详情、季集区域、设置分类点击、窄分屏、大字号单列、媒体库筛选、搜索结果限宽、房间布局，以及播放器更多入口和标签切换。手机、桌面与 TV 的导航、焦点、字幕章节和弹层用例一并回归。

媒体库原有三张手机及 TV 截图基准仍使用旧灰色。核对布局后，已同步到工作区当前的紫灰主题。

当前仅检测到 macOS，没有连接平板。Android 与 iPad 真机的触控手感、系统键盘、旋转动画、播放帧率和真实投屏仍需设备验收。

复现截图：

```bash
flutter test --dart-define=CAPTURE_TABLET=true \
  test/screens/discover_screen_test.dart \
  test/screens/media_detail_screen_test.dart \
  test/screens/search_screen_test.dart \
  test/screens/settings/settings_screen_test.dart \
  test/screens/libraries/grouped_library_browse_test.dart \
  test/watch_together/watch_together_experience_test.dart \
  test/widgets/mobile_player_gestures_test.dart
```
