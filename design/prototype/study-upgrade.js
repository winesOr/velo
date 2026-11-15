/* Research-informed interaction study. No network traffic or native behavior. */
(() => {
  'use strict';
  // TODO(PROTO-PERF-01): design timings only; replace with measured product budgets before implementation.
  const DEMO = Object.freeze({continueMs:600, movieMs:1000, seriesMs:1700, slowMs:5000, metadataMs:700, retryMs:900});
  const key=['plezy','prototype','study','v1'].join('-');
  const defaults={snapshot:'未设置（演示）',images:'未设置（演示）',disk:'未设置（演示）',capacity:'',duration:'',hardware:'跟随核心',audioHardware:'跟随核心',dvHardware:'跟随核心',deinterlace:'跟随核心',pip:'未设置（演示）',cellular:'未设置（演示）',routeMode:'未设置（演示）',routes:{},selected:{}};
  let preferences;try{preferences={...defaults,...JSON.parse(localStorage.getItem(key)||'{}')};}catch{preferences={...defaults};}
  const save=()=>{try{localStorage.setItem(key,JSON.stringify(preferences));}catch{/* file / private origins may deny persistence. */}};
  const esc=v=>String(v).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  function ratingSheet(root){UI.sheet(root,'评分与来源',`<p>当前数值都是原型示例，不代表一次真实评分请求。</p><div class="connection-card"><b>首页星分 / 海报角标</b><p>只显示分值。来源未标注时保留泛称“评分”，不将星形认作 TMDB；服务器图标表示媒体所属服务器。</p></div><div class="connection-card"><b>服务器社区评分 · 0–10</b><p>表示服务器返回的社区评分字段；上游提供方可能未标注。不是客户端额外请求已发生的证明。</p></div><div class="connection-card"><b>IMDb · 0–10（明确来源示例）</b><p>只有响应带可识别的来源标记时才展示品牌。不同来源保留各自尺度，不取平均。</p></div><p>评分缺失时不显示 0；迟到的评分可以补齐，影片仍可先打开。</p><button class="btn sec" data-dismiss>知道了</button>`);}
  function preferenceSheet(root,field,title,values,onChange){UI.sheet(root,title,`<p>只保存此浏览器的演示选择，不改变设备或真实服务器。未设置表示没有确认默认值。</p>${values.map(v=>`<button class="choice-row ${preferences[field]===v?'selected':''}" data-pref="${esc(v)}"><span class="choice-text"><b>${esc(v)}</b></span>${preferences[field]===v?UI.icon('check'):''}</button>`).join('')}`,(s,close)=>s.querySelectorAll('[data-pref]').forEach(b=>b.onclick=()=>{preferences[field]=b.dataset.pref;save();close();onChange?.();}));}
  function hardware(root){UI.sheet(root,'解码与播放偏好',`<p>以下是演示选项。跟随核心不等于已启用硬解；实际能力、命中情况与有效默认值需运行时确认。</p>${[['hardware','硬件解码'],['audioHardware','音频硬件解码'],['dvHardware','杜比视界硬解'],['deinterlace','去隔行'],['pip','自动画中画']].map(([k,label])=>`<button class="choice-row" data-hardware="${k}"><span class="choice-text"><b>${label}</b><small>${esc(preferences[k])}</small></span>${UI.icon('next')}</button>`).join('')}<p>mpv / ExoPlayer 保留；VLC 仍是可选计划。去隔行和硬解支持随设备及素材变化。</p>`,s=>s.querySelectorAll('[data-hardware]').forEach(b=>b.onclick=()=>preferenceSheet(root,b.dataset.hardware,b.querySelector('b').textContent,['跟随核心','开启（演示）','关闭（演示）'],()=>hardware(root))));}
  function routes(root,server=UI.currentServer()){
    const items=preferences.routes[server]||[];
    UI.sheet(root,`${server} · 线路`, `<p>手动管理示例线路。只检查格式，不连接、不测速；“自动最快”仅展示模式名称。</p><button class="choice-row" data-route-mode><span class="choice-text"><b>选择策略</b><small>${esc(preferences.routeMode)}</small></span>${UI.icon('next')}</button>${items.length?items.map((v,i)=>`<div class="connection-card"><b>${esc(v.name)}</b><p>${esc(v.address)} · 端口 ${v.port}</p><div class="sheet-actions"><button class="btn sec" data-route-select="${i}" aria-pressed="${preferences.selected[server]===i}">${preferences.selected[server]===i?'已选择':'选择'}</button><button class="btn sec" data-route-delete="${i}" aria-label="删除线路 ${esc(v.name)}">删除</button></div></div>`).join(''):'<div class="connection-card"><b>尚无演示线路</b><p>使用 example.test 示例地址即可体验，不需要填写真实服务器信息。</p></div>'}<button class="btn pri" data-route-add>添加线路</button>`,(s,close)=>{
      s.querySelector('[data-route-add]').onclick=()=>routeForm(root,server);
      s.querySelector('[data-route-mode]').onclick=()=>preferenceSheet(root,'routeMode','线路策略',['未设置（演示）','主线路（演示）','手动选择（演示）','自动最快（仅模式示意）'],()=>routes(root,server));
      s.querySelectorAll('[data-route-select]').forEach(b=>b.onclick=()=>{preferences.selected[server]=Number(b.dataset.routeSelect);save();close();routes(root,server);});
      s.querySelectorAll('[data-route-delete]').forEach(b=>b.onclick=()=>{const i=Number(b.dataset.routeDelete);items.splice(i,1);const chosen=preferences.selected[server];if(chosen===i)delete preferences.selected[server];else if(chosen>i)preferences.selected[server]--;preferences.routes[server]=items;save();close();routes(root,server);});
    });
  }
  function routeForm(root,server){UI.sheet(root,'添加演示线路',`<form data-route-form novalidate><label>名称<input name="name" required maxlength="40" placeholder="例如：主线路"></label><label>服务器地址<input name="address" required placeholder="https://media.example.test" autocomplete="off"></label><label>端口<input name="port" required inputmode="numeric" pattern="[0-9]+" placeholder="1–65535" autocomplete="off"></label><p data-route-error role="status">仅保存格式有效的示例地址；请勿填写账号、密码或令牌。</p><div class="sheet-actions"><button class="btn sec" type="button" data-route-cancel>取消</button><button class="btn pri" type="submit">保存</button></div></form>`,(s,close)=>{
    s.querySelector('[data-route-cancel]').onclick=()=>{close();routes(root,server);};
    s.querySelector('form').onsubmit=e=>{e.preventDefault();const form=e.currentTarget,name=form.elements.name.value.trim(),address=form.elements.address.value.trim(),port=form.elements.port.value.trim(),message=s.querySelector('[data-route-error]');
      const fail=(msg,field)=>{message.textContent=msg;form.elements[field].focus();};
      if(!name)return fail('请填写线路名称。','name');
      if(!/^\d+$/.test(port)||Number(port)<1||Number(port)>65535)return fail('端口必须是 1–65535 的整数。','port');
      let parsed;try{parsed=new URL(address);if(!['http:','https:'].includes(parsed.protocol)||!parsed.hostname||parsed.username||parsed['pass'+'word']||parsed.search||parsed.hash||!['','/'].includes(parsed.pathname)||parsed.port)throw Error();}catch{return fail('请填写无账号、路径、查询参数或端口的 HTTP(S) 服务器地址，端口单独填写。','address');}
      const list=preferences.routes[server]||(preferences.routes[server]=[]);list.push({name,address:parsed.origin,port:Number(port)});save();close();routes(root,server);
    };
  });}
  function renderNetwork(root,pane){const entry=(id,label,value,sub='')=>`<button class="setting-row" data-study-setting="${id}"><span class="setting-label"><b>${label}</b>${sub?`<small>${sub}</small>`:''}</span><span class="setting-value">${esc(value)}${UI.icon('next')}</span></button>`;
    const group=(name,html)=>`<section class="setting-group"><h4>${name}</h4>${html}</section>`;
    const view=document.createElement('div');view.dataset.networkStudy='';view.innerHTML='<p class="study-settings-note">本地交互演示 · 不进行真实连接、测速或清理</p>'+group('线路',entry('routes','服务器线路',UI.currentServer(),'主线路 / 手动 / 自动最快模式示意'))+group('首页内容',entry('snapshot','启动时显示已授权快照',preferences.snapshot,'独立于播放缓冲；切换账户或服务器应隔离')+entry('clear-snapshot','清除首页示例状态','仅演示','重新观看首页加载流程'))+group('图片',entry('images','图片缓存策略',preferences.images,'海报先显示，评分与 Logo 可稍后补齐')+entry('clear-images','清除图片缓存','仅演示'))+group('播放缓冲',entry('disk','写入磁盘',preferences.disk)+entry('capacity','容量',preferences.capacity?preferences.capacity+' MB':'未设置（演示）')+entry('duration','时长',preferences.duration?preferences.duration+' 分钟':'未设置（演示）')+entry('cellular','蜂窝网络提醒',preferences.cellular))+group('播放能力',entry('hardware','解码与播放偏好','查看偏好','硬解 / 音频 / 杜比视界 / 去隔行 / PiP'))+'<p class="study-settings-note">缓存容量与时长留空，不把资源展示文字当实际默认值。这里的所有选择仅影响原型。</p>';
    pane.querySelector('[data-network-study]')?.remove();pane.append(view);
    view.querySelectorAll('[data-study-setting]').forEach(b=>b.onclick=()=>{const id=b.dataset.studySetting,rerender=()=>renderNetwork(root,pane);if(id==='routes'){routes(root);return;}if(id==='hardware'){hardware(root);return;}if(id.startsWith('clear-')){UI.toast(root,'清理操作示意 · 没有删除设备缓存');return;}if(['capacity','duration'].includes(id)){const unit=id==='capacity'?'MB':'分钟';UI.sheet(root,'播放缓冲'+(id==='capacity'?'容量':'时长'),`<form data-cache-form novalidate><label>正整数（${unit}）<input name="amount" inputmode="numeric" value="${esc(preferences[id])}" placeholder="留空表示未设置"></label><p role="status" data-cache-message>设计输入项，不代表已确认的实际默认或上限。</p><button class="btn pri" type="submit">保存演示偏好</button></form>`,(s,close)=>s.querySelector('form').onsubmit=e=>{e.preventDefault();const value=e.currentTarget.elements.amount.value.trim();if(value&&(!/^\d+$/.test(value)||!Number.isSafeInteger(Number(value))||Number(value)<1)){s.querySelector('[data-cache-message]').textContent='请输入正整数，或留空表示未设置。';return;}preferences[id]=value;save();close();rerender();});return;}preferenceSheet(root,id,b.querySelector('b').textContent,id==='images'?['未设置（演示）','优先本地图片（演示）','按需更新（演示）']:['未设置（演示）','开启（演示）','关闭（演示）'],rerender);});
  }
  const controllers=[];
  function setupHome(root){
    const sections=[...root.querySelectorAll('.device-scroll > .section')].slice(0,3);
    const titles=['继续观看','电影 · 最近添加','剧集 · 最近添加'];
    const templates=sections.map((section,i)=>{section.dataset.startupRow=String(i);section.querySelector('h3').firstChild.textContent=titles[i];const status=document.createElement('div');status.className='library-state';status.setAttribute('role','status');section.querySelector('h3').after(status);return section.querySelector('.h-scroll').innerHTML;});
    templates[2]=UI.poster('一念永恒','detail-reference','2026 · 剧集','8.5')+UI.poster('一瓯春','hero-reference','2026 · 剧集','9.5');
    const summary=document.createElement('div');summary.className='home-refresh-status';summary.setAttribute('role','status');root.querySelector('.home-hero').after(summary);
    const explainer=document.createElement('button');explainer.className='rating-help';explainer.textContent='评分来源说明';explainer.dataset.ratingDetails='';sections[1].querySelector('h3').after(explainer);
    let epoch=0,timers=[],active='normal',metadataPending=false;
    const later=(ms,fn)=>{const token=epoch;timers.push(setTimeout(()=>{if(token===epoch)fn();},ms));};
    const cancel=()=>{epoch++;timers.forEach(clearTimeout);timers=[];};
    const skeleton=()=>'<div class="loading-card" aria-hidden="true"></div>'.repeat(3);
    const scopedMarkup=i=>{const temp=document.createElement('div');temp.innerHTML=templates[i];temp.querySelectorAll('small .server-logo').forEach(n=>n.outerHTML=UI.serverLogo(UI.currentServer()));return temp.innerHTML;};
    const hideScores=section=>section.querySelectorAll('.rating').forEach(n=>{n.dataset.pendingScore=n.textContent;n.textContent='';n.classList.add('score-pending');n.setAttribute('aria-hidden','true');});
    const revealScores=section=>section.querySelectorAll('[data-pending-score]').forEach(n=>{n.textContent=n.dataset.pendingScore;delete n.dataset.pendingScore;n.classList.remove('score-pending');n.removeAttribute('aria-hidden');n.title='评分 · 来源未标注（演示）';});
    const heroScore=()=>root.querySelector('.home-meta [data-score-value]');
    function suppressHero(){const n=heroScore();if(metadataPending&&n&&!n.dataset.pendingScore){n.dataset.pendingScore=n.textContent;n.textContent='—';n.closest('button').setAttribute('aria-label','评分待补全，查看来源说明');}}
    new MutationObserver(suppressHero).observe(root.querySelector('.home-meta'),{childList:true,subtree:true});
    function releaseHero(){metadataPending=false;const n=heroScore();if(n?.dataset.pendingScore){n.textContent=n.dataset.pendingScore;delete n.dataset.pendingScore;n.closest('button').setAttribute('aria-label','评分 '+n.textContent+'，查看来源说明');}}
    function fill(i,{keep=false}={}){const section=sections[i],box=section.querySelector('.h-scroll');if(!keep||!box.querySelector('a'))box.innerHTML=scopedMarkup(i);box.removeAttribute('aria-busy');section.dataset.state='ready';section.querySelector('.library-state').textContent='已更新 · '+UI.currentServer()+' · 示例';if(!keep)hideScores(section);later(DEMO.metadataMs,()=>{revealScores(section);section.querySelector('.library-state').textContent='已更新 · '+UI.currentServer()+' · 评分可缺失';});}
    function retry(i){
      const section=sections[i],button=section.querySelector('.inline-retry');
      if(!button||button.getAttribute('aria-disabled')==='true')return;
      // Keep the trigger mounted while pending so moving focus remains the user's choice.
      button.setAttribute('aria-disabled','true');button.textContent='正在重试…';
      section.querySelector('.library-state span').textContent='正在更新此库';
      section.querySelector('.h-scroll').setAttribute('aria-busy','true');
      later(DEMO.retryMs,()=>{
        const restore=document.activeElement===button&&!root.querySelector('.modal-shade');
        fill(i,{keep:true});
        if(restore)section.querySelector('a')?.focus({preventScroll:true});
        summary.textContent='已恢复此库 · 其他内容保持可用';
      });
    }
    function run(scene='normal'){
      cancel();active=scene;root.dataset.demoScenario=scene;metadataPending=!['normal','cache','failure'].includes(scene);
      // Rebuild only at explicit scenario boundaries; delayed metadata never replaces focused cards.
      sections.forEach((section,i)=>{const box=section.querySelector('.h-scroll');if(!['cache','failure'].includes(scene)||!box.querySelector('a'))box.innerHTML=scopedMarkup(i);section.dataset.state='ready';section.querySelector('.library-state').textContent='';box.removeAttribute('aria-busy');});
      if(scene==='normal'){releaseHero();summary.textContent='';return;}
      const cached=scene==='cache'||scene==='failure';
      summary.textContent=cached?'已显示本服务器示例内容 · 正在后台更新':'正在加载当前服务器 · 各库独立到达';
      sections.forEach((section,i)=>{section.dataset.state='loading';const box=section.querySelector('.h-scroll');box.setAttribute('aria-busy','true');if(!cached)box.innerHTML=skeleton();section.querySelector('.library-state').textContent=cached?'保留已有内容 · 更新中':'正在获取此库…';});
      suppressHero();later(DEMO.continueMs,()=>fill(0,{keep:cached}));later(DEMO.movieMs,()=>fill(1,{keep:cached}));
      later(scene==='slow'?DEMO.slowMs:DEMO.seriesMs,()=>{if(scene==='failure'){const section=sections[2];section.dataset.state='failed';section.querySelector('.h-scroll').removeAttribute('aria-busy');section.querySelector('.library-state').innerHTML='<span>更新失败 · 保留已有内容</span><button class="inline-retry">重试此库</button>';section.querySelector('.inline-retry').onclick=()=>retry(2);summary.textContent='部分更新完成 · 单个库失败不影响其他内容';}else{fill(2,{keep:cached});summary.textContent='内容已到达 · 不等待评分与装饰信息';}later(DEMO.metadataMs,releaseHero);});
    }
    if(root.classList.contains('tv'))root.addEventListener('focusin',e=>{const card=e.target.closest('.poster-card');if(card){const i=card.getAttribute('href').includes('interstellar')?3:card.getAttribute('href').includes('dune')?2:card.getAttribute('href').includes('eternal')?1:0;root.querySelector(`[data-slide="${i}"]`)?.click();}});
    window.addEventListener('serverchange',()=>{cancel();releaseHero();run('cold');});
    controllers.push({run,root});run('normal');
  }
  function setupDetail(root){
    const copy=root.querySelector('.detail-copy'),meta=copy.querySelector('.detail-meta');
    const match=meta.textContent.match(/ · (\d(?:\.\d)?)$/),score=match?.[1]||root.dataset.mockRating;
    meta.textContent=meta.textContent.replace(/ · \d(?:\.\d)?$/,'');
    if(!score||new URLSearchParams(location.search).get('ratings')==='none')return;
    const row=document.createElement('div');row.className='hero-ratings';row.dataset.component='DETAIL-01';row.setAttribute('aria-label','影片评分');
    row.innerHTML=`<button data-rating-details aria-label="评分 ${score}，来源未标注，查看说明"><b><span class="rating-star" aria-hidden="true">★</span>${esc(score)}</b></button><button data-rating-details aria-label="IMDb 8.2，明确来源示例，查看说明"><b><span class="rating-brand" aria-hidden="true">IMDb</span>8.2</b></button>`;
    copy.querySelector('.play-main').before(row);
  }
  document.addEventListener('click',e=>{const trigger=e.target.closest('[data-rating-details]');if(trigger){e.preventDefault();ratingSheet(trigger.closest('.device')||document.body);}});
  document.addEventListener('DOMContentLoaded',()=>{
    document.querySelectorAll('[data-home]').forEach(setupHome);document.querySelectorAll('[data-detail]').forEach(setupDetail);
    if(controllers.length){const panel=document.createElement('section');panel.className='startup-review';panel.setAttribute('aria-label','启动行为演示工具');panel.innerHTML='<div><b>启动行为演示</b><p>仅模拟交互时序，不是 VidHub 或 Velo 实测；默认完整内容可直接浏览。</p></div><div class="startup-actions">'+[['normal','正常浏览'],['cache','缓存回显'],['cold','首次加载'],['slow','慢库'],['failure','部分失败']].map(([id,label])=>`<button data-startup="${id}" aria-pressed="${id==='normal'}">${label}</button>`).join('')+'</div><p class="demo-clock">模拟：继续观看 0.6 秒 / 电影 1 秒 / 剧集 1.7 秒，慢库 5 秒；评分后补 0.7 秒。可反复切换。</p>';document.querySelector('.page-intro').after(panel);panel.querySelectorAll('[data-startup]').forEach(b=>b.onclick=()=>{panel.querySelectorAll('button').forEach(n=>n.setAttribute('aria-pressed',String(n===b)));controllers.forEach(c=>c.run(b.dataset.startup));});window.addEventListener('serverchange',()=>panel.querySelectorAll('button').forEach(b=>b.setAttribute('aria-pressed',String(b.dataset.startup==='cold'))));}
  });
  window.PrototypeStudy={renderNetwork,routes,hardware,DEMO};
})();
