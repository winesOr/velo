## Purpose

让用户管理自己的弹幕兼容服务，消除本机默认地址导致的不可用问题，并通过持久化、连通反馈和清晰的请求边界保证手机与电视上的配置可靠可恢复。

## ADDED Requirements

### Requirement: 空源与持久化
系统 SHALL 默认不配置任何弹幕源；首次启用在线弹幕且无可用配置时提供添加面板，支持名称、HTTP(S) 地址、启用禁用、排序、编辑和删除，并持久化成功保存的配置。

#### Scenario: 首次使用及取消
- **WHEN** 空源用户启用弹幕后取消添加
- **THEN** 视频继续播放，不请求任何默认地址，仍允许导入本地弹幕文件

#### Scenario: 保存失败与重启
- **WHEN** 保存失败或用户保存成功后重启
- **THEN** 失败时保留输入并显示失败；成功时恢复源顺序和开关，不重新填入 127.0.0.1

### Requirement: 路径和连接测试
系统 SHALL 保留用户地址中的路径前缀并正确追加 v2 路由，支持以 API 根结尾的输入而不重复追加；连接测试 SHALL 报告 HTTP、结构错误或耗时，成功仅代表测试接口可用。

#### Scenario: 带 token 路径
- **WHEN** 用户配置 https://gateway.example/prefix/token 或其 /api/v2 形式并测试
- **THEN** 请求到同一预期 search/anime 路由，路径 token 不丢失，常规日志和错误提示不暴露 token

### Requirement: 顺序尝试和签名隔离
系统 SHALL 按启用顺序尝试源并支持手动选择；仅精确官方 HTTPS origin 的直连请求使用自有凭据签名。自建网关 SHALL 不携带 AppId、AppSecret 或官方签名头，只添加应用 User-Agent 等必要通用请求头。

#### Scenario: 网关故障与备用源
- **WHEN** 第一源超时或兼容搜索无候选
- **THEN** 可尝试下一源，界面展示真实来源与失败原因，切源后重新匹配，不复用另一源的 episode ID

#### Scenario: 官方源缺少凭据或重定向
- **WHEN** 用户选择官方源但未配置自有凭据，或签名请求重定向到其他 origin
- **THEN** 缺凭据时提示配置且不发无效请求；跨 origin 不转发签名或凭据
