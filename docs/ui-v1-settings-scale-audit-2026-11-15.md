# P8-5 设置视觉尺度验收

本包核对了定稿要求与当前实现。公共字段已符合尺寸要求，因此复用现有实现，未再次修改视觉 token，也未新增测试或 golden。

| 项目 | 当前值 | 实现依据 |
| --- | --- | --- |
| 普通设置行 / TV 设置行 | 48 / 64 | `SettingsPresentation.rowHeight` |
| 普通分组 / TV 分组圆角 | 15 / 18 | `SettingsPresentation.groupRadius` |
| 标准选择字段 / 紧凑字段最小高度 | 58 / 52 | `AppSelectField` 的 `ConstrainedBox` |
| 选择字段圆角及焦点边界 | 14 | `AppSelectField` 的边界、裁剪和焦点包装 |

设置行保留系统字体及文字缩放。禁用说明通过实际能力、账户状态和现有 `subtitle` 传入，不编造统一原因。保存与失败反馈复用统一通知 helper。

验证执行了现有 `test/widgets/app_select_field_test.dart`、`test/widgets/setting_tile_test.dart`：11 个用例通过，覆盖长文本、200% 字体、键盘当前项与回焦、禁用状态、延迟选择和减少动画。没有新增视觉测试。本包没有 Dart 改动，静态分析沿用 P8-1、P8-2、P8-4 已通过的改动文件检查；规则脚本在提交前执行。

P8-2 新增网络导航使两张现有手机设置 golden 实际失败，已仅更新对应 dark/light 图片并核对；窄屏大字图片通过且未改。P8-4 验证发现的 `danmaku_settings_phone.png` 仍是旧紫色背景，已在当时 HEAD 复现，留给 P9-2 按中性色定稿处理。

旧计划要求批量重生设置 golden，已由用户的“仅本次改动导致现有 golden 失败时才重生”覆盖。无新增业务默认值或 TODO，无公共源码改动。手机、平板和 TV 实机显示仍待设备验收；现有 widget 测试不代替实机结果。
