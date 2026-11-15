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
  // Options are listed directly in the player drawer: two-line rows (name + codec/channels/rate), one tap applies.
  function group(root,kind) {
    const state=get(root),opts=list(root,kind),busy=!!state.pending;
    const unsupported=kind==='secondary'&&state.scene==='single';
    const body=unsupported?'<p class="track-empty"><b>当前核心不支持</b><small>次字幕选择不可用</small></p>':!opts.length?'<p class="track-empty"><b>没有可用音轨</b><small>此媒体没有可选择的音轨</small></p>':
      `<div class="track-list" role="listbox" aria-label="${names[kind]}" aria-busy="${state.pending===kind}">${opts.map(t=>{const on=state[kind]===t.id,wait=state.pending===kind&&state.target===t.id;return `<button class="track-option" role="option" aria-selected="${on}" data-track-kind="${kind}" data-track-id="${t.id}" ${t.disabled||busy?'disabled':''}><span><b>${escape(t.label)}</b><small>${escape(t.subtitle)}</small></span>${wait?'<span class="track-spinner" aria-hidden="true"></span>':on?UI.icon('check'):''}</button>`;}).join('')}</div>`;
    return `<div class="track-field-label">${names[kind]}</div>${body}`;
  }
  function markup(root,kind) {
    const s=get(root);const fields=kind==='audio'?group(root,'audio'):group(root,'primary')+group(root,'secondary');
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
  function choose(root,kind,next) {
    const state=get(root);
    if(state.pending||!list(root,kind).some(t=>t.id===next&&!t.disabled)||state[kind]===next)return;
    state.pending=kind;state.target=next;state.error='';refresh(root);
    // Keep focus inside the drawer while busy. No completion callback steals it.
    const status=root.querySelector('.track-status');status?.setAttribute('tabindex','-1');status?.focus({preventScroll:true});
    setTimeout(()=>{
      if(state.scene==='failure')state.error='切换失败，已保留原来的选择。请重试。';
      else if(list(root,kind).some(t=>t.id===next&&!t.disabled)) {state[kind]=next;if(kind==='primary'&&(next==='off'||next===state.secondary))state.secondary='off';store(root);}
      else state.error='轨道已不可用，已保留原来的选择。';
      const restore=document.activeElement===status;
      state.pending=null;state.target=null;refresh(root);
      if(restore&&!root.querySelector('.modal-shade,.cast-overlay:not([hidden])'))root.querySelector(`[data-track-kind="${kind}"][aria-selected="true"]:not(:disabled)`)?.focus({preventScroll:true});
      if(state.error)UI.toast(root,state.error,{type:'error',action:{label:'重试',run:()=>choose(root,kind,next)}});
    },state.scene==='slow'?1400:360);
  }
  function bind(root,container){container.querySelectorAll('[data-track-id]').forEach(button=>button.onclick=()=>choose(root,button.dataset.trackKind,button.dataset.trackId));}
  function review(root) {
    if(root.id!=='p1')return;const box=document.createElement('aside');box.className='track-review';
    box.innerHTML='<strong>验收场景 · 音轨与字幕（只影响第一个播放器）</strong>'+[['normal','正常'],['empty','无音轨'],['single','不支持次字幕'],['slow','切换中'],['failure','切换失败']].map(([id,label])=>`<button data-track-scene="${id}">${label}</button>`).join('')+'<span>360 / 1400 ms 为设计模拟；不调用播放核心。</span>';
    root.parentElement.append(box);
    const mark=()=>box.querySelectorAll('button').forEach(b=>{b.classList.toggle('active',b.dataset.trackScene===get(root).scene);b.setAttribute('aria-pressed',String(b.classList.contains('active')));});
    box.querySelectorAll('button').forEach(b=>b.onclick=()=>{get(root).scene=b.dataset.trackScene;get(root).error='';refresh(root);mark();root.dispatchEvent(new CustomEvent('tracksreview',{detail:get(root).scene==='empty'?'音频':'字幕'}));});mark();
  }
  window.FinalUI={trap};window.PlayerTracks={get,markup,bind,refresh,review};
})();
