# Velo 2.23.8 合并交付记录

日期：2026-10-24。基线 HEAD：`ba09c8f`，合并源为 `<repo>` 当前共享工作目录里的 Claude 与 Codex 未提交改动。检查时两边改动已在同一目录，不存在 Git 未合并条目。保留原有工作区，并在 `/tmp/plezy-merged-source-20261024-144906.tar.gz` 保存了打包前源码快照。

## 合并内容

- Claude：始终暗色首页、海报取色放宽与超时调整、最近添加按电视剧聚合、集数移至卡片说明、轮播进度圆点、固定高度玻璃设置抽屉、全局滑条与弹幕推荐。
- Codex：播放器中的 DLNA 设备发现与选择、带鉴权服务器静态直链、起播确认和可选续播、成功退出本地播放器、关闭资源不发送 Stop、Android multicast lease。
- 收尾修复：电视首页封面 provider 的原生 authority 改为与 fork Manifest 一致；本地文件交给外部播放器时，用当前应用包名解析 FileProvider。Manifest 测试直接对照实际原生 authority，避免测试和实现各自使用旧包名。
- 应用版本：`2.23.8+2161`，arm64 split 实际 versionCode 为 `4161`。

## 验证

- `scripts/run_tests.sh`：8281 通过、6 跳过、0 失败，用时 17:03；日志 `docs/qa/merged-casting-20261024-144906/flutter-tests.log`。
- Android `:app:testDebugUnitTest -x :app:compileFlutterBuildDebug`：627 通过、0 失败、0 跳过；59 个测试套件。
- `flutter analyze --no-pub`：无问题。初次 CI 扫到了临时设备诊断 Dart 脚本的 print；诊断脚本改存为文本证据后，最终分析通过。
- Dart 格式、翻译清洁、硬编码字符串、用户错误文本、脚本 guards、图标、原生格式、未使用代码和文件检查通过。
- `scripts/codegen.sh` 完成；隔离目录重新生成后逐字节内容比较通过。标准 `codegen --check` 继续因未提交的生成文件返回 1，故不宣称标准 CI 全绿。
- `openspec validate add-playback-casting --strict`：通过。
- 构建主机只读 SSDP 扫描发现「wines的小米电视S75 Mini LED」，AVTransport v1。没有发送播放命令，Plex/Jellyfin/Emby 起播、续播、电视遥控及强制结束手机后持续播放仍待实测。
- 源码快照前后核对：除本轮版本号和 provider 修复外，原有两边源码字节均保持；最终 SHA-256 清单位于 `source-manifest-final.json`。

## 产物

- APK：`<repo>/dist/android/Velo-2.23.8-20261024-merged-dlna-arm64-v8a.apk`。
- 大小：95504296 bytes，约 95.5 MB。
- 包名：`com.wines.plezy`；版本 `2.23.8`；versionCode `4161`；仅 arm64-v8a。
- 签名校验通过，与上一交付版 2.23.7 的证书 SHA-256 一致。
- 包内 DEX 不再包含旧的 `com.edde746.plezy.fileprovider` / `com.edde746.plezy.systemshelf.artwork` authority 字面值。
- APK SHA-256：`fd4064c56b8526e3956f645ea41e4528ba09e8131271e3e8b3af8a28d287c69d`。

## 微信交付

通过 Hermes 原生 `send` CLI 向已配置的默认微信私聊发送 APK 附件与改动说明。回执保存在 `docs/qa/merged-casting-20261024-144906/wechat-delivery.json`，只有返回附件发送成功才算完成交付。

本次发送返回 `success=true`，消息回执 `hermes-weixin-ed71338ace254410b2111afe75b43a32`。
