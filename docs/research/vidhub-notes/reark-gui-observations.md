> 历史研究摘要，来自本地资料快照 `c350c4a`（2026-11-14 整理）。原始证据未公开；文内观察、推断和未验证边界按原文保留，不能当作本次复测结果。公开副本仅脱敏路径并处理未公开证据链接。

# ReArk GUI observations (local private evidence)

Observation date: 2026-11-13 (local session after macOS unlock). Source app: `/Applications/ReArk.app` version 1.2.0. No API key or account data recorded.

Target: `<legacy-repo>/reference/apk/vidhub/vidhub-base.apk`.

- Summary verified package `com.oumi.utility.media.hub`, version `3.0.3`, versionCode `318`, minSDK `28`, targetSDK `36`.
- Summary identifies NetEase EasyShield, one DEX, 30 classes, 222 methods, 54 fields, 62 Activities, 5 Providers, 3 Receivers and 13 Services.
- Summary reports 24 permissions, including `INTERNET`, `ACCESS_NETWORK_STATE` and `FOREGROUND_SERVICE_MEDIA_PLAYBACK`.
- Historical first attempt: ReArk Agent query was unavailable because its endpoint requested an API key. This blocker is now resolved by the user-authorized local Magpie profile; no API key was entered.
- Opening `<legacy-repo>/reference/apk/vidhub/vidhub-config-arm64-v8a.apk` failed with “Invalid APK file”; this is consistent with the file being a split configuration APK, but the GUI error alone does not prove the exact cause.

This is supplementary GUI observation. It does not recover the protected business DEX, prove runtime call paths, or provide network/performance measurements. The base APK source and split source remain user-local and are not copied here.

Count discrepancy: ReArk Summary reports 30 classes, while the earlier REA class search returned 32 readable classes. The counting/filtering difference has not been resolved; both observations are retained.

## Follow-up: local Magpie connection verified

Source: `<local-artifacts>/reark-magpie-config-result.md`; ReArk UI request time 18:45, duration 22 seconds as recorded in that verification note. The source does not specify a timezone for this UI time.

- Local endpoint: `http://127.0.0.1:3425/v1`; selected model and analysis model: `auto/gpt-6.1-sol`. No API key was entered.
- Real ReArk completed `summarize_package` and `inspect_entry_points` and produced a Chinese response without the API key error.
- This verifies the application connection and bounded read-only tool use. Model prose is not new APK evidence; the 22-second query duration is not a playback benchmark.
- No dynamic device analysis or media performance measurement was performed. Protected business code, default playback engine and performance claims remain unresolved.
