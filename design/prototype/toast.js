/* Toast redesign study: one shared engine, three visual options (A/B/C), three contexts (phone / player / TV).
   Demonstration only. Other prototype pages keep their current UI.toast until an option is chosen. */
(() => {
  const {icon}=UI;
  // Adjustable parameters (ms). Action toasts use `action` regardless of type; TV adds `tvExtra`.
  const P={success:2500,info:2500,error:4000,action:5000,tvExtra:1000,enter:220,exit:180,swap:120,loadingDelay:300};
  const reduced=()=>document.body.classList.contains('vt-reduce')||matchMedia('(prefers-reduced-motion: reduce)').matches;
  const EASE='cubic-bezier(.2,.8,.2,1)';
  const GLYPH={success:'<circle cx="12" cy="12" r="9"/><path d="m8 12.4 2.7 2.7L16.2 9.5"/>',info:'<circle cx="12" cy="12" r="9"/><path d="M12 11v5.4M12 7.7h.01"/>',error:'<circle cx="12" cy="12" r="9"/><path d="M12 7.4v5.6M12 16.4h.01"/>'};
  const glyph=t=>t==='loading'?'<span class="vt-spin"></span>':`<svg viewBox="0 0 24 24">${GLYPH[t]}</svg>`;
  const log=[];// stack checks for automated verification
  window.VT={P,log};

  class Host{
    constructor(frame,variant,ctx){
      Object.assign(this,{frame,variant,ctx,cur:null});
      const h=document.createElement('div');h.className=`vt-host vt-${variant} vt-ctx-${ctx}`;
      h.innerHTML='<div class="vt-live" role="status" aria-live="polite" aria-atomic="true"></div><div class="vt-live" role="alert" aria-live="assertive" aria-atomic="true"></div>';
      frame.querySelector('.vt-screen').append(h);[this.polite,this.alert]=h.children;this.host=h;
    }
    visible(){return this.host.querySelectorAll('.vt-root').length;}
    duration(o){if(o.type==='loading')return 0;let d=o.duration??(o.action?P.action:P[o.type]);if(this.ctx==='tv')d+=P.tvExtra;return d;}
    show(o){
      const key=o.key||o.text,c=this.cur;
      if(c&&c.leaving){c.anim?.cancel();c.el.remove();this.cur=null;}
      const live=this.cur;
      let handle;
      if(live&&live.key===key&&live.type===o.type&&o.type!=='loading'){live.count++;this.fill(live,o);if(this.variant==='c')this.fit(live,false);this.restart(live);this.pulse(live);handle=live.handle;}
      else if(live){live.key=key;live.count=1;this.swap(live,o);this.restart(live);handle=live.handle;}
      else handle=this.create(o,key);
      log.push({scheme:this.variant,ctx:this.ctx,visible:this.visible()});
      return handle;
    }
    build(){
      const t=document.createElement('div');t.className='vt-toast';
      t.innerHTML='<span class="vt-ico" aria-hidden="true"></span><span class="vt-body"><span class="vt-msg"></span><span class="vt-count" hidden></span></span><span class="vt-action" hidden></span><i class="vt-timer" aria-hidden="true"></i>';
      if(this.variant==='c'){const isl=document.createElement('div');isl.className='vt-island';isl.append(t);return [isl,t];}
      return [t,t];
    }
    create(o,key){
      const [el,t]=this.build();el.classList.add('vt-root');
      const c={el,t,key,count:1,type:o.type,leaving:false,timer:0,remaining:0,started:0};
      c.handle={update:n=>this.cur===c&&!c.leaving?(c.key=n.key||n.text,c.count=1,this.swap(c,n),this.restart(c),c.handle):this.show(n),dismiss:()=>this.dismiss(c),get el(){return c.el;}};
      this.cur=c;this.fill(c,o);this.place(c);this.bind(c);
      if(this.variant==='c')this.fit(c,true);else this.enter(c);
      this.restart(c);return c.handle;
    }
    place(c){const region=c.type==='error'?this.alert:this.polite;if(c.el.parentNode!==region)region.append(c.el);}
    fill(c,o){
      const {t}=c;c.type=o.type;c.action=o.action||null;t.dataset.type=o.type;
      t.querySelector('.vt-ico').innerHTML=glyph(o.type);
      t.querySelector('.vt-msg').textContent=o.text;
      t.title=o.text;
      const n=t.querySelector('.vt-count');n.hidden=c.count<2;n.textContent=`×${c.count}`;n.setAttribute('aria-label',`共 ${c.count} 次`);
      const old=t.querySelector('.vt-action'),a=document.createElement(this.ctx==='tv'?'span':'button');a.className='vt-action';
      if(o.action){
        // TV: never moves focus to the toast; the action maps to the remote's Menu key (click simulates it here).
        a.innerHTML=this.ctx==='tv'?`<kbd>≡</kbd>${o.action.label}`:o.action.label;
        if(this.ctx!=='tv')a.type='button';
        a.addEventListener('click',e=>{e.stopPropagation();this.act(c);});
      }else a.hidden=true;
      old.replaceWith(a);t.classList.toggle('has-action',!!o.action);
      if(this.cur===c)this.place(c);
    }
    act(c){if(!c.action||c.leaving)return;const run=c.action.run;c.action=null;const k=c.key;run();if(this.cur===c&&c.key===k&&!c.leaving)this.dismiss(c);}
    swap(c,o){
      const parts=[...c.t.children].filter(n=>!n.classList.contains('vt-timer'));
      c.swapAnim?.forEach(a=>a.cancel());
      c.swapAnim=parts.map(n=>n.animate([{opacity:1},{opacity:0}],{duration:P.swap/2,easing:'ease-out',fill:'forwards'}));
      const token=c.swapToken=(c.swapToken||0)+1;
      c.type=o.type;c.action=o.action||null;
      setTimeout(()=>{if(c.swapToken!==token)return;this.fill(c,o);c.swapAnim?.forEach(a=>a.cancel());[...c.t.children].filter(n=>!n.classList.contains('vt-timer')).forEach(n=>n.animate([{opacity:0},{opacity:1}],{duration:P.swap,easing:'ease-out'}));if(this.variant==='c')this.fit(c,false);},P.swap/2);
    }
    measure(c){const max=getComputedStyle(this.host).getPropertyValue('--vt-max');return {w:c.t.offsetWidth,h:c.t.offsetHeight,max};}
    fit(c,first){
      const {w,h}=this.measure(c),tv=this.ctx==='tv',r=Math.min(h/2,tv?48:26);
      const el=c.el;
      if(first){
        el.style.width=w+'px';el.style.height=h+'px';el.style.borderRadius=r+'px';
        const kf=reduced()?[{opacity:0},{opacity:1}]:[{width:(tv?200:96)+'px',height:(tv?60:30)+'px',borderRadius:(tv?30:15)+'px',opacity:.2},{width:w+'px',height:h+'px',borderRadius:r+'px',opacity:1}];
        c.anim=el.animate(kf,{duration:reduced()?150:240,easing:'cubic-bezier(.3,.9,.3,1.05)'});
        c.t.animate([{opacity:0},{opacity:0,offset:.35},{opacity:1}],{duration:reduced()?150:240});
      }else{el.style.width=w+'px';el.style.height=h+'px';el.style.borderRadius=r+'px';}
      if(tv)this.frame.classList.add('vt-island-open');
    }
    enter(c){
      const rm=reduced(),kf=rm?[{opacity:0},{opacity:1}]:this.variant==='a'?[{opacity:0,transform:'translateY(-10px) scale(.94)'},{opacity:1,transform:'none'}]:[{opacity:0,transform:'translateY(-115%)'},{opacity:1,transform:'none'}];
      c.anim=c.el.animate(kf,{duration:rm?150:P.enter,easing:EASE});
    }
    pulse(c){if(reduced())return;(this.variant==='c'?c.el:c.t).animate([{transform:'scale(1)'},{transform:'scale(1.045)'},{transform:'scale(1)'}],{duration:180,easing:'ease-out'});}
    restart(c){
      clearTimeout(c.timer);c.total=this.duration(c);c.remaining=c.total;
      const bar=c.t.querySelector('.vt-timer');c.t.classList.toggle('timed',!!c.total&&!!c.action||c.type==='error');
      bar.classList.remove('run');void bar.offsetWidth;c.t.style.setProperty('--vt-dur',c.total+'ms');if(c.total)bar.classList.add('run');
      if(c.total&&!c.paused)this.arm(c);
    }
    arm(c){clearTimeout(c.timer);c.started=performance.now();c.timer=setTimeout(()=>this.dismiss(c),c.remaining);}
    pause(c){if(c.paused)return;c.paused=true;c.el.classList.add('vt-paused');if(c.total){clearTimeout(c.timer);c.remaining=Math.max(600,c.remaining-(performance.now()-c.started));}}
    resume(c){if(!c.paused)return;c.paused=false;c.el.classList.remove('vt-paused');if(c.total&&!c.leaving)this.arm(c);}
    bind(c){
      const el=c.el;let y0=null,dy=0,moved=false;
      // Hover / focus pauses the timer (WCAG 2.2.1); tap closes; swipe up closes.
      el.addEventListener('pointerenter',e=>{if(e.pointerType==='mouse')this.pause(c);});
      el.addEventListener('pointerleave',e=>{if(e.pointerType==='mouse'&&y0===null)this.resume(c);});
      el.addEventListener('focusin',()=>this.pause(c));el.addEventListener('focusout',()=>this.resume(c));
      el.addEventListener('keydown',e=>{if(e.key==='Escape'){e.stopPropagation();this.dismiss(c);}});
      el.addEventListener('pointerdown',e=>{if(e.target.closest('.vt-action'))return;y0=e.clientY;dy=0;moved=false;el.setPointerCapture(e.pointerId);this.pause(c);});
      el.addEventListener('pointermove',e=>{if(y0===null)return;const scale=this.ctx==='tv'?1/.45:1;dy=Math.min(0,(e.clientY-y0)*scale);if(Math.abs(dy)>6)moved=true;if(moved&&!reduced())el.style.transform=`translateY(${dy}px)`;});
      const up=()=>{if(y0===null)return;y0=null;if(dy<-18)this.dismiss(c,'up');else if(!moved)this.dismiss(c,'tap');else{el.style.transform='';this.resume(c);}};
      el.addEventListener('pointerup',up);el.addEventListener('pointercancel',()=>{y0=null;el.style.transform='';this.resume(c);});
    }
    dismiss(c,how){
      if(c.leaving)return;c.leaving=true;clearTimeout(c.timer);c.anim?.cancel();
      const rm=reduced(),from=c.el.style.transform||'none',tv=this.ctx==='tv';
      let kf;
      if(rm)kf=[{opacity:1},{opacity:0}];
      else if(this.variant==='c')kf=[{width:c.el.style.width,height:c.el.style.height,opacity:1,transform:from},{width:(tv?200:96)+'px',height:(tv?60:30)+'px',opacity:0,transform:from}];
      else if(this.variant==='b')kf=[{transform:from,opacity:1},{transform:'translateY(-115%)',opacity:.4}];
      else kf=[{transform:from,opacity:1},{transform:how==='up'?'translateY(-28px)':'translateY(-8px) scale(.96)',opacity:0}];
      c.anim=c.el.animate(kf,{duration:rm?120:P.exit,easing:'ease-in',fill:'forwards'});
      c.anim.onfinish=()=>{c.el.remove();if(this.cur===c){this.cur=null;this.frame.classList.remove('vt-island-open');}};
    }
  }

  /* ---------- device backdrops ---------- */
  const phone=()=>`<div class="vt-screen"><div class="vt-hero"><img src="assets/hero-reference.jpg" alt=""></div>
    <div class="vt-status"><span>9:41</span><span>${icon('signal')} 5G <b>100</b></span></div>
    <div class="vt-top"><span class="vt-pill">Emby ${icon('down')}</span><span class="vt-sp"></span><span class="vt-round">${icon('search')}</span><span class="vt-round">${icon('more')}</span></div>
    <div class="vt-copy"><small>SPRING OF THE BLADE</small><h4>一瓯春</h4><p>2026 · 剧情 · 家庭 · ★ 9.5</p><div class="vt-btns"><span class="vt-play">${icon('play')}继续观看 第 7 集</span><button class="vt-fav" data-fav aria-pressed="false" aria-label="收藏">${icon('heart')}</button></div></div>
    <div class="vt-sec"><h5>继续观看</h5><div class="vt-thumbs"><img src="assets/continue-reference.jpg" alt=""><img src="assets/continue-second.jpg" alt=""></div></div>
    <div class="vt-tabbar"><span class="on">${icon('home')}首页</span><span>${icon('library')}搜索</span><span>${icon('together')}一起看</span><span>${icon('settings')}设置</span></div><div class="vt-homebar"></div></div>`;
  const land=()=>`<div class="vt-screen"><div class="vt-video" title="点画面切换顶栏 HUD"></div><div class="vt-hud">
    <div class="vt-hud-top">${icon('back')}<span>星际穿越 <small>· 1080P</small></span><span class="vt-sp"></span>${icon('danmaku')}${icon('cast')}${icon('more')}</div>
    <div class="vt-hud-bot"><div class="vt-bar"><i></i></div><div>${icon('play')}${icon('forward')}<span>1:02:14 / 2:49:03</span><span class="vt-sp" style="flex:1"></span><span>倍速</span><span>字幕</span><span>选集</span></div></div></div></div>`;
  const tv=()=>`<div class="vt-screen"><div class="vt-tvbg"></div>
    <div class="vt-tvnav"><span class="on">${icon('home')}首页</span><span>${icon('library')}搜索</span><span>${icon('together')}一起看</span><span>${icon('settings')}设置</span></div>
    <div class="vt-tvcopy"><small>INTERSTELLAR</small><h4>星际穿越</h4><p>2014 · 科幻 · 剧情 · ★ 9.4<br>剩余 1 小时 42 分钟</p><div class="vt-tvbtns"><span class="pri">${icon('play')}继续观看</span><span>查看详情</span><button class="vt-fav" data-fav aria-pressed="false" aria-label="收藏" tabindex="-1">${icon('heart')}</button></div></div>
    <div class="vt-tvrow"><img src="assets/continue-reference.jpg" alt=""><img src="assets/continue-second.jpg" alt=""><img src="assets/interstellar-backdrop.jpg" alt=""></div></div>`;

  const LONG='无法播放《星际穿越》：服务器“家里的 Emby”返回的 HEVC Main10 / 杜比视界 Profile 5 视频，当前设备无法硬解，软解性能也不足。请在设置中切换播放内核，或选择其他版本后再试。';
  const DEMOS={
    success:h=>h.show({type:'success',text:'已加入稍后观看'}),
    info:h=>h.show({type:'info',text:'字幕已切换为 简体中文'}),
    error:h=>h.show({type:'error',text:'无法连接到“家里的 Emby”',action:{label:'重试',run:()=>{const t=h.show({type:'loading',text:'正在重新连接…'});setTimeout(()=>t.update({type:'success',text:'已重新连接'}),1200);}}}),
    undo:h=>h.show({type:'info',text:'已从继续观看中移除《一瓯春》',action:{label:'撤销',run:()=>h.show({type:'success',text:'已恢复到继续观看'})}}),
    loading:h=>{
      const fav=h.frame.querySelector('[data-fav]');if(fav?.getAttribute('aria-busy')==='true')return;
      const next=!h.fav;let t=null,done=false;fav?.setAttribute('aria-busy','true');
      // Inline busy state first; the toast only joins if the request takes longer than loadingDelay.
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
      <div class="vt-col"><div class="vt-frame vt-land vt-force-dark hud-on" data-ctx="land">${land()}</div><div class="vt-cap">手机横屏播放器 · 844 × 390 · 点画面切换顶栏 HUD，提示条自动避让（视频 HUD 始终深色）</div>
      <div class="vt-frame vt-tvwrap" data-ctx="tv">${tv()}</div><div class="vt-cap">TV · 1920 × 1080 按 0.45 缩放 · 标题安全区 5% · 正文 28px · 不获取焦点</div></div>`;
    hosts[v]=[...stage.querySelectorAll('.vt-frame')].map(f=>new Host(f,v,f.dataset.ctx));
    stage.querySelectorAll('.vt-video').forEach(n=>n.addEventListener('click',()=>n.closest('.vt-land').classList.toggle('hud-on')));
    bar.innerHTML=DEMO_LABELS.map(([k,l,c])=>`<button type="button" data-demo="${k}"><i style="background:${c}"></i>${l}</button>`).join('');
    bar.addEventListener('click',e=>{const b=e.target.closest('[data-demo]');if(b)hosts[v].forEach(h=>DEMOS[b.dataset.demo](h));});
  });

  // Parameters panel
  document.querySelectorAll('[data-param]').forEach(inp=>{inp.value=P[inp.dataset.param];inp.addEventListener('change',()=>{const n=Number(inp.value);if(Number.isFinite(n)&&n>=0)P[inp.dataset.param]=n;else inp.value=P[inp.dataset.param];});});
  const rm=document.querySelector('[data-reduce]');rm?.addEventListener('change',()=>document.body.classList.toggle('vt-reduce',rm.checked));
  const hud=document.querySelector('[data-hud]');hud?.addEventListener('change',()=>document.querySelectorAll('.vt-land').forEach(n=>n.classList.toggle('hud-on',hud.checked)));
})();
