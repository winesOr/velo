// Velo Fusion 原型：时间轴（热力 + 连续进度轨 + 缓冲 + 跳过标记，同一块画布）与假弹幕。
// 热力算法即 P0 方案：bucketMs = max(1000, durationMs ~/ 600)，P95 归一化（自主设计）。
const Proto = (() => {
  // 确定性伪随机，保证每次打开原型图形一致
  let seed = 7;
  const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);

  // 生成按 timeMs 升序的假弹幕：底噪 + 几个高能峰
  function fakeComments(durationMs, peaks) {
    const out = [];
    for (let t = 0; t < durationMs; t += 900 + rnd() * 2600) out.push(t);
    for (const [center, width, n] of peaks)
      for (let i = 0; i < n; i++) out.push(center + (rnd() + rnd() + rnd() - 1.5) * width);
    return out.filter(t => t >= 0 && t < durationMs).sort((a, b) => a - b);
  }

  function heat(comments, durationMs) {
    const bucketMs = Math.max(1000, Math.floor(durationMs / 600));
    const counts = new Array(Math.ceil(durationMs / bucketMs)).fill(0);
    for (const t of comments) counts[Math.min(counts.length - 1, Math.floor(t / bucketMs))]++;
    const sorted = [...counts].sort((a, b) => a - b);
    const p95 = Math.max(1, sorted[Math.floor((sorted.length - 1) * 0.95)]);
    // 轻度平滑只用于显示；计数保持原值，供长按"此刻 N 条"使用
    const smooth = counts.map((_, i) => {
      let s = 0, n = 0;
      for (let k = -4; k <= 4; k++) if (counts[i + k] !== undefined) { s += counts[i + k]; n++; }
      return Math.min(1, s / n / p95);
    });
    return { bucketMs, counts, smooth };
  }

  const fmt = ms => { const s = Math.floor(ms / 1000);
    return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`; };

  function draw(cv, o) {
    const dpr = window.devicePixelRatio || 1, W = cv.clientWidth, H = cv.clientHeight;
    cv.width = W * dpr; cv.height = H * dpr;
    const g = cv.getContext('2d'); g.setTransform(dpr, 0, 0, dpr, 0, 0); g.clearRect(0, 0, W, H);
    const th = o.track || 5, ty = H - th - 4, D = o.durationMs;
    // 定稿：进度条为一条连续轨道，不再按章节切成分段（章节数据保留，仅不再留缝）
    const segs = [[0, W]];
    const clip = () => { g.beginPath(); for (const [l, r] of segs) g.rect(l, 0, r - l, H); g.clip(); };
    const bar = (x0, x1, color) => { g.fillStyle = color;
      for (const [l, r] of segs) { const a = Math.max(l, x0), b = Math.min(r, x1);
        if (b > a) { g.beginPath(); g.roundRect(a, ty, b - a, th, th / 2); g.fill(); } } };
    // 1. 热度（先画），画在连续轨道上方
    if (o.heatOn !== false) {
      g.save(); clip();
      const hs = o.heat.smooth, top = 2, hh = ty - 3 - top, n = hs.length;
      const grad = g.createLinearGradient(0, top, 0, ty);
      grad.addColorStop(0, 'rgba(255,255,255,.42)'); grad.addColorStop(1, 'rgba(255,255,255,.04)');
      g.beginPath(); g.moveTo(0, ty - 1);
      const pt = i => [(i + .5) / n * W, ty - 1 - hs[i] * hh];
      g.lineTo(...pt(0));
      for (let i = 1; i < n; i++) { const [x0, y0] = pt(i - 1), [x1, y1] = pt(i); g.quadraticCurveTo(x0, y0, (x0 + x1) / 2, (y0 + y1) / 2); }
      g.lineTo(W, ty - 1); g.closePath(); g.fillStyle = grad; g.fill();
      g.restore();
    }
    // 2. 连续底轨 → 缓冲 → 已播放 → 片头片尾跳过区
    bar(0, W, 'rgba(255,255,255,.22)');
    bar(0, o.bufferMs / D * W, 'rgba(255,255,255,.4)');
    bar(0, o.posMs / D * W, '#fff');
    for (const [a, b] of o.skips || []) bar(a / D * W, b / D * W, 'rgba(255,196,84,.85)');
    // 3. 播放头
    const px = o.posMs / D * W;
    g.beginPath(); g.arc(px, ty + th / 2, th + 2.5, 0, 7);
    g.fillStyle = '#fff'; g.shadowColor = 'rgba(0,0,0,.5)'; g.shadowBlur = 6; g.fill(); g.shadowBlur = 0;
  }
  // 挂载一条时间轴：悬停 = 原型里模拟"长按显示此刻 N 条"；点击 = 跳转，落在热区时吸附到附近峰值
  function mount(wrap, o) {
    const cv = wrap.querySelector('canvas'), tip = wrap.querySelector('.tip');
    const cur = o.curEl ? document.querySelector(o.curEl) : null;
    const redraw = () => { draw(cv, o); if (cur) cur.textContent = fmt(o.posMs); wrap.setAttribute('aria-valuenow', String(Math.round(o.posMs / 1000))); wrap.setAttribute('aria-valuetext', fmt(o.posMs)); };
    const at = e => {
      const r = cv.getBoundingClientRect(), f = Math.min(1, Math.max(0, (e.clientX - r.left) / r.width));
      const i = Math.min(o.heat.counts.length - 1, Math.floor(f * o.durationMs / o.heat.bucketMs));
      return { f, i, x: e.clientX - r.left };
    };
    let longPressTimer = 0, longPressed = false;
    const inspect = e => { const { i, x } = at(e); tip.style.display = 'block'; tip.style.left = x + 'px'; tip.innerHTML = `${fmt(i * o.heat.bucketMs)} · 此刻 <b>${o.heat.counts[i]}</b> 条`; };
    cv.addEventListener('pointerdown', e => { longPressed = false; clearTimeout(longPressTimer); longPressTimer = setTimeout(() => { longPressed = true; inspect(e); }, 450); });
    cv.addEventListener('pointerup', () => clearTimeout(longPressTimer));
    cv.addEventListener('pointercancel', () => { clearTimeout(longPressTimer); longPressed = false; tip.style.display = 'none'; });
    cv.addEventListener('pointerleave', () => clearTimeout(longPressTimer));
    cv.addEventListener('mousemove', e => {
      const { i, x } = at(e);
      tip.style.display = 'block'; tip.style.left = x + 'px';
      tip.innerHTML = `${fmt(i * o.heat.bucketMs)} · 此刻 <b>${o.heat.counts[i]}</b> 条`;
    });
    cv.addEventListener('mouseleave', () => { tip.style.display = 'none'; });
    cv.addEventListener('click', e => {
      if (longPressed) { longPressed = false; return; }
      let { f, i } = at(e);
      const s = o.heat.smooth;
      if (s[i] > 0.6) { // 热区内：在 ±6 桶里找峰值
        for (let k = Math.max(0, i - 6); k <= Math.min(s.length - 1, i + 6); k++) if (s[k] > s[i]) i = k;
        f = i * o.heat.bucketMs / o.durationMs;
      }
      o.posMs = f * o.durationMs; o.bufferMs = Math.max(o.bufferMs, o.posMs + 90000);
      redraw();
    });
    wrap.addEventListener('heat-toggle', e => { o.heatOn = e.detail; redraw(); });
    wrap.tabIndex = 0; wrap.setAttribute('role', 'slider'); wrap.setAttribute('aria-label', '播放进度'); wrap.setAttribute('aria-valuemin', '0'); wrap.setAttribute('aria-valuemax', String(Math.round(o.durationMs / 1000)));
    let hold = 0;
    wrap.addEventListener('keydown', e => {
      if (e.key === 'ArrowLeft' || e.key === 'ArrowRight') { e.preventDefault(); e.stopPropagation(); o.posMs = Math.max(0, Math.min(o.durationMs, o.posMs + (e.key === 'ArrowRight' ? 5000 : -5000))); wrap.setAttribute('aria-valuenow', String(Math.round(o.posMs / 1000))); redraw(); }
      if (e.key === 'Enter' && !e.repeat) { hold = performance.now(); }
    });
    wrap.addEventListener('keyup', e => { if (e.key === 'Enter' && performance.now() - hold > 450) { const peaks = o.heat.smooth.map((v,i)=>({v,i})).filter((p,i,a)=>p.v > .6 && p.v >= (a[i-1]?.v || 0) && p.v >= (a[i+1]?.v || 0)); peaks.sort((a,b)=>Math.abs(a.i * o.heat.bucketMs-o.posMs)-Math.abs(b.i * o.heat.bucketMs-o.posMs)); if(peaks.length) { o.posMs = peaks[0].i * o.heat.bucketMs; redraw(); } } });
    window.addEventListener('resize', redraw);
    redraw();
  }

  const LINES = ['前方高能！！', '这段配乐绝了', '名场面来了', '哈哈哈哈哈哈', '泪目', '每次看到这里都起鸡皮疙瘩',
    '空降成功', '作画经费在燃烧', '233333', '原来伏笔在这里', '弹幕护体', '这个转场好丝滑', '再来亿遍', 'awsl'];
  const COLORS = ['#fff', '#fff', '#fff', '#ffd166', '#7fdbca', '#ff8fab', '#a0c4ff'];

  // 填充弹幕层：lanes 行，每行若干条，速度略有差异
  function danmaku(box, lanes, per) {
    for (let l = 0; l < lanes; l++) for (let k = 0; k < per; k++) {
      const s = document.createElement('span');
      s.textContent = LINES[Math.floor(rnd() * LINES.length)];
      s.style.top = (8 + l * 30) + 'px';
      s.style.color = COLORS[Math.floor(rnd() * COLORS.length)];
      const dur = 9 + rnd() * 5;
      s.style.animationDuration = dur + 's';
      s.style.animationDelay = (-(k / per) * dur - rnd() * 2) + 's';
      box.appendChild(s);
    }
  }

  return { fakeComments, heat, mount, danmaku, fmt };
})();
