# UI v1 实机修改清单（2026-11-16）

## 1. 说明

- **基准**：实机为 `origin/main` b8273be；原型为 `design/prototype/`（home / library / together / settings / detail / player / toast / ui-improvements 与 `final-ui-spec.md`）。
- **输入**：三份核对报告（下文来源列的前缀：`A-` = 首页/导航/库/一起看/设置报告，`B-` = 详情/播放器报告，`C-` = 共用报告），加旧计划 `docs/ui-v1-dev-plan-2026-11-15.md` 第 2 章的 Q 号决策。
- **用户最新决定（2026-11-16，覆盖旧计划）**：
  1. 全部按原型改。旧计划里所有“保留实机形态”的决策作废，报告里“决策保留”的条目全部改为要修改。
  2. TV 设置左栏选中态用原型的中性灰白（白 18% 底、白字、常规字重）。
  3. Q01 OLED 纯黑档是用户亲自定的，继续保留（TV 底色差异不改，见第 4 节）。
  4. 线路管理（P8-3 / UI-04）按原型做，之前推迟的作废；涉及连接模型，需先确认数据模型，可单独成包。
- **实机效果均为读代码推断**，没有在真机或模拟器上运行；“现状”列的行号基于 b8273be，施工时需重新核对。
- **与旧计划的关系**：本清单替代旧计划里尚未完成的部分。旧计划中已落地的 P1-2（AppToast）、P1-5、P3-1、P3-3 等不重做，只补本清单列出的差异。旧计划的 Q 号不再作为依据，除非第 4 节明说保留。
- **严重度**：大 = 一眼可见的结构差异或多余元素；中 = 明显的样式、文案、布局差异或缺功能；小 = 细节数值。
- **去重说明**：A-D5 与 B-V6（个人评分）、B-D6 与 B-D21、B-V4（版本区）、A-S4 与 C-C4（设置开关色）、A-G1 与 A-G7（一起看按钮）已合并。B 报告汇总行把详情手机的中档写成 10 条，实际逐条为 9 条（含已并入的 D21），以本清单为准。
- **编号**：`FIX-<页面>-<序号>`。页面代号：HOME（首页手机/平板）、HTV（首页 TV）、NAV、LIB（搜索/媒体库）、DET（详情手机/平板）、DTV（详情 TV）、TG（一起看）、SET（设置）、PLM（播放器手机/平板）、PLT（播放器 TV）、THEME、TOAST、DLG、MENU、A11Y（共用）。

**总量：119 条，大 8 / 中 43 / 小 68。**

---

## 2. 被推翻的旧决策（Q 号 → 新要求）

| 旧决策 | 旧结论 | 新要求 | 对应 FIX |
|---|---|---|---|
| Q02 | 方案 A：底栏第二项保持“媒体库”，保留“⋯” | 底栏第二项改为“搜索”，进入媒体库筛选墙（原型“搜索”页）；底栏去掉末尾“⋯”，只剩 4 项；TV 顶栏按原型四入口（首页/搜索/一起看/设置）；首页和库页的搜索入口都进该页 | NAV-01/02/05、HOME-06、LIB-01/02 |
| Q05 | 保留首页自动轮播 | 按原型：不自动切换，只能手动或滑动；圆点按原型样式 | HOME-04 |
| Q07 | 保留详情三选择器（版本/音轨/字幕） | 改为原型的一行紧凑版本胶囊，去掉详情页的音频/字幕选择字段 | DET-06（含平板、TV） |
| Q08 | 保留纵向全列表；“查看全部”不做网格 | “查看全部”打开集数网格弹窗（原型），不再原地换成纵向长列表；桌面/宽屏也走横排加分组 | DET-10、DET-12 |
| Q09 | 保留“你的评分”chip | 去掉详情里的个人评分 chip（评分全页仅评分条一处），个人评分能力并入“⋯”弹窗 | DET-05（含 TV） |
| Q10 | TV 剧集分组条本轮不做（P3-8 可选包） | 必须做：TV 详情按原型横排集卡加分组 chip | DTV-04 |
| Q11 | TV 媒体库保持左侧 220 宽侧栏（P4-2 默认不做） | 改为原型：标题“搜索”，右侧搜索框和服务器按钮，五行标签横排，七列海报 | LIB-10/11 |
| Q12 | 搜索结果页沿用现有视觉 | 原型没有结果页设计，沿用现有页面但接共用 token，列入待确认 | 待确认 U-04 |
| Q15 | 房间卡不显示影片名（只做视觉对齐） | 按原型显示“等待开始 · 3 位成员”、房间名、影片和集数、头像组、“进入房间 →”；需新增数据字段，与规范 §8“禁止虚构数据”冲突，需先确认 | TG-05 |
| Q17 | 设置行高待定 | 按原型实测：行高 51、组圆角 15（原型规范写的 58/r14 与实测不符，见待确认） | SET-07 |
| Q18 / P8-3 | 线路管理推迟，条件包 | 按原型做线路新增/选择/删除与名称、地址、端口校验；先确认连接模型 | SET-11 |
| Q24 | TV 控件隐藏时 ←→ 保持原地快进快退 | 按原型：隐藏时任意方向键或 Enter 只唤出控件并聚焦播放/暂停 | PLT-04 |
| Q27 | 画面比例保持 3 档 | 按原型 5 档（默认/拉伸/填充/16:9/4:3）；涉及 mpv/Exo 内核，可拆包 | PLM-06 |
| Q29 | 章节入口选自“顶栏独立按钮” | 顶栏右侧按原型不放“章节”按钮；章节入口放进选集抽屉（具体位置见待确认） | PLM-01 |
| P3-5 | 保留详情多出的下载/更多按钮 | 手机动作区只留 ♡、⚑ 两枚图标加右上“⋯”；TV 行内按原型 | DET-04、DTV-03 |
| P4-2 / P3-8 / P4-3 | 可选或条件包 | 全部转为必做（P4-3 的“搜索提为第 2 项”已由 Q02 新决定落地） | LIB-10、DTV-04、NAV-01 |
| P8-5（Q17） | 待定 | 同上 | SET-07 |

仍有效的旧决策：Q01（见第 4 节）、Q03（toast 顶部，已落地）、Q04（片名字号，见待确认）、Q06（详情标题与宽度，核对报告判为已一致）、Q13/Q14（成员就绪、创建房间流程，原型差异报告未列，按旧计划）、Q16（见待确认）、Q25、Q28、Q30、Q31、Q32、Q33（见第 4 节）。

---

## 3. 修改清单

### 3.1 首页（手机/平板）

| 编号 | 严重度 | 现状（实机 文件:行号） | 改成（原型要求） | 来源 |
|---|---|---|---|---|
| FIX-HOME-01 | 大 | 轮播每页都带“▶ 播放 / 剩余 N 分钟 / 查看详情”按钮：`discover_screen.dart:1682-1722`，`fusion_home_hero.dart:183-192`、`209-312`。平板走同一路径 | 手机/平板轮播不放任何按钮（原型 `ui.css:5` 手机 `.tv-hero-actions{display:none}`）；整张轮播图可点，点击进入详情。按钮只保留在 TV（见 HTV-01） | A-H1 |
| FIX-HOME-02 | 中 | 元信息是带半透明底、细边框、圆角 5 的小标签，含分级和画质，类型拆成两枚：`hero_metadata_badges.dart:35-80` | 一行纯文本“★ 9.5 │ 2026 │ 剧情 · 家庭”，12px，用“│”分隔，无底框，不显示分级和画质；评分点击说明仍保留 | A-H2 |
| FIX-HOME-03 | 中 | 服务器有 Logo 时显示 Logo 图，不显示文字片名：`fusion_home_hero.dart:163-175` | 轮播片名统一为文字：书法体 60px，上方英文原名 9px 大字距；不再用 clearLogo 替换。字号待确认（见 U-01） | A-H3 |
| FIX-HOME-04 | 中 | 自动轮播计时 `discover_screen.dart:1540`；选中圆点 18×6 带进度填充，颜色 onSurface 38%/24%：`:1585-1600` | 去掉自动轮播；圆点：选中 15×6 纯白，其余 6×6、29% 白；4 点居中 | A-H4 |
| FIX-HOME-05 | 中 | 顶栏“⋯”打开“选项”菜单（刷新加溢出 tab）：`discover_screen.dart:1083-1087` → `main_screen.dart:2445-2470` | 打开“首页选项”锚定菜单，两项：浏览全部媒体 / 外观与首页布局（`hero.js:43`）；依赖 NAV-02 去掉底栏“⋯” | A-H5 |
| FIX-HOME-06 | 小 | 顶栏放大镜进入独立 Search tab：`discover_screen.dart:1076-1080` | 放大镜进入“搜索”页（即 LIB 的筛选墙），40px 圆形玻璃按钮；依赖 NAV-01 | A-H6 |
| FIX-HOME-07 | 中 | 首页列表末尾没有入口卡：`discover_screen.dart:1287-1365` | 末尾增加“好故事，一起看”入口卡 340×80、r16：图标、标题“好故事，一起看”、副标题“创建房间，邀请朋友同步观看”、›；点击进入一起看 | A-H7 |
| FIX-HOME-08 | 小 | 行标题下没有评分来源入口：`hub_section.dart:504-600` | 电影行标题下增加“评分来源说明”小胶囊，点击打开 `rating_source_dialog` | A-H8 |
| FIX-HOME-09 | 小 | 行标题直接用服务器 hub 名，多服务器时加紫色“• 服务器名”：`hub_section.dart:542-575` | 固定两行：“电影 · 最近添加”“剧集 · 最近添加”，右侧“全部 ›”；去掉紫色服务器后缀，来源改在卡片副标题里用服务器图标区分；“继续观看”行在前 | A-H9 |
| FIX-HOME-10 | 小 | 海报角标带评分来源 Logo：`media_ratings_strip.dart:208-240`，`media_card.dart:664-675` | 只显示数字（如“8.3”），11px，位置/底色/圆角维持现状；与 LIB-09 同包 | A-H10 |
| FIX-HOME-11 | 小 | 卡宽 min(111, 33% 屏宽)：`discover_screen.dart:1336-1339` | 卡宽 105（390 宽框内露出下一张的比例按原型） | A-H11 |

### 3.2 首页（TV）

| 编号 | 严重度 | 现状（实机 文件:行号） | 改成（原型要求） | 来源 |
|---|---|---|---|---|
| FIX-HTV-01 | 大 | 焦点卡片驱动背景，左侧没有按钮也没有圆点；圆点被刻意隐藏：`discover_screen.dart:1444-1500`、`1555-1560`，`tv_spotlight_scaffold.dart:251-264` | 左侧信息区加两个按钮：白色“▶ 继续观看”胶囊和半透明“查看详情”胶囊，44 高；下方 4 个圆点（样式同 HOME-04）。卡片获得焦点时按原型更新主视觉 | A-T1 |
| FIX-HTV-02 | 中 | 左侧多一段 2–3 行简介，18–20px：`tv_spotlight_background.dart:199-240` | 去掉简介；只留英文原名、片名 62px、元信息、按钮、圆点 | A-T2 |
| FIX-HTV-03 | 小 | 元信息是“类型 · 分级 · 时长 · 日期”加评分：`tv_spotlight_background.dart:328-390` | “★ 9.5 │ 2026 │ 剧情 · 家庭”，与手机一致，含题材 | A-T3 |
| FIX-HTV-04 | 中 | 顶栏右侧没有搜索和“⋯”圆按钮，搜索放进了导航条：`discover_screen.dart:1060-1066` | 顶栏右上角加搜索和“⋯”两个圆按钮（“⋯”打开 HOME-05 的菜单）；导航胶囊只剩四项（NAV-05） | A-T4 |
| FIX-HTV-05 | 小 | 行标题前有 28px 填充图标，26px 粗体，“›”紧跟标题：`hub_section.dart:504-510`、`542`、`576-578` | 行标题 20px，无图标，“全部 ›”在最右端 | A-T5 |

### 3.3 导航（含 TV 顶栏）

| 编号 | 严重度 | 现状（实机 文件:行号） | 改成（原型要求） | 来源 |
|---|---|---|---|---|
| FIX-NAV-01 | 中 | 底栏第 2 项是“媒体库”（video_library 图标）：`navigation_tabs.dart:12-17`、`113-118` | 第 2 项文案“搜索”，田字格图标，进入 LIB 页（Q02 新决定）；搜索不再是独立 tab，需调整 `NavigationTabId`、`primaryNavigationIds`、启动页偏好迁移、`fusion_navigation_test.dart` | A-N1 |
| FIX-NAV-02 | 中 | 第 4 项后多一个 48px “⋯”，336 宽条被分成 4 个窄 tab 加更多：`fusion_navigation.dart:87-88`、`193-224` | 去掉“⋯”；底栏 336×58 平分 4 项；原溢出入口（探索、直播、下载等）的去处见待确认 U-05 | A-N2 |
| FIX-NAV-03 | 小 | Material Symbols rounded（home / video_library / group / 齿轮）：`navigation_tabs.dart:113-145` | 22px、1.7px 线宽的线性图标，设置用“滑杆”图标，一起看用线性双人图标 | A-N3 |
| FIX-NAV-04 | 小 | 首页深色时未选中项纯白：`fusion_navigation.dart:114-118` | 未选中用 caption 灰 #adada8（浅色 #686864） | A-N4 |
| FIX-NAV-05 | 中 | TV 顶栏为“首页/媒体库/一起看/搜索/设置/⋯”共 6 项：`fusion_navigation.dart:53-56`、`87-88` | TV 顶栏居中胶囊四项：首页 / 搜索 / 一起看 / 设置；搜索和“⋯”按钮移到右上圆按钮（HTV-04） | A-N5 |

### 3.4 搜索 / 媒体库

| 编号 | 严重度 | 现状（实机 文件:行号） | 改成（原型要求） | 来源 |
|---|---|---|---|---|
| FIX-LIB-01 | 中 | 页头是“[后端徽标] 库名 ▾”下拉加右侧“⋯”菜单：`libraries_screen.dart:787-850`、`930-960` | 页头“搜索”大标题 22px 粗体，右侧服务器图标按钮；库切换和管理入口的去处见待确认 U-03 | A-L1 |
| FIX-LIB-02 | 大 | 没有“媒体类型”行，靠库下拉切换：`library_quick_filters.dart:46-77` | 第 1 行：全部 / 电视剧 / 电影 / 动漫 / 综艺 / 演唱会 / 纪录 / 音乐，横滑；选中项 650 字重、紫底。需要跨库聚合“全部媒体”视图，涉及多服务器查询，可单独成包（升级为大） | A-L2 |
| FIX-LIB-03 | 中 | 手机端标签下还有“筛选 / 排序”胶囊行：`library_browse_tab.dart:1858`、`2221-2256` | 手机去掉该行，五行标签后直接是海报 | A-L3 |
| FIX-LIB-04 | 中 | 标签 12px 常规字重，padding 11×5，最小高 40：`library_quick_filters.dart:180-199` | 胶囊高 32，文字 15px/500，选中 650 加紫底 | A-L4 |
| FIX-LIB-05 | 小 | 题材、地区、年份每行末尾多一个“选项”标签：`library_quick_filters.dart:139` | 去掉；这三行行首标签为“不限” | A-L5 |
| FIX-LIB-06 | 小 | 排序行列出后端全部排序项：`library_quick_filters.dart:54-65` | 排序行固定 3 项：最新更新 / 最新上映 / 影片评分；其余排序项的去处见待确认 U-03 | A-L6 |
| FIX-LIB-07 | 小 | 搜索框和标签行左右边距 12，占位“搜索此媒体库”：`library_browse_tab.dart:1893-1925`，`library_quick_filters.dart:159` | 内容左边距约 17；搜索框 340×40，占位“输入影片名称搜索” | A-L7 |
| FIX-LIB-08 | 中 | 库网格副标题只有年份或 displaySubtitle：`media_card.dart:1323-1360` | 副标题 = 服务器图标加“共 N 季”（剧集）或年份；标题 14/650；三列、卡宽 107 | A-L8 |
| FIX-LIB-09 | 小 | 角标是“品牌 Logo + 8.5”：`media_ratings_strip.dart:230-236` | 黑底“8.5分”，11px/700，右下角；与 HOME-10 同包 | A-L9 |
| FIX-LIB-10 | 大 | TV：左侧 220 宽侧栏加网格，没有标签行：`library_browse_tab.dart:1828-1836`、`1933-1993` | TV：标题“搜索”，标题右侧搜索框加服务器按钮；五行标签横排；七列海报（Q11 作废） | A-L10 |
| FIX-LIB-11 | 中 | TV 页头是库内分区标签加工具图标排：`libraries_screen.dart:766-781`、`960-1022` | TV 页头只有“搜索”标题；推荐/浏览/合集/播放列表与工具图标的去处见待确认 U-03 | A-L11 |
| FIX-LIB-12 | 小 | TV 导航始终居中：`main_screen.dart:2504-2524` | 搜索页 TV 导航靠右，距右 28（`ui.css:9`） | A-L12 |

### 3.5 详情（手机/平板）

| 编号 | 严重度 | 现状（实机 文件:行号） | 改成（原型要求） | 来源 |
|---|---|---|---|---|
| FIX-DET-01 | 中 | 返回键带底圆形，右上没有“⋯”：`media_detail_screen.dart:3687-3698`，`action_buttons.dart:528-535` | hero 顶栏左“‹”无底，右上“⋯”（更多），下接标题 | B-D1 |
| FIX-DET-02 | 中 | 元信息合并为一行（年份·分级·时长·N 集·类型·全部画质），常折 2–3 行：`presentation.dart:229-249` | 两行 12px：第 1 行“来源 · 类型”（如“Tencent Video · 动画”）；第 2 行“共 N 季 · 21 分钟 · 1080p H264”；不显示分级 | B-D2 |
| FIX-DET-03 | 小 | 标题与元信息间距 14：`presentation.dart:242` | 约 7 | B-D3 |
| FIX-DET-04 | 中 | 图标行有下载、收藏、已看、更多四枚：`action_buttons.dart:524-533` | 播放键下只留 ♡、⚑ 两枚线性图标；更多挪到右上（DET-01）；下载入口并入“⋯”弹窗（P3-5 保留作废） | B-D4 |
| FIX-DET-05 | 中 | 有个人评分能力的服务器多出“你的评分”药丸：`media_detail_screen.dart:1163-1230`，`action_buttons.dart:536-537` | 去掉 chip，评分全页仅评分条一处；个人评分入口并入“⋯”弹窗。TV 同改（`responsive_layout.dart:170-185`） | B-D5、B-V6 |
| FIX-DET-06 | 大 | 三个全宽 58 高、r14 的选择字段（版本/音频/字幕）竖排，约 190px：`playback_selectors.dart:59-131`、`164-183`，`app_select_field.dart:191-230`；平板 ≥680 三列横排 `:134`；TV 同为三字段 `responsive_layout.dart:188-189` | hero 外一行紧凑版本胶囊：Emby 徽标 + “Emby” + “1080p · H264” + “2 个版本” + ›，约 236×38、r12；点击打开版本选择；去掉音频、字幕字段。手机、平板、TV 统一。电影文案“4K · 原始画质” | B-D6、D21、V4 |
| FIX-DET-07 | 小 | 版本弹窗副标题“第 1 个版本，共 2 个 · 大小”：`playback_selectors.dart:72-78`、`233-242` | 选项：服务器徽标 + “Emby · 1080p H264” / “默认线路 · 237.92 MB”（备用为“备用版本”） | B-D7 |
| FIX-DET-08 | 中 | 季选择 17px/500 纯白，文案“第4季”：`presentation.dart:84-89`，i18n `common.seasonNumber` | “第 4 季 ⌄”，11px 次要色，“第”与数字加空格；右侧“查看全部 ›” | B-D8 |
| FIX-DET-09 | 小 | 季弹窗无标题、单行季名：`presentation.dart:19-47` | 标题“选择季”；每项双行“第 N 季 / 共 X 集 · 已完结（或更新至）”加勾 | B-D9 |
| FIX-DET-10 | 中 | “查看全部”把横排原地换成纵向 EpisodeCard 长列表：`presentation.dart:101-103`，`media_detail_screen.dart:2754-2800` | 打开底部集数网格弹窗（Q08 作废）；点选后回到横排并滚动到该集 | B-D10 |
| FIX-DET-11 | 小 | 集卡状态为已观看/继续/未观看：`presentation.dart:311-315`、`410-415` | 副行“21 分钟 · 待播放 / 未观看”，选中集显示“待播放”；集卡 202 宽、序号角标 | B-D11 |
| FIX-DET-12 | 中 | 分组 chip 按已加载集数计算，多出“加载更多/重试”：`presentation.dart:429`、`456-460`，`episode_rail.dart:97-111` | 按已知总数一次显示整季所有组（1–10 / 11–20 / 21–27），未加载组可点击并触发加载；桌面/宽屏同样横排加分组（Q08 作废） | B-D12 |
| FIX-DET-13 | 中 | 季标题、集卡文字、分组 chip 硬编码 `Colors.white`：`presentation.dart:86`、`405`、`414`、`443-449` | 跟随主题前景色，浅色主题和浅色取色背景（`media_detail_screen.dart:3299-3315`）下可读 | B-D13 |
| FIX-DET-14 | 小 | “演员表”“视频 · 音频 · 字幕”：i18n `discover.cast`，`media_detail_screen.dart:3611-3614` | 区块标题“演员人员”“音视频字幕信息” | B-D14 |
| FIX-DET-15 | 小 | 有花絮时多出“预告片与花絮”：`media_detail_screen.dart:3588-3593` | 类型之后直接是相关影片，不单列该段 | B-D15 |
| FIX-DET-16 | 小 | 渲染服务器返回的若干 HubSection：`media_detail_screen.dart:3595-3608`，`hub_section.dart:500-590` | 单一“相关影片 · 全部 ›”，海报带评分角标与“年份 · 电影”副行 | B-D16 |
| FIX-DET-17 | 小 | 技术卡上方多一行标题，字段集不同：`media_detail_technical_info.dart:118`、`159-182` | 三张卡“视频 / 音频 / 字幕”，首行“标题：…”；视频字段：编码/分辨率/宽高比/帧率/视频范围/色域/位深度/像素格式；235 宽卡 | B-D17 |
| FIX-DET-18 | 小 | 左对齐键值卡，每个 part 一张：`media_detail_technical_info.dart:143-152` | 居中文件卡：片名 · 季集 / 路径 / 时长 · 大小 · 画质 | B-D18 |
| FIX-DET-19 | 小 | 页尾多“制作公司 / 导演 / 年龄分级”：`media_detail_screen.dart:3617-3647` | 去掉，文件卡即页尾 | B-D19 |
| FIX-DET-20 | 小 | “⋯”是锚定式上下文菜单，项目多：`action_buttons.dart:688-715` | 居中弹窗三项：一起看 / 下载此影片 / 查看媒体信息；并承接 DET-04、DET-05 挪入的入口 | B-D20 |

### 3.6 详情（TV）

| 编号 | 严重度 | 现状（实机 文件:行号） | 改成（原型要求） | 来源 |
|---|---|---|---|---|
| FIX-DTV-01 | 大 | 固定一屏 spotlight 加底部 `TvBrowseRail`，无类型 chip、无音视频/文件信息、无“查看全部”、无季下拉：`media_detail_screen.dart:3711-3800`、`4102-4176`，`tv_browse_rail.dart` | 可纵向滚动单页：左信息组加右大海报 → 版本胶囊 → “第 4 季 ⌄ / 查看全部” → 横排集卡 → 分组 chip → 演员 → 类型 → 相关影片 → 音视频信息 | B-V1 |
| FIX-DTV-02 | 中 | 信息组多聚焦集标题行和 3 行简介，元信息单行 18/700：`responsive_layout.dart:139-163` | 信息组只有标题、两行元信息、评分条、动作行 | B-V2 |
| FIX-DTV-03 | 大 | 行内为播放、预告、随机、下载、已看、待看清单、更多，没有收藏：`action_buttons.dart:432-440`、`460-477`（收藏仅在 `:494-506`） | 播放（约 215 宽）+ ♡ + ⚑，补上收藏；其余入口并入“⋯” | B-V3 |
| FIX-DTV-04 | 中 | 季 hub 直接横排，无分组条：`media_detail_screen.dart:4114-4131` | 横排集卡下加分组 chip，D-pad 焦点可达；风险高（TV 焦点系统） | B-V5 |

### 3.7 一起看

| 编号 | 严重度 | 现状（实机 文件:行号） | 改成（原型要求） | 来源 |
|---|---|---|---|---|
| FIX-TG-01 | 中 | 上下两条通栏按钮：紫底“＋ 创建会话”、描边“⊕ 加入会话”：`watch_together_screen.dart:256-273`，`mono_theme.dart:88-100` | 同一行两个自适应宽度胶囊：白底黑字“创建房间”、深灰“邀请码加入”，无图标；TV 两栏同样改 | A-G1、G7 |
| FIX-TG-02 | 小 | i18n `watchTogether.createSession`=“创建会话”，`joinSession`=“加入会话” | 全页“会话”改为“房间”（含 zh/en 等其它语言同步核对） | A-G2 |
| FIX-TG-03 | 小 | 单行 25px 标题“相隔两地，一起入戏。”，实心 `groups_rounded`：`watch_together_screen.dart:235-255` | 线性双人图标；“WATCH TOGETHER”小标签；两行大字“隔着距离，/也能一起入戏。”；说明“邀请朋友加入房间，同步播放与暂停。/各自连接媒体服务器。” | A-G3 |
| FIX-TG-04 | 中 | “最近的房间”titleLarge，下带长说明：`watch_together_screen.dart:286-296` | “我的房间”13px 粗体，右侧“最近”；去掉长说明 | A-G4 |
| FIX-TG-05 | 中 | ListTile 样式：门图标、房间名、等宽邀请码、⋮、控制模式标签：`watch_together_screen.dart:583-660`，`recent_rooms_service.dart:17-23` | 房间卡：“等待开始 · 3 位成员”标签、房间名、“影片 · 第 7 集”、W/A/L 头像组、右下“进入房间 →”。影片名/成员数需新增本地字段或实时数据，见待确认 U-02 | A-G5 |
| FIX-TG-06 | 小 | 没有页脚：`watch_together_screen.dart:286-318` | 页脚“房间仅通过邀请加入。” | A-G6 |

### 3.8 设置

| 编号 | 严重度 | 现状（实机 文件:行号） | 改成（原型要求） | 来源 |
|---|---|---|---|---|
| FIX-SET-01 | 中 | 开关打开为品牌紫 #6060f5 轨道加白钮；轨道/描边硬编码偏紫灰（#41424e、#60606e、#bcb9ce、#d4d3df）：`settings_presentation.dart:119-139` | 打开：#d5d8df 浅灰轨道加深色圆钮；关闭：前景 15% 白；全部走中性 token，所有设置页开关生效 | A-S4、C-C4 |
| FIX-SET-02 | 中 | TV 设置页顶部仍有导航胶囊：`main_screen.dart:2504-2524` | TV 设置页隐藏顶部导航（`ui.css:11`），全屏两栏；平板 ≥760 的两栏同样检查 | A-S8 |
| FIX-SET-03 | 小 | TV 左栏选中态 primaryContainer 紫底加紫字 600：`settings_category_pane.dart:124-150` | 用户已决定：白 18% 中性底、白字、常规字重（浅色主题对应的中性深色底待核）。左栏 10 类：服务器与账户 / 播放 / 字幕 / 弹幕 / 一起看 / 外观 / 下载与离线 / 连接与集成 / 网络与缓存 / 关于 | A-S10 |
| FIX-SET-04 | 小 | 一级行尾值：播放显示“mpv/ExoPlayer”，服务器无“3 台”，网络与缓存无值，关于无版本：`settings_screen.dart:236-300`、`555-565` | 播放“自动”；服务器与账户“3 台”（实为服务器数量）；网络与缓存“演示偏好”按原型取实值；“关于 Velo”加版本号如“2.23.1”；账户卡“Emby · N 台服务器” | A-S1 |
| FIX-SET-05 | 小 | 外观行尾显示主题模式：`settings_screen.dart:541-551` | 显示“跟随海报”（海报取色状态） | A-S2 |
| FIX-SET-06 | 小 | 没有页脚：`settings_screen.dart:288-296` | 页脚“VELO · YOUR MEDIA, YOUR WAY” | A-S3 |
| FIX-SET-07 | 小 | 行高 48，组圆角 15：`settings_presentation.dart:10-13` | 行高 51，组圆角 15（原型实测）；同步 `setting_tile.dart` 并重生成 golden | A-S5 |
| FIX-SET-08 | 小 | 左上角有径向光晕渐变：`settings_presentation.dart:145-155` | 纯色背景（深色 #121212；OLED 档按 Q01 仍纯黑） | A-S6 |
| FIX-SET-09 | 小 | Material Symbols 图标（play_circle、network_check 等）：`settings_screen.dart` 各 tile | 线性图标：播放用三角、字幕用字幕框、弹幕用气泡、服务器、网络与缓存用地球、关于用 i | A-S7 |
| FIX-SET-10 | 小 | TV 左栏“视频播放”：`settings_screen.dart:393` | “播放” | A-S9 |
| FIX-SET-11 | 中 | 网络与缓存只有首页缓存/图片缓存/播放缓冲三区，无线路入口：`network_cache_settings_screen.dart` | 服务器线路子页：新增 / 选择 / 删除线路，名称、地址、端口校验；“自动最快”按原型。**需先确认连接模型**（`lib/models` 与 database 表是否支持多线路），可单独成包 | C-UI-04 |

### 3.9 播放器（手机/平板）

| 编号 | 严重度 | 现状（实机 文件:行号） | 改成（原型要求） | 来源 |
|---|---|---|---|---|
| FIX-PLM-01 | 小 | 有章节时顶栏最左多“章节”按钮：`vc/mobile_video_controls.dart:211-227` | 顶栏右侧顺序：（一起看）弹幕、投屏、横竖屏、⋯，不放章节；章节入口放选集抽屉（待确认 U-06） | B-M1 |
| FIX-PLM-02 | 小 | 黑 54% 胶囊，仅人数图标加数字：`watch_together_overlay.dart:110-135`，`video_controls_header.dart:96-108` | 青色文字胶囊“一起看 · 3”，仅在房间中显示 | B-M2 |
| FIX-PLM-03 | 小 | 片名 16/粗，副行“第 4 季 · 第 7 集 · 新的旅程”13px：`video_controls_header.dart:243-268` | 片名大号；副行“S4 · E7  新的旅程” | B-M3 |
| FIX-PLM-04 | 中 | 时间在轨道下另起一行，右侧负剩余时间加结束时刻：`mobile_video_controls.dart:343-358`，`video_timeline_bar.dart:136-175` | 单行“8:32 ━━━ 23:40”，右侧为总时长；底部 HUD 降低一行高度 | B-M4 |
| FIX-PLM-05 | 小 | 抽屉标题“更多”：`player_settings_drawer.dart:152` | 标题“播放设置”（选集抽屉标题“选集”、倍速“播放速度”） | B-M5 |
| FIX-PLM-06 | 小 | 画面比例 3 档；多出“兜底片头秒数/片尾秒数”两行：`player_settings_drawer.dart:216-241` | 视频标签：画面比例 5 档（默认/拉伸/填充/16:9/4:3），自动跳过开关，更多（播放内核/版本与画质/画面缩放…）；去掉兜底秒数两行。5 档需改 `onCycleBoxFitMode` 和内核层，可拆包（待确认 U-07） | B-M6 |
| FIX-PLM-07 | 小 | 锁屏钮 44×44、r22、黑 42%：`video_controls.dart:1596-1640` | 左中锁屏 36 圆 | B-M7 |

### 3.10 播放器（TV）

| 编号 | 严重度 | 现状（实机 文件:行号） | 改成（原型要求） | 来源 |
|---|---|---|---|---|
| FIX-PLT-01 | 中 | 进度条与按钮行间多一行“音轨 · 字幕 · 倍速”摘要：`desktop_video_controls.dart:822`，`player_track_summary.dart:84-123` | 去掉摘要行，进度条下直接是底栏 | B-P1 |
| FIX-PLT-02 | 中 | 右组为无底图标 + 标签 + 值三行：`tv_action_button.dart:47-80`，`track_chapter_controls.dart:456-500` | 7 个 62×62 磨砂圆角方块，图标加一行字；倍速/字幕/音轨显示当前值（1.0x / 简中 / 普通话），其余“选集/章节/弹幕/设置”；标签用“倍速”“音轨” | B-P3 |
| FIX-PLT-03 | 小 | 左组未聚焦无底色，上/下一章图标为 fast_rewind / fast_forward：`player_focus_disc.dart:44-58`，`desktop_video_controls.dart:843-856`、`906-918` | 7 键（|◁ « ⟲10 ⏸ ⟳10 » ▷|）常态均有半透明圆底，播放键更大；上/下一章为 « » | B-P4 |
| FIX-PLT-04 | 中 | 隐藏时 ←→ 原地快进快退，↑↓/Enter 唤出：`parts/key_events.dart:309-327` | 隐藏时任意方向键或 Enter 只唤出控件并聚焦播放/暂停（Q24 作废）；快进快退在控件显示后操作 | 旧计划 Q24 |
| FIX-PLT-05 | 小 | 时间在轨道左右同一行：`video_timeline_bar.dart:118-132` | 时间在进度条上方两端 | B-P5 |
| FIX-PLT-06 | 小 | 副行缺集名；一起看始终为图标按钮：`video_controls_header.dart:173-214` | 副行“第 4 季 · 第 7 集  新的旅程”；一起看为“一起看 · 3”文字胶囊（顶栏右：弹幕、一起看、⋯，均有半透明圆底）；会话中显示规则见待确认 U-08 | B-P6 |
| FIX-PLT-07 | 小 | 左右组之间多“结束时间：HH:MM”：`desktop_video_controls.dart:925-946` | 去掉，留空 | B-P2 |

### 3.11 共用

**主题 token**

| 编号 | 严重度 | 现状（实机 文件:行号） | 改成（原型要求） | 来源 |
|---|---|---|---|---|
| FIX-THEME-01 | 大 | ColorScheme 未设 `onSurfaceVariant`，全仓 81 处次要文字回退到主文字色：`theme/mono_theme.dart:110` | 设为 caption：深色 #adada8、浅色 #686864（`--velo-caption`）；先行，后续各页视觉回归依赖它 | C-C1 |
| FIX-THEME-02 | 小 | 首页说明文字硬编码蓝灰 #b8bdc7 / #646b77：`home_typography.dart:28` | 中性 #adada8 / #686864 | C-C3 |
| FIX-THEME-03 | 中 | 主/次按钮全局胶囊；对话框次按钮无底无边：`mono_theme.dart:99`、`164-180`，`dialogs.dart:17-18` | 对话框按钮 r14：主按钮实底，次按钮 7% 底加 edge 描边（`.modal-sheet .btn.pri/.sec`） | C-C5 |
| FIX-THEME-04 | 小 | 输入框 r12、无描边、前景 8% 填充，dense 约 44：`mono_theme.dart:289-300` | r14、1px edge 描边、底为页面底色、最小高 48 | C-C6 |

**提示条（AppToast，整体已落地，只补差异）**

| 编号 | 严重度 | 现状（实机 文件:行号） | 改成（原型要求） | 来源 |
|---|---|---|---|---|
| FIX-TOAST-01 | 中 | 操作能力已建好（`app_toast.dart:159-186`）但 `snackbar_helper.dart:11-30` 不暴露 action，全仓无调用 | helper 暴露 `actionLabel/onAction`；接入：收藏/已看失败、连接失败带“重试”；移出继续观看、删除/移除带“撤销”；2px 剩余时间细线 | C-T1 |
| FIX-TOAST-02 | 中 | 460 宽度上限只在播放器横屏生效：`app_toast.dart:563-573` | 最大宽 = 屏宽−32，横屏 460，TV 720；使用 `OverlayTokens.notificationMaxWidth` | C-T2 |
| FIX-TOAST-03 | 小 | ×N 徽标为中性 10% 底：`app_toast.dart:604-616` | 状态色 22% 底加状态色字 | C-T3 |
| FIX-TOAST-04 | 小 | TV“菜单 撤销”仅 24px 文字：`app_toast.dart:620-624` | 48 高、r24、淡紫底胶囊，“菜单”带键帽描边 | C-T4 |
| FIX-TOAST-05 | 小 | 只有 blur 26：`app_toast.dart:668` | `blur(26px) saturate(1.4)` | C-T5 |
| FIX-TOAST-06 | 小 | TV 描边 0.5px：`app_toast.dart:664` | TV 描边 1.5（按 1080 坐标） | C-T6 |
| FIX-TOAST-07 | 小 | 150/120 档只在 accessibleNavigation 或低性能生效，系统减少动态下 0ms 硬切：`app_toast.dart:319-336` | 减少动态时 150ms 淡入、120ms 淡出 | C-T7 |
| FIX-TOAST-08 | 小 | 错误既是 liveRegion（polite）又额外 assertive 播报：`app_toast.dart:407-419`、`684` | 常驻 `role=status` 与 `role=alert` 两个 live 区，错误只播报一次 | C-T8 |
| FIX-TOAST-09 | 小 | TV 播放器 HUD 隐藏时按手机规则取 14：`app_toast.dart:506-512` | TV 无导航时距顶 54（1080 坐标） | C-T9 |
| FIX-TOAST-10 | 小 | 旧 floating snackBarTheme 与 `rootScaffoldMessengerKey` 仍在：`mono_theme.dart:255-263`，`snackbar_helper.dart:7` | 删除，防止 ScaffoldMessenger 直调回到底部 | C-T10 |
| FIX-TOAST-11 | 小 | 不同文案替换为 120+120ms：`app_toast.dart:392-403` | 旧内容 60ms 淡出加新内容 120ms 淡入 | C-T11 |

**对话框**

| 编号 | 严重度 | 现状（实机 文件:行号） | 改成（原型要求） | 来源 |
|---|---|---|---|---|
| FIX-DLG-01 | 中 | `_OptionPickerDialog` 用原生 SimpleDialog（12 个调用点），不透明、无磨砂描边，屏边 8：`dialogs.dart:623-626`，`local_media_match_dialog.dart:128` | 全部走 `AppDialog`：磨砂、edge 描边，屏边 16；审计其余 showDialog | C-D1 |
| FIX-DLG-02 | 小 | 默认 150ms 纯淡入：`dialogs.dart:34` | 180ms 淡入加缩放 .97（`velo-dialog-in`） | C-D2 |
| FIX-DLG-03 | 小 | 遮罩黑 50% / 32%、无模糊：`mono_theme.dart:232` | `--velo-shade` #0008 / #17151d45，blur 5px | C-D3 |
| FIX-DLG-04 | 中 | `AppAlertDialog` 标题行无关闭钮：`app_dialog.dart:46-92` | 每个对话框标题行右侧 30px 圆形 ×（`ui.js sheet()`） | C-D4 |
| FIX-DLG-05 | 小 | 单选圆圈加 ListTile：`settings_utils.dart:180-195` | 整行 5% 底、r12；选中淡紫底加紫字加右侧 ✓（`.choice-row`） | C-D5 |
| FIX-DLG-06 | 小 | 浮层底按 90% / 94%：`overlay_tokens.dart:7-8` | 按原型 CSS 的 `--velo-overlay` #202020f2（95%）；规范文字与原型 CSS 矛盾，已按原型 | C-D6 |

**菜单与字段**

| 编号 | 严重度 | 现状（实机 文件:行号） | 改成（原型要求） | 来源 |
|---|---|---|---|---|
| FIX-MENU-01 | 中 | AppMenuItem 最小高 40（带副标题 52）：`app_menu.dart:623` | 菜单行最小高 48（`.pop button{min-height:48px}`） | C-S1 |
| FIX-MENU-02 | 中 | 字段主次值 maxLines 1 加省略号：`app_select_field.dart:208`、`219` | 长轨名换行（`overflow-wrap:anywhere`），不挤箭头 | C-S2 |
| FIX-MENU-03 | 小 | 展开态描边为前景色，底色换选中紫底：`app_select_field.dart:176-181` | 展开态 2px #6060f5（accent）描边，底色不变 | C-S3 |
| FIX-MENU-04 | 小 | 字段底为 surface 实色：`app_select_field.dart:176` | 前景 4% 叠加 | C-S4 |
| FIX-MENU-05 | 小 | 锚定菜单无遮罩、无关闭钮，宽度按字数估算最大 360：`app_menu.dart:93-97`、`835-846` | 固定宽 286；`modal-shade` 遮罩加 blur 5；标题行加 × | C-S5 |
| FIX-MENU-06 | 小 | 空间不足时上翻或夹屏边：`app_menu.dart:797-820` | 非播放页空间不足时居中 | C-S6 |
| FIX-MENU-07 | 小 | 选中底 primary 12%；键盘焦点仅 8% 底，盖掉选中底：`app_menu.dart:696-697` | 选中用 `--velo-selected` 实色；`:focus-visible` 2px 紫描边 | C-S7 |

**可达性与焦点**

| 编号 | 严重度 | 现状（实机 文件:行号） | 改成（原型要求） | 来源 |
|---|---|---|---|---|
| FIX-A11Y-01 | 中 | 约 15 处 IconButton 无 tooltip/语义：`join_session_dialog.dart:71`、`search_input_field.dart:97`、`action_buttons.dart:702`、`watch_together_screen.dart:631`、`tag_edit_dialog.dart:134`、`library_management_sheet.dart:442`、`guide_tab.dart:1528/1570` 等 | 每个图标按钮有可理解名称（tooltip 加 semantics） | C-A1 |
| FIX-A11Y-02 | 小 | 焦点 2.5px 内描边加 1.02 放大（卡片 1.03）：`focus_theme.dart:10`、`24`、`84-93` | `:focus-visible` 2px `--velo-focus` 描边，offset 3，不缩放 | C-A2 |
| FIX-A11Y-03 | 小 | 普通 InkWell/ListTile 无按压反馈（NoSplash）：`press_feedback.dart` | 按压 .97、120/180ms，全局覆盖（旧计划推迟，现纳入末波） | C-A3 |

---

## 4. 不改项

| 项 | 原因 |
|---|---|
| Q01：深色底 #121212 加 OLED 纯黑档，TV 默认 OLED，底色为 #000（C-C2） | 用户亲自决定保留；TV 底色与原型 #121212 的差异列入此处，不改。FIX-SET-08 等涉及底色处，OLED 档仍纯黑 |
| Q03：toast 顶部迁移与 AppToast 主体 | 已落地并贴近定稿，只补 TOAST-01…11 的差异 |
| Q06：详情标题 36/32、内容宽 560 | 核对报告判为已一致 |
| C-UI-01 / 02 / 03 / 05 / 06 / 07 与 FINAL 增补 | 已实现或属规范自己列的后续项（同服逐库 PERF-02/05/06），不计差异；A11Y-01/02 等残余已计入 |
| TV 不提供投屏；Q25 桌面播放器保持现有按钮条；Q33 内容条下线与自动隐藏 10s | 原型 TV 无投屏；桌面不在原型范围；Q33 已按原型 |
| Q28 加载本地字幕、Q30 次字幕提示、Q31 弹幕删除确认居中框 | 原型声明不在本轮范围或无差异，不改 |
| Q13 成员就绪、Q14 创建房间流程（不做选片与开始按钮） | 本轮核对报告未列为差异，沿用旧计划结论 |
| 详情标题字号、播放器抽屉 340 宽/240ms/四标签、演员 65/r14、类型 chip、评分条、TV 右组顺序与七个传输键 | 核对报告判为已基本一致 |
| 平板手机之外的独立原型框 | 原型无平板框，平板跟随手机布局，不单列 |

---

## 5. 任务包划分

规模：S = 约 0.5 天内，M = 约 1 天，L = 2 天以上或需要大量测试重生成。每个包一个提交。每个会话做 3–6 个包。

### 波次与并行关系

- **第 1 波（共用先行，4 包互相并行）**：FX-01 ～ FX-04。其余页面都依赖这些 token 与组件。
- **第 2 波（页面，依赖第 1 波；下列包互相并行）**：FX-05 ～ FX-08、FX-10、FX-11、FX-13、FX-14。
- **第 3 波（依赖第 2 波的同文件或导航改动）**：FX-09、FX-12、FX-15、FX-17。
- **第 4 波（高风险、条件包）**：FX-16、FX-18、FX-19、FX-20、FX-21、FX-24。
- **第 5 波（扫尾与回归）**：FX-22、FX-23。

| 包 | 名称 | FIX 编号 | 主要文件 | 规模 | 波次 / 并行与依赖 |
|---|---|---|---|---|---|
| FX-01 | 主题 token | THEME-01…04、TOAST-10、DLG-03 | `theme/mono_theme.dart`、`theme/home_typography.dart` | M | 1；与 FX-02/03/04 并行。独占 `mono_theme.dart` |
| FX-02 | Toast 组件补差 | TOAST-02…09、11 | `widgets/app_toast.dart` | M | 1；并行 |
| FX-03 | 对话框 | DLG-01、02、04、05、06 | `utils/dialogs.dart`、`widgets/app_dialog.dart`、`theme/overlay_tokens.dart`、`settings_utils.dart`、`local_media_match_dialog.dart` | M | 1；并行 |
| FX-04 | 菜单、字段、焦点 | MENU-01…07、A11Y-02 | `widgets/app_menu.dart`、`widgets/app_select_field.dart`、`focus/focus_theme.dart` | M | 1；并行 |
| FX-05 | 导航与壳 | NAV-01…05、LIB-12、SET-02 | `navigation/navigation_tabs.dart`、`fusion_navigation.dart`、`main_screen.dart`、`fusion_navigation_test.dart`、启动页偏好迁移 | L | 2；依赖 FX-01。独占 `main_screen.dart`。NAV-02 的溢出入口去处待确认 U-05 |
| FX-06 | 海报卡共用 | HOME-10、HOME-11、LIB-08、LIB-09 | `media_card.dart`、`media_ratings_strip.dart` | S | 2；并行 |
| FX-07 | 首页手机/平板 | HOME-01、02、03、04、07、08、09 | `discover_screen.dart`、`fusion_home_hero.dart`、`hero_metadata_badges.dart`、`hub_section.dart` | L | 2；与 FX-09 同改 `discover_screen.dart`，必须先于 FX-09 |
| FX-08 | 一起看 | TG-01、02、03、04、06 | `watch_together_screen.dart`、i18n | M | 2；并行 |
| FX-10 | 播放器手机、头部与时间条 | PLM-01…07、PLT-05、PLT-06 | `vc/mobile_video_controls.dart`、`video_controls_header.dart`、`video_timeline_bar.dart`、`player_settings_drawer.dart`、`watch_together_overlay.dart`、`video_controls.dart` | L | 2；并行。PLM-06 的 5 档内核见 FX-24 |
| FX-11 | 详情 A：顶栏与动作区 | DET-01…05、DET-20 | `media_detail_screen.dart`、`action_buttons.dart`、`presentation.dart`（229-249） | M | 2；先于 FX-12 |
| FX-13 | 详情 C：下半区 | DET-14…19 | `media_detail_screen.dart`（3588-3647）、`media_detail_technical_info.dart`、`hub_section.dart`（仅 DET-16，与 FX-07 的 HOME 改动需协调） | M | 2；并行（与 FX-11 同文件不同区段，合并时注意冲突） |
| FX-14 | 设置 | SET-01、03…10 | `settings_screen.dart`、`settings_presentation.dart`、`settings_category_pane.dart`、`setting_tile.dart`、i18n、golden | M | 2；依赖 FX-01（token） |
| FX-09 | 首页顶栏与 TV | HOME-05、06、HTV-01…05 | `discover_screen.dart`、`tv_spotlight_scaffold.dart`、`tv_spotlight_background.dart`、`hub_section.dart` | L | 3；依赖 FX-05、FX-07 |
| FX-12 | 详情 B：版本与剧集区 | DET-06…13 | `playback_selectors.dart`、`app_select_field.dart`、`presentation.dart`、`episode_rail.dart`、`media_detail_screen.dart`（2754-2800） | L | 3；依赖 FX-11、FX-04 |
| FX-15 | 搜索/媒体库（手机） | LIB-01、03…07 | `libraries_screen.dart`、`library_browse_tab.dart`、`library_quick_filters.dart` | M | 3；依赖 FX-05、FX-06。库切换去处待确认 U-03 |
| FX-17 | 播放器 TV 底栏 | PLT-01…04、PLT-07 | `desktop_video_controls.dart`、`tv_action_button.dart`、`track_chapter_controls.dart`、`player_focus_disc.dart`、`parts/key_events.dart` | M | 3；依赖 FX-10（同一时间条/头部文件已改完） |
| FX-16 | 详情 TV | DTV-01…04 | `media_detail_screen.dart`（3711-4176）、`responsive_layout.dart`、`tv_browse_rail.dart`、`action_buttons.dart` | L | 4；依赖 FX-11、FX-12；D-pad 焦点高风险 |
| FX-18 | 媒体库 TV | LIB-10、LIB-11 | `library_browse_tab.dart`、`libraries_screen.dart` | L | 4；依赖 FX-15 |
| FX-19 | 跨库“全部媒体”与类型行（条件包） | LIB-02 | 库聚合查询层、`library_quick_filters.dart` | L | 4；依赖 FX-15；先确认 U-03，与 FX-18 并行 |
| FX-20 | 线路管理（条件包） | SET-11 | `network_cache_settings_screen.dart`、`lib/models`、database | L | 4；先确认连接模型，可单独成包；依赖 FX-14 |
| FX-21 | 房间卡数据（条件包） | TG-05 | `watch_together_screen.dart`、`recent_rooms_service.dart`（`.g.dart` 重生成与旧数据迁移） | M | 4；先确认 U-02；依赖 FX-08 |
| FX-24 | 画面比例 5 档内核（条件包） | PLM-06（5 档部分） | `TrackControlsState.onCycleBoxFitMode`、mpv/Exo 内核层 | L | 4；先确认 U-07；依赖 FX-10 |
| FX-22 | Toast 操作接入与可达性扫尾 | TOAST-01、A11Y-01、A11Y-03 | `snackbar_helper.dart`、各页调用点、约 15 处 IconButton、`press_feedback.dart` | L | 5；依赖所有页面包完成，避免与页面包冲突 |
| FX-23 | 全页视觉回归 | 无新增 FIX | golden 重生成，截图对照原型 | M | 5；最后做 |

### 会话建议（每会话 3–6 包）

| 会话 | 包 | 说明 |
|---|---|---|
| 1 | FX-01、FX-02、FX-03、FX-04 | 第 1 波，四包并行或顺序均可 |
| 2 | FX-05、FX-06、FX-07、FX-08 | 第 2 波 |
| 3 | FX-10、FX-11、FX-13、FX-14 | 第 2 波，互不依赖 |
| 4 | FX-09、FX-12、FX-15、FX-17 | 第 3 波 |
| 5 | FX-16、FX-18，及 FX-19、FX-20、FX-21、FX-24 中已确认的条件包 | 第 4 波 |
| 6 | FX-22、FX-23 | 第 5 波 |

共 24 个包（含 4 个条件包 FX-19、20、21、24），5 个波次。

---

## 6. 待确认项

| 编号 | 问题 | 影响 |
|---|---|---|
| U-01 | 首页片名字号：规范文字写 42（窄屏 37），原型 CSS 与现状为 45；是否在“按原型”下取 CSS 值 45？（Q04 一直未拍板） | HOME-03、HTV-02 |
| U-02 | 房间卡的影片名、成员数、头像：数据来源未定（新增本地字段 `lastMediaTitle`，或实时会话数据）；规范 §8 禁止虚构数据，是否允许演示占位？ | TG-05、FX-21 |
| U-03 | 搜索页（原型“搜索”）取代库下拉后：多库切换、管理媒体库、刷新、库内“推荐/浏览/合集/播放列表”分区、其余排序项放哪？“类型”行是否做跨库聚合查询（多服务器、查询语义）？Q12 的搜索结果页/人物结果原型无设计，是否要求设计补稿？ | LIB-01、02、06、11、FX-19 |
| U-04 | 同 U-03 的搜索结果页：沿用现有结果页，仅接 token，是否可接受 | Q12 |
| U-05 | 底栏去掉“⋯”后，探索、直播、下载等溢出 tab 的入口放哪（原型只有 4 项）？ | NAV-02 |
| U-06 | 手机无队列有章节的电影，章节入口放选集抽屉哪里？ | PLM-01 |
| U-07 | 画面比例 5 档需动 mpv/Exo 内核，原型称“未改变内核”：是否同意拆包并接受工期？ | PLM-06、FX-24 |
| U-08 | 播放器“一起看”胶囊：Q16 记录“原型 TV 顶栏恒有”，B 报告写“无会话时不显示”，以哪个为准？无会话时点击是否打开发起/加入抽屉？ | PLM-02、PLT-06 |
| U-09 | 设置行高：原型规范写 58 / r14，原型实测 51 / r15，按实测取 51；若要按规范需另告 | SET-07 |
| U-10 | 线路管理的连接模型：`lib/models` 与 database 表是否已有多线路字段？“自动最快”是否仅展示不探测？ | SET-11、FX-20 |
| U-11 | TV 设置左栏选中态在浅色主题下的中性底色未在原型中给出 | SET-03 |
| U-12 | Q32 平板抽屉宽度 400 与原型 340 是否统一（原型只有手机框） | PLM-05 附近，未列 FIX |

## 7. 待确认项结论（2026-11-16）

| 编号 | 结论 | 决定方 |
|---|---|---|
| U-05 | 探索、直播、下载等原溢出入口移入首页右上角“⋯”（首页选项）菜单：浏览全部媒体 / 探索 / 直播 / 下载 / 外观与首页布局，仅显示当前可用项；TV 同样放在顶栏右侧“⋯”。底栏只留 4 项。 | 用户 |
| U-03 / U-04 | 搜索页即跨库筛选墙，不再有“单库”概念：①“全部/电视剧/电影/动漫…”类型行按库的媒体类型聚合（同类型多库、多服务器合并），末尾追加“合集”“播放列表”两个 chip；②右上服务器按钮打开“选择服务器”抽屉（所有服务器 + 各服务器），抽屉下半区为“媒体库”分组：各库显示/隐藏开关、“管理媒体库”“刷新媒体库”两行；③库内“推荐”分区取消（首页承担）；④排序固定 3 项，再次点选中项切换升/降序，其余排序项取消；⑤类型/地区/年份 facet 取当前结果集的并集；⑥输入关键词就地过滤同一墙面，不跳独立结果页，有人物命中时在网格上方加一行“演员”横排。 | 用户授权由方案定 |
| U-02 | 房间卡数据：在 recent_rooms 本地记录中新增 lastMediaTitle、lastEpisodeLabel、lastMemberCount、lastMemberInitials（≤3）、lastSeenAt，在创建/加入/换片/成员变化时写入；卡片显示真实记录值，状态标签房间在线时用实时状态（等待开始/播放中），离线时显示“N 小时前 · 3 位成员”；缺字段就隐藏该行，不造数据。旧记录无需迁移，字段可空。 | 用户授权由我定 |
| U-10 / FX-20 | 线路管理单独成包，放第 4 波；开工前先核对现有连接模型，“自动最快”只展示不测速。 | 用户 |
| U-07 / FX-24 | 画面比例不改，保持现有 3 档；FX-24 取消。PLM-06 其余部分（去掉兜底片头/片尾秒数两行等）照做。 | 用户 |
| U-01 | 首页片名字号取原型 CSS 实际值 45（宽 <360 时 37）。 | 用户授权由我定 |
| U-09 | 设置行高 51、组圆角 15（原型实测）。 | 用户授权由我定 |
| U-06 | 章节入口放进选集/播放列表抽屉，作为顶部第二个标签“章节”；无剧集无队列时抽屉只有“章节”标签，按钮文案“章节”。 | 默认 |
| U-08 | 按原型：TV 顶栏“一起看”胶囊恒显示，无会话时点击打开发起/加入抽屉；手机仅会话中显示。 | 默认（按原型） |
| U-11 | TV 设置左栏选中态：深色用原型灰白；浅色主题用前景 10% 中性底 + 前景色文字。 | 默认 |
| U-12 | 抽屉宽：手机 340，平板保持 400。 | 默认 |
