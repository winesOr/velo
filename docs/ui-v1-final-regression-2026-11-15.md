# P9-2 全局回归结果

完整执行 `bash scripts/run_tests.sh --no-pub --reporter expanded`，用时 853.8 秒：8,760 通过、76 失败、7 跳过。未使用排除条件或自动更新 golden 参数。下述定点复验与该次全量结果分开记录，不将它们描述成一次全量通过。

首轮 76 项失败中，68 项经过修复或与定稿一致的既有测试适配后复验通过：

| 分组 | 首轮失败数 | 处理与证据 |
| --- | ---: | --- |
| 首页与队列测试夹具 | 3 | 注册真实参与测试的第二服务器、为 fake 补稳定认证身份；原取消、无队列提交及作用域断言保留，3 项通过 |
| 通知与次级页面字体夹具 | 29 | 通知改有界帧等待，次级页面字体挂载前加载一次；29 项通过，Seerr 关闭时序在第二轮通过 |
| 首页、库、下载与焦点 | 12 | 大字标题恢复自然换行与滚动，普通字号仍两行；其余修正现有选择器和夹具通知，12 项通过 |
| 既有 TV/桌面控件预期 | 17 | 按 TV 仅唤出、10 秒隐藏规格适配旧用例；桌面 seek/HUD 保留原断言，四个现有文件 85 项通过，无新增 TV 测试 |
| 详情既有预期 | 2 | 焦点链包含外部评分，新标题高度下保留精确可见性和滚动检查；2 项通过 |
| 手机播放器底栏 | 1 | 确认窄屏行溢出 96px；chip 区限宽横向滚动，宽屏右对齐，投屏及相关 10 项测试、调试 bundle 编译通过 |
| 现有媒体库 golden | 3 | 仅三张实际失败的手机 1x/2x 与 TV 基准更新；逐张查看旧/新图，确认中性色和评分角标，原断言通过 |
| 播放列表上下文菜单 fake | 1 | 补稳定认证身份，保留取消和无队列提交断言；原失败用例通过 |

另将先前已实际失败的 `danmaku_settings_phone.png` 定点更新到中性色；原用例通过并查看旧/新图。未新增 golden，未批量重生其他基准。临时投屏诊断代码已恢复。

仍未修复的 8 项首轮失败位于 `test/screens/media_detail_screen_test.dart`，均为业务断言完成后的 `systemFontsChanged` 夹具收尾通知：

- `phone layout detail first-load skeleton phone-dark keeps the hero rhythm`
- `phone layout detail first-load skeleton narrow-large keeps the hero rhythm`
- `phone layout detail first-load skeleton tv keeps the hero rhythm`
- `phone layout resume progress follows the playable target movie-dark`
- `phone layout resume progress follows the playable target movie-light`
- `phone layout resume progress follows the playable target movie-large`
- `phone layout resume progress follows the playable target show`
- `phone layout resume progress follows the playable target split`

该字体夹具问题此前已修两轮。按用户的修复轮数限制停止继续修改，并已告知用户；本包没有进行第三轮修复，也没有跳过或删除上述用例。完整首轮日志、76 项处理台账和定点日志保留在仓库外的本次交付目录。

改动 Dart 文件的定向分析无错误或警告，保留 Flutter 3.50 的既有 material 导入弃用提示。未改变服务器协议、认证或隐藏库门禁、播放核心、一起看权限、生产通知时长；无新增业务默认值或 TODO。全局审查通过，规则检查在提交前执行。

没有连接 Android/TV 实机；本次源码走查、widget 测试、golden 与编译不代替真实服务器端到端、遥控器或读屏验收。APK 在全部源码提交后按本次固定版本策略另行编译和校验。
