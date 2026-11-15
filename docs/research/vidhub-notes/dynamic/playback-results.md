> 历史研究摘要，来自本地资料快照 `c350c4a`（2026-11-14 整理）。原始证据未公开；文内观察、推断和未验证边界按原文保留，不能当作本次复测结果。公开副本仅脱敏路径并处理未公开证据链接。

# 动态播放正式交接（2026-11-14 UTC）
1. 全部路径基于 `design/vidhub-study/evidence/dynamic/`；本次仅控制 `vidhub_research_20261113`，无重启AVD、擦除/重装、读取账号/私人URL；前台起始 MediaServerItemDetailActivity / PID 2087。
2. `action-view-attempt.json:1`：包限定 ACTION_VIEW `http://127.0.0.1:18879/a/synthetic-avc.mp4`，Status ok，进入 VideoPlayActivity；1242/1253 ms 是 activity 启动计时，不是首帧。
3. `http-observations.jsonl:2`：Lavf/62.8.102，GET bytes=0-，206，12,068,014 B，响应头写出 2.163 ms、全文件写出 155.646 ms。
4. `http-observations.jsonl:3`：libmpv，GET bytes=0-，206，同样完整文件，响应头写出0.646 ms、全文件写出72.337 ms；两请求起始间隔11.691 s。UA双读已证，probe/play角色分配仍是推断。
5. 首行 curl bytes=0-99 是早先host selftest，排除；四次app-path响应均完整写出且disconnected=false；写出成功不等同全部已消费/磁盘缓存，网络带宽与首帧未测。
6. `synthetic-playback-filtered-log.txt:20` 与 `:22`：PID2087实际创建 c2.goldfish.h264.decoder；`:65`/`:66`实际尺寸360/640；`:71` max-input-size=6291456（6 MiB解码输入上限，非网络缓存）；`:41` output.delay.value=8（未将其解释为毫秒/应用缓冲）。
7. `delayed-action-view-attempt.json:1`：第二次 /b 配置500 ms延迟的ACTION_VIEW返回timeout/MainActivity（10519 ms）；无/b请求，因此延迟对照无效，不能解释最快线路/连接取消。
8. `target-exit-info.txt:6`起：2087于设备12:06:38.542 reason=6(ANR)，VideoPlayActivity等待FocusEvent(hasFocus=false)5000 ms；description为user request after error。未由测试脚本重启进程，不推定具体谁关闭，也不推广为实机缺陷。
9. 后续PID2527恢复播放/a：`http-observations.jsonl:4`/`:5`又分别Lavf/libmpv完整重读（42.619/102.983 ms），不代表/b回退算法或全局无缓存；`delayed-playback-filtered-log.txt:95`/`:96`明确mpv file-loaded / MPV_EVENT_FILE_LOADED。
10. `target-memory-after.json:1`记录2527的包限定内存快照；先前2087为PSS289827KB/RSS445140KB。不同PID不能据此判断优化；没有持续内存曲线或实机性能结论。
11. 已证本次外部URL播放路径涉及libmpv及Android MediaCodec的goldfish组件；不能据此断言所有媒体默认内核、真机硬解成功、mpv hwdec实际属性、应用设置的network-caching/cache-secs/demuxer-max-bytes数值。
12. 最快线路仍未动态触发：没有新增或修改账户服务器/线路；本地A/B URL测试不是服务器 fastest 选择流程。可读设置/动态注入未使用，无root/安全弱化。
13. CUA仍未识别模拟器应用，本轮无屏幕/首帧视觉验证；证据来自包限定API、日志、受控HTTP。`parameter-evidence-index.md:1`及`request-timing-summary.json:1`提供可引用索引。
14. `post-playback-cleanup.json:1`：04:08:34 UTC，在四个全文件响应完成且最后一次请求后超过60秒后停止本次fixture PID99455并移除18879 reverse；保留AVD、PID2527与登录数据；ANR后未再尝试。

## 本次日志报告的硬解设置补充
- `synthetic-playback-filtered-log.txt:18` 11-14 12:04:52.038  2087  2404 D MPVPlayerManager: hwdec set to auto-unsafe
- `synthetic-playback-filtered-log.txt:19` 11-14 12:04:53.401  2087  2087 D VideoPlayActivity: Mobile playback core decision: core=MPV reason=legacy_routing player_2=false is_strm=false is_iso=false is_dolby_vision=false is_dolby_vision_p5=false is_confirmed_non_p5=not_checked is_hdr=false device_dolby_decoder=not_checked dolby_hw_enabled=true vlc_hw_enabled=true
- `delayed-playback-filtered-log.txt:3` 11-14 12:06:39.901  2527  2639 D MPVPlayerManager: hwdec set to auto-unsafe
- `delayed-playback-filtered-log.txt:5` 11-14 12:06:40.388  2527  2639 D MPVPlayerManager: currentVo set to gpu
- `delayed-playback-filtered-log.txt:6` 11-14 12:06:41.873  2527  2527 D VideoPlayActivity: Mobile playback core decision: core=MPV reason=legacy_routing player_2=false is_strm=false is_iso=false is_dolby_vision=false is_dolby_vision_p5=false is_confirmed_non_p5=not_checked is_hdr=false device_dolby_decoder=not_checked dolby_hw_enabled=true vlc_hw_enabled=true

以上是日志报告的设置和选路结果，未执行mpv属性读回或验证set_option返回码；auto-unsafe不等于真机硬件解码成功，currentVo=gpu不等于解码器是GPU。core=MPV/legacy_routing仅适用于本次非STRM、非ISO、非DV、非HDR外部URL，不是全局默认。两份已过滤日志定向检索未命中具体network-caching/cache-secs/demuxer-max-bytes值；因为过滤日志不保全所有内容，缺失不能证明未设置缓存。
