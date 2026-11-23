/* 格式徽标改版稿：在原型页面上叠加格式徽标。?fmt=old 为当前实机样式，默认为改后方案。 */
(() => {
  const params = new URLSearchParams(location.search);
  const OLD = params.get('fmt') === 'old';
  document.documentElement.dataset.fmt = OLD ? 'old' : 'new';
  // ?font=noto：全部界面固定用思源黑体（Noto Sans SC）
  if (params.get('font') === 'noto') {
    document.documentElement.classList.add('font-noto');
    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = 'https://fonts.googleapis.com/css2?family=Noto+Sans+SC:wght@400;500;600;700&display=swap';
    document.head.appendChild(link);
  }

  // 演示片源：分辨率、编码、动态范围、音频（与 media_quality_labels.dart 的判定一致）
  const DATA = {
    dune: { res: '4K', codec: 'HEVC', dv: 'DV P8', video: ['dv'], audio: 'atmos', audioText: 'TrueHD 7.1', range: 'Dolby Vision P8 / HDR10' },
    interstellar: { res: '4K', codec: 'HEVC', video: ['hdr10'], audio: null, audioText: 'DTS-HD MA 5.1', range: 'HDR10' },
    blade: { res: '4K', codec: 'HEVC', dv: 'DV P8', video: ['dv', 'hdr10p'], audio: 'atmos', audioText: 'EAC3 5.1', range: 'Dolby Vision P8 / HDR10+' },
    spirited: { res: '1080p', codec: 'H264', video: [], audio: 'dolby', audioText: 'AC3 5.1', range: 'SDR' },
    eternal: { res: '1080p', codec: 'H264', video: [], audio: null, audioText: 'AAC 2.0', range: 'SDR' },
    spring: { res: '1080p', codec: 'H264', video: [], audio: null, audioText: 'AAC 2.0', range: 'SDR' },
  };
  // 实机详情页首行 / 次行 / 评分（按 3.0.14 实机截图排版）
  const HERO = {
    dune: { date: '2024/2/27', studio: 'Legendary', genres: '科幻,冒险', cr: 'PG-13', len: '2小时46分钟', size: '58.2 GB', resume: '38:12', ratings: [['star', '8.3'], ['imdb', '8.2']] },
    blade: { date: '2017/10/6', studio: 'Warner Bros.', genres: '科幻,悬疑', cr: 'R', len: '2小时44分钟', size: '61.7 GB', resume: '1:02:40', ratings: [['imdb', '8.0'], ['check', '8.1'], ['rt', '88%']] },
    interstellar: { date: '2014/11/7', studio: 'Paramount', genres: '科幻,剧情', cr: 'PG-13', len: '2小时49分钟', size: '48.3 GB', resume: '12:05', ratings: [['imdb', '8.7'], ['check', '8.7'], ['rt', '86%']] },
    spirited: { date: '2001/7/20', studio: 'Studio Ghibli', genres: '动画,奇幻', cr: 'PG', len: '2小时5分钟', size: '9.6 GB', resume: '45:31', ratings: [['imdb', '8.6'], ['check', '8.6'], ['rt', '96%']] },
    eternal: { date: '2026/9/20', studio: 'Tencent Video', genres: '动画,剧情,动作冒险', cr: 'TV-14', len: '共4季 · 21分钟', size: '237.9 MB', resume: '08:48', ratings: [['imdb', '8.4'], ['check', '8.2'], ['rt', '97%']] },
  };
  const RATING_ICON = {
    star: '<svg viewBox="0 0 24 24" width="16" height="16" aria-hidden="true"><path d="M12 2.8l2.8 6 6.5.7-4.9 4.4 1.4 6.4L12 17l-5.8 3.3 1.4-6.4-4.9-4.4 6.5-.7z" fill="#f5c544"/></svg>',
    imdb: '<img src="assets/ratings/imdb.svg" alt="" style="height:16px;width:auto">',
    rt: '<img src="assets/ratings/rt_upright.svg" alt="" style="height:18px;width:auto">',
    check: '<svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><circle cx="12" cy="12" r="11" fill="#7c4dff"/><circle cx="12" cy="12" r="7.2" fill="none" stroke="#fff" stroke-width="1.6"/><path d="M8.6 12.2l2.4 2.4 4.6-5" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>',
  };
  const RATING_NAME = { star: '评分', imdb: 'IMDb', check: '评分', rt: '烂番茄观众' };

  const IMG = { dune: 'dune', interstellar: 'interstellar', blade: 'blade', spirited: 'spirited', 'detail-reference': 'eternal', 'hero-reference': 'spring' };
  const PREMIUM = new Set(['dv', 'hdr10', 'hdr10p', 'hlg', 'atmos', 'dtsx']);

  const LABEL = { dv: 'Dolby Vision', hdr: 'HDR', hdr10: 'HDR10', hdr10p: 'HDR10+', hlg: 'HLG', atmos: 'Dolby Atmos', dolby: 'Dolby Audio', dtsx: 'DTS:X' };
  const SHORT = { dv: 'DV', atmos: 'Atmos', dolby: 'Dolby' };
  const DOLBY = { dv: 'Vision', atmos: 'Atmos', dolby: 'Audio' };

  // 当前实机用的 Material 图标（movie_filter / hdr_on / hdr_plus / spatial_audio / surround_sound）示意
  const ICON = {
    film: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" aria-hidden="true"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="M12 8.6l1.1 2.3 2.3 1.1-2.3 1.1L12 15.4l-1.1-2.3L8.6 12l2.3-1.1z"/></svg>',
    hdr: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" aria-hidden="true"><path d="M3.5 8v8M8 8v8M3.5 12H8M11 8h2.5a4 4 0 010 8H11zM18 16V8h2a2 2 0 010 4h-2l3 4"/></svg>',
    spatial: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" aria-hidden="true"><circle cx="9" cy="9" r="3.2"/><path d="M3 20c.6-3.2 3-5 6-5s5.4 1.8 6 5M16.5 5.5a5 5 0 010 7M19.3 3a9 9 0 010 12"/></svg>',
    surround: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" aria-hidden="true"><rect x="2.5" y="4" width="19" height="16" rx="2"/><circle cx="12" cy="12" r="2.4"/><path d="M7 8.5a5 5 0 000 7M17 8.5a5 5 0 010 7"/></svg>',
  };
  const oldIcon = (f) => (f === 'dv' ? ICON.film : f === 'atmos' ? ICON.spatial : f === 'dolby' || f === 'dtsx' ? ICON.surround : ICON.hdr);

  // ---------- 改前 ----------
  const oldBadge = (f, { art = false, compact = false } = {}) =>
    `<div class="fmt-old${art ? ' art' : ''}${compact ? ' compact' : ''}">${oldIcon(f)}${compact ? SHORT[f] || LABEL[f] : LABEL[f]}</div>`;
  // mediaFormatsFor：视频只取一项（DV 优先，否则 HDR），音频一项
  const oldFormats = (d) => [d.video.includes('dv') ? 'dv' : d.video.length ? 'hdr' : null, d.audio].filter(Boolean);

  // ---------- 改后 ----------
  const label = (f) => (DOLBY[f] ? `<b>Dolby</b><i>${DOLBY[f]}</i>` : LABEL[f]);
  const badge = (f, size = 'm', extra = '') => `<div class="fmt fmt-${size}${extra}">${label(f)}</div>`;
  const resBadge = (r, size = 'm') => `<div class="fmt fmt-${size} res">${r}</div>`;
  const shortNew = (f) => ({ dv: 'DV', hdr10: 'HDR10', hdr10p: 'HDR10+', hlg: 'HLG', atmos: 'Atmos', dtsx: 'DTS:X' })[f];
  // 海报只放“高级格式”：最佳视频一项 + 高级音频一项，合成一枚分段徽标，放左上
  const posterFormats = (d) => [d.video[0], PREMIUM.has(d.audio) ? d.audio : null].filter(Boolean);

  function decoratePosters(root = document) {
    root.querySelectorAll('.poster-wrap').forEach((wrap) => {
      if (wrap.dataset.fmtDone) return;
      const img = wrap.querySelector('img');
      const key = img && Object.keys(IMG).find((k) => img.getAttribute('src')?.includes(`assets/${k}.`));
      if (!key) return;
      wrap.dataset.fmtDone = '1';
      const d = DATA[IMG[key]];
      if (OLD) {
        // 当前实机：左上角，只显示第一个格式
        const first = oldFormats(d)[0];
        if (first) wrap.insertAdjacentHTML('beforeend', `<div class="fmt-old-pos">${oldBadge(first, { art: true, compact: true })}</div>`);
        return;
      }
      wrap.classList.add('fmt-new');
      const fs = posterFormats(d);
      if (fs.length) wrap.insertAdjacentHTML('beforeend', `<div class="fmt-new-pos"><div class="fmt art seg">${fs.map((f) => `<em style="font-style:normal">${shortNew(f)}</em>`).join('')}</div></div>`);
    });
  }

  function decorateDetail() {
    const media = params.get('media') || 'eternal';
    const d = DATA[media];
    if (!d) return;
    document.querySelectorAll('[data-detail]').forEach((root) => {
      if (root.dataset.fmtDone) return;
      const metas = root.querySelectorAll('.detail-copy .detail-meta');
      const meta = metas[1];
      if (!meta) return;
      root.dataset.fmtDone = '1';
      root.classList.add('real-detail');
      const h = HERO[media] || HERO.dune;
      const duration = meta.textContent.split(' · ')[0];
      const sep = '<i class="real-sep" aria-hidden="true">|</i>';
      // 首行按实机：日期 | 出品方 | 类型 | 分级（分级是描边小框）
      // 首行与播放按钮保持 Velo 现状（原型原样）；只有“改后”把评分移到收藏 / 已看下方并缩小
      void sep;
      const actions = root.querySelector('.detail-actions');
      if (!OLD && actions && !root.querySelector('.real-ratings')) {
        root.classList.add('ratings-below');
        actions.insertAdjacentHTML('afterend', `<div class="real-ratings" role="group" aria-label="评分">${h.ratings.map(([k, v]) => `<button type="button" aria-label="${RATING_NAME[k]} ${v}">${RATING_ICON[k]}<span>${v}</span></button>`).join('')}</div>`);
      }
      if (OLD) {
        // 当前实机：次行文字后面直接接徽标，窄屏一换行就掉到下一行
        const row = document.createElement('div');
        row.className = 'fmt-old-row real-line';
        row.innerHTML = `<span>${duration} · ${d.res} ${d.codec}</span>${oldFormats(d).map((f) => oldBadge(f)).join('')}`;
        meta.replaceWith(row);
      } else {
        // 改后：次行只留文字；规格单独一行，徽标与分级框同一套描边语言
        meta.textContent = `${duration} · ${d.codec}${d.dv ? ' · ' + d.dv : ''} · ${d.audioText}`;
        meta.classList.add('real-line');
        const row = document.createElement('div');
        row.className = 'fmt-row';
        row.setAttribute('aria-label', [d.res, ...d.video.map((f) => LABEL[f]), d.audio && LABEL[d.audio]].filter(Boolean).join('，'));
        row.innerHTML = resBadge(d.res) + d.video.map((f) => badge(f)).join('') + (d.audio ? badge(d.audio) : '');
        meta.after(row);
        const v = root.querySelector('[data-version-label]');
        if (v && d.video.length) v.textContent = `${d.res} · ${LABEL[d.video[0]]}`;
        const cards = root.querySelectorAll('.media-info');
        if (cards[0] && d.video.length) cards[0].querySelector('h4').insertAdjacentHTML('beforeend', badge(d.video[0], 's'));
        if (cards[1] && d.audio) cards[1].querySelector('h4').insertAdjacentHTML('beforeend', badge(d.audio, 's'));
      }
      // 两种模式都把演示数据改成与片源一致
      const set = (card, key, value) => {
        const dt = [...(card?.querySelectorAll('dt') || [])].find((n) => n.textContent.startsWith(key));
        if (dt) dt.nextElementSibling.textContent = value;
      };
      const cards = root.querySelectorAll('.media-info');
      set(cards[0], '视频范围', d.range);
      set(cards[0], '标题', `${d.res} ${d.codec}`);
      if (d.range !== 'SDR') { set(cards[0], '位深度', '10 bit'); set(cards[0], '色域', 'bt2020'); }
      set(cards[1], '标题', d.audio === 'atmos' ? `${d.audioText} Atmos` : d.audioText);
    });
  }

  function decoratePlayer() {
    const fs = ['dv', 'atmos'];
    document.querySelectorAll('.ttl, .tv-ttl').forEach((ttl) => {
      if (ttl.dataset.fmtDone) return;
      const tv = ttl.classList.contains('tv-ttl');
      const sub = tv ? ttl.querySelector(':scope > span') : ttl.querySelector('.sub');
      if (!sub) return;
      ttl.dataset.fmtDone = '1';
      if (OLD) {
        // 当前实机：DolbyPlaybackIndicator 挂在标题列下方，另起一行
        const row = document.createElement('div');
        row.className = 'fmt-old-row';
        if (tv) row.style.cssText = 'gap:12px;margin-top:10px';
        row.innerHTML = fs.map((f) => oldBadge(f, { art: true })).join('');
        if (tv) row.querySelectorAll('.fmt-old').forEach((b) => { b.style.cssText = 'font-size:22px;line-height:30px;padding:4px 12px;border-radius:14px;gap:6px'; b.querySelector('svg').style.cssText = 'width:28px;height:28px'; });
        ttl.appendChild(row);
        return;
      }
      // 改后：与副标题同一行，靠副标题右侧；TV 用 L 尺寸
      const row = document.createElement('div');
      row.className = 'fmt-sub-row';
      sub.before(row);
      row.appendChild(sub);
      row.insertAdjacentHTML('beforeend', `<div class="fmt-group" aria-label="正在输出 ${fs.map((f) => LABEL[f]).join('，')}">${fs.map((f) => badge(f, tv ? 'l' : 's')).join('')}</div>`);
    });
  }

  function decorateSkip() {
    if (OLD) return;
    document.querySelectorAll('.player-device .skip').forEach((b) => {
      if (b.dataset.fmtDone) return;
      b.dataset.fmtDone = '1';
      b.classList.add('skip-new');
      b.innerHTML = `<span class="skip-label">跳过片头</span><span class="skip-ico" aria-hidden="true"><svg viewBox="0 0 24 24"><path d="M4.5 6.5l7 5.5-7 5.5zM12.5 6.5l7 5.5-7 5.5z" fill="currentColor"/></svg></span>`;
    });
  }

  // 改后：底部第二个入口 搜索 → 收藏
  function decorateNav() {
    if (OLD) return;
    const onFav = location.pathname.endsWith('favorites.html');
    document.querySelectorAll('.app-nav a[href="library.html"]').forEach((a) => {
      if (a.dataset.fmtDone) return;
      a.dataset.fmtDone = '1';
      a.href = 'favorites.html';
      a.innerHTML = UI.icon('heart') + '<span>收藏</span>';
      a.classList.toggle('on', onFav);
      if (onFav) a.setAttribute('aria-current', 'page'); else a.removeAttribute('aria-current');
    });
  }

  // 改后：倍速改成按钮上方的下拉框，不再从侧边弹出
  const SPEEDS = ['2.0x', '1.5x', '1.25x', '1.0x', '0.75x', '0.5x'];
  function closeSpeed(root) { root.querySelector('.speed-dd')?.remove(); }
  function openSpeed(root, chip) {
    closeSpeed(root);
    const current = (chip.textContent.match(/[0-9.]+x/) || ['1.0x'])[0];
    const dd = document.createElement('div');
    dd.className = 'speed-dd';
    dd.setAttribute('role', 'listbox');
    dd.setAttribute('aria-label', '播放速度');
    dd.innerHTML = SPEEDS.map((v) => `<button type="button" role="option" aria-selected="${v === current}" class="${v === current ? 'sel' : ''}"><span class="ck">${v === current ? '✓' : ''}</span>${v}</button>`).join('') + '<div class="sep"></div><button type="button" class="more"><span class="ck"></span>更多速度…</button>';
    root.appendChild(dd);
    const box = root.getBoundingClientRect(), r = chip.getBoundingClientRect();
    const k = box.width / root.offsetWidth || 1;
    const w = dd.offsetWidth, h = dd.offsetHeight;
    const left = Math.min(Math.max(8, (r.left - box.left) / k + (r.width / k - w) / 2), root.offsetWidth - w - 8);
    const top = Math.max(8, (r.top - box.top) / k - h - 8);
    dd.style.left = left + 'px';
    dd.style.top = top + 'px';
    dd.querySelectorAll('button[role=option]').forEach((b) => b.onclick = (e) => {
      e.stopPropagation();
      const v = b.textContent.trim().replace('✓', '');
      chip.childNodes.forEach((n) => { if (n.nodeType === 3 && /x/.test(n.textContent)) n.textContent = v; });
      if (!/x/.test(chip.textContent)) chip.append(v);
      closeSpeed(root);
      chip.focus();
    });
    dd.querySelector('.more').onclick = (e) => { e.stopPropagation(); closeSpeed(root); };
    dd.addEventListener('keydown', (e) => { if (e.key === 'Escape') { closeSpeed(root); chip.focus(); } });
    (dd.querySelector('.sel') || dd.querySelector('button')).focus({ preventScroll: true });
  }
  function bindSpeed() {
    if (OLD || bindSpeed.done || !document.querySelector('.player-device')) return;
    bindSpeed.done = true;
    document.addEventListener('click', (e) => {
      const chip = e.target.closest?.('.player-device [data-act="speed"], .player-device [data-tv="speed"]');
      const root = e.target.closest?.('.player-device');
      if (chip && root) { e.stopImmediatePropagation(); e.preventDefault(); root.querySelector('.speed-dd') ? closeSpeed(root) : openSpeed(root, chip); return; }
      if (root && !e.target.closest('.speed-dd')) closeSpeed(root);
    }, true);
    // 原型里预先打开的“倍速”演示（侧边抽屉）换成下拉框
    setTimeout(() => document.querySelectorAll('.player-device').forEach((root) => {
      const d = [...root.querySelectorAll('.drawer')].find((n) => n.querySelector('.pop.center-text'));
      if (!d) return;
      d.remove();
      root.querySelectorAll('.scrim').forEach((n) => n.remove());
      const chip = root.querySelector('[data-act="speed"]');
      if (chip) openSpeed(root, chip);
    }), 700);
  }

  function decorate() {
    decoratePosters();
    if (window.UI) decorateNav();
    if (document.querySelector('[data-detail]')) decorateDetail();
    if (document.querySelector('.ttl, .tv-ttl')) { decoratePlayer(); decorateSkip(); bindSpeed(); }
  }

  function switcher() {
    if (params.has('preview') || window.self !== window.top) return;
    const nav = document.createElement('nav');
    nav.className = 'fmt-switch';
    nav.setAttribute('aria-label', '徽标方案');
    const make = (mode, text) => {
      const p = new URLSearchParams(location.search);
      mode === 'old' ? p.set('fmt', 'old') : p.delete('fmt');
      const q = p.toString();
      return `<a href="${location.pathname.split('/').pop() || 'index.html'}${q ? '?' + q : ''}" aria-current="${(mode === 'old') === OLD}">${text}</a>`;
    };
    nav.innerHTML = make('old', '改前（实机）') + make('new', '改后');
    document.body.appendChild(nav);
  }

  let pending = 0;
  const run = () => { cancelAnimationFrame(pending); pending = requestAnimationFrame(decorate); };
  const start = () => {
    if (params.has('tvonly')) document.body.classList.add('tv-only');
    const stage = params.get('stage');
    if (stage && document.getElementById(stage)) {
      const dev = document.getElementById(stage);
      document.body.classList.add('stage-only');
      dev.closest('.stage-row')?.classList.add('keep');
      let n = dev; while (n && !n.classList?.contains('stage-row')) { n.classList?.add('keep'); n = n.parentElement; }
    }
    decorate();
    switcher();
    new MutationObserver(run).observe(document.body, { childList: true, subtree: true });
    // 播放器演示切到电影《沙丘：第二部》
    setTimeout(() => document.querySelector('[data-list-mode="movie"]')?.click(), 400);
    const target = params.get('scroll');
    if (target === 'info') setTimeout(() => document.querySelectorAll('.device-scroll').forEach((s) => {
      const info = s.querySelector('.media-info-scroll');
      if (info) s.scrollTop = info.closest('.section').offsetTop - 260;
    }), 300);
  };
  document.readyState === 'loading' ? document.addEventListener('DOMContentLoaded', start) : start();
})();
