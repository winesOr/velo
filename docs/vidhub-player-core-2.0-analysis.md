# VidHub「2.0 播放核心」剖析与 Plezy 吸收方案

> 状态：**方案存档，暂不实施**（2026-10-23）。
> 证据来源：`reference/apk/vidhub/vidhub-base.apk`（3.0.3 / versionCode 318）与 `vidhub-config-arm64-v8a.apk`，用 REA（JADX / apktool）和 `strings` 静态读取。
> 局限：Java 层被易盾 NIS 加固，JADX 只能看到 32 个壳类（`com.netease.nis.wrapper.*`），核心切换规则拿不到。下文的「定制补丁」是从 `libvlc.so` 里 VidHub 自己加的日志格式串推断出来的，**没有做反汇编，也没有在真机上验证过行为**。

## 一、结论

- 「2.0 播放核心」就是 **libVLC 3.0.22-rc1**。版本串为 `3.0.22-rc1-37-g2eeb298f00`，资源里有 `build_vlc_revision=2eeb298f00` 和 `build_libvlc_revision=965e864`，也就是 3.0 分支的 rc1 再加 37 个提交。所有模块都静态链进了一个 43 MB 的 `libvlc.so`。
- 它的独特之处在于 VidHub 自己往 **Android 硬解路径（杜比视界、HDR、RExt）** 和 **AudioTrack 音频直通** 里加的补丁。容器、协议、字幕这些都是 VLC 原有的功能，不是 VidHub 加的。
- 它能直开 ISO，靠的是 VLC 自带的 libbluray、dvdnav 和 UDF。但 **BD-J 菜单不可用**：APK 里没有 `libbluray-j2se-1.4.0.jar`，也没有 JVM，运行时会走到 "BD-J menus not supported. Playing without menus"。
- Plezy 的 ExoPlayer 核心在杜比视界和音频直通上已经达到或超过 VidHub。**真正缺的是 ISO/原盘直开，以及 mpv 的磁盘缓存**，两项都不需要引入 VLC。

## 二、应用侧入口（资源文案）

| 键 | 英文文案 |
|---|---|
| `settings_player_core` | Playback Engine 2.0 |
| `settings_player_core_vlc_desc` | More powerful decoding, supports ISO and Dolby Vision… |
| `settings_playback_hardware_acceleration_dolby` | Dolby Vision Hardware Decoding（开启时如果设备支持就用 DV 硬解，关闭时一律软解） |
| `settings_player_audio_passthrough` | Audio Passthrough |
| `settings_playback_vlc_disk_cache_desc` | Recommended when playing high-bitrate video or when the network is unstable. |

mpv 核心走另一个 JNI 包装 `libplayer.so`（`com.omi.omimpv.wrapper.MPVLib`），和 VLC 互不干扰。

## 三、VidHub 在 libVLC 上的定制补丁

### 1. MediaCodec 杜比视界探测与解码器切换

- 先用普通 HEVC 解码器开播，再检查码流里有没有 NAL 62（RPU）。找到就切到 DV 解码器，没找到就保持 HEVC：
  `DVPROBE_RESULT ... rpu_nal62=found ... decision=try_switch_to_dv_decoder`、`DVPROBE_SWITCH_OK: hevc_decoder->dv_decoder=%s`
- P7 双层：码流里有 EL NAL 就退回 HEVC（`DVP7_FALLBACK`），P5/P8 单层保留 DV 解码器（`DVP7_OK`）。日志里注明 "EL is in MKV BlockAddition, not bitstream"。
- 从 dvcC/dvvC 读 profile、level 和 `bl_compatibility_id`，映射成 Android 的 profile/level，再写进 csd-2（`DV_CONFIG_APPLY`）。configure 失败时有重试和回退（`DV_CONFIG_RETRY_RESULT`、`FALLBACK: configure failed for %s -> try %s`）。
- 候选解码器按分数挑：综合 adaptive、ignore_size、profile_levels 打分，并剔除黑名单、编码器和与基础 codec 不兼容的条目（`DV candidate evaluate/reject/select`）。
- RPU 和画面帧单独排队，对齐时间戳（`DVRPU_QUEUE` / `DVRPU_OUTPUT`）。
- 新增选项 `media-player-dolby-vision-profile`，对应设置里的 DV 硬解开关。

### 2. HDR 元数据透传给 MediaCodec

- 把 mastering display、MaxCLL、MaxFALL 打包成 `hdr-static-info`，JNI 和 NDK 两条路径都实现了。
- 把色彩信息转换成 Android 的 `color-standard`、`color-transfer`、`color-range`，输入和输出两侧都打印对照日志（`HDR MediaCodec JNI/NDK input/output format`）。

### 3. HEVC RExt 防护

- 遇到 4:2:2、4:4:4 或 12bit 这类非 Main/Main10 流时，只挑声明支持 RExt profile 的解码器（`HEVC MediaCodec profile guard`）。
- 软解跟不上时，丢输出帧但保留参考帧，避免花屏；连续丢太多帧时强制出一帧（`HEVC RExt software output catch-up`）。

### 4. AudioTrack 音频直通

- 改动集中在 `[Audio Passthrough]` 和 `[DTS Passthrough Debug]` 两组日志里。能力探测覆盖 DTS、DTS-HD 和 TrueHD，会区分 API 级别和设备 flag，还有 `dtshd_fallback_time`。
- 能解析 DTS-HD 扩展帧。
- AudioTrack 写入卡住会自动重启输出，环形缓冲停滞也会重启；flush、pause、release 的时序都做了处理。
- 在 Android Q 之前的设备上，7.1 PCM 回退时会限制成立体声。

### 5. 网络预读的磁盘缓存

- prefetch 模块加了磁盘缓存，文件名是 `vlc-prefetch.XXXXXX`，会检查磁盘容量，失败时退回内存缓存。
- 预读的 seek 阈值会动态调整；HTTP 预读空闲后如果补不进数据，会重开一次连接。

### 6. 其他

- libass 在 Android 上读系统字体配置（`Android ASS ...`），APK 还内置了一个 6 MB 的 `subfont.ttf`。

## 四、VLC 原有的能力（不是 VidHub 加的）

- 原盘：libbluray（含 AACS/BD+ 的动态加载接口）、dvdnav、UDF、libarchive 的 iso9660。
- MediaCodec 的 tunneled playback（`mediacodec-tunneled-playback`）。
- SMB2/NFS/SFTP/UPnP 访问，Lua 做 playlist 和 meta 解析（`assets/lua/`），`assets/hrtfs/*.sofa` 做耳机空间音频。按 CLAUDE.md 约定，后两者不复用。

## 五、与 Plezy 现状逐项对照

| VidHub 能力 | Plezy 现状 | 结论 |
|---|---|---|
| DV 探测、切解码器、P7 处理 | `exoplayer/DoviBridge.kt` 判断设备能否硬解 P5/P7。`DoviConvertingTrackOutput.kt` 用 libdovi 把 P7 转成 P8.1，失败就剥成 HEVC。`DvBitstreamSanitizer.kt` 在 DV 和 HDR10+ 并存时剥掉解码器用不到的元数据 | **Plezy 更强**。VidHub 遇到 P7 只会退回 HEVC，DV 效果直接丢掉 |
| HDR 元数据透传 | ExoPlayer 原生就会把 `ColorInfo` 写进 MediaCodec，mpv 走 libplacebo | 不用加 |
| TrueHD / DTS-HD 直通 | `IecCarrierSink.kt`、`TrueHdMatPacker.kt`、`DtsHdIecPacker.kt` 自己封装 IEC 61937 载波 | 不用加，Plezy 做得更细 |
| tunneled playback | `shared/DeviceQuirks.kt` 已经按机型处理 | 不用加 |
| HEVC RExt 挑解码器 | 没找到专门处理。ExoPlayer 按解码器声明的 profile 筛，失败会退到 mpv（`VideoDecoderRecoveryPolicy.kt`） | 收益小，遇到具体片源再说 |
| 磁盘预读缓存 | mpv 只设了 `demuxer-max-bytes` 和 `demuxer-max-back-bytes`（`MpvPlayerCore.kt:514`），没开 `cache-on-disk` | **可以加** |
| ISO / 蓝光原盘直开 | `prebuilt_mpv/libmpv-android-3ce46fbf5add-arm64-v8a.tar.gz` 里的 libmpv 只有 dvdnav 相关字符串，找不到 `bd://` 协议，看起来没编进 libbluray。Dart 侧已经有 Jellyfin `VideoType`（`lib/media/media_file_info.dart:73`），但没有按它路由 | **真正的缺口** |

## 六、建议

按改动大小从小到大排：

1. **mpv 磁盘缓存（改动最小）**
   - 新增一个设置项，打开 mpv 的 `cache-on-disk=yes`，再设 `demuxer-cache-dir`，指向应用的 cache 目录。
   - 和 `DemuxerBudget` 的内存预算一起考虑，文案参考 VidHub「高码率或网络不稳时建议开启」。新字符串走 slang。
   - 只影响 mpv 核心；ExoPlayer 要做同类功能得另接 `CacheDataSource`，可以先不做。

2. **核实 RPU 兜底（只读代码，不改东西）**
   - VidHub 会在码流里直接找 NAL 62，所以容器里没有 dvcC/dvvC 时也能认出 DV。
   - 要确认的是：Plezy 遇到这种 MKV 时，会不会当成普通 HEVC 播、丢掉 DV。大概要读二三十分钟代码，结论决定要不要在 `DoviExtractorWrapper` 里补探测。

3. **ISO / 原盘直开（收益最大，要动原生构建）**
   - 重新编 libmpv-android，带上 libbluray、libdvdnav 和 libudfread。体积大约多几 MB，远小于 VLC 的 43 MB。
   - 产物替换 `prebuilt_mpv/libmpv-android-*.tar.gz`。注意 `android/app/build.gradle.kts` 里的预编译路径写死为 `<repo>/prebuilt_mpv/`，不要让 Gradle 去联网下载。
   - Dart 侧：Jellyfin `VideoType` 为 `Iso`、`BluRay` 或 `Dvd` 时强制走 mpv，用 `bd://` 或 `dvd://` 打开（本地或 SMB 的 ISO 文件可以直接作为 `--bluray-device`）。
   - 效果和 VidHub 一样：能播正片，选标题、章节、音轨都正常，但**没有 BD-J 菜单**。
   - 不需要原盘结构、只读 ISO 里的单个文件时，按 CLAUDE.md 优先考虑 libarchive 的 iso9660。

4. **VLC 第三后端（最后手段）**
   - 只有 ISO 直开不够、确实需要更广的格式兼容时才值得做，按 CLAUDE.md「VLC 只作为可选 2.0 播放核心」的约定加成第三后端。
   - 就目前的证据看，VLC 能比 mpv + ExoPlayer 多给的东西不多。它的 DV 处理（P7 直接退 HEVC）不如 Plezy 现有的 libdovi 转换。
   - 即使做了，也拿不到蓝光菜单，除非再打包 libbluray 的 Java 部分并解决 Android 上的 JVM 问题，成本很高。

## 七、需要同步修正的旧说法

- CLAUDE.md 里写 VLC 用于「蓝光原盘/菜单」。VidHub 3.0.3 实际拿不到 BD-J 菜单，「菜单」这部分应该删掉或加上注明。

## 八、待验证

- 自动切到 2.0 核心的规则在加密的 Java 层，静态手段拿不到。
- 所有补丁结论都只是代码里有这样的日志串。要验证行为，可以在装了 VidHub 的设备上播 DV/ISO 片源，用 REA 的 `read_adb_logcat` 抓 `MediaCodecNew`、`DV candidate`、`HDR MediaCodec`、`[Audio Passthrough]` 这几个前缀。

## 复算方式

```bash
# 解出 arm64 原生库（放到独立临时目录）
D=$(mktemp -d /tmp/vidhub-libs.XXXX)
unzip -q reference/apk/vidhub/vidhub-config-arm64-v8a.apk 'lib/arm64-v8a/*' -d "$D"

# 版本
strings -n 6 "$D/lib/arm64-v8a/libvlc.so" | grep -m1 -E '^3\.0\.[0-9]+-rc'

# VidHub 自加的日志串
strings -n 4 "$D/lib/arm64-v8a/libvlc.so" | grep -E 'MediaCodecNew|DV candidate|HDR MediaCodec|profile guard|HEVC RExt|\[Audio Passthrough\]|prefetch disk cache|BD-J menus'

# 设置文案
apktool d -s -o "$D/res" reference/apk/vidhub/vidhub-base.apk
grep -o 'name="settings_\(playback\|player\)[^"]*">[^<]*' "$D/res/res/values/strings.xml"

# Plezy 预编译 libmpv 是否带 libbluray
P=$(mktemp -d /tmp/plezy-mpv.XXXX)
tar -xzf prebuilt_mpv/libmpv-android-3ce46fbf5add-arm64-v8a.tar.gz -C "$P"
strings "$P/lib/libmpv.so" | grep -iE 'bd://|libbluray|dvdnav'
```
