# 研究、设计与验收档案

[设计总入口](../design/README.md) · [项目说明](../README.md) · [三应用早期融合策划](research/three-app-fusion-plan.md) · [VidHub 研究摘要](research/README.md)

本目录保存历史研究、实施计划、优化建议、任务卡与验收记录，整理于 2026-11-14。文档来自本地资料快照 `c350c4a`，包括当时的两份未跟踪观察记录；本次发布分支只包含文档与原型，不携带该快照之前的 50 个本地产品开发提交。因此文中代码位置、版本、命令结果和“已实现 / 已通过”均指原作者记录时的本地状态，不是本分支的当前功能矩阵或本次验证结果。后续检查以新鲜源码、测试与设备观察为准。

历史策划中的网盘、文件源聚合、刮削等建议已被后续范围决定替代。当前保留 Plex / Jellyfin / Emby、一起看、移动端 / TV、mpv / ExoPlayer；弹幕网关由用户配置。历史方案的完整正文供追溯，不构成实现授权。HTML 原型中的播放、投屏、发现和房间操作仅为演示。

公开副本保留原作者的观察、推断和未验证边界，仅为公开阅读脱敏本机路径，并将未公开资料链接改为文字引用。本地路径使用 `<repo>`、`<legacy-repo>`、`<local-artifacts>` 等占位符。受限制参考图、私人 QA 截图、真实服务器信息、凭据、签名、构建包、第三方 APK、原始逆向导出与 `reference/` 均不公开。公开演示截图和原型替代插画与私人原件分开；原始证据缺失时不能宣称可公开复核。上游版权和 GPL 声明继续保留。

## 文档索引

- [android-updates.md](android-updates.md)
- [flutter-migration-b2-validation-2026-11-13.md](flutter-migration-b2-validation-2026-11-13.md)
- [flutter-migration-b3-validation-2026-11-13.md](flutter-migration-b3-validation-2026-11-13.md)
- [flutter-migration-b4-validation-2026-11-13.md](flutter-migration-b4-validation-2026-11-13.md)
- [flutter-migration-b5-validation-2026-11-13.md](flutter-migration-b5-validation-2026-11-13.md)
- [fusion-library-settings-implementation.md](fusion-library-settings-implementation.md)
- [fusion-shell-implementation.md](fusion-shell-implementation.md)
- [fusion-together-implementation.md](fusion-together-implementation.md)
- [home-visual-audit-2026-10-24.md](home-visual-audit-2026-10-24.md)
- [playback-casting-implementation.md](playback-casting-implementation.md)
- [playback-startup-optimization-plan.md](playback-startup-optimization-plan.md)
- [player-native-observations-2026-11-13.md](player-native-observations-2026-11-13.md)
- [player-ui-refinement.md](player-ui-refinement.md)
- [player-v4-implementation.md](player-v4-implementation.md)
- [prototype-visual-audit-2026-10-23.md](prototype-visual-audit-2026-10-23.md)
- [prototype-visual-parity-implementation.md](prototype-visual-parity-implementation.md)
- [rating-badges-plan-2026-11-13.md](rating-badges-plan-2026-11-13.md)
- [rating-badges-validation-2026-11-13.md](rating-badges-validation-2026-11-13.md)
- [settings-prototype-audit-2026-10-24.md](settings-prototype-audit-2026-10-24.md)
- [skip-intro-outro-plan.md](skip-intro-outro-plan.md)
- [tablet-ui-audit-2026-10-25.md](tablet-ui-audit-2026-10-25.md)
- [ui-final-v1-phase1-verification.md](ui-final-v1-phase1-verification.md)
- [ui-final-v1-phase2-verification.md](ui-final-v1-phase2-verification.md)
- [ui-final-v1-phase3-verification.md](ui-final-v1-phase3-verification.md)
- [ui-ratings-selectors-development-plan-2026-11-11.md](ui-ratings-selectors-development-plan-2026-11-11.md)
- [ui-ratings-selectors-performance-plan-2026-11-11.md](ui-ratings-selectors-performance-plan-2026-11-11.md)
- [ui-ratings-selectors-validation-2026-11-11.md](ui-ratings-selectors-validation-2026-11-11.md)
- [ui-refit-plan-round2-2026-11-12.md](ui-refit-plan-round2-2026-11-12.md)
- [ui-refit-round2/R01-home-hero.md](ui-refit-round2/R01-home-hero.md)
- [ui-refit-round2/R02-bugfix.md](ui-refit-round2/R02-bugfix.md)
- [ui-refit-round2/R03-wakelock.md](ui-refit-round2/R03-wakelock.md)
- [ui-refit-round2/R04-selectors.md](ui-refit-round2/R04-selectors.md)
- [ui-refit-round2/R05-ratings.md](ui-refit-round2/R05-ratings.md)
- [ui-refit-round2/R06-runtime-perf.md](ui-refit-round2/R06-runtime-perf.md)
- [ui-refit-round2/R07-cold-start.md](ui-refit-round2/R07-cold-start.md)
- [ui-refit-round2/R08-display-issues.md](ui-refit-round2/R08-display-issues.md)
- [ui-refit-round2/R09-press-feedback.md](ui-refit-round2/R09-press-feedback.md)
- [ui-refit-round2/R10-visual-tokens-detail.md](ui-refit-round2/R10-visual-tokens-detail.md)
- [ui-refit-round2/R11-motion.md](ui-refit-round2/R11-motion.md)
- [ui-refit-round2/README.md](ui-refit-round2/README.md)
- [ui-refresh-validation-2026-11-10.md](ui-refresh-validation-2026-11-10.md)
- [velo-final-review-2026-10-24.md](velo-final-review-2026-10-24.md)
- [velo-merged-delivery-2026-10-24.md](velo-merged-delivery-2026-10-24.md)
- [vidhub-player-core-2.0-analysis.md](vidhub-player-core-2.0-analysis.md)
- [vidhub-ui-ambient-glass-architecture.md](vidhub-ui-ambient-glass-architecture.md)
- [vidhub-ui-architecture-analysis.md](vidhub-ui-architecture-analysis.md)

其他平台开发说明：[android-updates.md](android-updates.md)。
