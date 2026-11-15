# Velo UI V1 开发修改计划（按定稿原型修改实机）

编制日期：2026-11-15。本文只是计划汇总，不含任何代码改动，也不涉及提交。信息来源为五份分组对比计划（A 全局与首页、B 详情、C 搜索/媒体库与一起看、D 设置、E 播放器）和 TV 入口对照笔记，全部整合，未新增事实。凡是整理者自己补充的说明，都标注了“（整理者）”。

---

## 1. 概述

### 1.1 目的

按定稿原型 V1（`design/prototype/`，规范 `final-ui-spec.md`）修改实机 Flutter 客户端，使首页、详情、搜索/媒体库、一起看、设置和播放器（手机与 TV）与原型一致。同时保证：

- 不改服务协议和已有功能（规范 §6 要求“保留既有筛选行为，不改服务器查询语义”“不改已有服务协议或功能”）。
- Velo 衍生自 Plezy（GPL-3.0），上游署名必须保留（见 P0-1 与第 4 章）。

### 1.2 基准版本

| 项 | 值 |
|---|---|
| 原型基准 | `design/prototype/`（含 `final-ui-spec.md`、`home.html`、`ui.css`、`final-ui.css` 等），定稿提交 `acf7d1b`，分支 `claude/practical-ptolemy-q17g45` |
| 实机代码基线 | main@77ec375 + 912e8ab（播放器面板已改为右侧贴边全高抽屉） |
| 各分组计划自称的行号基线 | B：HEAD 8b315ac；E：HEAD acf7d1b；A、C、D 未写，其中 C 注明“实施前按符号重新确认”，D 注明“行号为近似定位” |
| 路径前缀约定 | A、C 的实机路径省略前缀 `lib/`；D 省略 `lib/screens/settings/`；E 用 `vc/` 代指 `lib/widgets/video_controls/`；B 多数为 `lib/` 下相对路径。**本文原样保留各分组写法**，开工前须按符号重新定位 |

⚠冲突（行号基线不一致）：B 写的是 HEAD 8b315ac，E 写的是 HEAD acf7d1b，而实机基线是 main@77ec375+912e8ab。因此文中所有“文件:行号”都可能漂移，每个任务包开工前须按符号重新确认。

### 1.3 统计总表

状态口径沿用各分组原文。“引用行”指只指向其他条目的行（A 的 HOME-03a、HOME-03d）。C 另有 5 个“原型有、规范未编号”的 U- 项，不计入下表，见附录。

| 模块 | 来源 | 条目数 | 一致 | 部分 | 缺失 | 引用行 | 备注 |
|---|---|---|---|---|---|---|---|
| 全局与共享 SHARED | A | 14 | 8 | 5 | 1 | 0 | 部分：01b、01d、NAV、CARD、STATE；缺失：03 |
| 首页 HOME | A | 16 | 9 | 3 | 2 | 2 | 部分：01a、01b、02a；缺失：01f、02b |
| 详情 DETAIL | B | 28 | 8 | 13 | 7 | 0 | 缺失：01c、02a、02d、04a、04b、04g、X1 |
| 搜索/媒体库 LIB-01 | C | 13 | 7 | 4 | 2 | 0 | 缺失：d、g |
| 一起看 TOGETHER-01 | C | 14 | 6 | 6 | 2 | 0 | 缺失：g、i |
| 设置 SETTINGS/U/X | D | 32 | 8 | 19 | 5 | 0 | 部分含 X-03~X-06 四个“多余入口”决策项；缺失：S02-a/b/c、S03-a、U-13 |
| 播放器 PLAYER | E | 31 | 11 | 17 | 3 | 0 | 缺失：P01-6、P01-7、P05-6 |
| **合计** | | **148** | **57** | **67** | **22** | **2** | 另有 C 的 U- 项 5 条、TV 对照笔记 1 份 |

各模块条数和各状态数已逐项复核，与各分组文件自带统计一致。A 的 SHARED-02 原文写“大体一致”，这里记为“一致”，与 A 自己的合计 17 吻合。

最大差距摘要（取自各分组）：

- A：toast 仍在底部；首页评分来源说明缺失；首页行级失败保旧加重试缺失。
- B：剧集横排仍是“每组 10 集互斥分页”；评分条仍是“数值+来源文字”两行；评分来源说明 dialog 缺失；收藏和已看无 pending 态；标题字号与内容宽度偏大。
- C：库页无结果计数；加入房间的服务器端错误不在表单内；“成员准备”缺失（含协议层）。
- D：关于页无 Plezy 上游署名和 GPL 声明（合规，最高优先）；无“网络与缓存”和线路管理；多处指向上游的入口（Donate、更新检查等）。
- E：手机选集与队列未合并，倍速、字幕、选集仍是小浮层；音轨和字幕在手机抽屉里是下拉而非双行直列；TV 右组入口缺倍速、选集，章节和队列藏在不可发现的“↓内容条”里（用户反馈“找不到播放清单”的根因）；TV 顶栏方向键不可达。

---

## 2. 需要用户拍板的决策清单

> **用户决定（2026-11-15）**：
> - Q01：选（a），按规范改为中性色，保留 OLED 纯黑档。
> - Q02：选方案 A，底栏第二项保留“媒体库”，搜索保持独立入口；“…”更多按钮按推荐保留现状。
> - Q03：选（a），全局改为统一的新提示条；**提示条视觉需重新设计**，先在原型中出设计稿，用户确认后再实施 P1-2。
> - 其余 Q04–Q33：全部按各条“推荐”执行。
> - TV 播放器（Q33 相关）：已确认 TV 不提供投屏，保留快退/快进与上/下一章按钮，选集与队列合并为一个入口（原型提交 acf7d1b）。

编号 Q01…Q33，已跨模块去重合并。“推荐”是各分组计划给出的建议，没有推荐时会写明。“影响任务包”指第 3 章的包编号。

### 2.1 全局与共享

**Q01 深色底色与 OLED 档**（来源：A 的 SHARED-01a、SHARED-01b）

- 问题：原型深色 bg 为 #121212、surface #202020、text #f3f3ef、caption #adada8；浅色为 #f4f3ef、#fdfcf9、#242424、#686864。实机深色 bg 是纯黑 #000000，整套为偏紫的色调。是否接受深色底从 #000 改为 #121212？实机已有 OLED 档（`settings_service.dart:50` 枚举 system/light/dark/oled，TV 默认 OLED，`settings_service.dart:922`），而规范写“不新增 OLED 模式”，是否保留？
- 选项：（a）按规范改色，保留 OLED 档（纯黑，主要用于 TV）；（b）按规范改色，砍掉 OLED；（c）保持现状。
- 推荐：（a）。OLED 是已有功能，不是新增；其余页面（详情、设置、库）都依赖这一步。
- 影响：P1-1，以及所有页面的视觉回归（P9-2）。

**Q02 底栏第二项“搜索 / 媒体库”与“…”更多按钮**（来源：A 的 SHARED-NAV 与 HOME-03a、C 的 §0 与决策点 1）

- 问题：原型底栏为 首页 / 搜索 / 一起看 / 设置（`ui.js` entries）。实机为 首页 / 媒体库 / 一起看 / 设置 加一个“…”更多按钮（`navigation/navigation_tabs.dart:11-17`），搜索是独立 tab（`NavigationTabId.search`，`:127`），手机从首页顶栏放大镜进入（`screens/discover_screen.dart:1010-1014`）。
- 选项（A、C 两份的描述合并）：
  - 方案 A：保持实机信息架构，底栏第二项仍为“媒体库”，只对齐视觉和筛选行，搜索保持独立入口；是否保留“…”一并确认。
  - 方案 B：按原型把“搜索”提为第 2 项。A 的写法是库放入“…”或库页另有入口，牵动 `main_screen.dart` 的 tab 顺序、`primaryNavigationIds`、TV 侧栏、`fusion_navigation_test.dart`；C 的写法是新增跨库“全部媒体”浏览视图（L，需合并多服务器分页，改变查询语义，与规范冲突）。
  - 方案 C：仅把底栏文案改成“搜索”。C 明确不推荐，进入后其实是库浏览，会误导。
- 推荐：方案 A（A、C 两份都推荐）。理由是规范 §6 要求不改查询语义，改名或合并会触及导航持久化（startup 偏好使用稳定的 NavigationTabId，`settings_service.dart:1643`）和 i18n；工作量最小。
- 影响：P1-3、P4-1、P4-3（条件包），所有带底栏的验收截图。

**Q03 toast 位置与播放器内处理**（来源：A 的 SHARED-03、D 的 S01-c、C 的 TG-01.k、B 的 DETAIL-X1）

- 问题：规范要求“顶部轻通知”，实机 `SnackBarBehavior.floating` 在底部（`mono_theme.dart:255-263`，`utils/snackbar_helper.dart:81`），且连续触发会排队而不是替换。是否全局迁到顶部？播放器内的 toast（`video_controls` 里有自己的 `showAppSnackBar` 调用）如何避开顶栏？
- 选项：（a）全局迁到顶部，用新建 `AppToast`（Overlay 方案），`snackbar_helper.dart` 五个公共函数签名不变，69 个调用点零改动；（b）仅迁非播放器页面，播放器内保持现状（整理者补充的选项，来源文件未列出）。
- 推荐：（a）。设置、一起看、详情都只需调用统一 helper，不要各自另造。播放器内的位置在 P1-2 里单独验证；A 已指出有“播放器 HUD 顶栏遮挡”风险。
- 影响：P1-2，以及 P3-1、P5-3、P8-5、P7-2。

### 2.2 首页

**Q04 首页片名字号**（来源：A 的 HOME-01b）

- 问题：规范文字写标题 42（窄屏 37），原型 CSS 实际为 45，代码也是 45（`theme/home_typography.dart:36-40`，手机 45/平板 48/TV 48），规范自相矛盾。
- 选项：（a）按规范：手机 42，宽度小于 360 时 37；（b）按原型 CSS 和现状 45。
- 推荐：来源未给倾向，需先向设计确认。若按规范，需同时改 `home_typography.dart` 与 `fusion_home_hero.dart`。
- 影响：P2-2。

**Q05 首页自动轮播是否保留**（来源：A 的 HOME-01d 与待确认问题 4）

- 问题：代码有自动轮播（`_resetAutoScrollTimer`），原型“无自动切换”。
- 选项：（a）保留；（b）去掉。
- 推荐：（a）保留，已有设置和无障碍暂停动作，在规范里备注即可。
- 影响：无代码改动；不影响任务包。

### 2.3 详情

**Q06 详情标题缩小与内容宽度**（来源：B 的 DETAIL-03a、DETAIL-X9，待确认 e）

- 问题：原型标题 36（窄屏 32）、内容宽 560；实机手机/平板 40、桌面 48、TV 64×scale（`presentation.dart:155-190`），`maxWidth` 720（`responsive_layout.dart:106`）。缩小是视觉降级，是否接受以原型为准？TV 是否按设计缩放到 36×scale？
- 选项：（a）按原型；（b）保持现状。
- 推荐：来源未给倾向，B 提示“需产品确认以原型为准”。
- 影响：P3-5。

**Q07 详情页是否保留音轨/字幕预选字段**（来源：B 的 DETAIL-X3、X4，待确认 a）

- 问题：原型详情页只有一行版本摘要，没有音轨/字幕字段；实机有三个并排选择器（版本/音轨/字幕，`playback_selectors.dart:18-211`）。
- 选项：（a）保留三选择器，只按原型样式微调版本字段；（b）改成原型只有一行摘要。
- 推荐：（a），“预选”是真实功能。
- 影响：P3-6。

**Q08 桌面/宽屏剧集列表与“全部选集”形态**（来源：B 的 DETAIL-04f、04g，待确认 b）

- 问题：桌面/宽屏使用纵向 `EpisodeCard` 全列表（`media_detail_screen.dart:2697-2770`），是否也改成横排加自动分组？“查看全部”原型是底部 sheet 的集数网格，实机是纵向详情卡列表，是否改成网格？
- 选项：（a）保留实机形态（纵向列表），仅手机/平板做横排分组，点选后回横排改为滚动到该集；（b）桌面也改横排；（c）“全部选集”改成原型网格。
- 推荐：B 倾向（a）：数据一致，形态保留实机纵向列表（信息更多）。
- 影响：P3-4、P3-8。

**Q09 个人评分 chip 是否算“第二条评分”**（来源：B 的 DETAIL-01a，待确认 c）

- 问题：个人评分 chip（`presentation.dart:~213`、`action_buttons.dart:~497`）出现在 actions 内/上，原型无此项，而原型要求评分全页仅一处。
- 选项：（a）保留，不算评分条；（b）并入“更多”菜单。
- 推荐：（a），属真实功能（Plex/Jellyfin 评分/收藏入口）。
- 影响：P3-2（验收口径）。

**Q10 TV 详情是否必须做剧集分组条**（来源：B 的 DETAIL-04g，待确认 d）

- 问题：TV 目前每季一个 `MediaHub`（`media_detail_screen.dart:4021-4060`），没有分组条；原型 TV 是单行横排加分组。
- 选项：（a）本轮不做，另立后续包；（b）做（L，风险高：D-pad 焦点系统复杂，已有大量 TV 测试）。
- 推荐：B 建议 TV 另立后续包，先和产品确认是否必须。
- 影响：P3-8。

### 2.4 搜索 / 媒体库

**Q11 TV 库页形态**（来源：C 的 LIB-01.k、决策点 4）

- 问题：实机 TV 是左侧 220 宽筛选侧栏加右侧网格（`library_browse_tab.dart:1828-1836`），原型是顶部标题右侧搜索框加标签行。
- 选项：（a）保持侧栏，仅调整视觉（紫色 focus/选中）；（b）改成原型顶部标签行（M，易回归）。
- 推荐：（a）。
- 影响：P4-2（可选包，默认不做）。

**Q12 原型缺“搜索结果页/人物结果”设计**（来源：C 的 U-LIB-3、决策点 5）

- 问题：原型的“搜索”页没有命中列表、人物结果、类型 chip，规范也没有编号；实机 `search_screen.dart` 有。
- 选项：（a）要求设计补稿；（b）沿用现有视觉，仅接 SHARED token。
- 推荐：来源只给出“建议向设计方补原型”，未强制；默认走（b），不改逻辑。
- 影响：P1-1（视觉 token 一并生效）；无专门任务包。

### 2.5 一起看

**Q13 “成员准备”实现方式（含设置页“显示名称/准备/提醒”）**（来源：C 的 TG-01.g、决策点 2；D 的 U-12）

- 问题：原型有成员“已准备/未准备”和“开始一起看”仅在全员就绪时可用；全仓库没有 ready 概念。D 的 U-12 指出设置页原型还有“显示名称/加入后需准备/成员提醒”，实机缺。
- 选项：（a）UI 派生就绪：已连接且未 buffering 且本地已匹配到媒体，只展示状态文字，无手动按钮（M，无协议改动）；（b）真准备开关：在 relay 协议、`SyncMessage`、`PeerService` 增加 ready 消息（L，需评估与自建中继兼容）。
- 推荐：（a）。设置页的 U-12 三项在本轮不新增，除非确认 watch_together 已有对应偏好。
- 影响：P5-3；P8-1（U-12 文案/说明）。

**Q14 创建房间“选择影片”与大厅“开始一起看”按钮**（来源：C 的 TG-01.c、TG-01.i、决策点 3）

- 问题：原型创建 dialog 含房间名和选择影片，大厅有“开始一起看”；实机流程是进房后在播放器/媒体详情选片，播放后同步给成员，没有该按钮。
- 选项：（a）不改流程，创建 dialog 只增加可选“房间名称”，文案加“你将成为房主，控制播放”，不做选片和开始按钮；（b）在大厅房主区加“选择影片”引导到媒体库（S，纯导航）；（c）改流程（涉及产品语义，不改协议的前提下 C 未推荐）。
- 推荐：（a）。
- 影响：P5-2、P5-3。

**Q15 房间卡是否增加本地 `lastMediaTitle` 字段**（来源：C 的 TG-01.b、决策点 6）

- 问题：原型房间卡显示影片名、成员数、头像；实机的 `RecentRoom{code,name,lastUsed,controlMode}`（`services/recent_rooms_service.dart:17-23`）没有这些。规范 §8 禁止虚构数据。
- 选项：（a）只做视觉对齐（r16、tag 样式），不显示影片；（b）新增本地字段 `lastMediaTitle`（进房时写入，需 `.g.dart` 重生成和旧数据迁移，M）。
- 推荐：（a），（b）作为可选。
- 影响：P5-3。

**Q16 播放器内“一起看”入口**（来源：E 的 D8、P04-3；tv-gap-notes）

- 问题：实机仅在会话中显示人数指示器（`video_controls_header.dart:77-91`），无会话时播放器内无发起/加入入口；原型 TV 顶栏恒有“一起看”chip，TV 对照笔记也把“一起看”列为缺直达入口（`video_settings_sheet.dart:1273`）。
- 选项：（a）仅会话中显示（现状）；（b）无会话时显示“一起看”chip，打开发起/加入抽屉（复用 `watch_together_screen`、`join_session_dialog` 内容，M）。
- 推荐：来源未给倾向；E 注明一起看后端行为不在本轮。
- 影响：P7-2（含 P04-3）。

### 2.6 设置

**Q17 设置行是否也改为 58 高 / r14**（来源：D 的 S01-b、决策项）

- 问题：规范字段是 r14、高 58；设置行实机 `rowHeight` 48、`groupRadius` 15（`theme/settings_presentation.dart:10-13`）。规范指的是字段，行高是否也要改需确认。
- 选项：（a）仅核对输入框 r14；（b）改 `SettingsPresentation.rowHeight/groupRadius` 并同步 `setting_tile.dart`，所有设置页 golden 需重生成。
- 推荐：来源未给倾向。
- 影响：P8-5、P1-1 的 golden 范围。

**Q18 线路管理做到什么程度**（来源：D 的 S02-a/b/c、决策项）

- 问题：原型有“设置 → 网络与缓存 → 服务器线路”，规范明确“生产网络映射待实施核对”，“自动最快”仅是资源线索，本轮未实现探测。实机无线路入口，需确认连接模型（`lib/models` 与 database 表的 endpoint/备用地址）是否支持多线路。
- 选项：（a）仅做本地偏好演示（含校验、持久化到 SettingsService pref，“自动最快”仅显示“规划中/不可选”）；（b）接入真实多线路模型。
- 推荐：D 要求先确认模型再决定；不做测速。
- 影响：P8-3、P8-2。

**Q19 原型有而实机无的设置项是否新增**（来源：D 的 U-08、U-09 与决策项）

- 问题：离线模式（`offlineMode` 仅在 `main_screen`、`video_player` 内使用，设置里没有）、“文字大小”、“启动页面”。
- 选项：（a）都不新增，仅核对文案；（b）新增。
- 推荐：D 的原则是“不凭原型新增生产能力”，倾向（a）。
- 影响：P8-1。

**Q20 上游残留入口：Donate / 更新检查 / 崩溃上报**（来源：D 的 X-04、X-05、X-06）

- 问题：
  - Donate（`settings_screen.dart:~541`，受 `DonationService.isEnabled` 控制，`services/donation_service.dart:10`）指向上游捐赠。
  - `services/update_service.dart:19、:25` 仍指向 edde746/plezy 与其 appcast，会提示上游版本。
  - 崩溃上报（Sentry，`settings_screen.dart:~831`）需核对是否仍指向上游 DSN；“测试 Sentry/ANR”（`:~881`）。
- 选项：Donate：确认 `isEnabled` 对 Velo 构建为 false，否则隐藏。更新检查：改指向 winesOr/velo（README 中的本仓库地址）或隐藏，D 注明发布渠道未定。Sentry：核对 DSN；测试项仅 debug 构建显示。
- 推荐：D 的建议即上述各项；这些是合规/品牌/隐私项，应优先处理。
- 影响：P0-2。

**Q21 保留类功能与分类位置**（来源：D 的 X-03、X-05、U-11、U-01）

- 问题：是否保留“管理媒体库”（`settings_screen.dart:~585`，隐藏/排序库）、Discord Rich Presence、备份导入导出；general/controls/advanced 分类并入“关于”还是“连接与集成”。
- 选项：保留（功能性，非云盘刮削），分类位置待定。
- 推荐：D 建议保留管理媒体库；其余未给倾向。
- 影响：P8-1。

**Q22 原型演示性“能力”是否真做**（来源：D 的 S03-c、S03-d、U-05）

- 问题：播放缓冲“写入磁盘/容量/时长”（实机只有 `playbackBufferTier` 三档，`playback_settings_screen.dart:667`）；硬解/音频硬解/DV/去隔行“跟随核心”三态（实机为布尔开关）；弹幕“速度”“同屏上限”（实机未发现）。
- 选项：（a）不新增能力，仅在文案上保持“未设置/有效状态由实际核心确认”语义，弹幕补预览；（b）真做（缓冲为 L，改三态需迁移 pref，风险高；与其他模块 PERF-05/07/09 关联）。
- 推荐：（a）。D 明确不建议改 tri-state。
- 影响：P8-2、P8-4。

**Q23 字幕设置页补语言入口的语义**（来源：D 的 U-06）

- 问题：实机字幕页只有样式（`subtitle_styling_screen.dart`），语言偏好在 `account_preferences_detail_screen.dart`，延迟/次字幕在播放器内。账户级与全局偏好语义不同，需确认能否在字幕页顶部加“语言”分组跳转。
- 选项：（a）只加跳转，不新增能力；（b）不动。
- 推荐：（a）。
- 影响：P8-4。

### 2.7 播放器（E 的 D1~D10 与 tv-gap-notes）

**Q24 TV 控件隐藏时 ←→**（来源：E 的 D1、P05-10）

- 问题：原型“隐藏时任意方向键/Enter 唤出并聚焦播放/暂停”；实机隐藏时 ←→ 是原地快退快进，只有 ↑↓/Enter 唤出（`parts/key_events.dart:309-327`）。
- 选项：（a）保留现状，验收文案改为“↑↓/Enter 唤出，←→ 原地快进快退”；（b）按原型，隐藏时 ←→ 只唤出（M）。
- 推荐：（a），改掉会退化既有 TV 习惯。
- 影响：P7-2。

**Q25 TV 新右组（图标+标签、四标签抽屉）是否同步用于桌面**（来源：E 的 D2）

- 选项：（a）仅 TV，桌面保持现有按钮条；（b）桌面同步。
- 推荐：（a）。
- 影响：P7-1。

**Q26 进度条章节细刻度**（来源：E 的 D3、P01-4）

- 问题：实机在连续轨道上画章节黑色细刻度（可由设置 `showChapterMarkersOnTimeline` 关闭），原型 `chapters: []` 无刻度。
- 选项：（a）保留；（b）默认值改 false 或删除绘制。
- 推荐：来源未给倾向，提示用户可能依赖章节刻度。
- 影响：P6-5。

**Q27 画面比例 3 档还是 5 档**（来源：E 的 D4、P01-3）

- 问题：原型 5 档（默认/拉伸/填充/16:9/4:3），实机 3 档循环；新增 16:9/4:3 要改 mpv/Exo 内核层，原型声明“未改变 mpv/Exo”。
- 选项：（a）保持 3 档，验收标注“原型 5 档为演示”；（b）做 5 档（L，`TrackControlsState.onCycleBoxFitMode` 改为 setter）。
- 推荐：（a）。
- 影响：P6-5、P7-1（TV 画面比例按钮并入设置标签）。

**Q28 “加载本地字幕”**（来源：E 的 D5、P04-1）

- 问题：原型声明“真实文件访问不在本轮实现”；实机字幕无本地载入（弹幕有）；TV 无文件选择器。
- 选项：（a）仅保留入口位置与禁用态；（b）真实现（`FilePickerService.pickFiles` 加外挂字幕 API，需核实 `Player` 是否有 `addExternalSubtitle`）。
- 推荐：（a）；若做，TV 隐藏该项。
- 影响：P6-5。

**Q29 手机无队列但有章节的电影，章节入口放哪**（来源：E 的 D6、P01-7）

- 问题：手机现状是有章节时“选集”chip 变章节列表；合并选集与队列后，章节需要独立入口。
- 选项：并入顶栏“…”，或在字幕 chip 旁加独立“章节”入口。
- 推荐：E 的建议是二者之一，未定。
- 影响：P6-3、P6-4。

**Q30 次字幕不支持时的提示**（来源：E 的 D7、P03-3）

- 选项：（a）保持隐藏（现状）；（b）显示一行灰字说明（新 i18n）。
- 推荐：低优先，来源未给倾向。
- 影响：P6-2。

**Q31 弹幕删除确认等居中 `AppAlertDialog` 是否改成抽屉内二级页**（来源：E 的 D9、P04-5）

- 问题：`danmaku_sources_sheet.dart:109` 的删除确认是居中 dialog（不是底部），是否算“辅助弹窗不从底部滑出”的例外。
- 选项：（a）保持居中确认框；（b）改成抽屉内二级页。
- 推荐：低优先，来源未给倾向；默认（a），验收时逐入口录屏确认。
- 影响：P6-5（验收）。

**Q32 抽屉宽度（手机 340、平板 400、TV 约 30%）**（来源：E 的 D10、P01-1、P05-7；tv-gap-notes）

- 问题：原型手机抽屉 340（窄屏不超过画面 85%）。实机手机 318、平板 400（`player_settings_drawer.dart:30`），其余入口各写 350/360（`track_chapter_controls.dart:176/214/240/272/346`、`casting.dart:23`、`watch_together_overlay.dart:50`、`mobile_chips.dart:121`）。TV 对照笔记写“抽屉宽 580@1080p”待定。
- 选项：（a）手机统一 340（≤85%），平板并入 340；（b）平板保留 400。TV：`max(340, 0.3×屏宽)`（E 的 P05-7），1080p 下约 576，与 580 接近。
- 推荐：E 的方案是新增 `OverlayTokens.drawerWidth=340`、`drawerMotion=240ms`，仅 edgeDrawer 使用；平板是否保留 400 需拍板。
- 影响：P6-1、P7-1。

**Q33 TV 对照笔记中的待定项**（来源：tv-gap-notes、E 的 P05-3/P05-5/P05-6/P05-10）

- 问题：
  - TV 是否保留投屏（笔记把投屏列为缺直达入口，`mobile_chips.dart:111` 仅移动端）。
  - 是否保留 ↓ 内容条，以及快退/快进/上下章按钮。
  - 自动隐藏 10s。
- 选项与来源事实：E 的 P05-5 与 P04-2 认为原型 TV 不提供投屏，P05-3 七个传输按钮一致，P05-6 要求下线内容条。原型提交 acf7d1b 的提交说明也写明“TV 播放器保留快退快进与上下章、去掉投屏、合并选集与队列”。
- 推荐：按原型（TV 无投屏；保留快退快进与上下章；内容条下线并合并到“选集/播放列表”）。10 秒自动隐藏见 P05-10，E 未给出实机现值，需开工前核实（⚠待核实）。
- 影响：P7-1、P7-2。

---

## 3. 开发阶段与任务包

### 3.1 阶段与依赖总览

| 阶段 | 内容 | 任务包 | 说明 |
|---|---|---|---|
| P0 | 合规与清理 | P0-1、P0-2 | 与其他阶段无代码依赖，可最先、可并行 |
| P1 | 基础 token 与共享组件 | P1-1 ~ P1-5 | P1-1 必须第一个合并；之后 P1-2/P1-4/P1-5 可并行，P1-3 等 Q02 |
| P2 | 首页 | P2-1、P2-2 | 依赖 P1-1 |
| P3 | 详情 | P3-1 ~ P3-8 | P3-1/P3-2/P3-4 互不依赖可并行；P3-3 依赖 P3-2 与 P1-5 |
| P4 | 搜索/媒体库 | P4-1 ~ P4-3 | P4-2 可选，P4-3 条件包 |
| P5 | 一起看 | P5-1 ~ P5-3 | P5-1、P5-2 互相独立；P5-3 依赖 P1-2 |
| P6 | 播放器手机 | P6-1 ~ P6-5 | P6-1、P6-2、P6-5 可并行；P6-3 依赖 P6-1；P6-4 依赖 P6-3 |
| P7 | 播放器 TV | P7-1、P7-2 | 依赖 P6-1、P6-2、P6-4；P7-2 依赖 P7-1 |
| P8 | 设置 | P8-1 ~ P8-5 | P8-5 依赖 P1-1/P1-2；P8-3 为条件包 |
| P9 | 回归与审计 | P9-1、P9-2 | 最后统一做 |

共 37 个任务包，每包一个提交。其中 P4-2 为可选（默认不做），P4-3 为条件包（仅 Q02 选 B 时才立项），P3-8 为可选（先确认 Q10），P8-3 为条件包（先确认 Q18）。

建议执行顺序（波次）：

1. **第 0 波**：P0-1、P0-2（合规，随时可并行，最先合并）。
2. **第 1 波**：P1-1（所有视觉依赖）。
3. **第 2 波（可并行）**：P1-2、P1-4、P1-5；P3-1（需 P1-2，可稍后）、P3-2、P3-4；P5-1、P5-2；P6-1、P6-2、P6-5；P8-1、P8-2。
4. **第 3 波**：P1-3（Q02 定后）、P2-1、P2-2、P3-3、P3-5、P3-6、P3-7、P4-1、P5-3、P6-3、P8-4、P8-5。
5. **第 4 波**：P6-4、P7-1、P7-2、P8-3（若立项）、P3-8/P4-2/P4-3（若立项）。
6. **第 5 波**：P9-1、P9-2。

A 文件原建议顺序为 A1 → A2/A4 → A3 → B1 → B2 → B3 → B4；B 文件为 B1 → B2 → B3 → B4 →（确认后）B6/B7/B5/B8；C 文件为 C1 → C2 → C3 → C4 → C5；E 文件为 A、B、F 并行 → C → D → E。以上顺序与这些建议一致，仅按跨模块依赖重排。

每个包的验收中，TV 项目给出方向键路径；没有给出方向键路径的 TV 项，来源文件也没有，均需在实机或模拟 TV 上手验。路径缩写沿用各来源写法（见 1.2）。

---

### P0 合规与清理

#### P0-1 关于页署名与 GPL 声明

| 项 | 内容 |
|---|---|
| 来源条目 | D：U-13；D 任务包 D1 |
| 改动范围 | `lib/screens/settings/about_screen.dart:34-47`（图标+名称+版本+描述）、`:57-66`（仅“开源许可证”入口）；`i18n/zh.i18n.json:1338`（appDescription 仍为上游文案“一款精美的 Flutter Plex、Jellyfin 和 Emby 客户端”）及各语言 `about.*`；`licenses_screen.dart`（仅列依赖包）；README.md:14 的署名可作文案来源 |
| 实现要点 | 新增“Velo 基于 Plezy（edde746）衍生，遵循 GPL-3.0”分组：上游链接、本仓库链接、GPL-3.0 全文入口（LICENSE 加入 assets，或 `showLicensePage` 自定义条目）、版权行；更新 appDescription 各语言（至少 zh/en）；手工注册 Velo/Plezy 的 `LicenseRegistry` 条目；日志入口可选移入。**这是 CLAUDE.md 的硬要求，优先级最高** |
| 工作量 | S |
| 依赖 | 无 |
| 验收 | 关于页可见“基于 Plezy，GPL-3.0”、上游与本仓库链接，LICENSE 可阅读；licenses 页加载不崩。TV：方向键 ↑↓ 可到达并激活各链接/入口，Back 返回设置列表（来源未单列，整理者补） |
| 测试 | 新增 `about_screen_test`（查找文案/入口）；licenses_screen 加载不崩 |
| golden | 否 |

#### P0-2 清理多余/上游入口

| 项 | 内容 |
|---|---|
| 来源条目 | D：X-04、X-05、X-06；D 任务包 D2；决策 Q20 |
| 改动范围 | `settings_screen.dart:~541`（`_buildDonateTile`）、`services/donation_service.dart:10`；`settings_screen.dart:~831`（崩溃上报）、`:~881`（测试 Sentry/ANR）；`services/update_service.dart:19、:25`、`settings_screen.dart:~975`（`_buildUpdateSection`） |
| 实现要点 | Donate 隐藏或确认 `isEnabled=false`；Test Sentry/ANR 仅 debug 构建显示；核对崩溃上报是否仍指向上游 DSN；更新检查改指向 winesOr/velo 或隐藏。**不得误删上游署名**，只处理捐赠/更新/上报等入口 |
| 工作量 | S |
| 依赖 | Q20 |
| 验收 | release 构建设置页无 Donate、无 Test Sentry/ANR；更新检查不再提示上游版本 |
| 测试 | 在 `settings_screen_test` 中断言上述行不存在 |
| golden | 否（若设置页 golden 含这些行则需重生成，来源未说明，需核对 `test/screens/settings/goldens`） |

---

### P1 基础 token 与共享组件

#### P1-1 调色板与圆角 token

| 项 | 内容 |
|---|---|
| 来源条目 | A：SHARED-01b、01d、01e、01a；A 任务包 A1；HOME-03d；LIB-01.a |
| 改动范围 | `theme/velo_brand.dart`（新增 `VeloPalette` 中性灰深/浅+caption 常量）、`theme/mono_theme.dart:50-80`（深/浅 `c` 调色）、`theme/mono_presentation.dart:77-91`（headerSurface/headerEdge/navigationSurface/navigationForeground 里写死的紫调色）、`mono_tokens.dart`（新增 `MonoTokens.radiusCard=14`，`:277-281` 现为 radiusMd 12）、`widgets/media_card.dart:631,1121`（海报卡）、`_posterFocusRadius`（`media_card.dart:1125`）；`test/theme/mono_theme_test.dart:59-60` 断言 bg=0xFF000000 |
| 实现要点 | 先把色值收拢成 `VeloPalette`，由 `mono_theme.dart` 与 `mono_presentation.dart` 共同引用；OLED 档保持纯黑；圆角方案选“新增 `radiusCard=14` 只给海报卡/继续观看卡”（比直接改 radiusMd 更安全，radiusMd 仅 10 处引用但会连带别处）。强调色 SHARED-01e 已一致无需改。LIB-01.a 的 `_Tag` 选中底色若 `VeloBrand` 提供 selectedBg/selectedFg 则改用（`library_quick_filters.dart`） |
| 工作量 | M |
| 依赖 | Q01；**必须第一个合并**，详情、设置、库、一起看、播放器的底色都依赖它 |
| 验收 | 手机/平板/TV × 深/浅/OLED 截图与 `previews/final-v1/*.png` 对照；对比度肉眼可读；海报卡圆角 14 且 focus 边框同步。TV：沿用新色值后做截图比对，方向键焦点描边仍清晰 |
| 测试 | 更新 `test/theme/mono_theme_test.dart`（bg 断言）；新增 palette 常量测试；跑 `flutter test test/theme test/widgets` |
| golden | **是**。全局底色和卡片圆角变化，现有三组 golden 都会失效并需重生成：`test/screens/libraries/goldens`、`test/screens/settings/goldens`、`test/widgets/goldens`（含 continue_watching 系列） |

#### P1-2 顶部 AppToast

| 项 | 内容 |
|---|---|
| 来源条目 | A：SHARED-03；A 任务包 A2；D：S01-c；C：TG-01.k；B：DETAIL-X1（成功 toast） |
| 改动范围 | 新建 `widgets/app_toast.dart`；改 `utils/snackbar_helper.dart:20-156`（5 个公共函数签名不变，内部改调 AppToast，`:155 showMainSnackBar` 的 `removeCurrentSnackBar`）、`theme/mono_theme.dart:255-263`（snackBarTheme）；`profile_navigation_scope` 另有 main messenger；播放器内调用点复核（`video_controls` 里自带的 `showAppSnackBar`） |
| 实现要点 | Overlay 方案：顶部 safe-area+16 居中；`Semantics(liveRegion:true)`；`IgnorePointer`/不抢焦点；同一时刻最多 1 条（新替旧）；淡入 180ms，`disableAnimations` 归零。root 与 main 两个 messenger 路径统一为 root Overlay（保留 `rootScaffoldMessengerKey` 兼容）。所有模块的通知迁移只要不绕开 helper 就自动完成，各页不要另造 |
| 工作量 | M |
| 依赖 | P1-1（A 的顺序）；Q03 |
| 验收 | 触发成功/提示/错误/连续 5 次：只出现 1 条、在顶部、不遮顶栏操作、焦点不变；读屏能听到。TV：toast 出现时 D-pad 焦点保持不变（Overlay 无焦点，需确认不影响 D-pad）；播放器内 toast 避开顶栏 |
| 测试 | 新增 `test/widgets/app_toast_test.dart`（位置、替换旧、liveRegion、不抢焦点、disableAnimations）；迁移 14 个含 SnackBar 的测试（`find.byType(SnackBar)` → `find.byType(AppToast)`） |
| golden | 否 |

#### P1-3 悬浮导航对齐

| 项 | 内容 |
|---|---|
| 来源条目 | A：SHARED-NAV、HOME-03a；A 任务包 A3 |
| 改动范围 | `navigation/fusion_navigation.dart:56-100,112-190`、`theme/mono_presentation.dart:10`（`navigationHeight=56` 已定义但未被引用）、`:11`（maxWidth 360）；方案 B 才动 `main_screen.dart`、`navigation/navigation_tabs.dart:11-16` |
| 实现要点 | 让 `navigationHeight` 真正驱动容器（Container constraints minHeight 56，现实际 3+48+3=54）；表面色改用 SHARED-01b 的 surface 色 @88%（现 `navigationSurface` alpha .94）；圆角 30、blur 28、底距 18、按压 .90 已一致。第 2 项与“…”按 Q02 的结论处理，推荐方案 A 即只改高度/色 |
| 工作量 | S（仅高度/色）；M（方案 B） |
| 依赖 | P1-1、Q02 |
| 验收 | 手机底栏高度实测 56、圆角 30、距底 18；四入口均可达；TV 顶栏不变。TV：顶栏焦点 ←→ 在各入口间移动 |
| 测试 | 更新 `test/navigation/fusion_navigation_test.dart`、`navigation_tabs_test.dart`、`test/widgets/mobile_navigation_rail_test.dart` |
| golden | 可能：所有带底栏的 golden 需 diff（来源未明说，整理者） |

#### P1-4 海报评分角标

| 项 | 内容 |
|---|---|
| 来源条目 | A：SHARED-CARD；A 任务包 A4 |
| 改动范围 | `widgets/media_ratings_strip.dart:108-143`（`MediaCardRatingBadge`）、`widgets/media_card.dart:662-675`（使用处，位置在 `:668-671`）；需确认不与 `watched_indicator.dart`、`unwatched_count_badge.dart` 重叠 |
| 实现要点 | 固定 `Colors.black @.8` 背景加白字（保留 personal 图标用白/accent）；位置改 `PositionedDirectional(bottom:4, end:5)`（现为左下 bottom 8、start 6）；圆角见 P1-1；无分不渲染保持（`:662-669`）；继续观看卡不显示评分保持（`:664-668`） |
| 工作量 | S |
| 依赖 | P1-1 |
| 验收 | 浅/深色下角标一致；与观看角标、进度条不重叠；无分卡片无空白占位。TV：卡片获焦放大后角标位置正确 |
| 测试 | 更新/新增角标 widget 测试；`test/screens/discover_screen_test.dart:1433-1453`（用 key 定位，预计不受影响）回归 |
| golden | 可能：`test/screens/libraries/goldens/fusion_library_*`（含海报卡）；continue_watching 不显示评分，预计不变 |

#### P1-5 评分来源说明 dialog（共享组件，含首页接入）

| 项 | 内容 |
|---|---|
| 来源条目 | A：HOME-01f；A 任务包 B1；B：DETAIL-01c、03d（评分部分）；B 任务包 B3（组件部分，已与 A 合并） |
| 改动范围 | 新建 `widgets/rating_source_dialog.dart`（A 命名 `RatingSourceDialog`，B 命名 `showRatingSourceDialog(context, ratings)`，合并为同一个文件）；改 `widgets/hero_metadata_badges.dart`（`InlineRatingBadges`，评分 Row 包成可点击加 `Semantics` button）、`widgets/fusion_home_hero.dart`；i18n 新增文案（zh/en 等，运行 slang 生成） |
| 实现要点 | 用 `app_dialog.dart` 的 `AppDialog` 居中；列出当前条目各评分源（图标+名称+数值+一句说明，含来源/尺度/服务器评分/“来源未标注”）；名称用现有 `ratingSourceLabel`；hero 的整体 GestureDetector onTap=播放，需让评分区域吞掉点击；TV 上评分需可聚焦，注意 hero 焦点链。详情接入见 P3-3 |
| 工作量 | M |
| 依赖 | P1-1 |
| 验收 | 点击首页评分弹出居中 dialog，Esc/关闭回评分按钮；缺分不显示入口。TV：焦点从 hero 方向键移到评分，Enter 开 dialog，Back 关闭并回到评分 |
| 测试 | 新增 widget 测试（打开/关闭/焦点返回/缺分无入口）；`flutter test test/widgets` |
| golden | 否 |

---

### P2 首页

#### P2-1 首页行级失败保旧与局部重试

| 项 | 内容 |
|---|---|
| 来源条目 | A：HOME-02b、SHARED-STATE；A 任务包 B2 |
| 改动范围 | `providers/discover_provider.dart`（已有 `partial.succeededServerIds`，补 failed 集合；`:562-580` onProgress）、`screens/discover_screen.dart:162,1237,1363,753`；TV `widgets/tv_browse_rail.dart`；新建 `widgets/hub_row_error.dart` |
| 实现要点 | provider 增加 `failedServerIds`/`failedHubs`；screen 在已有行之后/对应位置渲染 `HubRowError`（标题+“重试”按钮，高度与骨架行一致，复用 `state_messages` 文案与 `FocusableButton`）；点击只重载该服务器；保留已显示卡片；重试期间不 requestFocus；全失败且无任何内容时仍用整页 `SliverErrorState`。同服逐库发布（PERF-02/05/06）不并入 |
| 工作量 | L |
| 依赖 | P1-1 |
| 验收 | 模拟一台服务器失败：其余行保留，失败行出现“重试”，重试只刷新该服务器且不抢焦点；全失败时仍整页错误。TV：焦点在其他行时失败行出现/重试不改变焦点；方向键 ↑↓ 可到达失败行的“重试”按钮 |
| 测试 | 新增 provider 单测（partial failure 状态）、`discover_screen` widget 测试（保旧+重试）、TV 版 `TvBrowseRail` 对应行内重试用例 |
| golden | 否 |

#### P2-2 首页细节对齐

| 项 | 内容 |
|---|---|
| 来源条目 | A：HOME-01a、01b（并补 01c 回归测试、02a 骨架行高确认、03b/03c 视觉回归）；A 任务包 B3 |
| 改动范围 | `widgets/fusion_home_hero.dart:~110-190`、`theme/home_typography.dart:36-40`；`discover_screen.dart:1391-1440`；`discover_loading_skeleton.dart`、`discover_screen.dart:1273-1277`（骨架 cardWidth 111 与真实一致，仅确认） |
| 实现要点 | hero 文案区左右 inset 20 改 24（平板 32 不变），高度保持比例方案不变；片名字号按 Q04 结论处理（FittingTitleText 已处理溢出）；`home_theme_test` 若未覆盖“快速切换不回闪”补一条 |
| 工作量 | S |
| 依赖 | P1-1；Q04 |
| 验收 | 手机 390×844 对比 `previews/final-v1/home.png`；窄屏标题不溢出。TV：首页焦点切换卡片时海报同步更新 |
| 测试 | 更新 `test/widgets/home_hero_blend_test.dart`；`flutter test test/screens/discover_screen_test.dart` |
| golden | 否（来源无 hero golden）；`test/widgets/goldens/continue_watching_*` 视觉回归时确认 |

---

### P3 详情

#### P3-1 收藏/已看加载态

| 项 | 内容 |
|---|---|
| 来源条目 | B：DETAIL-X1、X2；B 任务包 B1 |
| 改动范围 | `action_buttons.dart(:332-370,:487)`、`presentation.dart(:123)`（`_toggleDetailFavorite`）、`detail_action_icon.dart`、i18n |
| 实现要点 | 新增 `_favoritePending`/`_watchedPending`；按钮 pending 时转圈（复用 play 按钮 `:~320` 的 18px `CircularProgressIndicator`）、`Semantics(busy)`、防重入；成功 `showSuccessSnackBar`（已收藏/已取消，新 i18n 或复用 `t.rateSheet.favorited`），失败保持旧状态并报错；watchlist 备选路径（`watchlistAction`，已有 `_watchlistMutationInFlight`）一并加转圈；新增 `DetailActionIcon.busy` 变体供 X1/X2 共用；`finally` 复位。TV 焦点在转圈期间不能丢（用 `canRequestFocus` 仍可聚焦的 busy 样式，而不是 `onPressed:null`）；离线时不显示 |
| 工作量 | M（X1 M + X2 S） |
| 依赖 | P1-2（toast） |
| 验收 | 慢网络下点收藏/已看：按钮转圈且不可再点，响应后切换并 toast；失败保持原状+错误提示；离线仍走原路径。TV：转圈期间焦点不丢，完成后焦点仍在该按钮 |
| 测试 | 扩展 `test/screens/media_detail_screen_test.dart`：用 Completer 延迟 `setFavorite`/`setWatched`，断言 busy→完成；连点只发一次 |
| golden | 否 |

#### P3-2 评分条重做

| 项 | 内容 |
|---|---|
| 来源条目 | B：DETAIL-02a、02b、02c、02d、01a、01b；B 任务包 B2；决策 Q09 |
| 改动范围 | `media_ratings_strip.dart`（`:28` alignment、`:31-36` 列宽 76/格高 78、`:57-58` 空返回、`:63-100`、`:73-91`）、`media_rating_badge.dart`（`ratingsSemanticLabel`、`InlineRatingBadges`）、`rating_utils.dart:~20-40`、`rating_display_policy.dart:19`（`detailLimit=4`）、`responsive_layout.dart:161`、`presentation.dart:221-222`、i18n；TV spotlight（`tv_spotlight_background.dart`）也引用 strip |
| 实现要点 | 单元重写为 `Row(icon 18, gap 6, value 18/600 tabular)`，移除可见来源标签（`ratingSourceLabel(...) ?? t.settings.otherRatingSources`）；无品牌 asset 的来源（critic/audience/simkl/mal/anilist/trakt/空）用中性星标（`Symbols.star_rounded` 琥珀色，原型 #f5c544）；个人评分仍用 person icon；`columnsFor` 76→88，`heightFor` 去掉 78 固定高改 min 48×textScale（外部调用方同步），格内纵 5 横 12，格间 1px `VerticalDivider`（前景 α.16）；`ratingsSemanticLabel` null 分支改“来源未标注”类措辞；TV 传 `alignment: WrapAlignment.start`，首格左 padding 0；无分时 strip 后固定 `SizedBox(18)` 需核对（可把 18 拆到 strip 内 padding）。风险：strip 注释写“reserved region”为防抖保留固定高度，改动后需验证 loading→有分时 hero 不跳动（hero 底对齐 `Align.bottom`，可能上移，需截图确认） |
| 工作量 | M |
| 依赖 | P1-1；Q09（验收口径） |
| 验收 | 手机/TV 有分（1~4 项）、无分、未知来源三态截图对比 `detail-series.png`/`detail-movie.png`；无可见平台文字；hero 无抖动。TV：评分左对齐，焦点链 上=信息、下=个人评分/播放 保持 |
| 测试 | 更新 `test/screens/media_detail/media_ratings_strip_test.dart`、`tv_spotlight_ratings_test.dart`、`fitted_metadata_line_test`（iconAspect 检查）；新增“未知来源用中性 icon、无来源文字”断言 |
| golden | 否（来源未提及详情 golden） |

#### P3-3 评分说明 dialog 接入详情与 TV 详情说明居中化

| 项 | 内容 |
|---|---|
| 来源条目 | B：DETAIL-01c、03d；B 任务包 B3 |
| 改动范围 | `media_ratings_strip.dart:63-100`（每格包 `InkWell`/`FocusableWrapper`）、`widgets/app_dialog.dart`、`responsive_layout.dart:~89`（`_openTvDetailsSheet` → `media_details_sheet.dart`，现为 sheet）、`media_detail_screen.dart:~1196`（个人评分走 `OverlaySheetController.show`）、i18n |
| 实现要点 | 复用 P1-5 的 dialog；strip 每格可点；TV 详情说明改居中 dialog（含内部滚动）；手机正文用 `CollapsibleText` 内联展开已符合原型，不动 |
| 工作量 | M |
| 依赖 | P3-2、P1-5 |
| 验收 | 点击分数弹出居中 dialog，关闭后滚动位置不变；Esc/返回键关闭并回到原焦点。TV：方向键聚焦评分格，Enter 开，Back 关并回原焦点；点信息区开居中详情 dialog，Back 回信息区 |
| 测试 | widget 测试：点击弹出、关闭后 scroll offset 不变、焦点返回 |
| golden | 否 |

#### P3-4 连续剧集与自动分组（手机/平板）

| 项 | 内容 |
|---|---|
| 来源条目 | B：DETAIL-04a、04b、04c、04d、04e、04f、04h；B 任务包 B4；决策 Q08 |
| 改动范围 | `presentation.dart:259-440`（`_buildDetailEpisodeRail`、`:402-428` 分组条、`:251` `_selectDetailEpisode`、`:100-118` “查看全部”）、`media_detail_screen.dart:2697-2770,1982-2000,2748`，新建 `media_detail/episode_rail.dart`（`DetailEpisodeRail`）|
| 实现要点 | 单一横向 `ListView.builder`，itemCount=_episodes.length(+懒加载尾卡)，卡宽 202+gap 12 固定，抽出纯函数 `groupForEpisodeIndex(i)=i~/10`。ScrollController listener：`index=round(offset/(202+12))`→`group=index~/10`，用 `ValueNotifier<int>` 只重建分组条；点组 → `controller.animateTo(group*10*(202+12))`（reduced motion 用 `jumpTo`，检查 `MediaQuery.disableAnimations`），不改当前选中集；换季与 `_detailAllEpisodes` 返回时 `rail.reset()` 并 `jumpTo(0)`；“查看全部”保持纵向列表，点选后回横排改为 `scrollTo(index)`；保持末组标签函数并加单测（23/27/30/12 集）；分组条加“当前组”`Semantics(selected)`。风险：现有懒加载分页（`_episodeListHasMore`、`_loadMoreEpisodeList`、`_episodeTailKey`）与“10 集一组”冲突，组数据未全部加载时按已知总数（`_allEpisodesTotal`/season.leafCount）计算，点到未加载组需先加载到该位置；焦点节点 `_episodeListFocusNode(index: start+index)` 改用全局 index |
| 工作量 | L |
| 依赖 | 无（可与 P3-1、P3-2 并行）；Q08 |
| 验收 | 23/27/30/12 集季：滑过 10/11 双向高亮同步；点组直达；末组 21–27 无空集；换季回首；“全部选集”计数一致；未加载组可达。TV 不在本包（见 P3-8） |
| 测试 | 纯函数单测（组号/标签/边界）；widget 测试：drag 滚动后高亮组、点组后 offset、换季 offset=0；保持既有 `test/screens/media_detail_screen_test.dart` 紧凑用例（2928、2975、3947、3976） |
| golden | 否 |

#### P3-5 标题/内容宽/动作排版

| 项 | 内容 |
|---|---|
| 来源条目 | B：DETAIL-03a、03c、X9；B 任务包 B6；决策 Q06 |
| 改动范围 | `presentation.dart:155-190`（`_buildNaturalDetailTitle`）、`responsive_layout.dart:106`（maxWidth 720）、`:66-176`（`_buildTvDetailForeground`）、`action_buttons.dart`（`:~273` gap、`:~503`）、logo 标题 `_buildDetailLogoOrTitle`（宽 400、高 100） |
| 实现要点 | 手机/平板 40→32，桌面 48→36，内容宽 720→560；TV 64×scale→36×scale（待 Q06）；logo 标题高度随之调整；03c 仅核对图标样式/透明背景，实机多出的下载/更多按钮保留 |
| 工作量 | M |
| 依赖 | P1-1；Q06 |
| 验收 | 390×844、平板、TV 截图对照三张基线；标题不与播放重叠。TV：焦点从信息区 ↓ 到播放按钮和图标行，路径不变 |
| 测试 | 更新依赖字号/宽度的现有断言；新增 golden 或尺寸断言 |
| golden | **是（新增）**：B 写“新增 golden 或尺寸断言”，二选一 |

#### P3-6 版本行样式

| 项 | 内容 |
|---|---|
| 来源条目 | B：DETAIL-X3、X4；B 任务包 B7；决策 Q07 |
| 改动范围 | `playback_selectors.dart:18-211`（`:55-80`、`:68-75` subtitle、`:94-131`）、`app_select_field.dart`（与 A 的 SHARED 协调，避免重复改）、`backend_badge.dart`/`catalog_source_logo.dart` |
| 实现要点 | 保留三选择器；版本字段增加服务器 logo，摘要显示“分辨率·编码 · N 个版本”，选项 subtitle 改“默认线路/备用·大小”；单版本时隐藏“N 个版本”和 chevron；X4 无改动，检查 PLAYER 批次 `track.label.primary/secondary` 规则同步 |
| 工作量 | M |
| 依赖 | P1-1；Q07 |
| 验收 | 单/多版本、不可播放版本、探测中 busy、选择后偏好保存（`_selectDetailVersion`） |
| 测试 | 既有 playback_selectors/版本偏好测试 + 新增摘要文案断言 |
| golden | 否 |

#### P3-7 媒体信息/电影/演员复核

| 项 | 内容 |
|---|---|
| 来源条目 | B：DETAIL-X5、X6、X7、X8；B 任务包 B8 |
| 改动范围 | `media_detail_technical_info.dart`（228 行，卡宽 235/圆角 16/padding 15/dt 11px，对照 `ui.css .media-info`）、`cast_member_strip.dart`（`media_detail_screen.dart:4495-4509`）、`:3381-3560`（电影无剧集布局）、`:3516-3526`、`:3541-3555` |
| 实现要点 | 仅截图比对并微调样式；电影空演员整段隐藏（`:3503`）保持；X5 的 `media_detail_technical_info.dart` 的 build 本次未量，需开发时逐项量 |
| 工作量 | S |
| 依赖 | P3-2 之后做更省重复截图 |
| 验收 | 电影无剧集布局、演员/类型/相关与 `detail-movie.png` 对比 |
| 测试 | 现有 `media_detail_technical_info_test` |
| golden | 否 |

#### P3-8 TV 自动分组（可选，先确认需求）

| 项 | 内容 |
|---|---|
| 来源条目 | B：DETAIL-04g；B 任务包 B5；决策 Q10 |
| 改动范围 | `media_detail_screen.dart:4021+`（`_tvDetailHubs`）、`:389`（`_tvDetailFocusedEpisode`）、`widgets/tv_browse_rail.dart` |
| 实现要点 | 在季 hub 顶部加分组 chips，以焦点集判组，需输入来源跟踪（可复用 `InputModeTracker`）；程序滚动不回写旧组；wheel/触摸退出焦点模式 |
| 工作量 | L |
| 依赖 | P3-4；Q10；风险高 |
| 验收（TV 方向键） | D-pad 焦点 10→11 立即高亮 11–20，反向同；wheel/触摸退出焦点模式 |
| 测试 | 扩展 TV 用例（`test/screens/media_detail_screen_test.dart` 的 1099/2870 等） |
| golden | 否 |

---

### P4 搜索 / 媒体库

#### P4-1 库页小补齐

| 项 | 内容 |
|---|---|
| 来源条目 | C：LIB-01.g、LIB-01.j、LIB-01.f、LIB-01.m；C 任务包 PKG-C1 |
| 改动范围 | `screens/libraries/library_browse_tab.dart`（`_buildConditionSummary:1859`、`:217` totalSize）、`widgets/overlay_sheet.dart:107-118`（断言 alignment）、`FiltersBottomSheet/SortBottomSheet` 命名（可选）、`utils/grid_size_calculator.dart:11-19`、`library_quick_filters.dart`、i18n 键 `libraries.itemCount` |
| 实现要点 | 在 `_buildConditionSummary`/筛选行下方加一行 `Semantics(liveRegion)` 文案“N 部作品”，仅 `_selectedFilters/_search` 非空时显示；i18n 需补齐 slang 各语言（20+ 语言）或允许回退 en；补测试：390dp 默认密度=3 列、320dp+textScale 2.0 标签行不溢出、筛选弹层 alignment=center |
| 工作量 | S |
| 依赖 | P1-1；Q02（方案 A 前提） |
| 验收 | 手机 390dp 打开任一库，选 genre=科幻→标签行下出现“N 部作品”；清除后消失；空态仍有“重置筛选”；320dp+2.0x 字体标签行无溢出；filter/sort/grouping 弹层居中无底部滑入 |
| 测试 | `test/screens/libraries/` 新增 quick filters 窄屏/文本缩放 widget test、计数行 test；`flutter analyze` + 相关 test |
| golden | 可能：`test/screens/libraries/goldens/fusion_library_phone_1x/2x/tv.png`，计数行只在有筛选时出现，预计不变；P1-1 已使其重生成 |

#### P4-2 TV 媒体库顶部筛选（可选，默认不做）

| 项 | 内容 |
|---|---|
| 来源条目 | C：LIB-01.k；C 任务包 PKG-C5；决策 Q11 |
| 改动范围 | `library_browse_tab.dart:1828-1836,1919,1832,1933`、`library_quick_filters.dart`（`_Tag` 加 TV focus 放大描边）、`search_screen.dart:465-500`（chip 导航参考）、`_navigateToChips/_navigateToGrid`、alpha 跳转栏、`focusTabBar`、`:1686` `_chipsBarHeight` |
| 实现要点 | 标题右侧 `SearchInputField`，复用 `LibraryQuickFilters`，补上下方向键 `onNavigateUp/Down` |
| 工作量 | M |
| 依赖 | Q11（默认保持侧栏，则不做本包） |
| 验收（TV） | 标题右侧搜索框；筛选标签行方向键可达，Down 进入网格、Up 回标签；焦点描边为紫色。必须在实体/模拟 TV 手验 |
| 测试 | `test/focus` 与 `test/screens/libraries` 的 dpad 遍历 test |
| golden | 是：`fusion_library_tv.png`（若实施） |

#### P4-3 IA 决策落地（条件包）

| 项 | 内容 |
|---|---|
| 来源条目 | C：§0 信息架构；C 任务包 PKG-C6；决策 Q02 |
| 改动范围 | 方案 A 无代码；方案 B（跨库浏览页）单独立项，不在本批 |
| 实现要点 | 方案 B 需合并多服务器分页，改变查询语义，且与 spec §6 冲突 |
| 工作量 | L（仅方案 B） |
| 依赖 | Q02 |
| 验收 / 测试 / golden | 视立项而定 |

---

### P5 一起看

#### P5-1 加入房间表单错误就地化

| 项 | 内容 |
|---|---|
| 来源条目 | C：TG-01.d、TG-01.e；C 任务包 PKG-C2 |
| 改动范围 | `watch_together/widgets/join_session_dialog.dart`（`:93-105` 校验；`maxLength=RelayProtocol.maxSessionIdLength`）、`watch_together/screens/watch_together_screen.dart:394-`（`_joinSession`、`_runSessionAction`、`_isJoining`）、`test/watch_together/join_session_dialog_test.dart` |
| 实现要点 | dialog 接收异步 `onSubmit: Future<String?> Function(code)`（返回错误文案则就地显示并保留输入），把 `joinSession` 调用移入 dialog；或成本更低的做法：失败时重新打开 dialog 预填上次输入（S）。码格式为字母数字（协议决定，保持，不是原型的 6 位数字） |
| 工作量 | M |
| 依赖 | 无 |
| 验收 | 输入不存在的码→在 dialog 内显示错误并保留输入；成功才关闭；busy 时按钮禁用。TV：dpad 焦点仍可用（粘贴按钮/输入框/确认之间） |
| 测试 | 更新 `join_session_dialog_test.dart`（异步提交失败保留输入）；新增 screen 层 test mock `WatchTogetherProvider.joinSession` 抛 `PeerError` |
| golden | 否 |

#### P5-2 创建房间表单

| 项 | 内容 |
|---|---|
| 来源条目 | C：TG-01.c；C 任务包 PKG-C3；决策 Q14 |
| 改动范围 | `watch_together_screen.dart:352`（`_createSession`）、`:373`（`_showControlModeDialog`）、`:451`（`_RenameRoomDialog`，风格与 FocusNode 链参考）、`:313`（`_recordRecentRoom(name:)` 已支持 name）、i18n |
| 实现要点 | 创建 dialog 增加可选“房间名称”输入，控制模式（仅房主/任何人）改为 dialog 内两选项；创建后记录名称；留空显示邀请码；文案加“你将成为房主，控制播放”；不做“选择影片”（不改同步协议） |
| 工作量 | M |
| 依赖 | Q14 |
| 验收 | 创建时可填名称，最近房间卡显示该名称；留空显示邀请码。TV：焦点链 名称→取消→确认 |
| 测试 | widget test + `recent_rooms_service` 已有逻辑回归 |
| golden | 否 |

#### P5-3 房间卡与大厅状态视觉

| 项 | 内容 |
|---|---|
| 来源条目 | C：TG-01.b、TG-01.h、TG-01.g（方案 a）、TG-01.k；C 任务包 PKG-C4；决策 Q13、Q15 |
| 改动范围 | `watch_together_screen.dart:510-585`（`_RecentRoomTile`）、`:587-760`（`_ActiveSessionContent`）、`:758-950`（`_JoinCurrentPlaybackCard`）；`services/recent_rooms_service.dart:17-23`（仅 Q15 选 b 时）、`models/watch_session.dart:12-19` |
| 实现要点 | 房间卡视觉对齐（r16、tag 样式），不伪造成员/影片；参与者行显示“已连接/缓冲中/未匹配媒体”，无媒体显示“待播放”，状态 tag（等待媒体/等待成员/播放中）；派生就绪（无协议改动）。toast 部分随 P1-2，本页只替换调用点。若 Q15 选 b：新增本地 `lastMediaTitle`，需 `.g.dart` 与存储迁移，兼容旧数据 |
| 工作量 | S–M（视觉 S，影片名可选 M） |
| 依赖 | P1-2；Q13、Q15 |
| 验收 | 参与者行状态正确；无媒体显示“待播放”；不出现虚构成员/影片。TV：宽≥760 且字体≤24 时左右两栏，←→ 在创建/加入与房间列表间移动 |
| 测试 | `_ActiveSessionContent` widget test 覆盖四种状态；可选补 TV 焦点遍历 widget test |
| golden | 否 |

---

### P6 播放器（手机/平板）

#### P6-1 抽屉外壳统一

| 项 | 内容 |
|---|---|
| 来源条目 | E：P01-1、P01-2、P04-2（宽度）；E 任务包 A；决策 Q32 |
| 改动范围 | `theme/overlay_tokens.dart`（`OverlayTokens.motion=180ms` 在 `:13`，新增 `drawerWidth=340`、`drawerMotion=240ms`）、`widgets/overlay_sheet.dart:777-835`（`:781` 宽度改 `min(maxWidth, 0.85*屏宽)`）、`player_settings_drawer.dart:30`（`widthFor` 318/平板 400）、`:79-113`（标题行+关闭）、各入口宽度常量（`track_chapter_controls.dart:176/214/240/272/346`、`casting.dart:23`、`watch_together_overlay.dart:50`、`mobile_chips.dart:121`）、`vc/` 下新增 `PlayerPresentation` 小常量文件（原型指向的 `player_presentation.dart:7` 实机不存在）、i18n |
| 实现要点 | 仅 edgeDrawer 使用 240ms 新常量，不动 floating 的 180ms（避免影响全站，SHARED-02 对话框 180ms 保持）；标题行（`t.videoControls.moreButton` 或新增 `playerSettingsTitle`）加关闭 `IconButton` 调 `OverlaySheetController.of(context).close()`；统一各入口宽度；TV 宽度见 P7-1 |
| 工作量 | S+S |
| 依赖 | Q32 |
| 验收 | 手机横屏打开设置/章节/弹幕/投屏/一起看，宽均 340（窄屏 ≤85%），240ms 滑入滑出，点遮罩/关闭键/Esc 均可关，标题行与关闭键可见 |
| 测试 | 更新 `test/widgets/overlay_sheet_edge_drawer_test.dart`（宽度/85%/时长）、`tablet_player_settings_test.dart` |
| golden | 否 |

#### P6-2 音轨/字幕改回双行直列

| 项 | 内容 |
|---|---|
| 来源条目 | E：P02-1、P02-2、P03-1、P03-3（P03-2 迁移时保持逻辑）；E 任务包 B；决策 Q30 |
| 改动范围 | `sheets/sheet_selection_column.dart:68-95`（内嵌 `embeddedBuilder` 回落 `Wrap` 改 `Column`，`:40-52` `runExclusive`）、`track_sheet.dart`（`:180/253/349-360/361-376/454/496/560-590/624-641`，四个 Column 去 `embeddedBuilder`、`onTap` 改 `scope.runExclusive`、次字幕独立列表、空态）、`helpers/track_selection_helper.dart:35/75-125`（选中紫底+勾，对齐 `GlassSheetColors.selected`）、`TrackLabelBuilder`（补采样率，需核实 `AudioTrack.sampleRate`）、i18n（“没有可用音轨 / 此媒体没有可选择的音轨”） |
| 实现要点 | 去掉 `_AudioColumn`/`_SourceAudioColumn` 的 `embeddedBuilder`；新增 `_SecondarySubtitleList`（`supportsSecondary` 时在“次字幕”下直列同款双行 tile，排除当前主轨，含“关闭”）；`tracks.isEmpty` 返回空态块；失败时显示值取 `player.state.track`（stream 真值天然回滚）；保持 `_SubtitleMenuValue(nativeTrackId, sourceStreamId)` 命名空间和主/次互斥逻辑（`:312、:454、:473-481、:516-523、:507`）；`AppSelectField` 本身保留给设置页等；次字幕不支持时按 Q30 处理 |
| 工作量 | M |
| 依赖 | Q30（P01-3 无关）；P6-1 非必需（E 说 A、B 可并行） |
| 验收 | 手机抽屉音频/字幕标签直接看到双行选项，点选即生效且面板与底栏 chip 同步；切换中再次点击无反应并显示进度条；模拟失败（单测）保留旧值并弹错误条；无音轨显示空态；次字幕列表不含当前主轨；关闭主字幕后次字幕为关闭。TV：遥控器必须能到次字幕（不再依赖长按/右键） |
| 测试 | 改写 `test/widgets/track_sheet_test.dart`、`player_track_selector_test.dart`（原断言 `AppSelectField`）、`tablet_player_settings_test.dart`；新增 pending 重入、失败回滚、空态用例；回归：切 tab 后音轨选择保留（P01-8） |
| golden | 否 |

#### P6-3 手机底栏 chip 抽屉化

| 项 | 内容 |
|---|---|
| 来源条目 | E：P01-6；E 任务包 C 的 C1 |
| 改动范围 | `mobile_chips.dart:36`（`_showPopover`）、`:40-44`（倍速 `PlayerSpeedPopover`）、`:46-55`（字幕 `TrackSheet` 窄 280）、`:57-85`、`:90`（`_openPlayerDrawer`）、`:111`、`video_settings_sheet.dart:419/483`（`openOnSpeed:true`）、`player_track_summary.dart`（回调 `onTapWithRect` 可保留） |
| 实现要点 | 倍速：新增 `PlayerSpeedDrawer`，或复用 `VideoSettingsSheet(openOnSpeed:true)` 的速度子页，以 edgeDrawer 打开；字幕 chip 改调 `_openPlayerDrawer(context, state, PlayerDrawerTab.subtitles)`；选集 chip 见 P6-4；章节入口按 Q29 |
| 工作量 | M |
| 依赖 | P6-1；Q29 |
| 验收 | 手机横屏倍速、字幕 chip 打开的都是右侧抽屉（不再是锚在按钮上方的小浮层） |
| 测试 | 更新相关 mobile chips 用例 |
| golden | 否 |

#### P6-4 选集/播放列表抽屉（EpisodesDrawer）

| 项 | 内容 |
|---|---|
| 来源条目 | E：P01-7；E 任务包 C 的 C2；供 P05-6 的 TV 复用 |
| 改动范围 | 新建 `sheets/episodes_drawer.dart`（`EpisodesDrawer`）；`sheets/player_popovers.dart:119`（`PlayerEpisodesPopover`）、`sheets/queue_sheet.dart:30`（保留缩略图/防剧透组件 `MediaSelectorThumbnail`、`hideSpoilers`）、`video_controls.dart:1401`（`canShowQueue || _chapters.isNotEmpty`）、`media_server_client.dart:246`（`fetchChildren(showId)`）、`:987`（`fetchSeasonEpisodesPage`）、`parts/navigation.dart:56`（`_onQueueItemSelected`）、`playback_state_provider`（取季/循环/随机）、i18n（选集/播放列表/接下来播放/接下来·第 N 季） |
| 实现要点 | 剧集模式：顶部季标签+本季集（已看/进度读 `MediaItem` 的 viewOffset/viewCount）+ 末尾“接下来 · 第 N+1 季”；电影/列表模式：当前项 + `PlaybackStateProvider.loadedItems` 后续项 + 循环/随机行（复用既有 shuffle/loop）；章节独立入口，不再兼职；手机与 TV 共用同一 widget。非队列（单集/电影直播放）时按 `metadata.parentId` 懒加载本季列表，离线/无网降级为只显示当前项；Jellyfin/Plex 两套后端都要测 |
| 工作量 | L |
| 依赖 | P6-3；Q29 |
| 验收 | 手机剧集点“选集”出右侧抽屉，顶部分季标签，本季已看打勾、当前集高亮+进度条、下一集标“接下来播放”，末尾衔接下一季；电影/播放列表按钮显示“播放列表”，列出当前项与接下来并可切循环/随机；选中后切集、抽屉关闭、焦点回按钮 |
| 测试 | widget 测试覆盖剧集/电影两种模式与离线降级；复用 `test/widgets/player_queue_spoilers_test.dart` 的防剧透断言 |
| golden | 否 |

#### P6-5 播放器小项

| 项 | 内容 |
|---|---|
| 来源条目 | E：P01-3、P01-4（可选）、P04-1（本地字幕占位）、P04-5（验收）；E 任务包 F；决策 Q26、Q27、Q28、Q31 |
| 改动范围 | `player_settings_drawer.dart:136-186`（`_AspectRatioRow :215`、`_AutoSkipRow :259`）、`SettingsService`（`showChapterMarkersOnTimeline` 默认值）、`timeline_slider.dart:393`、`buffer_range_painter.dart:97`；`track_sheet.dart`（字幕标签“调整”之后与“在线搜索”并排放本地字幕入口占位）；`danmaku_sources_sheet.dart:109` |
| 实现要点 | P01-3 保持 3 档，验收文案标“原型 5 档为演示”；P01-4 可选把章节刻度默认关；P04-1 仅占位入口与禁用态（TV 隐藏该项）；P04-5 无功能改动，验收时逐入口录屏确认无底部滑出。（P05-2 的描边/首步长在 E 的包 F 与包 E 中都出现，本文归入 P7-2） |
| 工作量 | S |
| 依赖 | Q26、Q27、Q28、Q31 |
| 验收 | 抽屉视频标签 3 档与原型差异已记录；章节刻度行为与决策一致；字幕标签有占位入口 |
| 测试 | 按所选项补充 |
| golden | 否 |

---

### P7 播放器 TV

#### P7-1 TV 右组入口重做与选集入口

| 项 | 内容 |
|---|---|
| 来源条目 | E：P05-4、P05-6、P05-7、P05-8、P05-12、P05-9；tv-gap-notes；E 任务包 D；决策 Q25、Q32、Q33 |
| 改动范围 | 新建 `widgets/tv_action_button.dart`（`TvActionButton`：图标+标签+当前值，`vc/widgets/`）；`widgets/track_chapter_controls.dart:162-344`（`:164` 设置、`:200` 音轨字幕合一、`:231` 章节、`:263` 队列、`:303` 画面比例、`:337` 弹幕，TV 走新分支，桌面不动）；`desktop_video_controls.dart`（`:786-910` 七按钮、`:947` `hideChaptersAndQueue`、`:386、:455、:634` 内容条路径、`:228` `_trackControlFocusNodes = List.generate(9)`、`:925`）、`parts/key_events.dart:86`、`parts/track_controls.dart:210`、`widgets/content_strip.dart:32`、`widgets/content_strip_panel.dart:50`（`ContentStripHint`）、`video_controls.dart:1542`（跳过按钮离底 180 分支）、`visibility.dart`、`player_settings_drawer.dart`（TV 下 ←→ 标签自动切页）、`overlay_sheet.dart:560-600`、`player_settings_controls.dart:297/387`、`player_focus_disc.dart`（紫描边/1.14）、`focus_theme.dart:14`（新增 `playerDrawerFocusDecoration`）、`parts/playback_input.dart:32-33`（章节提示）、`media_source_info.dart:328` |
| 实现要点 | 右组：倍速（`VideoSettingsSheet(openOnSpeed:true)`）、字幕/音轨/弹幕/设置分别 `PlayerSettingsDrawer(initialTab: subtitles/audio/danmaku/video)`（`volumeController` 传 null）、选集（`EpisodesDrawer`，图标 grid/list，标签随 `metadata.type` 与 `isQueueActive` 切换，单集也可用）、章节（`ChapterSheet`，不再受 `hideChaptersAndQueue` 隐藏，补缩略图）；画面比例并入设置标签；TV 去掉 `ContentStrip`/`ContentStripHint`/`hideChaptersAndQueue`/`_showContentStrip` 路径及 `key_events.dart:86` 返回层（影响面大，可先保留代码但 `useDpadNavigation` 下不再触发，下个包删除），↓ 键恢复为“无操作”；抽屉宽 `max(340, 0.3*屏宽)`，打开时 `initialFocus` 指向选中 tile/当前集，标签 `PlayerDrawerChoice` 的 `onFocusChange(true)` → `setState(_tab=…)`（仅 dpad 模式，焦点必须留在标签栏）；`PlayerFocusDisc` TV 分支加 6px `colorScheme.primary` 外描边+缩放 1.14，抽屉 tile 焦点 3px 内描边；上/下一章按钮改调 `_seekToChapterWithFeedback`，核对 `onSeekBackward/Forward`（`_seekByWithFeedback`）；新按钮要有稳定 `FocusNode`，否则 `overlay_sheet.dart:552` 的 `returnFocus.context==null` 无法恢复。TV 对照笔记中缺的入口（倍速、选集、版本与画质 `video_settings_sheet.dart:925`、睡眠 `:952`、一起看 `:1273`、字幕搜索）：倍速和选集作为直达按钮，版本/睡眠在设置标签内，一起看见 P7-2，投屏按 Q33 不提供 |
| 工作量 | L |
| 依赖 | P6-1、P6-2、P6-4；Q25、Q32、Q33 |
| 验收（TV 方向键路径） | 唤出控件→焦点在播放/暂停；→ 依次到 快进→下一章→下一集→倍速→字幕→音轨→选集→章节→弹幕→设置，← 反向；每个右组按钮 Enter 打开对应抽屉（字幕/音轨/弹幕/设置为同一四标签抽屉且停在对应标签）；抽屉内 ↑↓ 逐项、标签栏上 ←→ 自动切页、滑块 ←→ 调值、焦点不出抽屉；Back 先回设置子页再关抽屉，焦点回到触发按钮；电影（无队列）也能看到“播放列表”按钮；剧集“选集”抽屉 ←→ 在季标签间切换，Enter 切集；上一章/下一章点击出现章节名提示；快退/快进 ±10 秒有提示 |
| 测试 | `test/widgets/track_chapter_controls_test.dart`、`video_controls_test.dart` 增加 TV 入口与焦点顺序用例；`test/focus/` 增加抽屉焦点不泄漏用例；移除/改写内容条相关测试（`test/widgets/*strip*`）。风险：7 个带标签按钮 TV 宽度需实测，`_trackControlFocusNodes` 数量需核对 |
| golden | 否 |

#### P7-2 TV 顶栏与方向键路径

| 项 | 内容 |
|---|---|
| 来源条目 | E：P05-1、P05-2、P05-10、P05-11、P04-3；E 任务包 E；决策 Q16、Q24、Q33 |
| 改动范围 | `video_controls_header.dart`（TV 变体：弹幕开关、一起看、更多；`:77-91`）、`desktop_video_controls.dart:700-709`（`VideoControlsHeader`）、`:546-551`（进度条 ↑ 隐藏控件，`parts/visibility.dart:257`）、`:561-`（←→ 渐进 scrub）、`parts/key_events.dart:55-66,309-327`、`mobile_chips.dart:_toggleDanmaku`（提到 `parts/` 公共）、`timeline_slider.dart:371-372,448`（聚焦描边）、`buffer_range_painter`/`FocusTheme`、`settings_service.dart:581`（`_seekTimeSmall` 默认 10）、`watch_together_overlay.dart:22` |
| 实现要点 | 顶栏加三个入口并各加 `FocusNode`；↑ 改为：有跳过按钮→跳过，否则→顶栏第一项，顶栏 ↑ 无操作；弹幕开关复用手机逻辑；“更多”打开设置标签抽屉；“一起看”按 Q16（仅会话中，或无会话时显示 chip）；进度条聚焦时加 2px 白描边，首次 ←→ 步长对齐 `seekTimeSmall`（保持渐进加速不动，只核首步）；隐藏态按 Q24 的结论。TV 缩放（原型 DPR2 下 44 逻辑 px，按钮 88px、片名 48/600）需核对。风险：改变 ↑ 的“隐藏控件”语义（现 `_hideControlsFromKeyboard`），遥控器回归风险高 |
| 工作量 | M |
| 依赖 | P7-1；Q16、Q24、Q33 |
| 验收（TV 方向键路径） | 进度条 ↑→（有跳过按钮先到跳过）→顶栏；顶栏 ←→ 在 返回/弹幕/一起看/更多 间移动，Enter 触发；“更多”打开设置标签抽屉；顶栏 ↓ 回进度条；无抽屉时 Back 隐藏控件，再按 Back 退出；隐藏态 ↑↓/Enter 唤出并聚焦播放/暂停，有跳过按钮时 Enter 跳过；自动隐藏 10 秒、抽屉开启不隐藏（实机现值待核，见 Q33） |
| 测试 | 焦点遍历单测（顶栏 ↔ 跳过 ↔ 进度条 ↔ 底栏）；`test/focus` |
| golden | 否 |

---

### P8 设置

#### P8-1 设置 TV/平板分类对齐

| 项 | 内容 |
|---|---|
| 来源条目 | D：U-01、S01-a、S01-e、U-02、U-08、U-09、U-10、U-11、U-12；D 任务包 D3；决策 Q13、Q19、Q21 |
| 改动范围 | `lib/screens/settings/settings_screen.dart:236-300,311,325,366-455`、`settings_category_pane.dart:75-110`（左栏选中态）、`:89`（宽 310/230）、`:92-98`（左右键）、`widgets/setting_tile.dart`（`enabled=false` 统一 subtitle 规则） |
| 实现要点 | 分类顺序调为原型顺序：服务器与账户/播放/字幕/弹幕/一起看/外观/下载与离线/连接与集成/网络与缓存/关于（实机 danmaku 在 subtitles 前，且多 general/controls/advanced，需按 Q21 归并）；预留新增 network 分类（`'network'`）；“应用”组多出 Donate 见 P0-2；S01-e 补统一禁用说明规则；离线模式/文字大小/启动页按 Q19 不新增；U-12 的显示名称/准备/提醒按 Q13，核对 watch_together 是否已有对应 pref，无则不新增、标说明；U-10 可选加“管理下载/同步规则”跳转行（可选） |
| 工作量 | M |
| 依赖 | Q13、Q19、Q21 |
| 验收（TV 方向键） | TV 两栏：←→ 进出左右栏、焦点回左栏、↑↓ 在分类间移动；切换分类不抖、当前分类高亮 |
| 测试 | `test/screens/settings/settings_screen_test.dart`（动 category id 会影响）+ 焦点回归；手动 TV 验证 |
| golden | 是：`test/screens/settings/goldens/*`（`fusion_settings_tv.png`、`settings_phone_*.png` 等）如分类顺序/行变化 |

#### P8-2 网络与缓存页骨架

| 项 | 内容 |
|---|---|
| 来源条目 | D：S03-a、S03-b、S03-c、S03-d、S03-e、S01-c；D 任务包 D4；决策 Q22 |
| 改动范围 | 新增 `lib/screens/settings/network_cache_settings_screen.dart`；`services/home_snapshot_store.dart`、`providers/discover_provider.dart:104`；`settings_screen.dart:867`（清除图片缓存）、`:1140`（确认 dialog）、`services/image_cache_service.dart`；`playback_settings_screen.dart:667`（`playbackBufferTier`）、`:485`（硬解）、`:530`（去隔行）、`:613`（`disableDolbyVision`）、`:620`（`dvConversionMode`） |
| 实现要点 | 加“启动时显示已授权快照”开关与“清除首页示例状态”（确认 dialog；先核对 snapshot 授权与账户/服务器隔离语义，不凭原型新增生产默认，未设置≠0）；图片缓存清除项迁入/复制；缓冲与硬解仅文案“未设置/有效状态由实际核心确认”，不改 pref 类型；新页沿用 `showConfirmDialog` |
| 工作量 | M |
| 依赖 | Q22；与 P8-3 同属“网络与缓存” |
| 验收 | 清理有确认，取消不变；开关与清除可用 |
| 测试 | 新增 `network_cache_settings_screen_test` + golden |
| golden | **是（新增）** |

#### P8-3 线路管理（条件包）

| 项 | 内容 |
|---|---|
| 来源条目 | D：S02-a、S02-b、S02-c；D 任务包 D5；决策 Q18 |
| 改动范围 | 新增线路子页与 dialog（复用 `SettingsPage`/`SettingNavigationTile`、`showNumericInputDialog`（`setting_tile.dart:213` 一带）、`showScopedDialog`（`settings_screen.dart:1133`）、`showConfirmDialog`）；`add_jellyfin_screen`/`edit_jellyfin_connection_screen.dart`（仅编辑单地址，参考）；持久化沿用 `SettingsService` pref |
| 实现要点 | 新增纯函数 `validateRoute()`：名称必填；端口 1—65535 整数（0、65536、小数、非数字拒绝）；地址不接收嵌入凭据（`Uri.userInfo` 非空即拒）；取消不写入；刷新后保留；不发真实测速；选中态存本地 pref；“自动最快”仅显示“规划中/不可选”；先确认连接模型（`lib/models` 与 database tables 的 endpoint/备用地址）是否支持多线路，否则只能做本地偏好演示 |
| 工作量 | L |
| 依赖 | Q18、P8-2 |
| 验收 | 空名/0/65536/小数/非数字拒绝，1/65535 接受，取消不写入，重启保留 |
| 测试 | `validateRoute` 单测（含 userinfo 拒绝）+ widget 测试 |
| golden | 否 |

#### P8-4 字幕/弹幕设置页补齐

| 项 | 内容 |
|---|---|
| 来源条目 | D：U-03、U-04、U-05、U-06；D 任务包 D6（与 PLAYER-04 合并提交）；决策 Q22、Q23 |
| 改动范围 | `danmaku_settings_entry.dart:36-40`、`widgets/video_controls/sheets/danmaku_settings_sheet.dart:99-109、:432-460`（开关与“弹幕源”行）、`:486-500`、`:523`、`:663-685`、`:907`、`:341`；`danmaku_source.dart`；`subtitle_styling_screen.dart`、`account_preferences_detail_screen.dart` |
| 实现要点 | 核对 `:432-460` 的 `onChanged`：无源时拦截并打开源添加，补 widget 测试；读 `danmaku_source` 校验，补 127.0.0.1/localhost 文案（仅格式校验，不发请求）；弹幕“速度/同屏上限”视 `DanmakuSession` 是否有字段，没有则标“不新增能力”，仅加预览；字幕页顶部加“语言”分组跳转 `account_preferences`。⚠待核实：D 把“无源时点开关是否弹出添加源”标为待验证，E 的 P04-4 则称空配置直接进入添加源（`:99-109`），需读代码确认 |
| 工作量 | M |
| 依赖 | Q22、Q23；建议在 P6-2 之后（弹幕/字幕抽屉形态已定） |
| 验收 | 无源时开启弹幕→引导添加源；字幕页有语言入口 |
| 测试 | 扩展 danmaku 现有测试 |
| golden | 可能：`test/screens/settings/goldens/danmaku_settings_phone.png` |

#### P8-5 设置视觉尺度

| 项 | 内容 |
|---|---|
| 来源条目 | D：S01-b、S01-c；D 任务包 D7；决策 Q17 |
| 改动范围 | `lib/screens/settings/theme/settings_presentation.dart:10-13`（`rowHeight` 48、`groupRadius` 15）、`widgets/setting_tile.dart`、`widgets/app_select_field.dart:175` |
| 实现要点 | 按 Q17 结论改行高/圆角；设置页保存后的通知只调用统一 helper（P1-2），不另造 |
| 工作量 | S |
| 依赖 | P1-1、P1-2；Q17 |
| 验收 | golden 重生成并人工核对；各设置页无布局溢出 |
| 测试 | 重生成 settings golden |
| golden | **是**：`test/screens/settings/goldens/*` 全部 |

---

### P9 回归与审计

#### P9-1 弹层与可达性审计

| 项 | 内容 |
|---|---|
| 来源条目 | A：SHARED-02、SHARED-05a、SHARED-05b；A 任务包 B4 |
| 改动范围 | 审计命令（一次性，不入库）：`grep -rn "Alignment.bottom\|showModalBottomSheet\|showDialog\|AlertDialog(" lib`；未走 `AppDialog`/`OverlaySheet` 的弹层、直接调用 `ScaffoldMessenger.showSnackBar`、缺 tooltip 的 `IconButton`，结果写入 PR 描述；少量修补；`overlay_sheet.dart` 的回焦逻辑（`:465/546`） |
| 实现要点 | 核实：127 处 `OverlaySheetController` 调用里有无自带 bottom alignment；7 处 `showDialog` 是否都走 `AppDialog`；`BottomSheetPageScaffold`/`bottom_sheet_*` 仅是命名遗留；每个 `IconButton` 有 tooltip/semantic label；PressFeedback 仅 11 处使用，全覆盖属后续优化，不在本包 |
| 工作量 | S（审计）+ S（测试） |
| 依赖 | P1-2 之后（审计 toast 迁移完整性） |
| 验收（含 TV） | 抽查 10 个入口：居中、Esc 只关最上层、回焦到触发控件；每个 `IconButton` 有名称。TV：Back 逐层关闭，焦点回触发控件 |
| 测试 | 新增 `test/widgets/overlay_focus_test.dart` |
| golden | 否 |

#### P9-2 全局视觉回归与 golden 重生成

| 项 | 内容 |
|---|---|
| 来源条目 | A：“D 阶段（视觉回归）在 A1 合并后统一做”；各包的 golden 要求 |
| 改动范围 | `test/screens/libraries/goldens`、`test/screens/settings/goldens`、`test/widgets/goldens`；与 `previews/final-v1/*.png`（本地参考产物，**不得提交**，见第 4 章）对照 |
| 实现要点 | 所有包合并后逐页截图比对（手机/平板/TV × 深/浅/OLED）；重生成 golden 并人工核对；实体 TV 验证不在本计划内，由验收另列 |
| 工作量 | 来源未估算（整理者：视页面数量，按 M 预留） |
| 依赖 | 全部功能包 |
| 验收 | 与原型截图逐页对照通过；golden 全绿 |
| 测试 | `flutter test` 全量（来源建议的局部命令见各包） |
| golden | **是**（统一重生成） |

---

## 4. 风险与注意事项

### 4.1 协议改动

- **一起看“真 ready 协议”（Q13 方案 b）**：需在 relay 协议、`SyncMessage`、`PeerService` 增加 ready 消息，与已部署自建中继兼容性风险高。C 推荐不做，用 UI 派生就绪（P5-3）。
- **加入房间的码格式**：实机是字母数字（`RelayProtocol.maxSessionIdLength`、`isValidSessionId`，协议决定），而原型写 6 位数字，保持协议，不改格式。
- P5-1 改 `showJoinSessionDialog` 签名，需同步 `join_session_dialog_test.dart`；若走“失败重新打开 dialog 预填”则不改签名。
- “选择影片”“开始一起看”涉及产品语义，不改同步协议（Q14）。
- `DiscoverProvider` 数据流变更（P2-1）不是协议改动，但需新增 provider 单测，并保证多服务器渐进发布不回退。
- 线路管理（P8-3）若接入真实多线路，需先确认连接模型是否支持，规范明确“生产网络映射待实施核对”“不做测速”。

### 4.2 迁移

- `RecentRoom` 新增 `lastMediaTitle`（Q15 b）：需 `.g.dart` 重生成（build_runner）和旧数据兼容。
- 导航持久化：startup 偏好使用稳定 `NavigationTabId`（`settings_service.dart:1643`），Q02 选方案 B/C 会触及它；设置分类 id 变动（P8-1）会影响 `settings_screen_test.dart`。
- 不建议把硬解等布尔 pref 改为“跟随核心/开/关”三态（需迁移 pref，风险高）。
- 新增 i18n 键需走 slang 生成流程（`strings.g.dart`），项目语言文件在 9+ 到 20+ 种之间（A、C、E 的写法不一致，⚠冲突：A 未写，C 写“20+ 语言”，E 写“i18n 目录 9+ 语言”）。至少补 zh/en，其他语言是否允许回退 en 需按 CI 规范确认（README 提到翻译为严格 CI 待办）。

### 4.3 测试大面积变更

- toast 迁移：14 个含 SnackBar 的测试断言要改（P1-2）。
- 主题：`test/theme/mono_theme_test.dart:59-60`（bg=0xFF000000 断言）；三组 golden（libraries、settings、widgets/continue_watching）会随 P1-1 全部失效。
- 导航：`fusion_navigation_test.dart`、`navigation_tabs_test.dart`、`mobile_navigation_rail_test.dart`。
- 评分条：`media_ratings_strip_test`、`tv_spotlight_ratings_test`、`fitted_metadata_line_test`。
- 详情 TV：`media_detail_screen_test.dart` 有大量 TV 用例（584/1099/1229/2176/2870…）；紧凑用例 2928、2975、3947、3976 需保持。
- 播放器：`track_sheet_test.dart`、`player_track_selector_test.dart`、`tablet_player_settings_test.dart`（原断言 `AppSelectField`）、`overlay_sheet_edge_drawer_test.dart`、内容条相关 `test/widgets/*strip*`、`video_controls_test.dart`。
- 设置 golden：行高/分类变化需整体重生成。

### 4.4 上游残留（Plezy 署名合规必须保留）

- **必须保留**：README.md:14 的署名（“Velo 是 Plezy 的衍生项目”）、GPL-3.0 LICENSE、上游版权信息；P0-1 新增的关于页署名是补强而不是替换。清理任务（P0-2、重命名、去上游入口）都不得删除或弱化署名。
- 仍指向上游的残留：`update_service.dart:19、:25`（edde746/plezy 与 appcast）、`zh.i18n.json:1338` 的 appDescription、Donate、Sentry DSN（待核实）。
- 项目规则（CLAUDE.md）：不得提交凭据，不得提交本地参考产物。`previews/final-v1/*.png` 等对照截图只用于本地验收，不入库。
- 开工前阅读 `AGENTS.md`、`README.md`、`CONTRIBUTING.md`（CLAUDE.md 要求）。

### 4.5 平台差异

- **TV（dpad）**：所有 TV 改动需实体/模拟 TV 手验（规范 §7 声明浏览器≠实体 TV）；改变 ↑ 的“隐藏控件”语义、焦点链（顶栏/跳过/进度条/底栏）、抽屉 ←→ 自动切页重建 `KeyedSubtree` 时焦点不能被 `requestFocus` 抢走；新按钮必须有稳定 `FocusNode`（`overlay_sheet.dart:552`）。
- **桌面**：E 的 TV 新右组仅 TV 生效（Q25 推荐），桌面保持现有按钮条；桌面多出音量/全屏/置顶/PIP，无需另做。桌面/宽屏详情纵向剧集列表是否改动见 Q08。
- **移动端**：投屏仅手机且仅 Android（非 Android/直播/离线/房间中显示不可用原因）；TV 无文件选择器（本地字幕、备份导入等需 TV 隐藏）；平板走手机控件，抽屉宽度 400 与统一 340 的取舍见 Q32。
- **后端差异**：字幕在线搜索仅 Plex（`track_controls.dart:225`）；`EpisodesDrawer` 需在 Jellyfin/Plex 两套后端都测；mpv/Exo 差异决定 5 档画面比例不能只改 UI。
- **性能**：玻璃/blur 效果受 `DevicePerformance.isReduced` 影响（`press_feedback.dart`），AppToast/导航改动要保持减少动态归零。
- **主题**：OLED 档 TV 默认纯黑，P1-1 不得影响。

### 4.6 ⚠冲突汇总

| 编号 | 冲突点 | 两边说法 | 本文处理 |
|---|---|---|---|
| ⚠1 | 行号基线 | B：HEAD 8b315ac；E：HEAD acf7d1b；用户给定实机基线 main@77ec375+912e8ab | 原样保留行号，开工前按符号重确认 |
| ⚠2 | 评分来源说明组件重复立项 | A 的 B1：新建 `widgets/rating_source_dialog.dart`（`RatingSourceDialog`），hero 接入；B 的 B3：新建 `widgets/rating_source_dialog.dart`（`showRatingSourceDialog`），strip 接入 | 合并为 P1-5 创建、P3-3 接入 |
| ⚠3 | 抽屉宽度 | E：统一 340（现状手机 318/平板 400/各入口 350、360），TV 约 30%；TV 对照笔记：580@1080p 待定；E P05-7 公式 `max(340,0.3*屏宽)` 约 576@1080p | 合并为 Q32，推荐 340 与 30% |
| ⚠4 | TV 投屏 | TV 对照笔记把投屏列为“缺直达入口”；E 的 P05-5/P04-2 与原型提交 acf7d1b 说明均为“TV 不提供投屏” | 按原型不提供，列入 Q33 确认 |
| ⚠5 | TV 内容条/快退快进/上下章 | TV 对照笔记：待定是否保留；E：P05-3 七按钮一致保留，P05-6 要求下线 ↓内容条；acf7d1b 提交说明：保留快退快进与上下章、合并选集与队列 | 按 E 与原型处理，列入 Q33 |
| ⚠6 | 自动隐藏 10s | TV 对照笔记：待定；E P05-10 把“10 秒无操作自动隐藏”列为原型要求，实机现值未给 | 待核实，列入 Q33 与 P7-2 验收 |
| ⚠7 | 弹幕无源引导 | D 的 U-03：无源时点开关是否直接弹出添加源“待验证”；E 的 P04-4：空配置直接进入“添加源”（`danmaku_settings_sheet.dart:99-109`），判为一致 | 待核实，P8-4 中先读代码 |
| ⚠8 | P05-2（进度条描边/首步长）归属 | E 的包 E 与包 F 都列了 | 归入 P7-2 |
| ⚠9 | 抽屉动画时长 | A 的 SHARED-02：`overlay_tokens.dart` 数值全一致（dialog 180ms）；E 的 P01-1：抽屉原型 240ms，实机 180ms | 不矛盾：dialog 180、edgeDrawer 新增 240，仅 edgeDrawer 使用新常量 |
| ⚠10 | 底栏第二项方案 B 含义不同 | A：搜索提为第 2 项、库放“…”或库页入口；C：新增跨库“搜索+浏览”页（L） | 在 Q02 中并列写出 |
| ⚠11 | i18n 语言数量 | C 写“20+ 语言”，E 写“9+ 语言” | 开工前核对 i18n 目录 |
| ⚠12 | 评分展示规范两处实现不一致 | A 的 HOME-01e：首页 hero 评分已是 icon+数值，一致；B 的 DETAIL-02a：详情 strip 仍是“数值+来源文字”两行 | 非冲突，需在 P3-2 对齐首页写法（复用 `InlineRatingBadges`） |

---

## 5. 附录：逐条对照表

以下表格整合自五份分组计划，**保持原文、文件:行号不变**，按模块分组。已去重：A 的 HOME-03a、HOME-03d 是纯引用行（分别指向 SHARED-NAV、SHARED-01d），已删去，其内容并入对应条目；各任务包建议表（A 的“建议任务包”、B/C/D/E 的包列表）已并入第 3 章，不重复列。


### 附录 A：全局与共享、首页（来源 A；实机路径前缀 `lib/`）

**全局与共享 (SHARED)**

| 编号 | 原型要求（简述） | 实机现状（文件:行号） | 差距 | 修改方案 | 工作量 | 依赖/风险 |
|---|---|---|---|---|---|---|
| SHARED-01a 主题 system/light/dark | 三态外观，默认跟随系统，跨页一致 | `main.dart:189-190,214-218` 提供 light/dark 主题；`providers/theme_provider.dart:16-68` 跟随系统；`settings_service.dart:50` 枚举为 system/light/dark/**oled** | 功能已一致。多出 OLED 档：spec 写"不新增 OLED 模式"，但它是已有功能，TV 默认就是 OLED（`settings_service.dart:922`） | 已一致。OLED 保留，需产品确认；记录为"已有功能，非新增" | S（仅确认） | 产品决策点：是否砍 OLED。建议保留 |
| SHARED-01b 底色与表面色 token | 深：bg #121212 / surface #202020 / text #f3f3ef / caption #adada8；浅：#f4f3ef / #fdfcf9 / #242424 / #686864 | `theme/mono_theme.dart:50-80` 深 bg #000000、surface #20212B、text #ECECF3、muted #A6A7B8；浅 bg #F1F0F6、surface #FFFFFF、text #2D2E40、muted #686B80（偏紫的珍珠灰） | **部分**。数值全部不同：spec 要中性灰，代码是带紫调。深色 bg 是纯黑。`test/theme/mono_theme_test.dart:59-60` 断言 bg=0xFF000000 | 改 `mono_theme.dart` 的 `c` 调色（深/浅两组），OLED 档保持纯黑；同步改 `mono_presentation.dart:77-91`（headerSurface/headerEdge/navigationSurface/navigationForeground）里写死的紫调色；更新 mono_theme_test 断言。建议先把这些色值收拢成 `VeloPalette` 常量（放 velo_brand.dart）再被两处引用 | M | **全局视觉回归**，所有页面底色变化；需逐页截图比对。与产品确认以 spec 为准（深色 bg 从 #000 变 #121212）。其余包（详情/设置/库）都依赖这一步 |
| SHARED-01c 字体字号层级 | 正文14 / 列表15 / 区块18 / 页标题22 / 说明12；TV 保留大字号 | `theme/mono_theme.dart:28-60` `_textTheme(compact)`：14/15/18/22/12 完全一致，TV 用 Material 大字；`mono_presentation.dart:44-50` pageTitle 22/TV 24 | 已一致 | 无 | S | 无 |
| SHARED-01d 圆角/间距 token | 卡片/字段14；紧凑菜单18；dialog/抽屉24 | `overlay_tokens.dart:4-5` 24/18 ✓；`app_select_field.dart:129,134` 字段 14 ✓；`mono_theme.dart:277-281` `MonoTokens` radiusSm 8 / radiusMd **12** / radiusLg 20；海报卡 `media_card.dart:631,1121` 用 radiusMd | **部分**。海报/媒体卡圆角 12，原型 14（`final-ui.css` `.poster-wrap{border-radius:14px}`）。没有一个叫"卡片圆角"的 token | 把 radiusMd 改 14（仅 10 处引用，需逐一确认影响），或新增 `MonoTokens.radiusCard=14` 只给海报卡/继续观看卡用（更安全）。focus 边框 `_posterFocusRadius`（`media_card.dart:1125`）同步 | S | 改 radiusMd 会连带别处，推荐新增 token 方案 |
| SHARED-01e 强调色（紫仅用于选中/焦点） | accent #6060f5；前景 深 #b4aaff/浅 #6256c8；选中底 深 #36324e/浅 #e9e5f6 | `theme/velo_brand.dart:5-14` 数值完全一致；`mono_theme.dart:107-125` 注入 colorScheme | 已一致 | 无 | S | 无 |
| SHARED-NAV 悬浮底部导航 | 手机悬浮 pill：高 56、圆角 30、距底 18、blur 28、宽跟屏(max 336/360)；四项 首页/搜索/一起看/设置；选中 selected 底 + focus 色；未选中 caption | `navigation/fusion_navigation.dart:56-100,112-190`：圆角 30 ✓、blur 28 ✓、minimum bottom 18 ✓、maxWidth 360（`mono_presentation.dart:11`）、选中底 `VeloBrand.selection` ✓、按压 .90。**实际高度 = 3+48+3 = 54**（`mono_presentation.dart:10` 的 `navigationHeight=56` 定义了但**未被引用**）。四项为 **首页/媒体库/一起看/设置 + "…"更多按钮**（`navigation_tabs.dart:11-16`）；搜索在首页顶栏图标（`discover_screen.dart:1010-1014`）。表面色 `navigationSurface` alpha .94，原型 88% | **部分**。(1) 高度 54≠56；(2) 第 2 项是"媒体库"而非"搜索"，且多一个"…"按钮；(3) 表面色/alpha 略不同 | 高度：让 `navigationHeight` 真正驱动容器（Container constraints minHeight 56）。第 2 项与"…"：需产品决策。方案 A：保持现有信息架构（库为主入口、搜索在首页顶栏/…菜单）并在 spec 备注；方案 B：按原型把"搜索"提为第 2 项，库放入"…"或库页另有入口。本计划建议 A，工作量小。表面色改用 SHARED-01b 的 surface 色 @88% | S（仅高度/色）；M（B） | 选 B 会牵动 `main_screen.dart` 的 tab 顺序、`primaryNavigationIds`、TV 侧栏、`fusion_navigation_test.dart` |
| SHARED-SRV 服务器图标来源标识 | Plex/Emby/Jellyfin 用仓库 SVG，无首字母头像；首页选服更新 logo | `widgets/backend_badge.dart`（`assets/plex_chevron.svg / jellyfin_icon.svg / emby_icon.svg`）；首页顶栏胶囊 `discover_screen.dart:850-870`，选服菜单 `:880-905`，媒体卡角标 `media_card.dart:1062,1282` | 已一致 | 无 | S | 无 |
| SHARED-02 居中对话框 | 居中、r24/紧凑 r18、max 560/720、inset 16、blur 22、深 90%/浅 94%、180ms；禁止底部滑入；Tab 约束/Esc 只关最上层/关闭回触发控件 | `theme/overlay_tokens.dart:3-13` 数值全一致；`widgets/app_dialog.dart:17-45`（AppDialog，Dialog 外包 AppGlassSurface）；`overlay_sheet.dart:107-118,198-300` 默认 `Alignment.center`，抽屉 `edgeDrawer`；仓库已无 `showModalBottomSheet` 调用（仅 `main.dart:1934` 注释） | **大体一致**。需核实：(1) 127 处 `OverlaySheetController` 调用里有无自带 bottom alignment；(2) 7 处 `showDialog` 是否都走 AppDialog；(3) `BottomSheetPageScaffold`/`bottom_sheet_*` 仅是命名遗留 | 做一次审计脚本：`grep -rn "Alignment.bottom\|showModalBottomSheet\|showDialog\|AlertDialog(" lib`，列出未走 AppDialog/OverlaySheet 的；补一个 widget 测试验证 Esc 只关最上层、焦点回触发控件（`overlay_sheet.dart` 已有 focus 逻辑，需确认回焦） | S（审计）+ S（测试） | 低风险；审计可能发现零星遗漏 |
| SHARED-03 顶部轻通知 toast | 顶部紧凑位置、短句+状态图标、长文换行；不从底部出；role=status、不抢焦点；连续触发不堆叠 | `utils/snackbar_helper.dart:20-156`：已有图标+glass 外观（r18、maxWidth 520），但仍是 `SnackBarBehavior.floating` = **底部**（`mono_theme.dart:255-263`），`showSnackBar` 直接排队不清旧的（只有 `showMainSnackBar:155` 调 `removeCurrentSnackBar`）；入口 69 个文件、28 处 ScaffoldMessenger；`profile_navigation_scope` 另有 main messenger 以浮在底栏上方 | **缺失（位置）**。视觉已统一，但位置是底部；连续触发会排队而非替换 | 新建 `AppToast`（Overlay 方案，放 `lib/widgets/app_toast.dart`）：顶部 safe-area+16 居中、`Semantics(liveRegion:true)`、`IgnorePointer`/不抢焦点、同一时刻最多 1 条（新替旧）、淡入 180ms、`disableAnimations` 归零。`snackbar_helper.dart` 的 5 个公共函数保持签名不变，内部改为调用 AppToast，所以 69 个调用点零改动。root 与 main 两个 messenger 路径统一为 root Overlay（`rootScaffoldMessengerKey` 保留以兼容）。播放器内 toast 需避开顶栏（`video_controls` 里有自己的 showAppSnackBar 调用） | M | 14 个测试文件涉及 SnackBar，需要迁移断言（find.byType(SnackBar)→find.byType(AppToast)）；TV 上 Overlay 无焦点，需确认不影响 D-pad；播放器 HUD 顶栏遮挡风险；通知迁移清单要逐文件审计，不能只换颜色 |
| SHARED-04 选择字段与锚定菜单 | 字段 r14、min58/compact52、padding 12×8、主15/500 次12 箭头20、选中描边2px、菜单行≥48 | `widgets/app_select_field.dart:129,134,175` r14 ✓、58/52 ✓；`anchored_option_menus.dart`、`app_menu.dart` | 已一致（播放器/设置的字段用法归其他模块核对） | 无 | S | 无 |
| SHARED-05a 可达性：焦点与选中分开 | 焦点/选中分开表达；同一时刻仅最上层可交互；图标按钮有名称 | `focus/*`（FocusableButton 等）、`focus_builders.dart`；首页顶栏 `_glassIconButton` 有 tooltip（`discover_screen.dart:1010-1022`）；导航 `Semantics(label)`（`fusion_navigation.dart:121-125`） | 已一致（抽样）；异步完成不抢焦点见 HOME-02 | 把"每个 IconButton 有 tooltip/semantic label"做成一次 grep 审计，不新增组件 | S | 无 |
| SHARED-05b 按压反馈 | 按压 .97、press 120ms/release 180ms、减少动态归零 | `theme/interaction_tokens.dart:4-14` 全一致（main .97、card .96、nav .90）；`widgets/press_feedback.dart:33-40` 处理 `disableAnimationsOf` 且 `DevicePerformance.isReduced` | 已一致。注意：仅 11 处使用 PressFeedback，普通 InkWell/ListTile 无统一反馈（`mono_theme` 用 NoSplash） | 现有范围内不改；若要全覆盖，另提"按钮/列表项统一包 PressFeedback"，属后续优化 | S | 无 |
| SHARED-CARD 海报卡 + 海报内评分 | 卡片 r14；评分角标 黑 80% 底、白字、r6、11px、padding 6×4，位置右下(bottom 4/right 5)；无分角标完全收起 | `widgets/media_ratings_strip.dart:108-143` MediaCardRatingBadge：padding 6×4 ✓、r6 ✓、11px ✓；但底色 `surfaceContainerHighest @.94`（浅色模式为白底）、文字 onSurface；位置 `media_card.dart:668-671` 为 **左下**(bottom 8, start 6)；无分不渲染 ✓（`:662-669`）；海报圆角 12（见 SHARED-01d） | **部分**。(1) 底色/字色：浅色模式下白底黑字，原型固定黑 80% + 白字（海报上的信息层不随主题变）；(2) 位置左下 vs 右下；(3) 圆角 12 vs 14 | 改 MediaCardRatingBadge 为固定 `Colors.black @.8` 背景 + 白字（保留 personal 图标用白/accent）；位置改 `PositionedDirectional(bottom:4, end:5)` 并确认不与 WatchedIndicator/未看数角标重叠（`watched_indicator.dart`、`unwatched_count_badge.dart` 位置）；圆角见 01d | S | 位置变化可能与右上角角标/进度条冲突；`test/screens/discover_screen_test.dart:1433-1453` 用 key 定位，不受影响 |
| SHARED-STATE 加载/空/错误状态 | 行级骨架固定尺寸；失败保留已有内容并局部重试；空态有文案 | `screens/discover_loading_skeleton.dart`（整页 + `DiscoverHubLoadingSkeleton`）；`screens/libraries/state_messages.dart:124,182` EmptyStateWidget/ErrorStateWidget；`content_state_builder.dart:9,51` Sliver 版；`widgets/ambient_skeleton.dart`、`skeleton_media_card.dart` | **部分**。骨架/空/错三类组件齐全；但错误是整页级（见 HOME-02），没有"行级局部失败+重试"组件 | 新增 `HubRowError`（行内：标题+"重试"按钮，高度与骨架行一致），放 `widgets/`；复用 `state_messages` 的文案与 FocusableButton。其余状态已一致 | S（组件）；与 HOME-02 合并 | 与 HOME-02 同包 |

**首页 (HOME)**

| 编号 | 原型要求（简述） | 实机现状（文件:行号） | 差距 | 修改方案 | 工作量 | 依赖/风险 |
|---|---|---|---|---|---|---|
| HOME-01a 通栏海报 + 布局 | 全幅海报；heroInset 24、bottom 28；片名居中；元信息在主视觉内；手机 548 高 | `widgets/fusion_home_hero.dart:~110-190`：全幅 Stack、居中、左右 20(平板 32)、bottom 28；高度 `mono_presentation.dart:touchHeroHeight` = 屏高 65%（≥500+top）；`discover_screen.dart:1391-1440` | **部分**。左右 inset 20 vs 24 | 把 hero 文案区左右改 24（平板 32 不变）；高度保持比例方案（比固定 548 更适配），不改 | S | 无 |
| HOME-01b 片名字号 | spec：标题 42，窄屏 37；原型 CSS 实际 45 | `theme/home_typography.dart:36-40` heroTitle 手机 45/平板 48/TV 48；`fusion_home_hero.dart` fallbackTitle 44/48 | **部分**。spec 文字(42/37)与原型 CSS(45)自相矛盾；代码=原型 CSS | 先向设计确认以哪个为准。若按 spec：手机 42，宽<360 时 37，改 `home_typography.dart` 与 `fusion_home_hero.dart` 两处 | S | 需先澄清；FittingTitleText 已处理溢出 |
| HOME-01c 真实像素取色 | 32×32 canvas，滤低值/低饱和像素，保持亮度，压缩高饱和；缓存；从当前显示色插值；旧请求不覆盖新选择 | `utils/ambient_palette_extractor.dart:20-60` 32×32 采样、取底边 15% 区域、缓存 128；`navigation/home_theme.dart:21-60` generation 防旧结果覆盖、待定时保留上一个色；`test/navigation/home_theme_test.dart` | 已一致（算法细节与原型不同但目标相同） | 无；可补一条"快速切换不回闪"回归测试（若 home_theme_test 未覆盖） | S | 无 |
| HOME-01d 滑动切换、无箭头 | 左右滑动 + 圆点；无左右箭头；键盘/TV 方向键 | `discover_screen.dart:1411-1425` PageView（滑动）；圆点 `:1446-1520`（带自动轮播进度，TV 隐藏）；`HorizontalScrollWithArrows` 仅用于 hub 行（`hub_section.dart:708`），hero 无箭头 | 已一致。差异：代码有自动轮播（`_resetAutoScrollTimer`），原型无自动切换 | 无；自动轮播保留（已有设置/无障碍暂停动作），在 spec 备注 | S | 无 |
| HOME-01e 评分 icon+数值 | 评分仅 icon + 数值，不显平台/类型名；缺分不显示 0.0；未知来源中性 icon | `widgets/hero_metadata_badges.dart:42-47` `InlineRatingBadges`（品牌 SVG 图标+数值）；无分不渲染；未知来源星标（`media_rating_badge.dart` `_buildContent`） | 已一致 | 无 | S | 无 |
| HOME-01f 评分来源说明 | 点击主视觉评分打开说明 dialog；不增加首页投屏入口 | hero 评分无 onTap（`hero_metadata_badges.dart` 无手势）；`MediaRatingsStrip` 详情评分同样不可点；仓库内无"评分来源说明"组件；首页顶栏无投屏入口 ✓ | **缺失**（来源说明） | 新增 `RatingSourceDialog`（用 AppDialog，列出当前条目的各评分源：图标+名称+数值+一句说明，文案走 i18n，`ratingSourceLabel` 已有名称）；hero 里把评分 Row 包成可点击+Semantics button，打开该 dialog；详情页评分条后续复用（属详情模块） | M | 需新增 i18n 文案（多语言文件批量）；TV 上评分需可聚焦，注意 hero 焦点链；hero 的 GestureDetector 整体 onTap=播放，需让评分区域吞掉点击 |
| HOME-01g 顶栏（服务器胶囊 + 搜索 + 更多） | 左上服务器胶囊（logo+名称+下拉），右上搜索与"更多"玻璃按钮 | `discover_screen.dart:996-1022` 手机顶栏：用户/服务器胶囊（`:840-870`）+ 搜索 + 选项（`mainScope.openNavigation`）；玻璃按钮 `:972-990`，40px 圆形；菜单 `:880-960` | 已一致 | 无 | S | 无 |
| HOME-02a 逐库加载、先到先用 | 行级骨架固定尺寸；各库独立到达 | `providers/discover_provider.dart:562-580` 按服务器 `onProgress` 渐进发布 on-deck 与 hubs；`discover_screen.dart:1186-1190,1257-1259` 首屏骨架 vs hub 骨架分层；spec 自己写明"同服逐库发布仍属后续" | 部分一致（多服渐进已有，同服内逐库发布未做，spec 认定为后续任务 PERF-02/05/06） | 本包不做同服逐库；仅确认骨架行高与真实行一致（`discover_loading_skeleton.dart` cardWidth 111 与 `discover_screen.dart:1273-1277` 一致 ✓） | S（确认） | 同服逐库属性能包，不并入 |
| HOME-02b 失败保旧 + 局部重试 | 局部失败保留已有卡片；失败行提供行内重试；重试不抢焦点 | `discover_screen.dart:162,1237,1363` 错误是**整页**：`_errorMessage` 非空时整个内容区被 `SliverErrorState` 替代；部分服务器失败仅 `appLogger.w`（`:753`）；provider 无按行/按服务器失败状态 | **缺失** | provider 增加 `failedServerIds`/`failedHubs`（`discover_provider.dart` 已有 `partial.succeededServerIds`，补 failed 集合）；`discover_screen.dart` 在已有行之后/对应位置渲染 `HubRowError`（见 SHARED-STATE），点击只重载该服务器；保留已显示卡片；重试期间不 requestFocus。全失败且无任何内容时仍用整页 `SliverErrorState` | L | 动 `DiscoverProvider` 数据流，需新增 provider 单元测试；TV 版同需 `TvBrowseRail` 对应行内重试；焦点保持 |
| HOME-02c 切服务器丢弃旧结果 | 切服务器清空旧内容 | `discover_screen.dart:921-935` `source:` 切换：重置 heroIndex、`_updateHubKeys`、重取主题；provider 按 pass 校验 `currentPass()`（`discover_provider.dart:562`） | 已一致 | 无 | S | 无 |
| HOME-02d 评分补全不移动卡片/焦点 | 后补评分只更新节点内容 | 角标是 Stack 覆盖层（`media_card.dart:662-675`）不占布局，加载完不会改变卡片尺寸 ✓ | 已一致 | 无 | S | 无 |
| HOME-03b 继续观看卡 | 继续观看进度可读；无角标评分；横向浏览不挤压 | `discover_screen.dart:1241-1262` 继续观看 hub：卡宽 min(224, 62%屏宽)、剧集缩略图、`showWatchProgress`；`media_card.dart:664-668` 继续观看不显评分 ✓；`media_progress_bar.dart`、`watched_indicator.dart` | 已一致（进度条样式需视觉核对，但结构一致） | 视觉回归时截图对比 `previews/final-v1/home.png` | S | 无 |
| HOME-03c 分区/媒体行 | 每行：区块标题 18、横向卡片、露出下一张；卡宽 | `home_typography.dart:43-46` sectionTitle 18(手机)；`discover_screen.dart:1273-1277` 手机卡宽 min(111, 33%屏宽)；`hub_section.dart:708+` 横向 ListView，内边距 12/8/27；原型海报 105 宽 | 已一致（宽度 111 vs 105 微差，视觉回归决定） | 无 | S | 无 |
| HOME-TV TV 版首页 | 左信息、右大图、顶部入口；卡片获焦更新海报；方向键 | `discover_screen.dart:1339-1392` `_buildTvContent` → `TvSpotlightScaffold`（`widgets/tv_spotlight_scaffold.dart`）+ `TvBrowseRail`；焦点驱动 `_setSpotlightItem` 同步 HomeTheme（`:305`）；TV 导航 `FusionNavigation(isTv)` 顶部、r24、min 680 宽；TV 加载/错误/空态 `:1355-1376` | 已一致（TV 结构一致；实体 TV 验证 spec 另列） | 无代码改动；TV 沿用 SHARED-01b 色值后做截图比对 | S | 实体 TV 验证属验收，不在本计划内 |

### 附录 B：详情（来源 B；行号基线 HEAD 8b315ac）

**1. Hero 信息组与评分（DETAIL-01 / 02）**

| 编号 | 原型要求（简述） | 实机现状（文件:行号） | 差距 | 修改方案 | 工作量 | 依赖/风险 |
|---|---|---|---|---|---|---|
| DETAIL-01a 评分位置与唯一性 | title→metadata→ratings→actions；评分在 hero 内，播放之前；全页仅一处 | 手机/平板：presentation.dart:195-223 `_buildCompactDetailHeader` 在 metadata 之后放 `MediaRatingsStrip`，再放 18px 间距与 actions；TV：responsive_layout.dart:156-166 放在 `_tvDetailRatingsGroupKey`。无 hero 外重复块 | 位置已一致（**已一致**）。唯一附加：个人评分 chip（`_buildUserRatingChip` presentation.dart:~213、action_buttons.dart:~497）出现在 actions 内/上，原型无此项 | 保留（真实功能：Plex/Jellyfin 评分/收藏入口），验收时确认它不算第二条“评分条”；如需严格只留一处，可把 chip 并入更多菜单（先与产品确认） | S | 个人评分入口属既有功能，不删 |
| DETAIL-01b 无分整条收起 | 无分数时整条消失，不留空白 | media_ratings_strip.dart:57-58 空返回 `SizedBox.shrink()`；presentation.dart:221 外无多余 padding（紧随的 18px SizedBox 固定在 :222） | 部分：strip 本身收起，但其后固定 `SizedBox(18)`；metadata→actions 间距在无分时与有分时一致不用动；需核对无 metadata 时标题与按钮不重叠 | 无分/有分各拍一张截图；若间距不符把 18 拆到 strip 内 padding | S | — |
| DETAIL-01c 标题与播放不重叠 / 说明弹窗不改变页面位置 | 点分数打开居中 dialog，开关不动页面 | strip 无任何点击（media_ratings_strip.dart:63-100 只有 Semantics+Column），无说明 dialog。rating_bottom_sheet.dart 是“个人评分”sheet，不是来源说明 | **缺失**：点击分数的说明 dialog（来源/尺度/服务器评分/来源未标注） | 新增 `showRatingSourceDialog(context, ratings)`（复用 app_dialog.dart 的居中 dialog 与现有 `ratingSourceLabel`/i18n），strip 每格包 `InkWell`/FocusableWrapper；新增 i18n 串（zh/en 等，运行 slang 生成）；TV 格需可聚焦 | M | 依赖批次 A 的 SHARED dialog 规范；TV 焦点链（上=信息、下=个人评分/播放）要保持；i18n 多语言 |
| DETAIL-02a 紧凑评分条：只图标+分数 | 主界面仅 icon+数值（18px/600 等宽数字、18px 图标），不显示平台名/类型/示例；品牌 icon 来源明确才用，未知来源中性 icon | media_ratings_strip.dart:73-91 为“上数值、下来源文字(11px, 最多3行)”两行布局，数值纯文本无图标；`ratingSourceLabel(...) ?? t.settings.otherRatingSources` 作可见副标签 | **缺失/相反**：需移除可见来源标签，改为图标+数值横排。已有可复用：media_rating_badge.dart `InlineRatingBadges`/`ratingInfoForSource`(rating_utils.dart:~20-40 imdb/tmdb/RT svg + `iconAspect`)；source=='' 时需补中性星标 icon（`Symbols.star_rounded` 琥珀色，原型 #f5c544） | 重写 strip 单元为 `Row(icon 18, gap 6, value 18/600 tabular)`；无品牌 asset 的来源（critic/audience/simkl/mal/anilist/trakt/空）用中性星标；个人评分仍用 person icon；保留 `ratingsSemanticLabel` 作 aria，补充“服务器评分/来源未标注”文案 | M | 更新 test/screens/media_detail/media_ratings_strip_test.dart、tv_spotlight_ratings_test.dart、fitted_metadata_line_test 的 iconAspect 检查；TV spotlight（tv_spotlight_background.dart）也引用 strip |
| DETAIL-02b 尺寸/分隔/最多4项 | 格内纵 5×横 12、最小宽 88；格间 1px 分隔线(前景16%)；不用独立大卡；最多 4 项 | media_ratings_strip.dart:31-36 列宽按 76 计，格高 78×scale；padding 水平 3；`RatingDisplayPolicy.detailLimit=4`（rating_display_policy.dart:19）；无分隔线 | 部分：最多4已一致；最小宽 76→88、格 padding→纵5横12、高度 78 固定槽→按内容（原型 min-height 48）、新增细分隔线 | 改 `columnsFor`(76→88)、`heightFor`(去掉 78 固定高，改 min 48×textScale)，格间加 `VerticalDivider`(foreground α.16)；`heightFor` 的外部调用方（grep）同步 | M | strip 注释写“reserved region”为避免布局抖动保留了固定高度，改动后需验证 loading→有分时 hero 不跳动（hero 底对齐 Align.bottom，实际上会上移，需截图确认） |
| DETAIL-02c 无障碍/文案规范 | aria-label 写“服务器评分/来源未标注”+mock 属性；10分制与百分比不混；服务器徽标不能冒充评分提供方 | media_ratings_strip.dart:64 `ratingsSemanticLabel`（media_rating_badge.dart:~55）对未知来源输出 `t.discover.rating 值/10`；RT/TMDB 百分比由 `ratingInfoForSource` 处理（rating_utils.dart:30-38 已按 % 格式化） | 部分：尺度已区分；未知来源标签应改“来源未标注”类措辞；服务器徽标未参与评分（已一致） | 调整 `ratingsSemanticLabel` null 分支文案 + i18n | S | 与 02a 同改 |
| DETAIL-02d TV 评分对齐 | TV 左对齐，首项 padding-left 0 | responsive_layout.dart:161 TV 调用未传 `alignment`，默认 `WrapAlignment.center`（media_ratings_strip.dart:28） | 缺失：TV 居中而非左对齐 | TV 传 `alignment: WrapAlignment.start` 并让首格左 padding 0 | S | 与 02b 同包 |

**2. 动作与内容层次（DETAIL-03）+ 收藏/已看加载态**

| 编号 | 原型要求（简述） | 实机现状（文件:行号） | 差距 | 修改方案 | 工作量 | 依赖/风险 |
|---|---|---|---|---|---|---|
| DETAIL-03a 内容宽 560、标题 36/窄 32、actionGap 12 | detail-copy 宽 560；标题 36（窄 32）；动作间距 12 | presentation.dart:155-190 `_buildNaturalDetailTitle`：窄屏居中 40、桌面 48、TV 64×scale；responsive_layout.dart:106 `maxWidth: 720`；action_buttons.dart:~273 `gap = isTv ? 8*tvScale : 12`，手机紧凑行 spacing 8/16（:~503） | 部分：gap(非 TV) 一致；标题字号、内容宽度与原型不同 | 手机/平板 40→32、桌面 48→36、内容宽 720→560；TV 64×scale→36×scale（确认 TV 是否按设计缩放，原型 TV 36）；logo 标题高度(100)随之调整 | M | **风险：** 真实 App 现行标题更大，是整体视觉降级，需产品确认以原型为准；logo 路径 `_buildDetailLogoOrTitle` 宽 400 一并核对；多处测试断言字号/宽度 |
| DETAIL-03b 播放按钮浅底深字、始终可达 | 播放浅底深字 | action_buttons.dart:~240 `whitePlayStyle` #f4f5f6/#202126，进度条背景；紧凑模式整行宽度 `detail_primary_play` | **已一致**（含续播进度背景，属实机扩展，原型无） | 无 | — | — |
| DETAIL-03c 动作行（收藏/已看/更多） | 播放下方一行：收藏(心)、已看(旗)，更多在顶栏 | action_buttons.dart:~498-530 紧凑：`[download, favorite|watchlist, watched, more]` 图标行（间距 16/8）；TV/桌面 `allActions` 同行 | 部分：实机多出下载/更多；原型“更多”在顶栏。属功能保留项 | 保留；仅核对图标样式/透明背景与原型一致，顶栏 more 位置可不动 | S | 原型说明“保留既有原型动作”，不强迫删除 |
| DETAIL-03d 说明采用居中 dialog、长正文滚动 | 详情说明走居中 dialog | 手机详情正文用 `CollapsibleText`（media_detail_screen.dart:~3388，内联展开）；TV 点信息区 `_openTvDetailsSheet`（responsive_layout.dart:~89 → media_details_sheet.dart，sheet）；个人评分用 OverlaySheet（presentation 无，media_detail_screen.dart:~1196 `OverlaySheetController.show`） | 部分：手机内联展开已符合原型（原型“展开”也是内联）；TV 详情与个人评分为 sheet/overlay 而非居中 dialog | 与批次 A 统一后，把 TV 详情说明与评分来源说明改为居中 dialog（`app_dialog.dart`），含内部滚动 | M | 依赖批次 A 的 dialog 规范；TV 焦点返回 |
| DETAIL-X1 收藏加载态（新） | 点击后按钮转圈、禁用，等响应后切换并 toast；取消为“已取消” | action_buttons.dart:~487-495 favorite → presentation.dart:123-137 `_toggleDetailFavorite`：直接 `await setFavorite` 后 `setState`，**无 busy 态、无禁用、成功无 toast**；仅失败 snackbar；并发连点会重复请求 | **缺失** | 新增 `_favoritePending` 标志(Set/bool)；按钮 `onPressed: pending ? null : …`，icon 换为 18px `CircularProgressIndicator`（复用 play 按钮的 :~320 写法）、`Semantics(busy)`；成功 `showSuccessSnackBar`(已收藏/已取消，新 i18n 或复用 t.rateSheet.favorited)；失败保持旧状态并报错 | M | 离线时不显示（已 return）；watchlist 备选路径(`watchlistAction`)已有 `_watchlistMutationInFlight` 但无视觉态，一并加转圈；TV 焦点在转圈期间不能丢（disable 时用 `canRequestFocus` 仍可聚焦的 busy 样式而非 `onPressed:null`）|
| DETAIL-X2 已看加载态（新） | 同上，已看按钮转圈/禁用，响应后切换+toast | action_buttons.dart:332-352 `_handleWatchedTogglePressed`：有 toast（success/offline snackbar）但**无 pending 态**；按钮 :354-370 无 loading，可连点 | 部分：toast 已有；缺转圈+禁用+防重入 | 同 X1：`_watchedPending`，`_buildWatchedToggleButton` 显示转圈、onPressed 置空；`finally` 复位；`WatchActions.setWatched`(搜索 lib/utils 之外的定义)无需改 | S | 与 X1 共用 `DetailActionIcon` 的 busy 变体，可新增 `DetailActionIcon.busy`；`_watchStateChanged` 逻辑不动 |

**3. 连续剧集与自动分组（DETAIL-04）**

| 编号 | 原型要求（简述） | 实机现状（文件:行号） | 差距 | 修改方案 | 工作量 | 依赖/风险 |
|---|---|---|---|---|---|---|
| DETAIL-04a 连续横向列表，不分页互斥 | 整季一次渲染成横向连续列表，滑过 10 自然接 11 | presentation.dart:259-263 `_buildDetailEpisodeRail`：`_episodes.skip(group*10).take(10)` 只渲染当前组 10 集，**互斥分页**；仅 `_usesCompactHero` 且非 `_detailAllEpisodes` 时使用（media_detail_screen.dart:2697-2702） | **缺失（核心差距）** | 重构为单一 `ListView.builder` 横向，itemCount=_episodes.length(+懒加载尾卡)；卡片宽 202+gap12 固定，便于由 offset 反推可见集；抽出 `DetailEpisodeRail` 独立 widget + 纯函数 `groupForEpisodeIndex(i)=i~/10`，利于单测 | L | 现有懒加载分页（`_episodeListHasMore`、`_loadMoreEpisodeList`、`_episodeTailKey`）与“10集一组”有冲突：组数据未全部加载时分组按已知总数(`_allEpisodesTotal`/season.leafCount)计算，点到未加载组需先加载到该位置；焦点节点 `_episodeListFocusNode(index: start+index)` 改用全局 index |
| DETAIL-04b 自由滚动按左缘最近卡计算组 | floor((ep−1)/10)，正反同步 | 无滚动监听；组由 `_detailEpisodeGroup` 手动设定（presentation.dart:402-428、media_detail_screen.dart:2748） | **缺失** | ScrollController listener：`index=round(offset/(202+12))`（或 `ScrollNotification`）→ `group=index~/10`，只在变化时 setState（用 `ValueNotifier<int>` 只重建分组条，避免整页重建）；rAF 等价用 `addPostFrameCallback` | M | 与 04a 同包 |
| DETAIL-04c 点分组只滚到首集，不改当前播放集；点集才更新选中 | 点组→`scrollToEpisode(group*10+1)`；点集→播放/选中 | presentation.dart:402-428 点组仅切换分页（不改选中，**行为部分一致**）；`_selectDetailEpisode`（:251）点集更新选中并 `_playbackStatusRevision++`（**一致**）；`onLongPress` 直接播放（实机扩展） | 部分：点组现为替换分页而非滚动 | 点组 → `controller.animateTo(group*10*(202+12))`（reduced motion 用 jumpTo，检查 `MediaQuery.disableAnimations`） | S | 并入 04a |
| DETAIL-04d 末组不足 10、首尾不越界、无空集 | 末组如 21–27，不生成空集 | presentation.dart:405 `(len+9)~/10` 组数、:420 `min((i+1)*10,len)` 末组标签正确；`group.clamp` :260（**一致**）；分页加载更多按钮 :430-434（实机扩展） | **已一致**（改成连续列表后需保持）；“加载更多”在分组条尾部 | 保持标签函数不变并加单测（23/27/30/12集） | S | — |
| DETAIL-04e 换季重置 | currentEpisode=1 / group=0 / scrollLeft=0 | `_selectSeason`（media_detail_screen.dart:~1982-2000）：`_detailSelectedEpisode=null; _detailEpisodeGroup=0` 并在加载后 `_selectDetailEpisode(first)`；**scrollLeft 无重置**（目前每次重建 ListView 自然归零，改为持久 controller 后需显式 jumpTo(0)） | 部分 | 换季与 `_detailAllEpisodes` 返回时 `rail.reset()`；`_selectedSeasonIndex` 变化时 jumpTo(0) | S | 并入 04a |
| DETAIL-04f 全部选集与横排总数一致 | “查看全部”列表总数=横排总数 | presentation.dart:100-118 “查看全部”→`_detailAllEpisodes=true`→media_detail_screen.dart:2697+ 纵向 `EpisodeCard` 列表（同一 `_episodes`）；原型为底部 sheet 的集数网格（`data-all-episodes`） | 部分：数据源同一(一致)，形态不同（纵向详情卡 vs 原型网格 sheet）。实机纵向列表信息更多，且点卡片选中后回到横排并 `group=index~/10`（:2748，会随新方案改为滚动到该集） | 数据一致；形态保留实机纵向列表（需产品确认）；点选后回横排时改为 `scrollTo(index)` | S | 产品确认是否改成原型网格 |
| DETAIL-04g 手机按可见集 / TV 按焦点集，焦点 10→11 立即切组 | TV 方向键焦点集决定组；程序滚动不回写旧组；wheel/touch 退出 focusMode | **TV 不使用此横排**：TV 用每季一个 `MediaHub`（media_detail_screen.dart:4021-4060 `_tvDetailHubs`，tv_browse_rail），无分组条；桌面/宽屏(`!_usesCompactHero`)使用纵向 `EpisodeCard` 全列表（:2697-2770） | **缺失**：TV 与桌面无“自动分组”；原型 TV 也是单行横排+分组 | 先做手机/平板（`DetailEpisodeRail`）；TV 若要对齐：在 `tv_browse_rail` 的季 hub 顶部加分组 chips，以 `_tvDetailFocusedEpisode`(:389) 判组，需输入来源跟踪（可复用 `InputModeTracker`）。建议 TV 另立后续包，先和产品确认是否必须 | L(TV) | 风险高：D-pad 焦点系统复杂，已有大量 TV 测试（media_detail_screen_test.dart 的 TV 用例 584/1099/1229/2176/2870…）；桌面纵向列表是否也要改横排需产品确认 |
| DETAIL-04h 分组条样式 | 圆角胶囊 `11–20`，当前高亮 | presentation.dart:402-428 `TabChipStrip` 胶囊 α.125/.035，字号 11（原型截图同风格） | **已一致**（视觉） | 加“当前组”`Semantics(selected)` | S | — |

**4. 多版本选择 / 音轨字幕预选 / 媒体信息**

| 编号 | 原型要求（简述） | 实机现状（文件:行号） | 差距 | 修改方案 | 工作量 | 依赖/风险 |
|---|---|---|---|---|---|---|
| DETAIL-X3 版本入口 | 单行紧凑条：服务器 logo + “1080p·H264”+“N 个版本”+ chevron；点开 dialog/sheet“选择播放版本”，行内含服务器 logo、版本、副标题(默认线路/大小)、选中勾 | playback_selectors.dart:18-211 三个并排/竖排 `AppSelectField`（版本/音轨/字幕，各自 label+value+busy），`detail_source_version` 选项 label=`version.displayLabel`，subtitle=“第 n/共 m 个”(:68-75)；`_selectDetailVersion`(:213) 保存偏好 | 部分：功能(多版本选择、偏好保存、探测 busy)齐全；形态与原型不同——原型只有一行摘要，无音轨/字幕字段（原型 PLAYER-01 才有双行轨道字段） | 保留三选择器（真实需求“预选”），按原型样式微调：版本字段增加服务器 logo（`backend_badge.dart`/`catalog_source_logo.dart` 现成）、摘要显示“分辨率·编码 · N 个版本”、选项 subtitle 改“默认线路/备用·大小”；单版本时隐藏“N 个版本”和 chevron | M | 需产品确认：详情页是否保留音轨/字幕预选（建议保留，属真实功能）；`AppSelectField` 已属批次 A(SHARED) 范围，避免重复改 |
| DETAIL-X4 音轨/字幕预选 | 原型详情无此字段；PLAYER 里为双行字段 | playback_selectors.dart:94-131 音轨/字幕字段 + `DetailPlaybackSelection`(playback_selection.dart) + `previewPlaybackTracks`；选择传入 `navigateToVideoPlayerWithRefresh`(action_buttons.dart:~60-82) | **已一致**（原型无要求，功能保持）；与 PLAYER-01 的双行(primary/secondary)标签已用 `track.label.primary/secondary`（:106-111） | 无；检查 PLAYER 批次的 label 规则同步 | — | 归 PLAYER 批次联动 |
| DETAIL-X5 媒体信息 | 卡片横滚：图标+标题+键值对(“视频：…”)，宽 235、圆角16、padding15 | presentation.dart:227-245 `_buildDetailTechnicalInfo` → widgets/media_detail_technical_info.dart(228 行)；section 标题“视频 · 音频 · 字幕”(media_detail_screen.dart:~3550)；下方 info rows(`_buildInfoRow` 工作室等) | 待核：卡片尺寸/样式未逐项核（只读未展开 media_detail_technical_info.dart 的 build）；结构上已是同类横向卡片 | 开发时对照 ui.css `.media-info`(235/r16/p15/dt 11px)逐项量；预计只需样式微调 | S | 需截图比对，本次未量 |

**5. 电影无剧集布局 / 演员 / 相关推荐 / TV**

| 编号 | 原型要求（简述） | 实机现状（文件:行号） | 差距 | 修改方案 | 工作量 | 依赖/风险 |
|---|---|---|---|---|---|---|
| DETAIL-X6 电影无剧集布局 | 电影：标题→元信息→评分→播放(无“第N集”)→版本→简介→演员→类型→相关→媒体信息；无季/剧集区 | media_detail_screen.dart:3381-3560：剧集块受 `isShow`/`metadata.isSeason` 门控(:3414/:3469)，电影跳过；播放文案由 `_getPlayButtonLabel` 决定（无集号）；顺序=选择器→简介→(季/集)→演员→类型→extras→related→技术信息→info rows | **已一致**（顺序等价；实机多 extras/info rows 属真实数据） | 仅需截图对照 detail-movie.png（空演员文案“此示例未载入演员资料”是原型 mock，真实无角色时整段隐藏 :3503，保持） | S | — |
| DETAIL-X7 演员 | 横排圆角方形头像+名+角色(voice)，标题“演员” | media_detail_screen.dart:4495-4509 `CastMemberStrip`（cardWidth 65/88，portraitBorderRadius 14，compact）；cast_member_strip.dart | **已一致**（样式近似；原型标题“演员人员”为原型文案，不照搬） | 截图复核头像尺寸 | S | — |
| DETAIL-X8 类型 chips / 相关影片 | 类型胶囊、相关影片“全部 >” | :3516-3526 `Chip` 类型；:3541-3555 `HubSection` related（带 more/focus） | **已一致** | — | — | — |
| DETAIL-X9 TV 详情整体 | 左下信息组：标题36→元信息→(评分)→播放+图标→版本行→季选择→横排剧集 | responsive_layout.dart:66-176 `_buildTvDetailForeground`（标题 64、信息区可点开 sheet、评分居中、动作行、选择器），剧集在下方 `tv_browse_rail` hubs（:3648、4021） | 部分：结构一致；标题 64 vs 36、评分居中 vs 左、无分组条、评分 strip 样式同 §1；信息区点击为 sheet | 随 §1/§2 修改；TV 评分左对齐；标题字号确认 | M | 依赖 DETAIL-03a/04g；TV 测试多 |

### 附录 C：搜索/媒体库与一起看（来源 C；实机路径前缀 `lib/`）

**0. 信息架构差异（原型“搜索” vs 实机“媒体库”）**

| 项 | 原型 | 实机 | 结论 |
|---|---|---|---|
| 底栏 4 项 | 首页 / **搜索** / 一起看 / 设置（ui.js:12 entries；icon 为 library 图标，页标题“搜索”，页内=全库海报墙+五行筛选+搜索框+服务器选择） | `navigation/navigation_tabs.dart:13-17 primaryNavigationIds` = discover / **libraries(媒体库)** / together / settings；搜索是独立 tab `NavigationTabId.search`（`:127`），不在底栏：手机从首页 hero 右上角放大镜进入（`screens/discover_screen.dart:1014`），TV 由 `navigation/fusion_navigation.dart:53-55` 把 search 插到倒数第二，桌面在 `widgets/side_navigation_rail.dart:1104` | 原型把“按条件浏览（筛选/排序）”和“按关键词搜索”合并到同一页并命名“搜索”；实机拆成两页：媒体库=单库浏览（推荐/浏览/合集/播放列表 tab，`libraries_screen.dart`），搜索=关键词命中列表（`search_screen.dart`，ListView 命中 + 类型 chip 全部/各类型/人物） |
| 范围 | 跨服务器合并（“所有服务器/Emby/Jellyfin/Plex”选择，library.js:服务器 sheet） | 单个媒体库为单位，标题处下拉选库、可按服务器分组（`libraries_screen.dart:787 _buildLibraryDropdownTitle`） | 数据语义不同，不能直接把“类型行 全部/电视剧/电影/动漫/综艺…”平移：实机类型来自库本身（movie/show/music），非跨库类型 |
| 建议 | — | — | **推荐方案 A（保持实机 IA，不改名）**：底栏第二项保留“媒体库”，视觉/筛选行对齐原型；搜索保持独立入口。理由：spec §6 写明“保留既有筛选行为，不改服务器查询语义”“不改已有服务协议或功能”，改名/合并会触及导航持久化（startup 偏好用 NavigationTabId 稳定 id，`settings_service.dart:1643`）与 i18n。**备选 B**：新增“全部媒体”跨库浏览视图（L，需合并多服务器分页，改动查询语义，与 spec 冲突）。**备选 C**：仅把底栏文案改“搜索”——不推荐，会误导（进入后是库浏览）。→ 需用户拍板（见末尾决策点）。 |

**1. 搜索 / 媒体库（LIB-01）**

| 编号 | 原型要求（简述） | 实机现状（文件:行号） | 差距 | 修改方案 | 工作量 | 依赖/风险 |
|---|---|---|---|---|---|---|
| LIB-01.a 视觉 token | 页标题22；选择与 focus 用 Velo 紫 #6060f5；卡片/字段 r14 | 页标题 `MonoPresentation.pageTitle`（`search_screen.dart:551`）；紫色 `theme/velo_brand.dart:6 accent=0xff6060f5`；筛选 tag 选中色 `library_quick_filters.dart` `_Tag` 用 `colorScheme.primary` alpha .14（原型选中底深#36324e/浅#e9e5f6，前景 #b4aaff/#6256c8） | 已一致（紫色来源一致）。选中底色用 alpha .14 而非 spec 的 selected 色值，属细微差 | 若 SHARED 批提供 `VeloBrand.selectedBg/selectedFg` token，则 `_Tag` 改用；否则保持 | S | 依赖 SHARED 批 token；不阻塞 |
| LIB-01.b 五行标签：排序行 | 排序行（最新更新/最新上映/评分），选中紫胶囊，点同项切升降 | `library_quick_filters.dart` `_TagRow` 排序行：遍历后端 `sorts`，点选中项反转方向（~:56-68）；仅手机 `_usesMobileBrowseOptions`（`library_browse_tab.dart:1548,1841`） | 已一致（行为更全，后端 sort 全列出而非 3 项） | 无 | — | 平板/桌面走 chips bar 而非标签行（原型只有手机/TV） |
| LIB-01.c 五行标签：类型/地区/年份行 | 类型(genre)、地区、年份各一行，行首标签=不限，值横滑，选中紫胶囊 | `library_quick_filters.dart:~40-48` 取 `['genre','country','year']` 有值列表的 filter，`_QuickFilterValues` 行首 tag=不限(`selected: clauses.isEmpty`)，`values.take(24)`，末尾“选项”→`onMore` 打开完整筛选 sheet；高度<500 或键盘弹出时整体隐藏 | 已一致（数据来自后端 filter 值，不推断；多一个“选项”入口，保留） | 无 | — | 值多于 24 个被截断，需靠“选项”进入 |
| LIB-01.d 五行标签：“类型”(全部/电视剧/电影/动漫/综艺/演唱会/纪录/音乐) | 第一行媒体大类（跨库类型） | 无。库自身决定类型；仅 TV/剧集库有分组 chips（`_buildChipsBar`，grouping=shows/seasons/episodes，菜单入口 `_showGroupingBottomSheet:1100`） | 缺失（概念性差异，跨库大类在单库视图里没有意义） | 方案 A：不做；方案 B：新增跨库视图时才有。若要在单库内给出等价“分组”一行，可把 grouping 作为第一行 `_Tag` 行复用 `_buildGroupingBottomSheet` 的数据（M） | S(不做)/M | 取决 IA 决策 |
| LIB-01.e 搜索框 | 标题下方搜索框，输入即过滤；TV 放在标题右侧 | 库内 `_buildSearchField`（`library_browse_tab.dart:1877`，FocusableTextField，hint `t.libraries.searchHint`，带清除）；防抖 `_searchDebounce`；TV 放左 220 宽面板顶部（`:1832,1933`） | 手机已一致；TV 位置不同（左栏 vs 标题右侧） | 手机无需改；TV 见 LIB-01.k | — | — |
| LIB-01.f 三列海报墙（手机） | 390 宽 3 列，评分“N分”右下角，副标“共N季/年份” | `utils/grid_size_calculator.dart:11-19` 手机 maxExtent lerp(100,200,density) → 默认密度约 3 列；卡片评分角标/副标由 MediaCard 渲染（HOME-03 范围，非本包） | 部分：列数依赖用户密度设置；副标文案“共N季”需核对 MediaCard | 在 `test/screens/libraries` 加 390dp 默认密度=3 列断言；副标/角标归 HOME-03 包 | S | 依赖 HOME-03 MediaCard 改造 |
| LIB-01.g 结果计数 | 有筛选/搜索时显示“N 部作品”(role=status) | 无计数行；`totalSize` 已有（`library_browse_tab.dart:217`），仅用于空态判断 | 缺失 | 在 `_buildConditionSummary`/筛选行下方加一行 `Semantics(liveRegion)` 文案，仅 `_selectedFilters/_search` 非空时显示；新增 i18n 键 `libraries.itemCount`（zh/en 及其他语言走 slang 生成） | S | i18n 需补全所有语言文件（项目有 20+ 语言）或允许回退 en；分页未加载完时 totalSize 来自服务端 total，可信 |
| LIB-01.h 无结果空态 | 保留已选条件 + 清除入口 | `library_browse_tab.dart:2281-2290 SliverEmptyState`（`noItemsMatchFilters` + “重置筛选”按钮=`_resetFilters:1277`）；已选条件摘要 `_buildConditionSummary:1859` 仍在上方 | 已一致 | 无 | — | `_resetFilters` 同时清搜索/排序/分组/筛选（比原型“清空筛选”更重），确认符合预期 |
| LIB-01.i 组合筛选可回退/清除恢复 | 多条件叠加，可逐个取消，清除全部恢复 | `_QuickFilterValues._select` 对同字段替换、选中再点取消；`_applyFilters` 持久化到 StorageService（`:1270-1275`） | 已一致 | 无 | — | — |
| LIB-01.j 菜单无底部滑入 | 打开菜单居中/锚定，不从底部滑出 | 筛选/排序/分组均经 `OverlaySheetController.show`，默认 `Alignment.center` floating（`widgets/overlay_sheet.dart:107-118`）；类名/文件名仍叫 *BottomSheet 但呈现为居中浮层 | 已一致（命名遗留，需实机确认手机上无底部滑入动画） | 可选：把 `FiltersBottomSheet/SortBottomSheet` 重命名（纯重构，非必须）；加 widget test 断言 alignment=center | S | 命名与 spec 弹层语义不符会误导后续开发者 |
| LIB-01.k TV 版 | 七列墙；搜索框在标题右侧；筛选行与海报均可方向键到达；焦点放大+描边 | `library_browse_tab.dart:1828-1836`：TV 左侧 220 宽 `ListView`（搜索框 + 分组/筛选/排序 `FocusableListTile`）+ 右侧网格；`LibraryQuickFilters` 在 TV 不渲染；网格 TV maxExtent lerp(120,220)（`grid_size_calculator.dart:15`）；方向键 Right→网格（`:1919`）、Left→侧栏 | 部分：结构不同（侧栏列表 vs 顶部标签行），列数取决于 TV 逻辑宽度/密度（未必 7 列） | 两选一：①保持侧栏（功能更全，TV 上标签行 24 值横滑不便），仅调整视觉（紫色 focus/选中）；②按原型改 TV 顶部：标题右侧 `SearchInputField` + 复用 `LibraryQuickFilters`（需给 `_Tag` 加 TV focus 放大描边，`FocusableButton` 已有；补上下方向键导航 `onNavigateUp/Down`，参考 `search_screen.dart:465-500 _buildFilterChips` 的 chip 导航） | M(②) | 需实体/模拟 TV 焦点验证；改动 `_navigateToChips/_navigateToGrid/focus 记忆` 易回归（见 alpha 跳转栏、`focusTabBar`）；建议①为默认 |
| LIB-01.l 服务器选择 | 标题右侧服务器图标按钮 → 居中 sheet（所有服务器/各服务器，带连接状态与 logo） | 无独立服务器过滤；库标题下拉（`libraries_screen.dart:787`，可按服务器分组，`groupByServer` 设置）选库 | 部分/概念不同（选库而非过滤服务器） | 方案 A 不新增；若要对齐可把库下拉的弹层样式改为与原型 `choice-row`（AppSelectField 风格）一致（S，属 SHARED） | S | 依赖 SHARED 批 |
| LIB-01.m 长标题/窄屏/TV 焦点 | 长标题、手机窄屏、TV 焦点均可用 | `_Tag` 限宽 65% 屏宽+省略（`library_quick_filters.dart` `_Tag`）；搜索框 `FocusableTextField`；TV 有 dpad 体系 | 已一致（需回归验证，无专门测试覆盖标签行窄屏） | 补 widget test：窄屏 320dp + textScale 2.0 下标签行不溢出 | S | — |
| U-LIB-1 键盘/横屏隐藏筛选行 | 原型无 | `library_quick_filters.dart` 高度<500 或键盘弹出时返回 `SizedBox.shrink` | 实机多出的合理行为 | 保留 | — | — |
| U-LIB-2 库 tab（推荐/浏览/合集/播放列表）、字母跳转条、文件夹树、分组 | 原型无 | `screens/libraries/tabs/*`、`alpha_jump_bar.dart`、`folder_tree_view.dart` | 原型未涵盖，spec 要求“功能不回退” | 保留不动 | — | 改动 chips/筛选区高度时注意 `_chipsBarHeight` 与字母条偏移 (`library_browse_tab.dart:1686`) |
| U-LIB-3 搜索页（原型无对应） | 原型“搜索”页没有命中列表/人物结果/类型 chip | `search_screen.dart`（输入框 `:561`、空/失败/无结果态 `:582-607`、类型 chips `_buildFilterChips:465`、结果 ListView `_buildResultsList:502`）；空态用 `StateMessageWidget` | 原型未设计；spec 也未编号 | 不改逻辑；仅在 SHARED 批统一空态/chip 视觉。建议向设计方补“搜索结果页”原型（见决策点） | S | 无原型验收基准 |

**2. 一起看（TOGETHER-01）**

| 编号 | 原型要求（简述） | 实机现状（文件:行号） | 差距 | 修改方案 | 工作量 | 依赖/风险 |
|---|---|---|---|---|---|---|
| TG-01.a 入口页结构 | intro 卡（眼睛标签、大标题、说明）+ 主按钮“创建房间”+ 次按钮“邀请码加入”；下方“我的房间” | `watch_together/screens/watch_together_screen.dart:213-258`：`_RoomSurface(highlighted)` 内图标/introHeading(25px)/description/FilledButton 创建/OutlinedButton 加入；右侧/下方“最近房间”（`:271-300`） | 已一致 | 无 | — | 无 eyebrow “WATCH TOGETHER”小标签，可忽略 |
| TG-01.b 我的房间卡 | 卡片：状态 tag“等待开始·3位成员”、房间名、影片·集数、头像组、“进入房间 →” | `_RecentRoomTile`（`:510-585`）：显示 `room.name ?? room.code`、code、进入态；数据 `RecentRoom{code,name,lastUsed,controlMode}`（`services/recent_rooms_service.dart:17-23`）；长按/SELECT 打开重命名/移除 | 部分：无成员数/头像/影片/状态——这些是本地“最近房间”记录，没有实时数据 | 视觉对齐卡片（r16、tag 样式），不伪造成员/影片。若要展示影片名，可在 `RecentRoom` 增加 `lastMediaTitle`（本地字段，进房时写入，需改 `.g.dart` 生成与存储迁移）— 建议仅做视觉，影片名作为可选 M | S(视觉)/M(影片名) | 不得展示虚构数据（spec §8）；model 变更需 build_runner 与旧数据兼容 |
| TG-01.c 创建房间表单 | 创建=居中 dialog：房间名称 + 选择影片 + “你将成为房主” | `_createSession:352`：弹 `AppAlertDialog` 选控制模式（仅房主/任何人，`_showControlModeDialog:373`）→ 直接创建；房间名只能事后“重命名”（`_RenameRoomDialog:451`）；影片在会话内通过播放器/`currentPlayback` 选 | 部分：缺房间名输入；影片选择在实机流程中属于会话后（host 播放某片即同步），语义不同 | 在创建 dialog 增加可选“房间名称”输入（复用 `_RenameRoomDialog` 的 AppDialog+FocusableTextField 风格），创建后 `_recordRecentRoom(name:)`（该方法已支持 name 字段，`:313`）；“选择影片”不做（不改同步协议），说明文案加“你将成为房主，控制播放”（已有 hostOnly/anyone 选择 → 改为 dialog 内两选项 + 名称字段） | M | i18n 新增键；control mode 选择改表单需保持 TV dpad 焦点（参考 `_RenameRoomDialog` 的 FocusNode 链）；需更新相关 widget test |
| TG-01.d 加入表单 | 6 位数字邀请码；校验失败就地显示错误且不丢输入 | `widgets/join_session_dialog.dart`：AppDialog、`maxLength=RelayProtocol.maxSessionIdLength`、大写 formatter、validator（空/非法 `isValidSessionId`，`:93-105`）、粘贴按钮、焦点链；本地校验失败留在 dialog | 部分：本地校验已就地；但服务器端失败（房间不存在/连接失败）发生在 dialog 关闭之后（`_joinSession:394-` 调 `_runSessionAction`，失败走 `showErrorSnackBar`），输入丢失、错误不在表单内。码格式为字母数字而非 6 位数字（协议决定，保持） | 让 dialog 接收异步 `onSubmit: Future<String?> Function(code)`（返回错误文案则就地显示并保留输入），把 `widget.watchTogether.joinSession` 调用移入；或保持关闭后失败时重新打开 dialog 预填上次输入（成本更低 S） | M | 改 `showJoinSessionDialog` 签名需同步 `test/watch_together/join_session_dialog_test.dart`；busy 状态与 `_runSessionAction` 的 `_isJoining` 协调 |
| TG-01.e 加入错误文案 | “未找到房间，请检查邀请码后重试。” | `t.watchTogether.failedToJoin` + `_sessionActionErrorDetail`（`:349`，PeerError.message 已本地化） | 部分（文案机制已有，位置见 d） | 随 d 一起 | — | — |
| TG-01.f 房间大厅：邀请码展示 | 标题、“邀请码 246810”、可查看邀请信息（不会发真实邀请） | `_SessionCodeHero`（`:1032-1096`）：可复制邀请码，复制后 snackbar；不发送账号数据 | 已一致 | 无 | — | 满足“邀请不泄露账号数据” |
| TG-01.g 成员列表+准备状态 | 成员行显示“已准备/未准备”；成员可“我准备好了/取消准备”；房主“开始一起看”仅在全员就绪 | `_ActiveSessionContent`（`:587-760`）：参与者列表带房主星标、`isBuffering` 转圈、房主可“设为房主”；`Participant{peerId,displayName,isHost,isBuffering}`（`models/watch_session.dart:12-19`）；全仓库无 ready 概念（grep 仅命中 “already”） | 缺失（含协议层） | 两种做法：①**UI 派生就绪**（无协议改动）：就绪=已连接且未 buffering 且本地已匹配到媒体，展示为状态文字，没有手动“准备”按钮（M）；②**真准备开关**：需在 relay 协议/`SyncMessage`/`PeerService` 增加 ready 消息、与自建中继兼容（L，风险高）。建议 ① | M(①)/L(②) | ②涉及 relay 协议兼容性与已部署中继；决策点 |
| TG-01.h 影片状态卡 | “待播放/影片名/已找到媒体·等待成员准备” | `_ActiveSessionContent` 内 `currentPlayback` 区（`watchTogether.currentMediaTitle`，无媒体时 `noMediaSelected`）、`_JoinCurrentPlaybackCard`（`:758-950`，访客匹配本地媒体，`local_media_match_dialog.dart`） | 部分：信息齐全但无“待播放”状态 tag 与匹配状态展示 | 加状态 tag（等待媒体/等待成员/播放中），数据均已有；与 g 的派生就绪共用 | S | 依赖 g① |
| TG-01.i 开始一起看按钮 | 房主在大厅点“开始一起看”进入播放 | 实机无该按钮：房主在媒体详情/播放器入口发起，播放后同步给成员 | 缺失（流程不同） | 不做；或在大厅房主区加“选择影片”引导到媒体库（S，纯导航）。建议由用户决定 | S | 与“不改协议”一致；产品决策 |
| TG-01.j 离开/结束 | “离开房间”返回入口 | 结束/离开按钮 + 确认 dialog（`:128-168`），房主/访客文案不同；访客在会话中不能系统返回（`canGoBack`，`:80`） | 已一致（更严格） | 无 | — | — |
| TG-01.k 弹层规范 | 创建/加入/邀请用居中 dialog；错误就地；顶部轻 toast | 加入/重命名用 AppDialog/AppAlertDialog 居中（✓）；提示用 `showSnackBar` floating（`utils/snackbar_helper.dart:81`，默认底部） | 部分：toast 位置是 SHARED-03 全局问题 | 依赖 SHARED 批把 snackbar 迁到顶部；本页只替换调用点无需改 | S | 依赖 SHARED-03 |
| TG-01.l 深浅主题无硬编码白卡 | 卡片跟随主题 | `_RoomSurface` 用 `colorScheme.surface/onSurface/outline`（`:983-1001`），`_RoomStatus` 用 theme 色 | 已一致 | 无 | — | — |
| TG-01.m TV 版 | TV：创建/加入在左，房间列表在右；方向键移动 | `_AdaptiveRoomColumns`（`:955-980`）宽≥760 且字体≤24 时左右两栏，大字体回退单栏；`FocusableButton`/`autofocus: _recentRooms.isEmpty`、房间 tile 长按 SELECT 菜单（`:537`）；TV 顶栏导航含“一起看”（fusion_navigation） | 已一致（TV 大字体单栏为刻意设计） | 无；补一个 TV 焦点遍历 widget test（可选） | S | 需实体 TV 验证（spec §7 声明浏览器≠实体） |
| TG-01.n 底栏位置 | 第三项“一起看” | `navigation_tabs.dart:13-17`：discover/libraries/**together**/settings | 已一致 | 无 | — | — |
| U-TG-1 中继健康检查/不可达提示 | 原型“中继连接设置留在设置页”，页内无 | `_checkHealth`（`:~190-209`）+ `_RoomStatus(relayUnreachable)` + 重试 | 实机多出 | 保留 | — | — |
| U-TG-2 播放中一起看浮层 | 原型仅 PLAYER-05 TV 抽屉中“一起看(人数)” | `watch_together/widgets/watch_together_overlay.dart`（486 行） | 属 PLAYER 包（他人负责） | 仅提示联动 | — | 与 PLAYER-05 抽屉对齐 |

### 附录 D：设置（来源 D；路径前缀 `lib/screens/settings/`）

**SETTINGS-01 设置导航与统一字段**

| 编号 | 原型要求（简述） | 实机现状（文件:行号） | 差距 | 修改方案 | 工作量 | 依赖/风险 |
|---|---|---|---|---|---|---|
| S01-a 分组入口 | 手机一级仅放类别：观看体验(播放/字幕/弹幕)、为你定制(一起看/外观)、资源与服务(服务器/下载/连接)、应用(关于)；二级进入详情（settings.js home 分支） | settings_screen.dart:236-300 四个 SettingsGroup（viewingExperience/personalization/resourcesServices/application），_openDestination:311、_buildDestination:325 | 已一致（分组与原型同构）。「应用」组多出 Donate 入口（见 X-04）；「网络与缓存」入口缺失（见 S02/S03） | 无需改；新增「网络与缓存」入口时放入「资源与服务」组 | S | 无 |
| S01-b 字号/字段 | 正文14/列表15/区块18/页标题22/说明12；字段r14、高58 | theme/mono_theme.dart:25 起 _textTheme 已按 14/15/18/22/12；输入字段 widgets/app_select_field.dart:175 minHeight 58；但设置行 theme/settings_presentation.dart:10-13 rowHeight 48、groupRadius 15 | 部分：文字尺度一致；设置行 48 高/组圆角15 与“字段 r14/58”不同（spec 指字段，行高是否也要 58 需用户确认） | 若要对齐：改 SettingsPresentation.rowHeight/groupRadius（并同步 setting_tile.dart）；否则仅核对输入框 r14 | S | 影响全部设置页 golden（test/screens/settings/goldens）需重生成 |
| S01-c 顶部通知 | 保存后“顶部通知”确认已保存；统一 toast | utils/snackbar_helper.dart:81 SnackBarBehavior.floating（底部浮动），设置内保存多用 showSuccessSnackBar（settings_screen.dart:1148） | 部分：有统一 snackbar，但位置为底部，非顶部通知；SHARED 全局迁移属其他计划 | 与 SHARED 任务包共用：把 snackbar 改为顶部 overlay；设置页只需调用统一 helper | M（全局）/S（设置页） | 与 SHARED-* 计划耦合，勿在设置内另造 |
| S01-d 主题跨页同步 | 外观→界面主题 系统/浅/深，选择跨页同步 | appearance_settings_screen.dart:193-195 SettingSelectionTile<ThemeMode>，providers/theme_provider.dart 监听 | 已一致（需 widget 测试回归确认） | 无；保留 appearance_settings_screen_test | S | 无 |
| S01-e 分类切换不抖动/当前项可见/禁用说明 | 切换分类不抖；当前分类高亮；禁用项有说明 | settings_category_pane.dart:75-110 左栏选中态；禁用说明散落各 tile（如 playback 的 platform 限制 subtitle） | 部分/待实机验证：无统一“禁用说明”规范 | 手工验证 + 为 SettingNavigationTile/SwitchTile 的 enabled=false 补统一 subtitle 规则（核对 widgets/setting_tile.dart） | S | 需实机/TV 验证 |

**SETTINGS-02 线路管理**

| 编号 | 原型要求 | 实机现状 | 差距 | 修改方案 | 工作量 | 依赖/风险 |
|---|---|---|---|---|---|---|
| S02-a 入口 | 设置→网络与缓存→服务器线路（按服务器：Emby/Jellyfin/Plex），策略 未设置/主线路/手动/自动最快（演示） | 全 lib/screens/settings 无“线路/网络与缓存”入口；grep 线路 在 zh.i18n.json 无结果。服务器详情在 add_jellyfin_screen/edit_jellyfin_connection_screen.dart（仅编辑单地址） | 缺失 | 新增 network_cache_settings_screen.dart（TV 两栏新增 id 'network'）；线路子页复用 SettingsPage/SettingNavigationTile | L | spec 明确：生产网络映射“待实施核对”，“自动最快”仅资源线索，本轮未实现探测；需确认连接模型（lib/models + database tables 的 endpoint/备用地址）是否支持多线路，否则只能做本地偏好演示 |
| S02-b 新建/编辑/删除 | 居中 dialog；名称必填；端口 1—65535 整数（0、65536、小数、非数字拒绝）；地址不接收嵌入凭据（user:pass@）；取消不写入；刷新后保留；不发真实测速 | 无线路表单。可复用：utils 内 showNumericInputDialog（setting_tile.dart:213 一带）、showScopedDialog（settings_screen.dart:1133）、showConfirmDialog | 缺失 | 新增线路 dialog + 校验纯函数 validateRoute()（便于单测）；持久化沿用 SettingsService pref（不改协议） | M | 同上；凭据检测用 Uri.userInfo 非空即拒 |
| S02-c 选择/自动策略 | 选中线路刷新后仍正确；自动最快不做探测 | 无 | 缺失 | 选择态存本地 pref；“自动最快”只显示为“规划中/不可选”不实现 | S | 需用户决策：是否本轮仅做演示偏好 |

**SETTINGS-03 缓存和播放偏好**

| 编号 | 原型要求 | 实机现状 | 差距 | 修改方案 | 工作量 | 依赖/风险 |
|---|---|---|---|---|---|---|
| S03-a 首页内容缓存 | “启动时显示已授权快照”（独立于播放缓冲，未设置/演示）；“清除首页示例状态” | services/home_snapshot_store.dart 存在，providers/discover_provider.dart:104 使用；设置页无开关/清除入口 | 缺失入口（能力已存在） | 在网络与缓存页加开关+清除（确认 dialog）；先核对 snapshot 授权/账户隔离语义（spec：切换账户/服务器应隔离） | M | 不能凭原型新增生产默认；未设置≠0 |
| S03-b 图片缓存 | 图片缓存策略（未设置）+ 清理图片缓存（统一确认） | 仅“清除图片缓存”在高级区 settings_screen.dart:867，确认 dialog 在 :1140；services/image_cache_service.dart | 部分：清理有且有确认；策略项缺 | 把清除项迁/复制到网络与缓存页；策略项暂不做或仅展示 | S | 无 |
| S03-c 播放缓冲 | 写入磁盘/容量/时长：初始为空；未设置与 0 分开；512MB 不是默认 | playback_settings_screen.dart:667 playbackBufferTier（auto/large/extraLarge 三档） | 部分：只有档位，无“容量/时长/写入磁盘”自由值；原型字段是演示偏好 | 不新增生产能力；仅在文案/占位保持“未设置”语义；若要新增需先确认 mpv/Exo 配置（plan 其他模块 PERF-05/07/09） | S（仅文案）/L（真做） | 需用户决策 |
| S03-d 硬解/音频硬解/DV/去隔行 跟随核心 | 解码与播放偏好 sheet：“跟随核心”≠已启用硬解 | playback_settings_screen.dart:485 hardwareDecoding 开关、:530 deinterlace、:613 disableDolbyVision、:620 dvConversionMode；无“跟随核心”三态与“音频硬解”项 | 部分：功能都有，呈现为布尔开关而非“跟随核心/开/关”；缺音频硬解 | 仅文案：说明“有效状态由实际核心确认”；不改 pref 类型 | S | 改 tri-state 需迁移 pref，风险高，不建议 |
| S03-e 清理确认/不声称生效 | 删除/清理统一确认；本地偏好不声称已下发 | showConfirmDialog 已用于清图片缓存 | 已一致（清理）；演示项文案适用于新页 | 新页沿用 showConfirmDialog | S | 无 |

**原型有、spec 未编号**

| 编号 | 原型要求 | 实机现状 | 差距 | 修改方案 | 工作量 | 依赖/风险 |
|---|---|---|---|---|---|---|
| U-01 TV 两栏 | 左分类、右设置项；方向键左右切换；分类：服务器与账户/播放/字幕/弹幕/一起看/外观/下载与离线/连接与集成/网络与缓存/关于 | settings_screen.dart:366-455 SettingsCategoryPane（settings_category_pane.dart:89 宽 310/230，92-98 左右键）。分类 id：connections/playback/danmaku/subtitles/together/appearance/general/services/downloads/controls/advanced/about | 部分：结构一致、按键逻辑有；分类顺序不同（实机 danmaku 在 subtitles 前），多 general/controls/advanced；无 network；connections 含 identity summary 与 manage libraries | 调整顺序为原型顺序；general/advanced/controls 并入“关于”或“连接与集成”下（需决策）；新增 network 分类 | M | 需实体 TV 验证焦点；动 category id 会影响 test/screens/settings/settings_screen_test.dart |
| U-02 手机首页资料卡 | settings-profile 卡：用户名 + 当前服务器·N 台服务器 | _buildIdentitySummary（settings_screen.dart:~495-515）显示 profile 名+serverSummary | 已一致 | 无 | S | 无 |
| U-03 空源引导 | 弹幕默认无源；开启弹幕且无源时先引导添加源；列表“还没有弹幕源” | danmaku_settings_entry.dart:36-40 无源显示 noDanmakuSources；widgets/video_controls/sheets/danmaku_settings_sheet.dart:430-460 开关与“弹幕源”行 | 部分/待验证：值文案有；“无源时点开关→直接弹出添加源”行为需读 sheet 逻辑确认 | 核对 :432-460 的 onChanged，无源时拦截并打开源添加；补 widget 测试 | S | 属 PLAYER-04 范围，避免重复修改 |
| U-04 添加弹幕源表单 | 名称+地址；仅格式校验；localhost 提示；不内置地址；上移/删除 | danmaku_source.dart、danmaku_settings_sheet.dart 有 sources 管理（danmaku/README.md） | 待核对：localhost 提示与“不发请求”校验未逐行核实 | 读 danmaku_source 校验，补 127.0.0.1/localhost 文案 | S | 与 PLAYER-04 协调 |
| U-05 弹幕样式与密度 | 字号/不透明度/速度/同屏上限/显示区域；预览 | sheet :486-500 opacity/fontSize；:663-685 显示区域行数；屏蔽词 :907；繁简 :523 | 部分：缺“速度”“同屏上限”（未发现）；无样式预览 | 视 DanmakuSession 是否有 speed/density 字段；没有则标“不新增能力”，仅加预览 | M | spec：不能凭原型新增设置能力 |
| U-06 字幕设置 | 首选字幕/音频语言、字幕样式、次字幕、默认延迟、在线/本地字幕 | subtitle_styling_screen.dart 仅样式（字号/颜色/描边/背景）；语言偏好在 account_preferences_detail_screen.dart；延迟/次字幕在播放器内 | 部分：入口分散，字幕页缺语言/次字幕/延迟 | 字幕页顶部加“语言”分组跳转 account_preferences；不新增能力 | M | 账户级 vs 全局偏好语义不同，需确认 |
| U-07 播放核心 | mpv/ExoPlayer；VLC 仅“规划中”不可选 | playback_settings_screen.dart:75 player 区，settings_screen.dart:~572 显示 exoPlayer/mpv；无 VLC | 已一致 | 无 | S | 无 |
| U-08 服务器与账户 | Emby/Jellyfin/Plex 列表、添加服务器、当前用户、离线模式、管理线路 | _buildConnectionsSection（settings_screen.dart:~617）、add_connection_screen.dart（Plex/Jellyfin/Emby/借用）、profile/；离线模式未在设置中（offlineMode 仅在 main_screen/video_player） | 部分：添加/账户有；设置内无“离线模式”“管理备用线路” | 离线模式入口需用户决策（不凭原型新增）；线路入口见 S02 | S | 决策 |
| U-09 外观 | 跟随海报取色、主题、减少动态、首页内容、媒体库密度、文字大小、启动页 | appearance_settings_screen.dart：viewMode/gridSpacing/visualEffects(:339)/theme/home 区块；通用页 general_settings_screen.dart 启动 | 部分：减少动态有(visualEffects)；“文字大小”“启动页面”无对应 | 不新增；仅核对文案分组名“外观与首页”（settings_screen.dart:~558 已有 appearanceAndHome） | S | 无 |
| U-10 下载与离线 | 仅 Wi-Fi、下载画质、存储位置、管理下载、同步规则 | _buildDownloadsSection（settings_screen.dart:~703）：位置/仅Wi-Fi/自动删除已看/后台状态 | 部分：基本一致；管理下载/同步规则入口在 screens/downloads、sync，不在设置 | 可在分类内加跳转行（可选） | S | 无 |
| U-11 连接与集成 | Trakt/Seerr/AniList·MAL；手机遥控 TV | services_settings_screen.dart（Trakt/Seerr/Discord/trackers）；_buildControlsSection（:~795）含 companionRemoteServer | 已一致（多出 Discord Rich Presence） | 无 | S | 无 |
| U-12 一起看 | 中继服务器、显示名称、加入后需准备、成员提醒 | settings_screen.dart:1289 _RelayUrlDialog，together 分类仅含中继 | 部分：缺显示名称/准备/提醒（原型有） | 核对 watch_together 是否已有这些 pref；无则不新增，标说明 | S | 决策 |
| U-13 关于页 | 版本、开源许可 GPL-3.0、日志与诊断；声明含 Velo·GPL-3.0 | about_screen.dart:57-66 仅“开源许可证”入口（第三方依赖）；:34-47 图标+名称+版本+描述；i18n/zh.i18n.json:1338 appDescription 为上游文案“一款精美的 Flutter Plex、Jellyfin 和 Emby 客户端”；日志在高级区 | 缺失：关于页无 Plezy 上游署名、无 GPL-3.0 声明/LICENSE 入口/仓库链接；licenses_screen.dart 只列依赖包（未核实是否含 Velo 自身许可）；README.md:14 已有署名可作文案来源 | about_screen.dart 新增“Velo 基于 Plezy（edde746）衍生，遵循 GPL-3.0”分组：上游链接、GPL-3.0 全文入口（LICENSE 加入 assets 或 showLicensePage 自定义条目）、版权行；更新 appDescription 各语言（至少 zh/en）；日志入口可选移入 | S | 合规项（CLAUDE.md 硬要求），优先级最高；LicenseRegistry 手工注册 Velo/Plezy 条目 |

**多余入口核查（需用户决策）**

| 编号 | 原型要求 | 实机现状 | 差距 | 建议 | 工作量 | 依赖/风险 |
|---|---|---|---|---|---|---|
| X-01 云盘入口 | 明确不加 | 设置内未发现云盘/网盘/WebDAV 入口（grep cloud 仅命中无关详情页） | 已一致 | 保留现状 | - | - |
| X-02 刮削入口 | 明确不加 | 设置内未发现刮削/TMDB 入口；metadata_edit_screen.dart、plex_match_screen.dart 是服务器端元数据编辑，非设置 | 已一致 | 保留 | - | - |
| X-03 管理媒体库 | 原型无“管理媒体库” | settings_screen.dart:~585 _buildManageLibrariesTile（隐藏/排序库，上游功能） | 原型无、实机有 | 建议保留（功能性、非云盘刮削）——需用户决策 | - | 决策 |
| X-04 支持开发者 | 原型无 | settings_screen.dart:~541 _buildDonateTile，受 DonationService.isEnabled（services/donation_service.dart:10）控制 | 多余（指向上游捐赠） | 建议确认 isEnabled 对 Velo 构建为 false；否则隐藏——需用户决策 | S | 合规/品牌 |
| X-05 高级/调试 | 原型无 | settings_screen.dart:~831 崩溃上报(Sentry)、测试 Sentry/ANR(:~881)、重置设置、备份导入导出 | 多余 | 保留功能；Test Sentry/ANR 仅 debug 构建显示；崩溃上报需核对是否仍指向上游 DSN——需用户决策 | S | 隐私风险 |
| X-06 更新检查 | 原型无 | services/update_service.dart:19、:25 仍指向 edde746/plezy 与其 appcast；设置页 _buildUpdateSection(:~975) | 风险：会提示上游版本 | 改指向 winesOr/velo 或隐藏；需用户决策 | S | 发布渠道未定 |

### 附录 E：播放器（来源 E；`vc/` = `lib/widgets/video_controls/`；行号基线 HEAD acf7d1b）

**播放器面板与 HUD（PLAYER-01）**

| 编号 | 原型要求（简述） | 实机现状（文件:行号） | 差距 | 修改方案 | 工作量 | 依赖/风险 |
| --- | --- | --- | --- | --- | --- | --- |
| P01-1 右侧全高抽屉形态 | 贴画面右缘全高，宽 340（窄屏 ≤画面 85%），左圆角 24，遮罩，240ms 整幅滑入滑出，点遮罩/关闭/Esc 关闭 | 部分。`overlay_sheet.dart:777-835` edgeDrawer 已贴边全高、左圆角 `OverlayTokens.radius=24`、整幅右滑、遮罩点击关闭（:646-660）。宽度：手机抽屉 `PlayerSettingsDrawer.widthFor` 318/平板 400（`player_settings_drawer.dart:30`），其余入口各写 350/360（`track_chapter_controls.dart:176/214/240/272/346`、`casting.dart:23`、`watch_together_overlay.dart:50`、`mobile_chips.dart:121`）；宽度只 `min(maxWidth, 屏宽)`，无 85% 上限；动画 `OverlayTokens.motion=180ms`（`theme/overlay_tokens.dart:13`），原型 240ms | 宽度不统一、无 85% 上限、时长 180 vs 240 | 在 `overlay_sheet.dart:781` 对 edgeDrawer 的宽度改为 `min(maxWidth, 0.85*屏宽)`；新增 `OverlayTokens.drawerWidth=340`、`drawerMotion=240ms` 仅 edgeDrawer 使用（不动 floating 的 180ms，避免影响全站）；各入口统一引用 `PlayerPresentation`（`vc/` 下新增常量，原型指向 `player_presentation.dart:7` 但该文件现不存在，需新建小常量文件）；TV 抽屉宽取画面 ~30%（见 P05-7） | S | 动画时长常量会影响 edgeDrawer 的既有 widget 测试 `test/widgets/overlay_sheet_edge_drawer_test.dart`；平板 400 是否保留需决策 |
| P01-2 四标签面板外壳 | “播放设置”标题+关闭键；视频/音频/字幕/弹幕四标签，不随内容改外框 | 部分。四标签已有且固定宽度（`player_settings_drawer.dart:79-113`，切换用 `KeyedSubtree` 不改外框）；无标题行与关闭按钮 | 缺标题行 + 关闭键（触控/遥控可见的退出路径） | 在 `PlayerSettingsDrawer.build` 顶部加标题行（`t.videoControls.moreButton` 或新增 `playerSettingsTitle` 文案）+ 关闭 `IconButton` 调 `OverlaySheetController.of(context).close()`；新增 i18n key（需走 `strings.g.dart` 生成流程） | S | 多语言文件需同步（i18n 目录 9+ 语言） |
| P01-3 视频标签内容 | 画面比例（默认/拉伸/填充/16:9/4:3）、自动跳过开关、更多（播放内核/版本与画质/画面缩放/睡眠定时） | 部分。`player_settings_drawer.dart:136-186`：画面比例 3 档（`_AspectRatioRow` :215，播放器只支持循环 3 模式）、自动跳过 `_AutoSkipRow` :259、自定义跳过秒数（原型没有）、播放内核、`VideoSettingsSection.video` 含版本/缩放/睡眠 | 缺 16:9/4:3 两档；多出两个“跳过秒数”数值项（保留不影响） | 16:9/4:3 需要 mpv/Exo 侧新增强制宽高比，超出本轮范围（原型声明“未改变 mpv/Exo”），建议 UI 仍 3 档并在验收里标“原型 5 档为演示”；若要做则改 `TrackControlsState.onCycleBoxFitMode` 为 setter | S（保持 3 档）/ L（做 5 档） | 决策点 D4 |
| P01-4 连续进度条 | 一条连续轨道，热度/缓冲/已播放/片头片尾区间画在同一轨，不按章节分段 | 一致。`timeline_slider.dart:393`、`buffer_range_painter.dart:97-104`（注释即“thin ticks on a continuous track, not gaps”）；热力 `heatmap`、`skipRanges` 同轨（:405-410，片头片尾区间为轨底 2px 琥珀线） | 仅有章节细刻度（黑 45% 1~2px），不是分段 | 无需改。如要与原型零刻度完全一致，把 `showChapterMarkersOnTimeline` 默认值改 false（`SettingsService`）或删 tick 绘制 | S（可选） | 决策点 D3；用户可能依赖章节刻度 |
| P01-5 跳过片头/片尾按钮 | 白底 90%、黑字 16/600、快进图标、圆角 8、投影；画面右 24、控件显示时离底 80；TV 在进度条上方右侧，隐藏时右下 | 一致。`vc/widgets/skip_marker_button.dart:62-103`；位置 `video_controls.dart:1532-1548`：right 24，控件隐藏 24、手机显示 80、桌面/TV 115、内容条 180 | TV 与原型 TV 布局（离底 ≈158 逻辑px）需实机核对 115 是否被 TV 加高的底栏盖住 | 无需改；实机 TV 截图核对，必要时把 TV 的 115 改成按底栏实测高度 | S | 仅核对 |
| P01-6 倍速/字幕/选集入口改用抽屉（手机） | “倍速、选集、字幕搜索、投屏同为此抽屉”；手机横屏底栏 chip：倍速 -> 抽屉（居中文字列表）、字幕 -> 字幕标签抽屉、选集 -> 选集抽屉 | 缺失。三个 chip 仍是锚在按钮上方的小浮层：`mobile_chips.dart:40-44`（倍速 `PlayerSpeedPopover`）、:46-55（字幕 `TrackSheet` 窄 280 浮层）、:57-85（选集 `PlayerEpisodesPopover`/章节），`_showPopover` :36 用 `anchor:` 而非 edgeDrawer | 三个入口不是抽屉 | 倍速：新增 `PlayerSpeedDrawer`（或复用 `VideoSettingsSheet(openOnSpeed:true)` `video_settings_sheet.dart:419/483` 的速度子页，已有）以 edgeDrawer 打开；字幕 chip：改调 `_openPlayerDrawer(context, state, PlayerDrawerTab.subtitles)`（`mobile_chips.dart:90`）；选集 chip：见 P01-7 | M | 与 P01-7 同包；`player_track_summary.dart` 的 chip 回调签名 `onTapWithRect` 可保留 |
| P01-7 选集与队列合并（手机） | 一个入口：剧集叫“选集”（分季标签、本季剧集含已看/进度/接下来播放、末尾衔接下一季）；电影/播放列表叫“播放列表”（当前项+接下来，循环/随机）；不再单设队列 | 缺失。手机：`PlayerEpisodesPopover`（`sheets/player_popovers.dart:119`）只列当前队列项，无分季、无已看/进度标记、无“衔接下一季”，电影无章节时 chip 隐藏（`video_controls.dart:1401 canShowQueue || _chapters.isNotEmpty`），有章节时 chip 变成章节列表（`mobile_chips.dart:62-85`）。TV：`QueueSheet`（`sheets/queue_sheet.dart:30`）仅队列项列表 | 无分季、无状态标记、名称不随内容类型切换、章节与选集混用 | 新建 `sheets/episodes_drawer.dart`（`EpisodesDrawer`）：剧集模式=顶部季标签（`fetchChildren(showId)` 取季，`media_server_client.dart:246`；本季集用 `fetchSeasonEpisodesPage` :987；已看/进度读 `MediaItem` 的 viewOffset/viewCount）+ 末尾“接下来 · 第 N+1 季”；电影/列表模式=当前项 + `PlaybackStateProvider.loadedItems` 后续项 + 循环/随机行（复用 `PlaybackStateProvider` 既有 shuffle/loop）；选中走 `_onQueueItemSelected`（`parts/navigation.dart:56`）。保留 `QueueSheet` 的缩略图/防剧透组件（`MediaSelectorThumbnail`、`hideSpoilers`）。章节仍独立入口（手机 chip 在无队列时不再兼职章节，章节并入原型的“…”/章节入口，决策 D6）。手机与 TV 共用同一 widget | L | 依赖 `PlaybackStateProvider` 在非队列（单集/电影直播放）时也要给出“本季列表”：需要在 drawer 内按 `metadata.parentId` 懒加载，离线/无网要降级为只显示当前项；Jellyfin/Plex 两套后端都要测 |
| P01-8 层级、Esc、不遮断时间轴、切 tab 不丢选择 | 面板不遮断全部时间轴；切 tab 不丢选择；Esc 只关最上层；运输按钮不变紫/白面板 | 一致。边缘抽屉右侧覆盖不盖底部时间轴左段；选择写入播放器状态而非 widget 状态，`KeyedSubtree`（`player_settings_drawer.dart:107`）重建不丢；Esc/Back 走 `sheetController.pop`（`key_events.dart:83`） | 无 | 无需改；加一条回归测试（切 tab 后音轨选择保留） | S | — |

**音频选择（PLAYER-02）**

| 编号 | 原型要求（简述） | 实机现状（文件:行号） | 差距 | 修改方案 | 工作量 | 依赖/风险 |
| --- | --- | --- | --- | --- | --- | --- |
| P02-1 双行直列选项 | 抽屉内直接列出双行选项（主行轨名、次行编码·声道·采样率），点选即生效，勾选+紫底，不二次弹出 | 部分。手机抽屉内嵌模式：`track_sheet.dart:349-360` `AppSelectField<String>` 下拉（685dfc3 引入，点开才弹菜单）；非内嵌（TV/桌面独立 `TrackSheet`）已是双行列表 `track_sheet.dart:361-376` + `track_selection_helper.dart:35/75-125`（title+subtitle） | 手机抽屉是下拉；`sheet_selection_column.dart:68-95` 内嵌回落是 `Wrap`（横向 chip，不适合双行）；次行缺“采样率”（`TrackLabelBuilder.audioLabel` 只有编码/声道，需核实） | 去掉 `_AudioColumn`/`_SourceAudioColumn` 的 `embeddedBuilder`；`SheetSelectionColumn` 内嵌分支把 `Wrap` 改为 `Column` 直列 `itemBuilder`（`sheet_selection_column.dart:88-96`）；`buildTrackTile` 选中态加紫色底+勾（对齐 `GlassSheetColors.selected`）；`TrackLabelBuilder`（`media/` 或 `utils/`，grep `class TrackLabelBuilder`）补采样率字段（若 `AudioTrack` 有 `sampleRate`） | M | 要改 `test/widgets/track_sheet_test.dart`、`player_track_selector_test.dart`、`tablet_player_settings_test.dart` 里对 `AppSelectField` 的断言；`AppSelectField` 本身保留给设置页等其它位置 |
| P02-2 pending / 失败 / 无音轨 | pending 禁止重入；失败保留旧值并恢复可选；无音轨禁用，不提交失效值 | 部分。下拉路径用 `scope.runExclusive`（`sheet_selection_column.dart:40-52` 重入保护、进度条、失败 `showErrorSnackBar` 且不改显示值）；列表路径 `track_sheet.dart:366-374` 直接 `player.selectAudioTrack(track)` 未 await、无 busy、无失败处理；无音轨时抽屉仍显示空列表无提示 | 列表路径缺 pending/失败；缺空态 | `_AudioColumn`/`_SourceAudioColumn`/`_SubtitleColumn`/`_SourceSubtitleColumn` 的 `onTap` 全部改走 `scope.runExclusive(() async {await player.select...; onTrackChanged?.call})`；`tracks.isEmpty` 时返回空态块（“没有可用音轨 / 此媒体没有可选择的音轨”，新 i18n） | M | 与 P02-1 同一提交；失败时显示值取 `player.state.track`（已是 stream 真值，天然回滚） |
| P02-3 快捷入口与面板同步 | 选择后快捷入口和面板同步，重开保留 | 一致。入口摘要（`widgets/player_track_summary.dart`、TV 按钮 `track_chapter_controls.dart:200-228` 的 `semanticValue`）与面板都监听 `player.streams.track` | 无（TV 右组按原型要显示当前值文字，见 P05-4） | 无 | S | — |

**主字幕与次字幕（PLAYER-03）**

| 编号 | 原型要求（简述） | 实机现状（文件:行号） | 差距 | 修改方案 | 工作量 | 依赖/风险 |
| --- | --- | --- | --- | --- | --- | --- |
| P03-1 主/次字幕独立字段 | 主、次字幕各为独立双行直列字段，含“关闭”项 | 部分。内嵌模式主字幕 `AppSelectField` :454、次字幕 `AppSelectField` :496（下拉）；非内嵌列表里主字幕是列表、次字幕靠长按/右键（`track_sheet.dart:560-590` badge 1/2，不可发现） | 手机抽屉下拉；次字幕在列表模式靠长按，遥控器不可达 | 内嵌与非内嵌统一：新增 `_SecondarySubtitleList`（`supportsSecondary` 时在“次字幕”标题下直列同款双行 tile，排除当前主轨，含“关闭”）；主字幕列表保留。移除长按/右键设次字幕的唯一入口依赖（可保留作快捷） | M | 与 P02-1 同包；TV 遥控器必须能到次字幕 |
| P03-2 冲突与命名空间 | 稳定 ID 区分 native/source；主字幕关闭清次字幕；同轨不能同时主/次 | 一致。`_SubtitleMenuValue` 记录 `(nativeTrackId, sourceStreamId)`（:312、:454）；关闭主字幕/选中与次字幕相同轨时先清次字幕（:473-481、:516-523）；次字幕候选排除主轨（:507） | 无 | 无；换成列表后保持该逻辑 | S | 迁移时勿丢 |
| P03-3 不支持次字幕 | 不支持时不呈可选假功能（原型显示“当前核心不支持”说明） | 部分。`player.supportsSecondarySubtitles` 为 false 时整块隐藏（`track_sheet.dart:494`），无说明 | 无提示文案（可接受） | 保持隐藏或加一行灰字说明（新 i18n），二选一 | S | 决策 D7（低优先） |

**字幕获取与播放器辅助能力（PLAYER-04）**

| 编号 | 原型要求（简述） | 实机现状（文件:行号） | 差距 | 修改方案 | 工作量 | 依赖/风险 |
| --- | --- | --- | --- | --- | --- | --- |
| P04-1 在线搜索 / 本地载入字幕 | 搜索/载入用同一右侧抽屉（非居中）；输入、空结果、取消、反馈 | 部分。在线搜索：`track_sheet.dart:624-641` 在抽屉内 `OverlaySheetController.push(SubtitleSearchSheet)`（页栈，返回键 pop），仅 Plex（`track_controls.dart:225 subtitleSearchSupported`）。本地载入字幕：无（弹幕有本地文件 `danmaku_settings_sheet.dart:341`，字幕没有） | 缺“加载本地字幕”；搜索入口在 Jellyfin 隐藏 | 本地字幕：用 `FilePickerService.pickFiles`（`video_settings_sheet.dart:1571` 同款）+ 播放器外挂字幕加载 API（需核实 `Player` 是否有 `addExternalSubtitle`，`track_sheet` 的 external 轨已存在）；放在字幕标签“调整”之后与“在线搜索”并排。原型声明“真实文件访问不在本轮实现”，建议本轮只保留入口位置与禁用态 | M（若实现）/ S（仅占位） | 决策 D5；TV 无文件选择器，TV 隐藏该项 |
| P04-2 投屏 | 播放器保留专属投屏抽屉；首页/设置无投屏入口；TV 不提供 | 一致。入口仅手机顶栏 `mobile_video_controls.dart:217` -> `casting.dart:7 _showCastSheet`（edgeDrawer 360，`DlnaCastSheet`）；非 Android/直播/离线/房间中显示不可用原因；全库仅此处引用 `DlnaCastSheet`；桌面/TV 控件不传 `onCast`（`video_controls.dart:1410` 只给手机） | 宽度 360 与 340 不统一 | 随 P01-1 统一宽度 | S | — |
| P04-3 热力图 / 弹幕 / 一起看入口 | 热力图、弹幕、一起看入口继续存在 | 部分。热力图（`timeline_slider.dart:36-37,405`）、弹幕（手机顶栏开关 :212 + chip :272 + 抽屉标签）一致；一起看：`video_controls_header.dart:77-91` 仅会话中显示人数指示器（`watch_together_overlay.dart:22`，点开 edgeDrawer 350 会话菜单），播放器内没有“发起/加入”入口 | 无会话时播放器内无一起看入口（原型 TV 顶栏恒有“一起看”chip） | 决策后：①仅会话中显示（现状）②无会话时显示“一起看”chip 打开发起/加入抽屉（复用 `watch_together_screen`/`join_session_dialog` 的内容放进抽屉） | M（若做②） | 决策 D8；一起看后端行为不在本轮 |
| P04-4 不引入内置网关 | 默认网关为空 | 一致。弹幕源完全由用户添加（`danmaku_settings_sheet.dart:99-109` 空配置直接进入“添加源”，无内置 baseUrl 默认） | 无 | 无 | S | — |
| P04-5 辅助弹窗不从底部滑出 | 任何辅助弹窗不从底部滑出 | 部分。播放器内入口均已 edgeDrawer（912e8ab）；残留 `danmaku_sources_sheet.dart:109` 删除确认用 `showDialog<AppAlertDialog>`（居中，不是底部，符合“不从底部滑出”），无 bottom sheet 残留（grep `showModalBottomSheet` 在 `vc/`、`screens/video_player*` 无命中） | 居中确认框是否算“辅助弹窗”需确认；`BaseVideoControlSheet` 的非内嵌头部仍用 `BottomSheetPageScaffold`（:78，仅命名） | 无功能改动；验收时逐入口录屏确认；如需彻底统一，把删除确认改成抽屉内二级页 | S | 决策 D9（低优先） |

**TV 播放界面（PLAYER-05）**

| 编号 | 原型要求（简述） | 实机现状（文件:行号） | 差距 | 修改方案 | 工作量 | 依赖/风险 |
| --- | --- | --- | --- | --- | --- | --- |
| P05-1 顶栏 | 返回、片名+第N季·第N集；右侧弹幕开关、一起看(人数)、更多(->设置抽屉)；按钮 88px，片名 48/600；方向键可达 | 部分。`desktop_video_controls.dart:700-709` 用 `VideoControlsHeader`：返回键+片名+（会话中）人数+时钟；无弹幕开关、无“更多”；返回键聚焦节点不在方向键链上（进度条 ↑ 直接隐藏控件 :546） | 顶栏右侧三个入口缺；顶栏方向键不可达 | `VideoControlsHeader` 增加 TV 变体（`trailing`）：弹幕开关（复用 `mobile_chips.dart:_toggleDanmaku` 逻辑 -> 提到 `parts/` 公共）、一起看 chip（P04-3 决策）、更多（打开设置抽屉）；给顶栏三/四个按钮加 `FocusNode` 并接入 `_handleTimelineKeyEvent` 的 ↑（改为：有跳过按钮 -> 跳过；否则 -> 顶栏第一项；顶栏 ↑ -> 无操作/或隐藏）；字号/按钮尺寸按 TV 缩放核对（原型 DPR2 下 44 逻辑 px） | M | 改变 ↑ 的“隐藏控件”语义（现 `_hideControlsFromKeyboard`），遥控器回归风险高；需 TV 实机/`test/focus` 测试 |
| P05-2 进度条（TV） | 连续轨道、左右时间 28px；聚焦时轨道加粗并描边；←→ 与快进快退按钮一致 ±10 | 部分。聚焦加粗 3->8（`timeline_slider.dart:371-372`）+ 圆点焦点（:448 起）；←→ 渐进加速 scrub（`desktop_video_controls.dart:561-`，非固定 ±10 而是随连按加速） | 无“描边”；←→ 语义是渐进加速，与“±10”表述不同（首下是 `seekTimeSmall` 吗，需核实） | 聚焦时给轨道加 2px 白描边（`buffer_range_painter` 或 `FocusTheme`）；首次 ←→ 步长对齐 `seekTimeSmall`(默认 10)，按住再加速，写进验收 | S | 步长改动影响连续 scrub 手感，保持加速不动只核首步 |
| P05-3 底栏左组七个传输按钮 | 上一集/上一章/快退10/播放/快进10/下一章/下一集 | 一致。`desktop_video_controls.dart:786-910` 七按钮顺序、禁用态、章节 tooltip 一致；`_seekTimeSmall` 默认 10（`settings_service.dart:581`） | 无 | 无 | S | — |
| P05-4 底栏右组入口 | 竖排图标+标签：倍速、字幕、音轨、选集/播放列表、章节、弹幕、设置，打开对应抽屉 | 部分。`track_chapter_controls.dart:162-344`：设置(tune，`VideoSettingsSheet` 350 抽屉 :164)、音轨字幕合一按钮（:200，`TrackSheet` 双列）、章节（:231，被 `hideChaptersAndQueue` 隐藏）、队列（:263，被隐藏、仅队列激活才有）、画面比例循环（:303，原型无）、弹幕（:337，只开弹幕设置）。缺：倍速按钮、独立字幕/音轨按钮、文字标签、当前值展示 | 缺倍速；字幕/音轨未拆；缺选集入口（P05-6）；多余画面比例按钮；按钮仅图标无标签；入口不是统一四标签抽屉 | 新增 TV 专用右组（`TvActionButton`：图标+标签+当前值，`vc/widgets/` 新文件），`track_chapter_controls` 在 `PlatformDetector.isTV()` 时走新分支（桌面保持不动）：倍速（`VideoSettingsSheet(openOnSpeed:true)`）、字幕/音轨/弹幕/设置分别 `PlayerSettingsDrawer(initialTab: subtitles/audio/danmaku/video)`（`volumeController` 传 null）、选集（P05-6）、章节（`ChapterSheet`，不再受 `hideChaptersAndQueue` 隐藏）；画面比例并入设置标签 | L | 7 个按钮的 focus node 数量 `_trackControlFocusNodes = List.generate(9)`（`desktop_video_controls.dart:228`）要核对；TV 宽度放得下 7 个带标签按钮需实测；桌面端是否同步改成这套（决策 D2） |
| P05-5 TV 不提供投屏/PIP/锁屏/截图/横竖屏 | 无投屏按钮与抽屉；PIP、锁屏、截图、旋转不适用 | 一致。投屏仅手机（P04-2）；PIP 对 TV 置空 `track_controls.dart:181`；旋转锁屏 `track_chapter_controls.dart:316` `!isTV()`；TV 控件无截图；音量 TV 隐藏（desktop_video_controls.dart:925）；全屏/置顶仅 `isDesktopOS` | 无 | 无 | S | — |
| P05-6 选集/播放列表单一入口 | 一个按钮：剧集“选集”、电影/列表“播放列表”，抽屉分季/当前项+接下来；底栏不再单设队列 | 缺失（用户反馈根因）。章节与队列在 dpad 下被收进 ↓ 内容条（`desktop_video_controls.dart:947 hideChaptersAndQueue`、:386、:455）；入口不可发现；队列按钮仅 `isQueueActive`（`track_controls.dart:210`）；电影/单集无入口；`ContentStrip` 无分季（`widgets/content_strip.dart:32`） | 入口缺 + 内容类型不切换 + 内容条要下线 | 用 P01-7 的 `EpisodesDrawer` 做 TV“选集/播放列表”按钮（图标 grid/list，标签随 `metadata.type` 与 `isQueueActive` 切换）；TV 去掉 `ContentStrip` 与 `ContentStripHint`、`hideChaptersAndQueue`、`_showContentStrip` 路径及其 `key_events.dart:86` 返回层（影响面大，可先保留代码但 `useDpadNavigation` 下不再触发，下个包删除）；`_hasStripContent` 相关的 ↓ 键恢复为“无操作”；无队列的单集剧集也可用（按 parentId 取季，P01-7） | L | 与 P01-7 同一 widget；删除内容条要同步改 `video_controls.dart:1542`（跳过按钮离底 180 分支）、`visibility.dart`、`test/widgets/*strip*`/`video_controls_test.dart`；内容条当前也承载章节缩略图，章节抽屉需补缩略图（`ChapterSheet` 已有 `serverId`/缩略图能力，需核对 TV 焦点） |
| P05-7 抽屉焦点限制与 TV 规格 | 抽屉宽≈画面 30%、左圆角 24、240ms；抽屉内焦点不泄漏；↑↓逐项（标签栏算一项），←→在标签间切换（自动切页）/步进器/选项组间移动，滑块←→调值；打开时焦点落在当前项；四标签 | 部分。`overlay_sheet.dart:560-600` 有 `_sheetFocusScopeNode`、`ExcludeFocus` 非顶页、`FocusableSlider`/`PlayerDrawerStepper`（`player_settings_controls.dart:297/387`）已存在；TV 现用多个独立 350 抽屉而非四标签；标签行 `PlayerDrawerChoice(tab:true)` 点击切换，←→ 仅移动焦点不自动切页；打开初始焦点不保证落在选中项 | 缺 TV 四标签复用；缺 ←→ 自动切页；宽度 350 vs 约 30% | TV 全面复用 `PlayerSettingsDrawer`（见 P05-4）；标签 `PlayerDrawerChoice` 的 `onFocusChange(true)` -> `setState(_tab=…)`（仅 dpad 模式）；`initialFocus` 指向选中 tile/当前集；宽度 `max(340, 0.3*屏宽)` | M | 自动切页会重建 `KeyedSubtree`，焦点必须留在标签栏，不能被 `requestFocus` 抢走；需写焦点单测 |
| P05-8 焦点样式 | 放大 1.14 + 白底黑字 + 紫色 6px 外描边；抽屉内紫色 3px 内描边+选中底 | 部分。`player_focus_disc.dart` 白底黑图标圆盘 + `FocusTheme.playerControlFocusScale=1.12`（`focus_theme.dart:14`）；无紫色外描边；抽屉内 tile 焦点为通用 `FocusableListTile` 样式 | 缺紫色描边（“非仅颜色”靠白底已满足，但与定稿不一致）；缩放 1.12 vs 1.14 | 在 `PlayerFocusDisc` 的 TV 分支加 6px `colorScheme.primary` 外描边 + 缩放 1.14；抽屉 tile 的 dpad 焦点加 3px 内描边（`FocusTheme` 新增 `playerDrawerFocusDecoration`） | S | 仅 TV 生效，避免桌面键盘焦点样式变化过大 |
| P05-9 返回逐层 | 先关最上层浮层（搜索弹窗->抽屉；设置子列表先回设置抽屉），焦点回触发按钮；无抽屉隐藏控件；隐藏时再按退出 | 一致。`key_events.dart:80-86` + `video_player_screen.dart:2368-2376`（子页 `pop` 逐层、`overlay_sheet.dart:465/546` 恢复触发焦点）；跳过提示按返回只收起提示（:116） | 焦点回到触发按钮需在新“右组按钮”上验证；内容条下线后 :86 层去除 | 无功能改动；随 P05-4/P05-6 验收 | S | 新按钮要有稳定 `FocusNode`，否则 `returnFocus.context==null` 无法恢复（`overlay_sheet.dart:552`） |
| P05-10 控件隐藏与唤出 | 隐藏时任意方向键/Enter 唤出并聚焦播放/暂停；有跳过按钮时 Enter 直接跳过；10 秒无操作自动隐藏，抽屉开启不隐藏 | 部分。唤出聚焦播放/暂停：`key_events.dart:55-66`（`_activatePlayerSurfaceSelect`）与 :324 `requestPlayPauseFocus`；Enter 跳过 :58；抽屉开启 `cancelAutoHide`（`track_chapter_controls.dart:172` 等）。但隐藏时 ←→ 是原地快退快进（:309-318），不唤出 | ←→ 与原型“任意方向键唤出”冲突 | 保持现状（←→ 快进快退是 TV 既有习惯，改掉会退化）；原型/验收文案改为“↑↓/Enter 唤出，←→ 原地快进快退”。若坚持按原型，则隐藏时 ←→ 只唤出 | S（改文案）/ M | 决策 D1 |
| P05-11 TV 跳过按钮 | 仅在片头/片尾区间出现；控件显示时在进度条上方右侧，隐藏时右下；可聚焦（顶栏->跳过->进度条） | 一致。`markers.dart:262 _isSkipMarkerButtonVisible`、`visibility.dart:257-269`、`skip_marker_button.dart:62-70` 有焦点节点与 ↓ 回调 | 进度条 ↑ 到跳过已通；顶栏 ↑ 随 P05-1 | 无 | S | — |
| P05-12 上/下一章与快退快进 | 快退/快进 ±10 并 OSD 提示；上/下一章跳章节边界并提示章节名（>3 秒回本章开头） | 部分。遥控硬键走 `_seekToChapterWithFeedback`（`playback_input.dart:152-172`，有章节名提示，3 秒阈值在 `media_source_info.dart:328`）；屏幕按钮 `_seekToNextChapter/_seekToPreviousChapter`（`playback_input.dart:33`）走 `_seekToChapter` 不弹提示；快退/快进按钮 `desktop_video_controls.dart:828/865` 调 `onSeekBackward/Forward`（`_seekTimeSmall`，核实是否带徽标提示） | 按钮点击无章节名提示；快退/快进按钮是否有 OSD 需核对 | `parts/playback_input.dart:32-33` 两个方法改调 `_seekToChapterWithFeedback`；核对 `onSeekBackward/Forward` 的 `_seekByWithFeedback` | S | 按钮与硬键共用后，注意 burst 累加（`_abandoningBurst`） |

### 附录 F：TV 播放器入口对照笔记（原文）
# 实机 TV 播放器入口对照（2026-11-15，供对比修改方案使用）
- 实机 TV 底栏：desktop_video_controls.dart:786-910 上一集/上一章/快退/播放/快进/下一章/下一集；track_chapter_controls.dart:164 设置、:200 音轨字幕合一、:303 画面比例、:337 弹幕
- 章节 :231、队列 :263 在 dpad 模式下收进 ↓ 唤出的内容条（desktop_video_controls.dart:947、:455）——用户反馈“找不到播放清单”
- 实机 TV 缺直达入口：倍速、选集、一起看、投屏、版本与画质、睡眠定时、字幕搜索（版本 video_settings_sheet.dart:925、睡眠 :952、一起看 :1273、投屏 mobile_chips.dart:111 仅移动端）
- 返回键 video_controls.dart:471-474；跳过按钮 :1532
- 待定：抽屉宽 580@1080p；TV 是否保留投屏；是否保留 ↓ 内容条与快退/快进/上下章按钮；自动隐藏 10s

