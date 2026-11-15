(() => {
  const icon = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" aria-hidden="true"><path d="M3 9V5a1 1 0 0 1 1-1h16a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1h-7M3 13a7 7 0 0 1 7 7M3 17a3 3 0 0 1 3 3"/><circle cx="3" cy="20" r=".8" fill="currentColor"/></svg>';
  const devices = [
    ['客厅电视 · Sony', 'DLNA / UPnP', '电视端弹幕不可用；字幕取决于接收设备支持。'],
    ['客厅 · Velo TV', 'Velo 客户端', '设计目标：由 TV 客户端加载弹幕。一起看同步仍需接入验证。'],
    ['书房 · Chromecast', 'Google Cast', '字幕与格式需匹配接收端能力；当前展示连接流程。']
  ];
  document.querySelectorAll('[data-cast-open]').forEach((trigger, index) => {
    trigger.innerHTML = icon + (trigger.classList.contains('item') ? '<span>选择投屏设备</span>' : '');
    trigger.setAttribute('aria-label', '投屏');
    trigger.setAttribute('aria-haspopup', 'dialog');
    const frame = trigger.closest('.phone, .tv');
    const overlay = document.createElement('div');
    overlay.className = 'cast-overlay'; overlay.hidden = true;
    overlay.innerHTML = `<section class="cast-sheet" role="dialog" aria-modal="true" aria-labelledby="cast-title-${index}"></section>`;
    frame.append(overlay);
    const sheet = overlay.firstElementChild;
    let selected = null, paused = false, position = 512, volume = 65;
    const fmt = value => `${Math.floor(value / 60)}:${String(value % 60).padStart(2, '0')}`;
    const close = () => { trigger.focus(); if (!frame.classList.contains('player-device')) { overlay.hidden = true; return; } overlay.classList.add('out'); setTimeout(() => { overlay.hidden = true; overlay.classList.remove('out'); }, 240); };
    const header = title => `<div class="cast-heading"><h3 id="cast-title-${index}">${title}</h3><button class="cast-close" aria-label="关闭投屏面板">×</button></div>`;
    function render() {
      if (selected === null) {
        sheet.innerHTML = header('投屏到') + '<p class="cast-caption">选择同一网络中的设备 · 模拟设备列表</p>' + devices.map((d, i) => `<button class="cast-device" data-device="${i}"><span class="screen">${UI.icon('tv')}</span><span><b>${d[0]}</b><small>${d[1]}</small></span><span class="arrow">›</span></button>`).join('') + '<div class="cast-actions"><button class="btn sec" data-refresh>刷新设备</button></div><p class="cast-note" role="status">连接后，手机可控制播放、进度与音量。</p>';
        sheet.querySelectorAll('[data-device]').forEach(button => button.onclick = () => { selected = Number(button.dataset.device); render(); });
        sheet.querySelector('[data-refresh]').onclick = () => { sheet.querySelector('[role=status]').textContent = '已刷新：3 台模拟设备。原型不会扫描真实网络。'; };
      } else {
        const device = devices[selected];
        sheet.innerHTML = header(device[0]) + `<div class="cast-status">● 已连接 · ${device[1]} · 演示</div><div class="cast-media"><b>${document.querySelector('.reference-home') ? '一瓯春' : '一念永恒'}</b><small>第 7 集 · 手机遥控</small></div><div class="cast-range-label"><span data-time>${fmt(position)}</span><span>23:40</span></div><input data-seek type="range" min="0" max="1420" value="${position}" aria-label="播放进度"><div class="cast-transport"><button data-back aria-label="后退十秒">−10</button><button data-pause aria-label="${paused ? '播放' : '暂停'}">${paused ? '▶' : '❚❚'}</button><button data-forward aria-label="前进十秒">+10</button></div><label class="cast-range-label">音量 <span data-volume-label>${volume}%</span></label><input data-volume type="range" min="0" max="100" value="${volume}" aria-label="音量"><div class="cast-actions"><button class="btn sec" data-change>更换设备</button><button class="btn pri" data-disconnect>断开投屏</button></div><p class="cast-note">${device[2]}<br>仅演示交互，不推送真实视频。</p>`;
        const seek = sheet.querySelector('[data-seek]');
        const update = value => { position = Math.max(0, Math.min(1420, value)); seek.value = position; sheet.querySelector('[data-time]').textContent = fmt(position); };
        seek.oninput = () => update(Number(seek.value));
        sheet.querySelector('[data-back]').onclick = () => update(position - 10);
        sheet.querySelector('[data-forward]').onclick = () => update(position + 10);
        sheet.querySelector('[data-pause]').onclick = () => { paused = !paused; render(); };
        sheet.querySelector('[data-volume]').oninput = e => { volume = Number(e.target.value); sheet.querySelector('[data-volume-label]').textContent = `${volume}%`; };
        sheet.querySelector('[data-change]').onclick = () => { selected = null; render(); };
        sheet.querySelector('[data-disconnect]').onclick = () => { selected = null; paused = false; trigger.title = '投屏已断开'; render(); };
      }
      sheet.querySelector('.cast-close').onclick = close;
      sheet.querySelector('button').focus();
    }
    trigger.onclick = () => { overlay.classList.remove('out'); overlay.hidden = false; render(); };
    overlay.onclick = e => { if (e.target === overlay) close(); };
    overlay.onkeydown = e => {
      if (e.key === 'Escape') { e.stopPropagation(); close(); }
      if (e.key === 'Tab') {
        const controls = [...sheet.querySelectorAll('button, input')];
        const first = controls[0], last = controls[controls.length - 1];
        if (e.shiftKey && document.activeElement === first) { e.preventDefault(); last.focus(); }
        else if (!e.shiftKey && document.activeElement === last) { e.preventDefault(); first.focus(); }
      }
    };
  });
})();
