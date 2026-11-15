/* Velo top notification (SHARED-03, final option A: centered frosted capsule).
   One engine for every prototype page. UI.toast(root,text,opts) delegates here.
   The toast.html study also renders the rejected options B / C with the same engine. */
(() => {
  // Durations (ms). Action toasts use `action` regardless of type; TV adds `tvExtra`. Loading never auto-dismisses.
  const P={success:2500,info:2500,error:4000,action:5000,tvExtra:1000,enter:220,exit:180,swap:120,loadingDelay:300};
  const reduced=()=>document.body.classList.contains('vt-reduce')||matchMedia('(prefers-reduced-motion: reduce)').matches;
  const EASE='cubic-bezier(.2,.8,.2,1)';
  const GLYPH={success:'<circle cx="12" cy="12" r="9"/><path d="m8 12.4 2.7 2.7L16.2 9.5"/>',info:'<circle cx="12" cy="12" r="9"/><path d="M12 11v5.4M12 7.7h.01"/>',error:'<circle cx="12" cy="12" r="9"/><path d="M12 7.4v5.6M12 16.4h.01"/>'};
  const glyph=t=>t==='loading'?'<span class="vt-spin"></span>':`<svg viewBox="0 0 24 24">${GLYPH[t]||GLYPH.info}</svg>`;
  const log=[];// visible-count samples for automated "never stacks" checks
  const ANCHORS='.toolbar,.topbar,.tvt,.app-nav,[data-toast-anchor]';
  const FLOOR={phone:50,land:14,tv:54},ZONE={phone:130,land:90,tv:240},GAP={phone:8,land:8,tv:16};
  const shown=(n,stop)=>{for(let e=n;e&&e!==stop.parentElement;e=e.parentElement){const s=getComputedStyle(e);if(s.display==='none'||s.visibility==='hidden'||Number(s.opacity)<.05||e.hidden)return false;}return n.getClientRects().length>0;};

  class Host{
    constructor(root,variant='a',ctx){
      ctx=ctx||(root.classList.contains('tv')||root.classList.contains('tvp')?'tv':root.classList.contains('land')?'land':'phone');
      Object.assign(this,{root,variant,ctx,cur:null});
      const h=document.createElement('div');h.className=`vt-host vt-${variant} vt-ctx-${ctx}`;
      if(root.classList.contains('player-device'))h.classList.add('vt-force-dark');
      h.innerHTML='<div class="vt-live" role="status" aria-live="polite" aria-atomic="true"></div><div class="vt-live" role="alert" aria-live="assertive" aria-atomic="true"></div>';
      (root.querySelector(':scope>.vt-screen')||root).append(h);[this.polite,this.alert]=h.children;this.host=h;
      this.stage=h.parentElement;
    }
    // TV toast sizes are authored in 1920×1080 units; a smaller TV preview scales them with zoom.
    zoom(){return this.ctx==='tv'?(this.stage.offsetWidth||1920)/1920:1;}
    // Option A sits 8px below the visible top bar (or HUD / TV nav); otherwise the safe-area floor.
    position(){
      if(this.variant!=='a')return;
      const z=this.zoom();this.host.style.zoom=z===1?'':String(z);
      const box=this.stage.getBoundingClientRect(),k=box.height/(this.stage.offsetHeight||box.height)||1;
      let top=FLOOR[this.ctx]*z;
      this.stage.querySelectorAll(ANCHORS).forEach(n=>{if(this.host.contains(n)||!shown(n,this.stage))return;const r=n.getBoundingClientRect(),t=(r.top-box.top)/k,b=(r.bottom-box.top)/k;if(t>=-2&&t<ZONE[this.ctx]*z&&b>0)top=Math.max(top,b+GAP[this.ctx]*z);});
      this.host.style.setProperty('--vt-top',Math.round(top/z)+'px');
    }
    visible(){return this.host.querySelectorAll('.vt-root').length;}
    duration(o){if(o.type==='loading')return 0;let d=o.duration??(o.action?P.action:P[o.type]??P.info);if(this.ctx==='tv')d+=P.tvExtra;return d;}
    show(o){
      o={type:'info',...o};
      const key=o.key||o.text,c=this.cur;
      if(c&&c.leaving){c.anim?.cancel();c.el.remove();this.cur=null;}
      const live=this.cur;this.position();
      let handle;
      if(live&&live.key===key&&live.type===o.type&&o.type!=='loading'){live.count++;this.fill(live,o);if(this.variant==='c')this.fit(live,false);this.restart(live);this.pulse(live);handle=live.handle;}
      else if(live){live.key=key;live.count=1;this.swap(live,o);this.restart(live);handle=live.handle;}
      else handle=this.create(o,key);
      log.push({scheme:this.variant,ctx:this.ctx,visible:this.visible()});
      clearInterval(this.track);this.track=setInterval(()=>{if(!this.cur){clearInterval(this.track);return;}this.position();},300);
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
      c.handle={update:n=>(n={type:'info',...n},this.cur===c&&!c.leaving?(c.key=n.key||n.text,c.count=1,this.swap(c,n),this.restart(c),c.handle):this.show(n)),dismiss:()=>this.dismiss(c),get el(){return c.el;}};
      this.cur=c;this.fill(c,o);this.place(c);this.bind(c);
      if(this.variant==='c')this.fit(c,true);else this.enter(c);
      this.restart(c);return c.handle;
    }
    place(c){const region=c.type==='error'?this.alert:this.polite;if(c.el.parentNode!==region)region.append(c.el);}
    fill(c,o){
      const {t}=c;c.type=o.type;c.action=o.action||null;t.dataset.type=o.type;
      t.querySelector('.vt-ico').innerHTML=glyph(o.type);
      t.querySelector('.vt-msg').textContent=o.text;t.title=o.text;
      const n=t.querySelector('.vt-count');n.hidden=c.count<2;n.textContent=`×${c.count}`;n.setAttribute('aria-label',`共 ${c.count} 次`);
      const old=t.querySelector('.vt-action'),a=document.createElement(this.ctx==='tv'?'span':'button');a.className='vt-action';
      if(o.action){
        // TV never moves focus to the toast: the action runs from the remote's Menu key (click also works in the prototype).
        a.innerHTML=this.ctx==='tv'?`<kbd>菜单</kbd>${o.action.label}`:o.action.label;
        if(this.ctx==='tv')a.title=`按遥控器菜单键${o.action.label}`;else a.type='button';
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
    fit(c,first){
      const w=c.t.offsetWidth,h=c.t.offsetHeight,tv=this.ctx==='tv',r=Math.min(h/2,tv?48:26),el=c.el;
      el.style.width=w+'px';el.style.height=h+'px';el.style.borderRadius=r+'px';
      if(first){
        const kf=reduced()?[{opacity:0},{opacity:1}]:[{width:(tv?200:96)+'px',height:(tv?60:30)+'px',borderRadius:(tv?30:15)+'px',opacity:.2},{width:w+'px',height:h+'px',borderRadius:r+'px',opacity:1}];
        c.anim=el.animate(kf,{duration:reduced()?150:240,easing:'cubic-bezier(.3,.9,.3,1.05)'});
        c.t.animate([{opacity:0},{opacity:0,offset:.35},{opacity:1}],{duration:reduced()?150:240});
      }
      if(tv)this.root.classList.add('vt-island-open');
    }
    enter(c){
      const rm=reduced(),kf=rm?[{opacity:0},{opacity:1}]:this.variant==='a'?[{opacity:0,transform:'translateY(-10px) scale(.94)'},{opacity:1,transform:'none'}]:[{opacity:0,transform:'translateY(-115%)'},{opacity:1,transform:'none'}];
      c.anim=c.el.animate(kf,{duration:rm?150:P.enter,easing:EASE});
    }
    pulse(c){if(reduced())return;(this.variant==='c'?c.el:c.t).animate([{transform:'scale(1)'},{transform:'scale(1.045)'},{transform:'scale(1)'}],{duration:180,easing:'ease-out'});}
    restart(c){
      clearTimeout(c.timer);c.total=this.duration(c);c.remaining=c.total;
      const bar=c.t.querySelector('.vt-timer');c.t.classList.toggle('timed',!!c.total&&(!!c.action||c.type==='error'));
      bar.classList.remove('run');void bar.offsetWidth;c.t.style.setProperty('--vt-dur',c.total+'ms');if(c.total)bar.classList.add('run');
      if(c.total&&!c.paused)this.arm(c);
    }
    arm(c){clearTimeout(c.timer);c.started=performance.now();c.timer=setTimeout(()=>this.dismiss(c),c.remaining);}
    pause(c){if(c.paused)return;c.paused=true;c.el.classList.add('vt-paused');if(c.total){clearTimeout(c.timer);c.remaining=Math.max(600,c.remaining-(performance.now()-c.started));}}
    resume(c){if(!c.paused)return;c.paused=false;c.el.classList.remove('vt-paused');if(c.total&&!c.leaving)this.arm(c);}
    bind(c){
      const el=c.el;let y0=null,dy=0,moved=false;
      // Hover / focus pauses the timer (WCAG 2.2.1); tap closes; swipe up closes; Esc closes when focus is inside.
      el.addEventListener('pointerenter',e=>{if(e.pointerType==='mouse')this.pause(c);});
      el.addEventListener('pointerleave',e=>{if(e.pointerType==='mouse'&&y0===null)this.resume(c);});
      el.addEventListener('focusin',()=>this.pause(c));el.addEventListener('focusout',()=>this.resume(c));
      el.addEventListener('keydown',e=>{if(e.key==='Escape'){e.stopPropagation();this.dismiss(c);}});
      el.addEventListener('pointerdown',e=>{if(e.target.closest('.vt-action'))return;e.stopPropagation();y0=e.clientY;dy=0;moved=false;el.setPointerCapture(e.pointerId);this.pause(c);});
      el.addEventListener('pointermove',e=>{if(y0===null)return;const r=el.getBoundingClientRect(),k=r.height/(el.offsetHeight||r.height)||1;dy=Math.min(0,(e.clientY-y0)/k);if(Math.abs(e.clientY-y0)>6)moved=true;if(moved&&!reduced())el.style.transform=`translateY(${dy}px)`;});
      const up=e=>{if(y0===null)return;const raw=e.clientY-y0;y0=null;if(raw<-18)this.dismiss(c,'up');else if(!moved)this.dismiss(c,'tap');else{el.style.transform='';this.resume(c);}};
      el.addEventListener('pointerup',up);el.addEventListener('pointercancel',()=>{y0=null;el.style.transform='';this.resume(c);});
      el.addEventListener('click',e=>e.stopPropagation());
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
      c.anim.onfinish=()=>{c.el.remove();if(this.cur===c){this.cur=null;this.root.classList.remove('vt-island-open');}};
    }
  }

  const hosts=new WeakMap(),all=new Set();
  function host(root,variant='a',ctx){const k=variant+(ctx||'');let m=hosts.get(root);if(!m)hosts.set(root,m={});if(!m[k]){m[k]=new Host(root,variant,ctx);all.add(m[k]);}return m[k];}
  // Public API: show(root,{type:'success'|'info'|'error'|'loading',text,action:{label,run},key,duration}) → {update,dismiss}
  function show(root,o){return host(root).show(o);}
  // Async helper: inline busy state first; the toast joins only if the work outlasts loadingDelay, then morphs in place.
  function pending(root,loadingText,promise,{success,error,retry}={}){
    let t=null,done=false;const timer=setTimeout(()=>{if(!done)t=show(root,{type:'loading',text:loadingText,key:'pending:'+loadingText});},P.loadingDelay);
    const finish=o=>{done=true;clearTimeout(timer);return t?t.update(o):show(root,o);};
    return Promise.resolve(promise).then(v=>{finish({type:'success',text:typeof success==='function'?success(v):success});return v;},err=>{finish({type:'error',text:typeof error==='function'?error(err):(error||'操作失败'),action:retry?{label:'重试',run:retry}:undefined});return undefined;});
  }
  // TV: the remote's Menu key runs the action of the visible toast in the focused TV surface.
  document.addEventListener('keydown',e=>{
    if(!['ContextMenu','m','M'].includes(e.key)||e.target.closest?.('input,textarea,select'))return;
    for(const h of all){if(h.ctx!=='tv'||!h.cur||!h.cur.action||h.cur.leaving)continue;if(!h.root.contains(document.activeElement)&&all.size>1&&![...all].every(x=>x===h||x.ctx!=='tv'||!x.cur?.action))continue;e.preventDefault();h.act(h.cur);break;}
  });
  window.VeloToast={P,log,Host,host,show,pending};
})();
