# Plezy visual prototype V3

Open `index.html` to review the six primary surfaces. Each page includes touch and TV layouts; at narrow widths, the phone layout fills the viewport.

```bash
python3 -m http.server 8765 --bind 127.0.0.1
# http://127.0.0.1:8765/design/prototype/index.html
```

## Review routes

- `home.html`: four artwork themes, dot / swipe navigation without arrow buttons, pixel-derived palette, continuous transitions, account / server entry.
- `detail.html`: TV series reference; seasons, episode groups, all episodes, version choice, favorite / watched, overview, actors, related, stream information.
- `detail.html?media=dune`: film detail without episode controls. Other sample IDs: `interstellar`, `spirited`, `blade`, `spring`.
- `library.html`: three-column phone / seven-column TV, search, media type, server / genre / year / region / watch-state filters, sort, empty state, reset.
- `together.html`: create, join, lobby, readiness and invite. Demo invite code: `246810`.
- `settings.html`: category hierarchy, TV split view, empty-source onboarding, gateway URL validation, source order / removal, style ranges. Values persist only under `plezy-visual-study-settings-v2` in this prototype origin's localStorage.
- `player.html`: V4 layout. Top right: danmaku toggle, cast, portrait/landscape, more. Left rail: lock only (rotation is the top-right portrait/landscape button). Right rail: screenshot, PiP. No centre buttons; double-tap left / centre / right seeks back, pauses, seeks forward, and vertical swipes on the left / right half set brightness / volume. Speed, subtitle and episode chips open translucent popovers above the bottom HUD; "more" and the danmaku chip open a floating four-tab drawer (video / audio / subtitle / danmaku). Menus follow the light / dark appearance; the video HUD stays dark.
- `player.html` §⑤ TV · 播放界面（PLAYER-05）：1920×1080 画面缩放进 TV 帧；方向键移动、Enter 确认、Esc/Backspace 逐层返回；顶栏/进度条/底栏（上一集、播放、下一集、倍速、字幕、音轨、选集、队列、章节、弹幕、设置）、跳过片头、右侧抽屉。点一下画面或 Tab 进入后用键盘操作。

All media, network connectivity, casting and room behavior are demonstrations. Gateway “检查格式” validates syntax only. No actual server sign-in, media download, discovery or playback occurs. VLC is disabled and marked planned. Generic secondary settings dialogs confirm layout / entry placement, not implementation completeness.

## Visual implementation

`ui.css` / `ui.js` own the shared tokens, linear icons, controls, modal behavior and spatial keyboard demonstration. `theme.js` reads a 32×32 canvas, filters low-value / low-saturation pixels, preserves the sampled luminance and compresses highly saturated colors, caches image work, and interpolates from the currently displayed color. Old requests cannot overwrite the latest selection. Artwork crossfades after decode, using the same 560ms timing. These are our prototype choices, not claims about inaccessible VidHub business code.

The unchanged tall screenshot is cropped by CSS for artwork / cast / episode previews. Final implementation uses clean server images; screenshot-derived artwork has limited cropping fidelity.

`proto.css` retains the existing base / player canvas styling. `qa/` holds browser screenshots, interaction receipts and verification notes. Full comparison and Flutter change suggestions: `docs/prototype-visual-audit-2026-10-23.md` in the repository.

## V3 review adjustments (2026-10-23)

- Server identity uses the existing repository Emby / Jellyfin / Plex SVG paths. Home server selection updates the logo, media metadata carries its server icon, and version switching updates the detail source icon. No provider uses a first-letter avatar.
- Home account / more menus are anchored popovers. Filters, episode selection and settings use centered, fully rounded floating dialogs; all player panels (settings, tracks, subtitles, speed, episodes, search, cast) are full-height right-side drawers (340px, left corners 24px, scrim, slide in/out). No dialog attaches to the bottom edge. The 16px corner and separate menu surface reference VidHub's decoded `dialog_corner_background` / `dialog_radius` resources; exact behavior remains our prototype implementation.
- `appearance.js` handles `system`, `light`, `dark`, defaults to system, persists under `plezy-prototype-appearance`, listens to OS changes in system mode, and synchronizes other open prototype documents via storage events. `appearance.css` owns the light palette and stronger dark navigation separation. Artwork sampling stays independent from the appearance preference.
- Choose the appearance in Settings → 外观与首页 → 界面主题, or use the review toolbar above the device. Video HUD remains dark for readability over the video frame.
- The home carousel uses real pointer / touch swipes, dots and TV keyboard input; the visible left / right arrow controls were removed.
- Latest verification and screenshots: `qa/revision-3/`. Earlier V2 evidence remains historical.


## 本轮优化：启动、评分与分区设置（2026-11-13）

- 首页上方“启动行为演示”提供正常浏览、缓存回显、首次加载、慢库、部分失败。默认正常浏览，不自动播放加载动画。手机和 TV 同时切换；首页服务器切换会取消上一场景，清空旧内容并演示当前服务器加载。
- “缓存回显 / 部分失败”保留已经显示的卡片；继续观看、电影库、剧集库各自到达。失败行可单独重试，其他内容可继续打开。首次加载 / 慢库使用行级骨架。后补评分只更新节点内容，不替换媒体卡片或改变焦点。
- 首页轮播评分按钮和电影行“评分来源说明”打开统一解释；详情新增两个评分示例入口。未知来源保持泛称，未载入的评分不展示 0；银翼杀手首页卡片刻意无分。IMDb 是带来源的设计示例，不代表已抓取到竞品 IMDb 请求。
- 设置首页 → 网络与缓存（TV 左侧同名分类）：服务器线路可新增 / 选择 / 删除，名称非空、端口必须是 1–65535 整数。地址为不带账号、路径、参数或端口的 HTTP(S) origin；端口单独输入，建议使用 `https://media.example.test`。所有操作仅校验格式，不请求网络，也没有测速结果。
- 首页快照、图片缓存、播放缓冲分开呈现。容量与时长初始留空；硬解等选项初始跟随核心，均不推定 VidHub 实际默认值。“清除缓存”只提示演示，不删除设备缓存。
- 新选项保存到原型 origin 的 localStorage（`plezy-prototype-study-v1`）；旧设置键不变。无凭据存储。`file://` 可直接打开，浏览器限制存储时仍可在当前页面演示；海报取色可能受本地 canvas 安全限制，HTTP 本地预览更完整。
- 两份独立交付：`performance-improvements.html` / `.md`、`ui-improvements.html` / `.md`，总览已有入口。性能建议面向后续原生实现，本次没有改 Dart / Android，也不代表性能优化已上线。

### 演示参数与证据边界

`study-upgrade.js` 的 `DEMO` 集中定义设计参数：继续观看 600 ms、电影 1000 ms、剧集 1700 ms、慢库 5000 ms、评分后补 700 ms、单库重试 900 ms。只用于让状态可观察，绝非测得的 VidHub / Velo 延迟、缓存 TTL、超时或最快线路算法；`TODO(PROTO-PERF-01)` 标明未来应替换为实测产品预算。

本轮沿用早期 V3 海报取色、玻璃浮层、手机 / TV、库筛选、一起看和播放器。新增代码在 `study-upgrade.js/css`，既有 HTML、hero.js 与 settings.js 只做接入。评分提供方、竞品缓存命中 / TTL / 真正首页就绪时间和最快线路算法仍未查清；详情紫色图标没有在此实现中被当成 HTTP 来源证据。素材仍沿用本地已有示例，不新增第三方网络加载。


## 最终 UI 基准 V1

入口 `index.html`；逐组件验收规范 `final-ui-spec.html`。本轮将详情评分归入海报信息组，播放器采用 Velo AppSelectField 双行字段，统一全页居中对话框与顶部轻通知，不再使用底部弹出面板。三种外观、海报取色与上一轮加载场景保留。

- `final-ui.css`：Velo Cinema/品牌与 Overlay token；非播放页独立弹窗居中（24px），播放器内面板为右侧抽屉（宽340px、左侧圆角24px），紧凑选择菜单 18px，字段 14px。
- `final-ui.js`：播放器轨道稳定 ID、主次字幕互斥、按示例设备保存、焦点约束。默认普通话/简体中文/次字幕关闭；仅本地演示。
- `player.html` 第一个播放器下的验收工具切换正常、无音轨、无次字幕、慢切换、失败。也可用 `?tracks=empty|single|slow|failure`；360/1400ms 是设计参数。
- `detail.html?ratings=none` 展示无分收起；默认评分在 hero 元数据后、播放前，数值为示例，服务器分来源未标注。
- 真实 Flutter UI 未在本轮修改；居中弹窗/顶部通知是用户确定的新基准，真实应用需按最终规范逐项实施。

详情剧集采用整季连续横向列表：默认示例第4季27集（前3季12/24/30集），分组为1–10/11–20/21–27。向前或向后滑动以最接近列表左边缘的卡片同步高亮；点分组滚动至首集，不重建分页。选集与TV焦点均保留连续内容，换季回第1集。上述集数仅为验收样例。
