# Velo Cinema Study 02

本地核心影音交互原型。打开 `index.html` 或在本目录启动静态服务器：

```sh
python3 -m http.server 8765 --directory design/prototype-v2
```

打开 <http://127.0.0.1:8765/>。默认首页；`#atlas` 为界面索引，`#lab` 为动效实验室。

- 产品主导航：首页、媒体库、一起看、设置；搜索常驻顶部。
- 原型工具栏：桌面 / 手机 / TV，服务能力、正常 / 加载 / 空 / 错误 / 离线 / 无权限、黑白 / 青绿、亮暗切换。
- 默认黑灰白；青绿是 Velo 待选强调色，不是已确认的 VidHub 主题色。
- 所有影片与 SVG 画面均为原创演示素材；无真实媒体文件、账号、凭据或内置弹幕网关。
- 播放、投屏、服务连接与房间同步均为浏览器内模拟，不构成 Flutter / 真机实现或验收。
- 本轮聚焦核心；音乐、直播 / 录制、遥控 / 跨端配对暂缓。下载 / 同步保留相关设计草稿，不属于本轮核心验收。
- 动效默认值在 `config.js`；`TODO(PROTO-01)` 待触控与 TV 真机调优。
- `coverage.json` 是源页面到路由 / 面板的设计映射，状态 `implemented-unverified` 不代表通过测试。实际结果见 `VALIDATION.md`。

项目源自 Plezy，保留 GPL-3.0 与上游归属。参考与研究边界见 `DESIGN.md`。
