# UI V1 第二轮待修清单（2026-11-16）

基准：`docs/ui-v1-fix-list-2026-11-16.md`（第 2、7 节为用户决定）与定稿原型 `design/prototype/`。
来源：对 `claude/practical-ptolemy-q17g45` 的 a3a67b6 逐条验收（共 119 条，已完成 106 条）。结论靠读代码与原型对照，未实机运行；文件:行号以 a3a67b6 为准，开工前按符号重新定位。

## A. 界面未对齐原型

| 编号 | 原条目 | 问题 | 改成 | 位置 |
|---|---|---|---|---|
| R2-01 | HOME-04 | 手机/平板首页仍有 8 秒自动轮播 | 去掉自动轮播与计时器，只能手动滑动/点圆点切换 | `discover_screen.dart` `_heroAutoScrollDuration`、`_autoScrollTimer` |
| R2-02 | HOME-05 | 首页“⋯”菜单标题显示“选项”，下面又多一行“首页选项”；菜单以按钮中心定位 | 标题只有“首页选项”一行；菜单锚在按钮正下方右对齐 | `main_screen.dart` 约 2462-2482，`app_menu.dart` 约 107 |
| R2-03 | THEME-02 | 首页走带底图分支时次要文字被强制纯白（卡片副标题、“全部 ›”、一起看入口副标题、评分来源胶囊），浅色主题下也是白 | 用原型次要灰（caption token），浅色主题跟随主题；同步修改锁定白色的测试 | `mono_presentation.dart` 62-65，`discover_screen.dart` 96-101，`test/theme/mono_theme_test.dart` 91、106 |
| R2-04 | DLG-01 | 删除下载进度框仍用原生弹窗路由：无模糊遮罩/缩放；该框不可关闭但标题行出现 × | 改用统一对话框样式，不可关闭时不显示 × | `smart_deletion_handler.dart` 46 |
| R2-05 | LIB-10、LIB-12 | TV 搜索页页头（搜索框+服务器按钮）在右上，与靠右的 TV 顶部导航疑似重叠；golden `fusion_library_tv.png` 仍是旧侧栏 | 按原型：导航在上，页头下移 65（纳入 `_tvContentBelowNavigation`）；重生成该 golden | `libraries_screen.dart`、`main_screen.dart` |
| R2-06 | DET-09 | 季选择弹窗第二行一律“更新至 N 集” | 已完结季显示“共 X 集 · 已完结”，连载中显示“更新至 N 集” | 季选择弹窗 |
| R2-07 | DTV-01 | TV 详情相关区按服务器分组渲染多行，每行都叫“相关影片” | 合并成一行“相关影片”（同手机端） | `media_detail_screen.dart` TV 分支 |
| R2-08 | SET-04 | 账户卡副行“N 个服务器” | “N 台服务器” | 设置账户卡 / i18n |
| R2-09 | SET-07 | TV 设置行高用了 51 | TV 设置行高 55（手机/平板保持 51） | `setting_tile.dart` / settings presentation |
| R2-10 | PLM-02 | 手机“一起看 · N”胶囊缺人形图标 | 胶囊前加人形图标（原型 player.html:123） | 手机播放器顶栏 |
| R2-11 | PLM-06 | 视频标签“更多”下只有“播放内核” | 按原型补齐：播放内核 / 版本与画质 / 画面缩放 / 睡眠定时（只接已有功能入口；画面比例保持 3 档） | `player_settings_drawer.dart` / `player_settings_controls.dart` |
| R2-12 | PLT-02 | TV 右组最后一个方块文案“播放设置”，62 宽放不下 | 文案“设置” | `track_chapter_controls.dart` 约 498 |
| R2-13 | PLT-04 | 控件隐藏且“跳过片头”可见时，Enter 只唤出控件 | 隐藏时若跳过片头按钮可见，Enter 直接跳过；其他情况仍只唤出控件 | `parts/key_events.dart` 52-55 |

## B. 第 6 会话（FX-20/22/23）引入的问题

| 编号 | 问题 | 改成 | 位置 |
|---|---|---|---|
| R2-14 | 撤销窗口内弹出别的提示，删除会立即执行 | 新提示不得提前提交待撤销操作；排队或独立计时，到期才提交 | `app_toast.dart` 282，`snackbar_helper.dart` 85 |
| R2-15 | 所有删除确认都是“确认框 + 5 秒撤销”两步，删线路要确认两次 | 二选一：有撤销的删除不再弹确认框（线路、最近房间、继续观看、播放列表项按原型直接删+撤销）；不可撤销的危险删除保留确认框且不加撤销 | `dialogs.dart` 383，`server_routes_screen.dart` 267-274 |
| R2-16 | 服务器从列表消失时线路页抛 StateError | firstWhere 加兜底，服务器不存在时返回上一页或显示空态 | `server_routes_screen.dart` 114 |
| R2-17 | 加载中“添加线路”传空函数，看似可点 | 加载中显示为禁用（onPressed: null） | `server_routes_screen.dart` 295 |
| R2-18 | “手动选择”时选中线路不显示勾 | 选中线路行尾显示勾 | `server_routes_screen.dart` 235 |
| R2-19 | Plex 身份核对不检查 HTTP 错误，失败只提示“保存失败” | 检查状态码，区分连不上 / 身份不符 / 认证失败给出具体提示 | `server_routes_screen.dart` 176-179 |
| R2-20 | import 顺序不规范 | 按项目 lint 排序 | `multi_server_manager.dart` 1 |
| R2-21 | 提交的文档含本机路径 `/Volumes/…` | 删除本机路径，改为仓库相对路径 | `docs/ui-v1-fx20-22-23-validation-2026-11-16.md` 32、137 |
| R2-22 | a3a67b6 放宽了 2 处断言 | 恢复：菜单锚在卡片下方的位置断言；播放列表菜单标题断言（按新设计的标题文案） | `test/screens/catalog_search_screen_test.dart` 166，`test/screens/playlist_detail_screen_test.dart` 716、738 |

## C. 全量测试

见文末“全量测试结果”。
