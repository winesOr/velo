# Proposal

## Why

现有 Flutter fork 已有弹幕绘制、流光背景、玻璃播放控件和一起看，但弹幕源仍默认指向本机且设置不持久化；最新五页原型也尚未接入实际数据与焦点系统。需要把已确认的视觉和功能转成可验证的 OpenSpec 契约，按阶段交付可用版本。

## What Changes

- P0：用户自建多弹幕源、持久化、弹弹play v2 匹配流程、按季记忆、时间偏移、同画布热力图、播放器 Logo。
- P1a：按最新 `home/library/together/player/settings.html` 改造手机与 TV 的导航、通栏 Hero、海报墙、设置和一起看入口，使用生产数据。
- P1b：完善弹幕样式、密度、过滤与片头跳过撤销，形成原型对应的播放闭环。
- 在 `roadmap.md` 记录后续投屏、WebDAV/SMB/115 文件源、可选 VLC 与 P2 项目的依赖和独立 change 边界。这些后续能力不属于本 change 的 apply 范围。
- 原型的假设备、邀请码、预设色板、图片素材和静态计数只作设计参考；正式功能使用真实能力和真实数据。

## Capabilities

### New Capabilities

以下是首次建立的规范边界，包含现有行为的新增约束，不表示所有模块从零实现。

- `adaptive-media-shell`：手机四入口、TV 顶部导航、Hero 与主题联动。
- `media-library-browsing`：服务端能力感知的组合筛选、排序和海报墙。
- `watch-together-experience`：独立房间入口、创建加入、成员状态及重连反馈。
- `danmaku-sources`：空源引导、多源管理、请求边界和持久化。
- `danmaku-matching`：三步匹配、按季记忆、偏移和异步结果隔离。
- `danmaku-heatmap`：确定性分桶、P95、同画布绘制和峰值交互。
- `danmaku-presentation`：跨界面统一设置、密度与过滤。
- `player-hud`：Logo、时间轴兼容、跳过撤销与播放控制层级。

### Modified Capabilities

无。初始化时 `openspec/specs/` 尚无基线；上述规范先作为 change deltas，实施和验收完成后再归档为基线。

## Impact

- UI：`lib/screens/main_screen.dart`、`lib/navigation/`、`lib/screens/discover_screen.dart`、`lib/screens/libraries/`、`lib/screens/settings/`、`lib/watch_together/`。
- 播放：`lib/danmaku/`、`lib/widgets/video_controls/`、`lib/screens/video_player/`、`lib/widgets/optimized_media_image.dart`。
- 状态：扩展 `lib/services/settings_service.dart` 及既有 Provider；匹配结果携带服务器与弹幕源身份；所有新增文案经 slang 生成。
- 外部：用户配置的弹幕兼容网关；官方直连仅在提供自有合法凭据且签名行为核验后启用。现有媒体服务器和中继协议继续复用。
- 本轮交付是规划文档和项目 OpenSpec 配置；应用源码实现、真机性能结论和构建产物尚未产生。
