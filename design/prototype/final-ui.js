/* Final baseline interaction model. Track changes are local simulations, never player calls. */
(() => {
  const states = new WeakMap();
  const escape = value => String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const audio = [{id:'a-zh',label:'普通话',subtitle:'AAC · 2.0 声道 · 48 kHz'}, {id:'a-ja',label:'日语',subtitle:'E-AC-3 · 5.1 声道 · 48 kHz'}, {id:'a-commentary',label:'导演解说 · 原声',subtitle:'English · AAC · 2.0 声道'}];
  const subtitles = [{id:'off',label:'关闭字幕',subtitle:'不显示这条字幕'}, {id:'s-zh',label:'简体中文',subtitle:'内嵌 · ASS · 中文'}, {id:'s-tw',label:'繁體中文',subtitle:'内嵌 · SRT · 中文'}, {id:'s-en',label:'English',subtitle:'外部 · SRT · English'}];
  const names = {audio:'音轨',primary:'主字幕',secondary:'次字幕'};
  function get(root) {
    if (!states.has(root)) {
      let saved = {}; try { saved = JSON.parse(localStorage.getItem('velo-final-tracks-'+root.id)||'{}'); } catch {}
      const state = {audio:'a-zh',primary:'s-zh',secondary:'off',scene:new URLSearchParams(location.search).get('tracks')||'normal',pending:null,error:''};
      for (const kind of Object.keys(names)) if ((kind==='audio'?audio:subtitles).some(t=>t.id===saved[kind])) state[kind]=saved[kind];
      if(state.primary==='off'||state.primary===state.secondary)state.secondary='off';
      states.set(root,state);
    }
    return states.get(root);
  }
  function store(root) { const {audio,primary,secondary}=get(root);try{localStorage.setItem('velo-final-tracks-'+root.id,JSON.stringify({audio,primary,secondary}));}catch{} }
  function list(root,kind) { const s=get(root); if(kind==='audio')return s.scene==='empty'?[]:audio;return subtitles.map(t=>({...t,disabled:kind==='secondary'&&t.id!=='off'&&(t.id===s.primary||s.primary==='off')})); }
  function field(root,kind) {
    const state=get(root), current=list(root,kind).find(t=>t.id===state[kind]);
    const disabled=!!state.pending||!list(root,kind).length||(kind==='secondary'&&(state.scene==='single'||state.primary==='off'));
    const title=kind==='audio'&&!current?'没有可用音轨':kind==='secondary'&&state.scene==='single'?'当前核心不支持':current?.label||'选择字幕';
    const sub=kind==='audio'&&!current?'此媒体没有可选择的音轨':kind==='secondary'&&state.scene==='single'?'次字幕选择不可用':current?.subtitle||'';
    return `<label class="track-field-label" for="${root.id}-${kind}">${names[kind]}</label><button id="${root.id}-${kind}" class="track-field" data-track-field="${kind}" aria-haspopup="listbox" aria-expanded="false" aria-busy="${state.pending===kind}" ${disabled?'disabled':''}><span><b>${escape(title)}</b><small>${escape(sub)}</small></span>${state.pending===kind?'<span class="track-spinner" aria-hidden="true"></span>':UI.icon('down')}</button>`;
  }
  function markup(root,kind) {
    const s=get(root);const fields=kind==='audio'?field(root,'audio'):field(root,'primary')+field(root,'secondary');
    return `<div class="track-fields" data-track-group="${kind}">${fields}<p class="track-status ${s.error?'error':''}" role="status">${escape(s.error||(s.pending?'正在切换…':kind==='audio'?'按当前播放选择显示音轨。':'主字幕关闭时，同时关闭次字幕。'))}</p></div>`;
  }
  function refresh(root) {
    root.querySelectorAll('.track-fields').forEach(box=>{const kind=box.dataset.trackGroup;box.outerHTML=markup(root,kind);});
    bind(root,root);
    root.querySelectorAll('[data-act="subs"]').forEach(button=>{const s=get(root),label=subtitles.find(t=>t.id===s.primary)?.label||'字幕';button.innerHTML=UI.icon('subtitles')+escape(label==='关闭字幕'?'字幕关闭':label);});
  }
  function trap(panel,close) {
    panel.addEventListener('keydown',e=>{
      if(e.key==='Escape'){e.preventDefault();e.stopPropagation();close();return;}
      if(!['Tab','ArrowDown','ArrowUp','Home','End'].includes(e.key))return;
      const nodes=[...panel.querySelectorAll('button:not(:disabled),a[href],input:not(:disabled),select:not(:disabled)')].filter(n=>n.getClientRects().length);
      if(!nodes.length)return;const i=nodes.indexOf(document.activeElement);
      if(e.key==='Tab'){if((e.shiftKey&&i<=0)||(!e.shiftKey&&i===nodes.length-1)){e.preventDefault();(e.shiftKey?nodes.at(-1):nodes[0]).focus();}return;}
      if(/INPUT|SELECT/.test(e.target.tagName))return;
      e.preventDefault();e.stopPropagation();nodes[e.key==='Home'?0:e.key==='End'?nodes.length-1:(i+(e.key==='ArrowDown'?1:-1)+nodes.length)%nodes.length].focus();
    });
  }
  function menu(root,anchor,kind) {
    const state=get(root);if(state.pending||anchor.disabled)return;
    root.querySelector('.track-menu-layer')?.remove();anchor.setAttribute('aria-expanded','true');
    const layer=document.createElement('div');layer.className='track-menu-layer';
    const options=list(root,kind);
    layer.innerHTML=`<section class="track-menu" role="dialog" aria-modal="true" aria-label="选择${names[kind]}"><div class="track-menu-heading"><span>选择${names[kind]}</span><button data-track-close aria-label="关闭">${UI.icon('close')}</button></div><div role="listbox" aria-label="${names[kind]}">${options.map(t=>`<button class="track-option" role="option" aria-selected="${state[kind]===t.id}" data-track-id="${t.id}" ${t.disabled?'disabled':''}><span><b>${escape(t.label)}</b><small>${escape(t.subtitle)}</small></span>${state[kind]===t.id?UI.icon('check'):''}</button>`).join('')}</div></section>`;
    const close=(focus=true)=>{layer.remove();anchor.setAttribute('aria-expanded','false');if(focus)(root.querySelector(`[data-track-field="${kind}"]`)||anchor)?.focus({preventScroll:true});};
    root.append(layer);const panel=layer.firstElementChild;
    // Anchor only when the complete option list fits beside the field. Small screens use a centered dialog.
    const r=root.getBoundingClientRect(),a=anchor.getBoundingClientRect(),h=panel.offsetHeight,w=Math.min(320,root.clientWidth-32),bottom=a.bottom-r.top-root.clientTop+8,top=a.top-r.top-root.clientTop-h-8;
    if(root.clientWidth>=620&&(bottom+h<root.clientHeight-16||top>=16)){
      panel.classList.add('anchored');panel.style.width=w+'px';panel.style.left=Math.max(16,Math.min(root.clientWidth-w-16,a.left-r.left-root.clientLeft))+'px';panel.style.top=(bottom+h<root.clientHeight-16?bottom:top)+'px';
    }
    layer.onclick=e=>{if(e.target===layer||e.target.closest('[data-track-close]'))close();};trap(panel,close);
    panel.querySelector('[aria-selected="true"]:not(:disabled)')?.focus({preventScroll:true});
    panel.querySelectorAll('[data-track-id]').forEach(button=>button.onclick=()=>{
      if(state.pending||button.disabled)return;const next=button.dataset.trackId;if(!list(root,kind).some(t=>t.id===next&&!t.disabled))return;
      if(state[kind]===next){close();return;}close(false);state.pending=kind;state.error='';refresh(root);
      // Keep focus within the stable player dialog while busy. No completion callback steals it.
      const status=root.querySelector('.track-status');status?.setAttribute('tabindex','-1');status?.focus({preventScroll:true});
      setTimeout(()=>{
        if(state.scene==='failure')state.error='切换失败，已保留原来的选择。请重试。';
        else if(list(root,kind).some(t=>t.id===next&&!t.disabled)) {state[kind]=next;if(kind==='primary'&&(next==='off'||next===state.secondary))state.secondary='off';store(root);}
        else state.error='轨道已不可用，已保留原来的选择。';
        const current=document.activeElement,restore=current===status;
        state.pending=null;refresh(root);
        if(restore&&!root.querySelector('.modal-shade,.cast-overlay:not([hidden]),.track-menu-layer'))root.querySelector(`[data-track-field="${kind}"]`)?.focus({preventScroll:true});
        if(state.error)UI.toast(root,state.error);
      },state.scene==='slow'?1400:360);
    });
  }
  function bind(root,container){container.querySelectorAll('[data-track-field]').forEach(button=>button.onclick=()=>menu(root,button,button.dataset.trackField));}
  function review(root) {
    if(root.id!=='p1')return;const box=document.createElement('aside');box.className='track-review';
    box.innerHTML='<strong>验收场景 · 音轨与字幕（只影响第一个播放器）</strong>'+[['normal','正常'],['empty','无音轨'],['single','不支持次字幕'],['slow','切换中'],['failure','切换失败']].map(([id,label])=>`<button data-track-scene="${id}">${label}</button>`).join('')+'<span>360 / 1400 ms 为设计模拟；不调用播放核心。</span>';
    root.parentElement.append(box);
    const mark=()=>box.querySelectorAll('button').forEach(b=>{b.classList.toggle('active',b.dataset.trackScene===get(root).scene);b.setAttribute('aria-pressed',String(b.classList.contains('active')));});
    box.querySelectorAll('button').forEach(b=>b.onclick=()=>{get(root).scene=b.dataset.trackScene;get(root).error='';refresh(root);mark();root.dispatchEvent(new CustomEvent('tracksreview',{detail:get(root).scene==='empty'?'音频':'字幕'}));});mark();
  }
  window.FinalUI={trap};window.PlayerTracks={get,markup,bind,refresh,review};
})();
