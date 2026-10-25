# Design

## Context

动机见 proposal.md；基线为最新 `design/prototype/ui.css`、`appearance.css` 和各页 HTML，详见 `docs/prototype-visual-audit-2026-10-23.md`。当前 ThemeProvider 已有明暗和系统监听；HomeThemeController 会先回默认色，Discover 强制暗色且直接赋背景；FusionNavigation 独立动画并写死白色。详情只有背景组件而未传采样图；OverlaySheet 的动画和圆角仍按贴底设计。现有业务在另一在途 change 中实现，本 change 只增加其视觉约束，不改它的完成记录。

## Goals / Non-Goals

**Goals:** 将最新原型转为可复用样式与实际页面；真实数据、异步请求隔离、安全区、大字体和 TV 焦点持续可用。

**Non-Goals:** 不替换状态框架、播放核心、服务器协议；不新增跨服媒体实体合并、投屏协议、云盘、刮削或 VLC；不将原型截图和模拟数据打包为正式媒体。

## Decisions

### 1. 集中基础视觉

继续 monoTheme/MonoTokens，增加 `lib/theme/mono_presentation.dart` 保存标题、导航和色板映射等共享标准。深色普通底为黑，浅色为 #f2f2f7；内容前景和表面与原型对齐。导航无 shadow，普通字号高56、最大宽360，选中填充与描边独立；大字体允许增高。图标默认线性中等笔画，少数语义图标保留显式 fill。避免给每个页面再加局部颜色常量。

### 2. 统一显示色而非多个独立动画

HomeThemeController 保存原始采样色，HomeThemeScope 接收外观并由单一 TweenAnimationBuilder 计算连续显示色，提供原始目标与当前显示值。消费者不再各自开启颜色动画；新目标从当前值继续，减少动态效果直接到终值。取色失败在首次或明确缺图时进入兜底，换图等待不清空。背景组件向外报告实际已就绪图片路径/Provider，保证同片轮换和失败回退也能驱动采样，沿用请求代次保护。

采样保留有效像素明度、压缩高饱和色，再按外观映射：暗色混入稳定中性底，浅色混入浅底；这属于项目自主实现，不声称 VidHub 方法体。首页推荐进入详情；继续观看保持既有用户策略；来源菜单区分服务器选择和用户身份管理。

### 3. 扩展已有浮层生命周期

保留 OverlaySheetController 的页栈、openSheetCount、Android返回、焦点恢复和输入滚动。添加悬浮居中/播放侧面板呈现，四角16、距边至少12，有限位移与淡入；输入键盘时约束可用高度。手机菜单直接复用已有锚点 showAppMenu。无 OverlaySheetHost 的 fallback 用普通对话框呈现，避免回落底部面板。复杂全屏业务页面仍使用已有路由。

### 4. 页面数据不重建

详情抽出信息与版本展示组件，复用现有选集分页、ClearLogo、播放/下载、技术信息查询和版本偏好；显示信息与播放目标绑定并保护异步代次。主播放独立一行，次操作和来源版本在下方；手机清晰海报渐变与整页共享调色。电影不出现选集，长剧增加分组定位但不能只对已加载页伪装全量集数。

媒体库聚合查询和能力提示保留，把手机详细条件收进居中弹窗；TV仍侧栏。设置复用已有参数页面，新增分类摘要、真实服务器身份和字幕快捷入口。一起看保留真实房间标识与匹配/重连状态。播放器继续用现有热力画布、Logo和轨道状态，仅调整位置和参数入口。

### 5. 并行所有权

主代理独占 theme、navigation、首页、CyclingMediaBackdrop、共享翻译源与生成、OpenSpec记录。详情代理独占 media_detail_screen、media_detail/ 和新增详情组件；目录代理独占 libraries/、settings/ 与 settings_section；浮层代理独占 overlay_sheet、app_menu、播放器表现文件与 watch_together/screens。各代理只写自己的测试，不改其他人的文件或使用git回退；需要公共接口时先通知主代理。Flutter codegen、全量检查统一串行，避免锁和生成物冲突。

## Risks / Trade-offs

- [工作区已有大量未提交修改] → 以启动时文件为基线增量编辑，不 reset、不覆盖、不自动提交。
- [公共图标与浮层影响旧页面] → 回归菜单焦点、嵌套返回、键盘、安全区及大字体；显式 fill 的业务含义保留。
- [不同服务器字段缺失] → 信息卡用真实字段和空态，不模拟版本、片长或文件信息。
- [截图与真实硬件差异] → fixture 只证明布局；Android arm64/TV实机和GPU性能单独验收，不用单测替代。

## Migration Plan

按基础主题→首页→详情→目录设置→一起看播放器合并；共享设置键不删除，OLED旧偏好继续兼容。视觉改造按文件批次可回退，新增UI无需数据库迁移。跑生成新鲜度、analyzer、相关测试与完整CI，记录既有失败；仅完成对应验收后勾选。未完成硬件验收不归档。
