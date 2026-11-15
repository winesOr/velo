> 历史研究摘要，来自本地资料快照 `c350c4a`（2026-11-14 整理）。原始证据未公开；文内观察、推断和未验证边界按原文保留，不能当作本次复测结果。公开副本仅脱敏路径并处理未公开证据链接。

# VidHub dynamic execution — intermediate, pending user UI handoff

1. Existing plezy_api36 AVD booted successfully, and already contained VidHub 3.0.3/318. It was not launched or replaced there; only this newly started emulator instance was closed. Its data was not wiped.
2. Created isolated AVD vidhub_research_20261113 at <local-artifacts>/vidhub-research-avd/vidhub_research_20261113.avd from existing Android36 AOSP arm64 image. Registered pointer: ~/.android/avd/vidhub_research_20261113.ini. No root/security changes.
3. Fresh isolated installation succeeded using matched base, arm64, xhdpi, en, zh splits from local XAPK. Base/ABI hashes equal supplied samples. Hashes in installed-artifacts.json. No density-split blocker remains for this installation.
4. am start -W MainActivity returned Status ok; reported foreground Activity is Android GrantPermissionsActivity. App PID 2451 remained alive. Launch timing 1671ms is ActivityManager timing, NOT playback first-frame or performance.
5. run-as returned package not debuggable. No Frida/root/injection was installed. JNI runtime values and actual hardware decoder remain unknown.
6. CUA inventory did not expose the emulator; getApp on executable symlink/name/realpath returned Invalid app. No adb input/uiautomator workaround was used. Parent requested manual user handling of the permission prompt. UI playback tests are pending.
7. Generated 60s 640x360 AVC testsrc2 + AAC sine media using isolated imageio-ffmpeg package in <local-artifacts>/vidhub-media-tools (no global tool upgrade). Manifest/hash: media-fixture.json.
8. Loopback HTTP source at 127.0.0.1:18879, adb reverse registered. Android URL: http://127.0.0.1:18879/a/synthetic-avc.mp4. Host curl Range bytes=0-99 self-test returned206/100. That log entry is a fixture self-test, NOT VidHub traffic. No App media request recorded yet.
9. Server source controlled_http.py and raw scoped application log vidhub-process-log.txt retained. No user media server/token used. App startup logged CoreComponentFactory ClassNotFoundException then continued to permission activity; this alone is not proof of fatal crash.
10. Pending: user reaches homepage, then controlled playback/Range observation. Fastest-server-route tests require a compatible local media server, not just direct-file URLs. All real cache/hwdec params and route algorithm remain unknown.
11. Current processes intentionally left running for user handoff: isolated emulator and localhost fixture server. Parent must either continue or stop them at task completion; do not erase AVD evidence.
