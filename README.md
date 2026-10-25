<h1>
  <img src="assets/velo.png" alt="Velo" height="36" />
  Velo
</h1>

**一个欢迎共同开发的开源媒体客户端，基于 Plezy，使用 Flutter 构建。**

支持连接 Plex / Jellyfin / Emby，面向手机、平板、桌面和 TV。我们希望在优秀的播放基础上，继续完善弹幕、弹幕热力图、媒体库体验和玻璃质感界面。

[English](#english) · [参与贡献](CONTRIBUTING.md) · [提交问题](https://github.com/winesOr/velo/issues) · [社区讨论](https://github.com/winesOr/velo/discussions) · [GPL-3.0](LICENSE)

## 项目来源与致谢

**Velo 是 [Plezy](https://github.com/edde746/plezy) 的衍生项目，感谢 [edde746](https://github.com/edde746) 及所有上游贡献者。**

- 本仓库独立创建，不使用 GitHub Fork 关系；这不改变代码来源、上游版权或 GPL 许可义务。
- 开源初始版本以 Plezy 上游提交 [`8ef7c2c`](https://github.com/edde746/plezy/commit/8ef7c2cd9a35fd208403d0577d063d4143375fd9) 为基础，包含本地后续开发成果。首次公开整理日期：2026-10-26。
- 保留上游版权声明与 GPL-3.0 许可证；第三方依赖和资源按其各自许可证使用。
- Velo 与 Plezy、VidHub、Yamby 及 Plex / Jellyfin / Emby 均无官方隶属或背书关系。其他产品名称和商标归各自权利人所有。
- 本仓库不发布其他应用的 APK、反编译产物或本地逆向证据，也不提供影视内容、媒体服务器或内置弹幕网关。

## 当前状态

这是**持续开发中的社区版本**，不是稳定版发布，也不承诺已完成所有平台的验证。本仓库暂不提供正式安装包；上游商店中的 Plezy 不等同于 Velo。

首次公开版本仍有[严格 CI 规范检查待办](https://github.com/winesOr/velo/issues/1)（翻译、图标规范和未使用代码），以及[独立发行准备事项](https://github.com/winesOr/velo/issues/2)。欢迎参与修复；静态分析通过不代表完整 CI 或真机验收已完成。

当前源码包含：

- Plezy 提供的多媒体服务器连接、播放、多语言、下载和一起看等基础能力。
- Velo 品牌、自定义导航与自适应界面、海报取色和流光毛玻璃背景。
- 用户自行配置的多弹幕源、剧集匹配、过滤、样式设置与弹幕热力图。
- 播放器交互、字幕与音轨面板、片头片尾处理、投屏及配对相关实现。
- 单元测试、Widget 测试、金图与可选 Android E2E 测试工具。

功能是否可用取决于平台、媒体服务器、播放核心及外部服务。欢迎提交可复现的问题，不要将“源码包含实现”理解为所有设备均已验收。

## 快速开始

### 环境

- Flutter **3.47.0 或更高**，Dart **3.12.0 或更高、低于 4.0.0**；以 `pubspec.yaml` 和 CI 固定版本为准。
- 目标平台所需的 Android SDK / JDK、Xcode 或桌面开发工具链。
- Python 3.10 或更高（建议 3.13，用于代码生成和检查脚本）。
- 可选：Bun（开发辅助工具）、Docker / Maestro（Android E2E）。

```bash
git clone https://github.com/winesOr/velo.git
cd velo
flutter pub get
(cd packages/wakelock_plus && flutter pub get --enforce-lockfile --no-example)
scripts/codegen.sh
flutter run
```

Dart 包名、原生包标识和部分脚本仍沿用 Plezy，尚未完成所有发行标识的迁移。安装到已有 Plezy 的设备前，请先备份；不要将开发构建当成完全隔离的正式应用。

### 检查与测试

```bash
flutter analyze
scripts/run_tests.sh
scripts/codegen.sh --check
scripts/ci_checks.sh
```

### Android 构建

```bash
flutter build apk --release --target-platform android-arm64
```

原生库按 `mpv-build.lock.json` 获取并校验。可将对应归档放到本地 `prebuilt_mpv/` 以避免重复下载；此目录不入库。没有配置正式签名时，当前 Android 构建使用开发签名，不适合作为正式商店发布。不要提交私钥、签名密码或 `android/key.properties`。

上游的正式发行与包管理器更新工作流暂不对 Velo 启用，需先完成独立应用标识、签名和更新渠道配置。常规源码 CI 保留。

### 可选服务配置

Trakt 集成不再携带上游的应用凭据。需要该能力的构建者应自行注册 Trakt 应用，并在构建时传入 `--dart-define=TRAKT_CLIENT_ID=...` 和 `--dart-define=TRAKT_CLIENT_SECRET=...`。未配置时 Trakt 服务不可用，不影响媒体服务器的基本播放。原生客户端中的这类值可以被提取，请勿将它们视为安全的服务端秘密。

## 一起开发

欢迎先在 [Issues](https://github.com/winesOr/velo/issues) 或 [Discussions](https://github.com/winesOr/velo/discussions) 讨论想法，再提交小而清晰的 PR。

适合参与的方向：

- 修复播放、字幕、弹幕匹配与多服务器场景的问题。
- 改进手机 / 平板布局及 TV 遥控器焦点可达性。
- 补充跨平台测试、性能测量和构建文档。
- 完善翻译、可访问性和贡献者入门体验。

请先阅读 [贡献指南](CONTRIBUTING.md)。报告问题时提供版本、平台、复现步骤和**已脱敏**日志；不要附带令牌、服务器账号、私密地址或受版权限制的媒体。

## 许可证

Velo 继承 Plezy 的 **GNU General Public License v3.0（GPL-3.0）**，完整文本见 [LICENSE](LICENSE)。分发修改版时，请遵守对应源码提供及版权、许可声明保留等要求。第三方依赖的许可证不因本项目许可而改变。

---

## English

Velo is an independent, community-developed Flutter media client **derived from [Plezy](https://github.com/edde746/plezy)**. Many thanks to edde746 and all upstream contributors.

This repository was created separately rather than through GitHub's Fork feature. It retains the upstream copyright notices and GPL-3.0 license. Its initial public source snapshot is based on upstream commit `8ef7c2cd9a35fd208403d0577d063d4143375fd9`, with subsequent local development.

The source includes Plex / Jellyfin / Emby integration inherited from Plezy, custom adaptive interfaces, user-configured danmaku sources and heatmaps, and ongoing playback improvements. It is a development snapshot, not a stable release or a claim of validation on every platform. No official Velo binaries are published yet.

Use the setup and test commands above. See [CONTRIBUTING.md](CONTRIBUTING.md) to get involved, report reproducible issues, or propose a focused pull request. Do not submit credentials, private server data, third-party APKs, or copyrighted media.

Velo is not affiliated with or endorsed by Plezy, VidHub, Yamby, Plex, Jellyfin, or Emby. Third-party names, trademarks, dependencies, and assets remain subject to their respective rights and licenses.
