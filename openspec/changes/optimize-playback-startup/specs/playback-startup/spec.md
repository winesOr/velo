# Spec Delta

## Purpose

降低从选择影片到显示画面的等待，同时保留媒体版本、音轨、字幕、鉴权和播放生命周期的既有语义。后台预取和字幕任务必须与当前用户和播放来源隔离，不能将过期结果应用到后续影片。

## ADDED Requirements

### Requirement: Ordered startup configuration

系统 SHALL 在打开媒体前完成必需配置，批量偏好配置 SHALL 保留顺序和逐项失败信息，单个不支持的偏好不得阻止其他偏好或主视频播放。

#### Scenario: Unsupported subtitle preference
- **WHEN** 一批字幕偏好中有一个被播放核心拒绝
- **THEN** 其余偏好仍被尝试，并保留被拒绝项的错误信息

#### Scenario: Configuration is pending
- **WHEN** 原生端仍在处理起播配置
- **THEN** 播放器不得提前把该批次报告为完成

### Requirement: Isolated playback preparation

系统 SHALL 在详情页后台预取可安全复用的播放信息。复用 SHALL 匹配认证会话、端点、媒体与所选版本及轨道选项，并受短期有效期限制。预取不得打开媒体流、修改服务端播放选择或覆盖本地下载优先规则。

#### Scenario: Matching prepared playback
- **WHEN** 用户在有效期内播放同一来源且选项未变
- **THEN** 播放初始化复用进行中或已完成的预取结果

#### Scenario: Account or source changes
- **WHEN** 账号、端点、版本或播放选项变化
- **THEN** 使用当前上下文重新协商，不复用不匹配结果

#### Scenario: Preparation failed
- **WHEN** 后台预取失败
- **THEN** 用户点击播放仍可重新尝试正常初始化，鉴权拒绝不得被静默吞掉

### Requirement: Remote subtitles do not gate video startup

系统 SHALL 在打开主视频时将远程外挂字幕读取作为后台任务。快速尝试预算为 1.5 秒，超时后可后台重试；成功后挂载到当前影片并保留原字幕来源身份。失败不得重开无字幕视频或把用户选择持久化为关闭。

#### Scenario: Slow subtitle server
- **WHEN** 远程字幕在快速预算内没有返回
- **THEN** 主视频继续起播，字幕任务在后台重试

#### Scenario: Playback was replaced
- **WHEN** 字幕下载完成前用户切换影片或退出播放器
- **THEN** 旧任务不得向新的播放来源挂载或选择字幕

#### Scenario: Subtitle arrives during playback
- **WHEN** 当前影片的选中字幕下载完成
- **THEN** 挂载并应用当前有效选择，ExoPlayer 必需的重新准备保留位置及播放意图

#### Scenario: Replacement negotiation failed
- **WHEN** 新来源在打开前协商失败且旧影片继续播放
- **THEN** 旧影片尚未完成的字幕可继续挂载，不因尝试代际变化被永久丢弃

#### Scenario: Viewer chose another track
- **WHEN** 字幕任务完成前用户已更改音轨、主副字幕或关闭字幕
- **THEN** 后续轨道选择保留用户的最新意图
