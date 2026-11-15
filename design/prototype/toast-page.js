/* toast.html only: device backdrops and demo buttons for the final option A and the archived options B / C. */
(() => {
  const {icon}=UI,{P,host}=VeloToast;
  window.VT={P,log:VeloToast.log};
  const phone=()=>`<div class="vt-screen"><div class="vt-hero"><img src="assets/hero-reference.jpg" alt=""></div>
    <div class="vt-status"><span>9:41</span><span>${icon('signal')} 5G <b>100</b></span></div>
    <div class="vt-top" data-toast-anchor><span class="vt-pill">Emby ${icon('down')}</span><span class="vt-sp"></span><span class="vt-round">${icon('search')}</span><span class="vt-round">${icon('more')}</span></div>
    <div class="vt-copy"><small>SPRING OF THE BLADE</small><h4>一瓯春</h4><p>2026 · 剧情 · 家庭 · ★ 9.5</p><div class="vt-btns"><span class="vt-play">${icon('play')}继续观看 第 7 集</span><button class="vt-fav" data-fav aria-pressed="false" aria-label="收藏">${icon('heart')}</button></div></div>
    <div class="vt-sec"><h5>继续观看</h5><div class="vt-thumbs"><img src="assets/continue-reference.jpg" alt=""><img src="assets/continue-second.jpg" alt=""></div></div>
    <div class="vt-tabbar"><span class="on">${icon('home')}首页</span><span>${icon('library')}搜索</span><span>${icon('together')}一起看</span><span>${icon('settings')}设置</span></div><div class="vt-homebar"></div></div>`;
  const land=()=>`<div class="vt-screen"><div class="vt-video" title="点画面切换顶栏 HUD"></div><div class="vt-hud">
    <div class="vt-hud-top" data-toast-anchor>${icon('back')}<span>星际穿越 <small>· 1080P</small></span><span class="vt-sp"></span>${icon('danmaku')}${icon('cast')}${icon('more')}</div>
    <div class="vt-hud-bot"><div class="vt-bar"><i></i></div><div>${icon('play')}${icon('forward')}<span>1:02:14 / 2:49:03</span><span class="vt-sp" style="flex:1"></span><span>倍速</span><span>字幕</span><span>选集</span></div></div></div></div>`;
  const tv=()=>`<div class="vt-screen"><div class="vt-tvbg"></div>
    <div class="vt-tvnav" data-toast-anchor><span class="on">${icon('home')}首页</span><span>${icon('library')}搜索</span><span>${icon('together')}一起看</span><span>${icon('settings')}设置</span></div>
    <div class="vt-tvcopy"><small>INTERSTELLAR</small><h4>星际穿越</h4><p>2014 · 科幻 · 剧情 · ★ 9.4<br>剩余 1 小时 42 分钟</p><div class="vt-tvbtns"><span class="pri">${icon('play')}继续观看</span><span>查看详情</span><button class="vt-fav" data-fav aria-pressed="false" aria-label="收藏" tabindex="-1">${icon('heart')}</button></div></div>
    <div class="vt-tvrow"><img src="assets/continue-reference.jpg" alt=""><img src="assets/continue-second.jpg" alt=""><img src="assets/interstellar-backdrop.jpg" alt=""></div></div>`;

  const LONG='无法播放《星际穿越》：服务器“家里的 Emby”返回的 HEVC Main10 / 杜比视界 Profile 5 视频，当前设备无法硬解，软解性能也不足。请在设置中切换播放内核，或选择其他版本后再试。';
  const DEMOS={
    success:h=>h.show({type:'success',text:'已加入稍后观看'}),
    info:h=>h.show({type:'info',text:'字幕已切换为 简体中文'}),
    error:h=>h.show({type:'error',text:'无法连接到“家里的 Emby”',action:{label:'重试',run:()=>{const t=h.show({type:'loading',text:'正在重新连接…'});setTimeout(()=>t.update({type:'success',text:'已重新连接'}),1200);}}}),
    undo:h=>h.show({type:'info',text:'已从继续观看中移除《一瓯春》',action:{label:'撤销',run:()=>h.show({type:'success',text:'已恢复到继续观看'})}}),
    loading:h=>{
      const fav=h.root.querySelector('[data-fav]');if(fav?.getAttribute('aria-busy')==='true')return;
      const next=!h.fav;let t=null,done=false;fav?.setAttribute('aria-busy','true');
      setTimeout(()=>{if(!done)t=h.show({type:'loading',text:next?'正在收藏…':'正在取消收藏…',key:'fav'});},P.loadingDelay);
      setTimeout(()=>{done=true;h.fav=next;if(fav){fav.removeAttribute('aria-busy');fav.setAttribute('aria-pressed',String(next));}const msg={type:'success',text:next?'已收藏《一瓯春》':'已取消收藏',key:'fav-done'};t?t.update(msg):h.show(msg);},1500);
    },
    burst:h=>[0,140,280].forEach(d=>setTimeout(()=>h.show({type:'success',text:'已加入下载队列'}),d)),
    long:h=>h.show({type:'error',text:LONG})
  };
  window.VT.DEMOS=DEMOS;

  const DEMO_LABELS=[['success','成功','var(--vt-success)'],['info','提示','var(--vt-info)'],['error','错误 · 重试','var(--vt-error)'],['undo','带“撤销”','var(--vt-act)'],['loading','加载中 → 成功（收藏）','var(--vt-load)'],['burst','连续触发 ×3','var(--vt-success)'],['long','长文本两行截断','var(--vt-error)']];
  const hosts={};window.VT.hosts=hosts;
  document.querySelectorAll('[data-scheme]').forEach(sec=>{
    const v=sec.dataset.scheme,stage=sec.querySelector('.vt-stage'),bar=sec.querySelector('.vt-demo');
    stage.innerHTML=`<div class="vt-col"><div class="vt-frame vt-phone" data-ctx="phone">${phone()}</div><div class="vt-cap">手机竖屏 · 390 × 844 · 首页（真实海报背景，跟随浅色 / 深色）</div></div>
      <div class="vt-col"><div class="vt-frame vt-land vt-force-dark hud-on" data-ctx="land">${land()}</div><div class="vt-cap">手机横屏播放器 · 844 × 390 · 点画面切换顶栏 HUD，提示条自动避让（播放器内始终深色）</div>
      <div class="vt-frame vt-tvwrap" data-ctx="tv">${tv()}</div><div class="vt-cap">TV · 1920 × 1080 按 0.45 缩放 · 标题安全区 5% · 正文 28px · 不获取焦点 · 菜单键执行操作</div></div>`;
    hosts[v]=[...stage.querySelectorAll('.vt-frame')].map(f=>host(f,v,f.dataset.ctx));
    stage.querySelectorAll('.vt-video').forEach(n=>n.addEventListener('click',()=>n.closest('.vt-land').classList.toggle('hud-on')));
    bar.innerHTML=DEMO_LABELS.map(([k,l,c])=>`<button type="button" data-demo="${k}"><i style="background:${c}"></i>${l}</button>`).join('');
    bar.addEventListener('click',e=>{const b=e.target.closest('[data-demo]');if(b)hosts[v].forEach(h=>DEMOS[b.dataset.demo](h));});
  });

  document.querySelectorAll('[data-param]').forEach(inp=>{inp.value=P[inp.dataset.param];inp.addEventListener('change',()=>{const n=Number(inp.value);if(Number.isFinite(n)&&n>=0)P[inp.dataset.param]=n;else inp.value=P[inp.dataset.param];});});
  const rm=document.querySelector('[data-reduce]');rm?.addEventListener('change',()=>document.body.classList.toggle('vt-reduce',rm.checked));
  const hud=document.querySelector('[data-hud]');hud?.addEventListener('change',()=>document.querySelectorAll('.vt-land').forEach(n=>n.classList.toggle('hud-on',hud.checked)));
})();
