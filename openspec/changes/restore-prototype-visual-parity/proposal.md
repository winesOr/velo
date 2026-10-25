# Proposal

## Why

当前 Flutter 已接入融合导航、弹幕与一起看，但页面样式仍混用旧组件；首页强制深色、取色闪回默认色、详情取色未接通，且移动菜单仍从底部弹出。将 2026-10-23 最新原型及用户复审要求落实为应用行为，先统一视觉，再以真实数据完成各页还原。

## What Changes

- 统一浅色、深色、跟随系统下的背景、文字、线性图标、紧凑标题及无投影导航；服务器身份使用真实协议 Logo。
- 普通选择弹窗居中、菜单靠近触发点、播放参数在侧面悬浮，保留嵌套返回和 TV 焦点。
- 首页海报、整页渐变和导航共享连续色彩过渡；实际显示图片驱动取色，手机推荐进入详情，无左右箭头。
- 完成电影与剧集详情：清晰主视觉、整页媒体色、独立主播放、来源版本、选集、演员和底部媒体文件信息。
- 对齐媒体库的搜索、类型与筛选工具行、设置分类、一起看卡片以及播放器参数布局。
- 为异步色彩、明暗外观、浮层焦点和关键页面提供自动化回归；记录截图与未完成的硬件验收。

## Capabilities

### New Capabilities

主规格目前为空；以下补充视觉契约，与在途 `plan-plezy-fusion-redesign` 的业务能力配合，后续归档须保留两者要求。

- `interface-appearance`: 三种外观、视觉层级、线性图标、导航与服务器标识。
- `floating-panels`: 锚点菜单、居中弹窗和播放侧面板及焦点返回。
- `artwork-theme`: 实际海报身份驱动的连续颜色和首页呈现。
- `media-detail-presentation`: 电影和剧集详情结构及版本关联技术信息。
- `library-presentation`: 能力感知的紧凑筛选与来源海报墙。
- `settings-presentation`: 分组首页、身份摘要、字幕入口与 TV 分类。
- `watch-room-presentation`: 创建加入、真实房间与成员的紧凑显示。
- `player-controls-presentation`: 中性 HUD、轨道摘要和参数侧面板。

### Modified Capabilities

无已归档主规格；本 change 不修改另一在途 change 的完成勾选。

## Impact

修改 `lib/theme/`、`lib/navigation/`、共享图标/菜单/OverlaySheet、首页和海报组件、详情、媒体库、设置、一起看及播放器控件。沿用 Provider、slang、TV focus 和现有服务器接口，无新增播放或网络依赖；不实现云盘、刮削、投屏协议或 VLC。保留工作区已有修改；不提交或归档未验收的工作。
