> 历史研究摘要，来自本地资料快照 `c350c4a`（2026-11-14 整理）。原始证据未公开；文内观察、推断和未验证边界按原文保留，不能当作本次复测结果。公开副本仅脱敏路径并处理未公开证据链接。

# Direct dynamic parameter evidence

- `synthetic-playback-filtered-log.txt:20` 11-14 12:05:04.529  2087  2427 D CCodec  : allocate(c2.goldfish.h264.decoder)
- `synthetic-playback-filtered-log.txt:22` 11-14 12:05:04.537  2087  2427 I CCodec  : Created component [c2.goldfish.h264.decoder] for [c2.goldfish.h264.decoder]
- `synthetic-playback-filtered-log.txt:38` 11-14 12:05:04.540  2087  2427 D CCodecConfig:   c2::u32 input.buffers.max-size.value = 6291456
- `synthetic-playback-filtered-log.txt:41` 11-14 12:05:04.540  2087  2427 D CCodecConfig:   c2::u32 output.delay.value = 8
- `synthetic-playback-filtered-log.txt:58` 11-14 12:05:04.543  2087  2426 I MediaCodec: [c2.goldfish.h264.decoder] setting surface generation to 2137089
- `synthetic-playback-filtered-log.txt:65` 11-14 12:05:04.545  2087  2427 D CCodecConfig: c2 config diff is   c2::u32 raw.size.height = 360
- `synthetic-playback-filtered-log.txt:66` 11-14 12:05:04.545  2087  2427 D CCodecConfig:   c2::u32 raw.size.width = 640
- `synthetic-playback-filtered-log.txt:69` 11-14 12:05:04.546  2087  2427 D CCodec  :   int32_t height = 360
- `synthetic-playback-filtered-log.txt:71` 11-14 12:05:04.546  2087  2427 D CCodec  :   int32_t max-input-size = 6291456
- `synthetic-playback-filtered-log.txt:74` 11-14 12:05:04.546  2087  2427 D CCodec  :   int32_t width = 640
- `synthetic-playback-filtered-log.txt:87` 11-14 12:05:04.546  2087  2427 D CCodec  :   int32_t width = 640
- `synthetic-playback-filtered-log.txt:88` 11-14 12:05:04.546  2087  2427 D CCodec  :   int32_t height = 360
- `synthetic-playback-filtered-log.txt:96` 11-14 12:05:04.547  2087  2427 D CCodecConfig: c2 config diff is   c2::u32 raw.max-size.height = 360
- `synthetic-playback-filtered-log.txt:97` 11-14 12:05:04.547  2087  2427 D CCodecConfig:   c2::u32 raw.max-size.width = 640
- `delayed-playback-filtered-log.txt:11` 11-14 12:06:41.922  2527  2702 D CCodec  : allocate(c2.goldfish.h264.decoder)
- `delayed-playback-filtered-log.txt:13` 11-14 12:06:41.945  2527  2702 I CCodec  : Created component [c2.goldfish.h264.decoder] for [c2.goldfish.h264.decoder]
- `delayed-playback-filtered-log.txt:29` 11-14 12:06:41.950  2527  2702 D CCodecConfig:   c2::u32 input.buffers.max-size.value = 6291456
- `delayed-playback-filtered-log.txt:32` 11-14 12:06:41.950  2527  2702 D CCodecConfig:   c2::u32 output.delay.value = 8
- `delayed-playback-filtered-log.txt:49` 11-14 12:06:41.956  2527  2701 I MediaCodec: [c2.goldfish.h264.decoder] setting surface generation to 2587649
- `delayed-playback-filtered-log.txt:56` 11-14 12:06:41.957  2527  2702 D CCodecConfig: c2 config diff is   c2::u32 raw.size.height = 360
- `delayed-playback-filtered-log.txt:57` 11-14 12:06:41.957  2527  2702 D CCodecConfig:   c2::u32 raw.size.width = 640
- `delayed-playback-filtered-log.txt:60` 11-14 12:06:41.957  2527  2702 D CCodec  :   int32_t height = 360
- `delayed-playback-filtered-log.txt:62` 11-14 12:06:41.957  2527  2702 D CCodec  :   int32_t max-input-size = 6291456
- `delayed-playback-filtered-log.txt:65` 11-14 12:06:41.957  2527  2702 D CCodec  :   int32_t width = 640
- `delayed-playback-filtered-log.txt:78` 11-14 12:06:41.957  2527  2702 D CCodec  :   int32_t width = 640
- `delayed-playback-filtered-log.txt:79` 11-14 12:06:41.957  2527  2702 D CCodec  :   int32_t height = 360
- `delayed-playback-filtered-log.txt:87` 11-14 12:06:41.957  2527  2702 D CCodecConfig: c2 config diff is   c2::u32 raw.max-size.height = 360
- `delayed-playback-filtered-log.txt:88` 11-14 12:06:41.957  2527  2702 D CCodecConfig:   c2::u32 raw.max-size.width = 640
- `delayed-playback-filtered-log.txt:95` 11-14 12:06:41.993  2527  2639 V mpv     : event: file-loaded
- `delayed-playback-filtered-log.txt:96` 11-14 12:06:41.993  2527  2639 D MPVPlayerManager: engine event MPV_EVENT_FILE_LOADED

## 本次日志报告的硬解设置补充
- `synthetic-playback-filtered-log.txt:18` 11-14 12:04:52.038  2087  2404 D MPVPlayerManager: hwdec set to auto-unsafe
- `synthetic-playback-filtered-log.txt:19` 11-14 12:04:53.401  2087  2087 D VideoPlayActivity: Mobile playback core decision: core=MPV reason=legacy_routing player_2=false is_strm=false is_iso=false is_dolby_vision=false is_dolby_vision_p5=false is_confirmed_non_p5=not_checked is_hdr=false device_dolby_decoder=not_checked dolby_hw_enabled=true vlc_hw_enabled=true
- `delayed-playback-filtered-log.txt:3` 11-14 12:06:39.901  2527  2639 D MPVPlayerManager: hwdec set to auto-unsafe
- `delayed-playback-filtered-log.txt:5` 11-14 12:06:40.388  2527  2639 D MPVPlayerManager: currentVo set to gpu
- `delayed-playback-filtered-log.txt:6` 11-14 12:06:41.873  2527  2527 D VideoPlayActivity: Mobile playback core decision: core=MPV reason=legacy_routing player_2=false is_strm=false is_iso=false is_dolby_vision=false is_dolby_vision_p5=false is_confirmed_non_p5=not_checked is_hdr=false device_dolby_decoder=not_checked dolby_hw_enabled=true vlc_hw_enabled=true

以上是日志报告的设置和选路结果，未执行mpv属性读回或验证set_option返回码；auto-unsafe不等于真机硬件解码成功，currentVo=gpu不等于解码器是GPU。core=MPV/legacy_routing仅适用于本次非STRM、非ISO、非DV、非HDR外部URL，不是全局默认。两份已过滤日志定向检索未命中具体network-caching/cache-secs/demuxer-max-bytes值；因为过滤日志不保全所有内容，缺失不能证明未设置缓存。
