(() => {
  const {icon,poster,sheet,toast}=UI;
  const media=new URLSearchParams(location.search).get('media')||'eternal';
  const catalogue={eternal:{mockRating:'8.6',title:'一念永恒',image:'detail-reference',kind:'动画',year:'2026',series:true,subtitle:'Tencent Video · 动画',meta:'共 4 季 · 21 分钟 · 1080p H264'},dune:{title:'沙丘：第二部',image:'dune',kind:'科幻 · 冒险',year:'2024',series:false,subtitle:'2024 · 科幻 / 冒险 · 8.3',meta:'2 小时 47 分钟 · 4K · 杜比视界'},interstellar:{title:'星际穿越',image:'interstellar',kind:'科幻 · 剧情',year:'2014',series:false,subtitle:'2014 · 科幻 / 剧情 · 9.4',meta:'2 小时 49 分钟 · 4K · HDR10'},spirited:{title:'千与千寻',image:'spirited',kind:'动画 · 奇幻',year:'2001',series:false,subtitle:'2001 · 动画 / 奇幻 · 9.4',meta:'2 小时 5 分钟 · 1080p'},blade:{title:'银翼杀手 2049',image:'blade',kind:'科幻 · 悬疑',year:'2017',series:false,subtitle:'2017 · 科幻 / 悬疑 · 8.3',meta:'2 小时 44 分钟 · 4K · HDR10'},spring:{title:'一瓯春',image:'hero-reference',kind:'剧情 · 家庭',year:'2026',series:true,subtitle:'2026 · 剧情 / 家庭 · 9.5',meta:'共 1 季 · 45 分钟 · 1080p'}};
  const item=catalogue[media]||catalogue.eternal;
  const summary=item.series?'平凡少年踏上修行之路，在一次次奇遇中寻找属于自己的答案。热血与羁绊交织，一段新的旅程就此展开。':'当命运将熟悉的世界推向未知，一场关于选择、信念与人性的旅程缓缓展开。';
  let episodeInputSource='other';
  document.addEventListener('keydown',e=>{if(['Tab','ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(e.key))episodeInputSource='keyboard';},true);
  for(const event of ['pointerdown','touchstart','wheel'])document.addEventListener(event,()=>{episodeInputSource='pointer';},{capture:true,passive:true});
  document.querySelectorAll('[data-detail]').forEach(root=>{
    root.classList.toggle('reference-series',media==='eternal');
    // Explicit prototype fixture; this is not a server or provider response.
    root.dataset.mockRating=item.mockRating||'';
    let season=item.series&&media==='eternal'?4:1,group=0,currentEpisode=1,expanded=false;
    // Prototype seasons deliberately include a partial final group for acceptance checks.
    const episodeCount=(forSeason=season)=>media==='eternal'?({1:12,2:24,3:30,4:27}[forSeason]||12):23;
    let scrollFrame=0,episodeFocusMode=false;
    const related=poster('沙丘：第二部','dune','2024 · 电影','8.3')+poster('星际穿越','interstellar','2014 · 电影','9.4')+poster('千与千寻','spirited','2001 · 电影','9.4')+poster('银翼杀手 2049','blade','2017 · 电影','8.3');
    const info=(name,type,rows)=>`<article class="media-info"><h4>${icon(type)}${name}</h4><dl>${rows.map(([k,v])=>`<dt>${k}：</dt><dd>${v}</dd>`).join('')}</dl></article>`;
    root.innerHTML=`<div class="device-scroll"><section class="detail-hero"><div class="detail-art"></div><div class="detail-fade"></div>${UI.status()}<div class="toolbar detail-toolbar"><a href="home.html" class="icon-button" aria-label="返回首页">${icon('back')}</a><span class="spacer"></span><button class="icon-button" data-more aria-label="更多操作">${icon('more')}</button></div><div class="detail-copy"><h3 class="detail-title">${item.title}</h3><p class="detail-meta">${item.subtitle}</p><p class="detail-meta">${item.meta}</p><a href="player.html" class="btn pri play-main">${icon('play')}<span data-play-label>${item.series?'播放 第 1 集':'播放'}</span></a><div class="detail-actions"><button aria-label="收藏" aria-pressed="false" data-toggle="已加入收藏">${icon('heart')}</button><button aria-label="标记已看" aria-pressed="false" data-toggle="已标记看过">${icon('flag')}</button></div></div></section><button class="detail-versions" data-versions>${UI.serverLogo('Emby')}<span data-version-server>Emby</span><b data-version-label>${item.series?'1080p · H264':'4K · 原始画质'}</b><span>2 个版本</span>${icon('next')}</button><section class="section detail-summary-section"><p class="detail-summary"><span data-summary>${summary.slice(0,44)}…</span><button data-expand>展开</button></p></section>${item.series?'<section class="section"><h3><button class="season-select" data-season><span data-season-label>第 '+season+' 季</span>'+icon('down')+'</button><button data-all-episodes>查看全部 '+icon('next')+'</button></h3><div class="h-scroll episode-continuous" data-episodes aria-label="连续剧集列表" tabindex="0"></div><div class="episode-groups" aria-label="剧集分组"></div></section>':''}<section class="section"><h3>演员人员</h3><div class="h-scroll">${[['苏尚卿','白小纯（voice）',-15],['李诗萌','杜凌菲（voice）',-91],['郭浩然','李青候（voice）',-167],['乔诗语','周心琪（voice）',-243],['陈张太康','陈恒（voice）',-319]].map(([name,role,x])=>`<a class="cast-card" href="library.html" aria-label="查看${name}相关作品"><div class="cast-portrait" style="--actor-x:${x}px"></div><b>${name}</b><small>${role}</small></a>`).join('')}</div></section><section class="section"><h3>类型</h3><div class="genre-chips">${item.kind.split(' · ').map(s=>`<a href="library.html">${s}</a>`).join('')}</div></section><section class="section"><h3>相关影片<a href="library.html">全部 ${icon('next')}</a></h3><div class="h-scroll">${related}</div></section><section class="section"><h3>音视频字幕信息</h3><div class="media-info-scroll">${info('视频','video',[['标题',item.series?'1080p H264':'4K HEVC'],['编码',item.series?'h264':'hevc'],['分辨率',item.series?'1920 × 1080':'3840 × 2160'],['宽高比','16:9'],['帧率','25.000'],['视频范围','SDR'],['色域','bt709'],['位深度','8 bit'],['像素格式','yuv420p']])}${info('音频','audio',[['标题','AAC stereo'],['语言','普通话'],['声道布局','stereo'],['声道数','2 ch'],['采样率','48000 Hz'],['配置文件','LC'],['比特率','93 kbps'],['默认','是']])}${info('字幕','subtitles',[['语言','简体中文'],['格式','ASS'],['默认','是'],['外挂字幕','可选择']])}</div></section><section class="section"><div class="file-info"><b>${item.title} · ${item.series?'第 '+season+' 季 第 1 集':'原始版本'}</b><span>/media/${item.series?'series':'movies'}/${item.title}/${item.series?'S0'+season+'E01':'movie'}.mp4</span><p style="margin-top:8px">${item.series?'21 分钟 · 237.92 MB':'2 小时 47 分钟 · 24.8 GB'} · ${item.series?'1080p H264':'4K HEVC'}</p></div></section></div><div class="home-indicator"></div>`;
    if(media!=='eternal'){
      root.querySelector('.detail-art').style.backgroundImage=`url('assets/${item.image}.jpg')`;
      root.querySelector('.detail-art').style.backgroundSize='cover';
      root.querySelector('.detail-art').style.backgroundPosition='center 20%';
      // Actor photos in the supplied series reference do not belong to other films.
      const actorSection=root.querySelector('.cast-card').closest('.section');actorSection.innerHTML='<h3>演员人员</h3><p class="detail-summary">此示例未载入演员资料</p>';
    }
    UI.hydrate(root);ArtTheme.controller(root)(`assets/${item.image}.jpg`);
    function markGroups(index){
      group=Math.max(0,Math.min(Math.ceil(episodeCount()/10)-1,index));
      root.querySelectorAll('[data-group]').forEach(b=>{const active=Number(b.dataset.group)===group;b.classList.toggle('active',active);b.setAttribute('aria-pressed',String(active));});
    }
    function syncVisibleGroup(){
      const box=root.querySelector('[data-episodes]');if(!box)return;
      const focused=document.activeElement?.closest('[data-episode]');
      if(episodeFocusMode&&focused&&box.contains(focused)){markGroups(Math.floor((Number(focused.dataset.episode)-1)/10));return;}
      const cards=[...box.querySelectorAll('[data-episode]')],left=box.getBoundingClientRect().left;
      const nearest=cards.reduce((best,card)=>Math.abs(card.getBoundingClientRect().left-left)<Math.abs(best.getBoundingClientRect().left-left)?card:best,cards[0]);
      if(nearest)markGroups(Math.floor((Number(nearest.dataset.episode)-1)/10));
    }
    function selectEpisode(n){
      currentEpisode=Math.max(1,Math.min(episodeCount(),n));
      root.querySelector('[data-play-label]').textContent=`播放 第 ${currentEpisode} 集`;
      root.querySelectorAll('[data-episode]').forEach(b=>{const selected=Number(b.dataset.episode)===currentEpisode;b.classList.toggle('active',selected);b.setAttribute('aria-pressed',String(selected));b.querySelector('small').textContent='21 分钟 · '+(selected?'待播放':'未观看');});
    }
    function scrollToEpisode(n,smooth=true){
      episodeFocusMode=false;
      const box=root.querySelector('[data-episodes]'),card=box?.querySelector(`[data-episode="${Math.max(1,Math.min(episodeCount(),n))}"]`);if(!card)return;
      box.scrollTo({left:box.scrollLeft+card.getBoundingClientRect().left-box.getBoundingClientRect().left,behavior:smooth&&!matchMedia('(prefers-reduced-motion: reduce)').matches?'smooth':'instant'});
      requestAnimationFrame(syncVisibleGroup);
    }
    function episodeCards(){
      const box=root.querySelector('[data-episodes]');if(!box)return;
      box.innerHTML=Array.from({length:episodeCount()},(_,i)=>{const n=i+1;return `<button class="episode-card ${n===currentEpisode?'active':''}" data-episode="${n}" aria-pressed="${n===currentEpisode}"><div class="episode-thumb"><span class="episode-no">${String(n).padStart(2,'0')}</span></div><b>第 ${n} 集 · ${['新的旅程','故人重逢','风起云涌'][i%3]}</b><small>21 分钟 · ${n===currentEpisode?'待播放':'未观看'}</small></button>`;}).join('');
      root.querySelector('.episode-groups').innerHTML=Array.from({length:Math.ceil(episodeCount()/10)},(_,i)=>`<button data-group="${i}" aria-pressed="${i===0}" class="${i===0?'active':''}">${i*10+1}–${Math.min((i+1)*10,episodeCount())}</button>`).join('');
      episodeFocusMode=false;box.scrollLeft=0;markGroups(0);
    }
    episodeCards();
    const episodes=root.querySelector('[data-episodes]');
    if(episodes){
      episodes.addEventListener('scroll',()=>{cancelAnimationFrame(scrollFrame);scrollFrame=requestAnimationFrame(syncVisibleGroup);},{passive:true});
      episodes.addEventListener('click',e=>{const b=e.target.closest('[data-episode]');if(!b)return;selectEpisode(Number(b.dataset.episode));toast(root,`已选择第 ${currentEpisode} 集`);});
      episodes.addEventListener('focusin',e=>{const b=e.target.closest('[data-episode]');if(!b)return;episodeFocusMode=root.classList.contains('tv')&&episodeInputSource==='keyboard';b.scrollIntoView({block:'nearest',inline:'nearest',behavior:'instant'});if(episodeFocusMode)markGroups(Math.floor((Number(b.dataset.episode)-1)/10));requestAnimationFrame(syncVisibleGroup);});
      episodes.addEventListener('keydown',e=>{if(['Tab','ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(e.key)){episodeFocusMode=root.classList.contains('tv');requestAnimationFrame(syncVisibleGroup);}},{capture:true});
      for(const event of ['wheel','touchstart','pointerdown'])episodes.addEventListener(event,()=>{episodeFocusMode=false;requestAnimationFrame(syncVisibleGroup);},{passive:true});
      episodes.addEventListener('focusout',e=>{if(!episodes.contains(e.relatedTarget)){episodeFocusMode=false;requestAnimationFrame(syncVisibleGroup);}});
      root.querySelector('.episode-groups').onclick=e=>{const b=e.target.closest('[data-group]');if(b)scrollToEpisode(Number(b.dataset.group)*10+1);};
    }
    root.querySelector('[data-expand]').onclick=e=>{expanded=!expanded;root.querySelector('[data-summary]').textContent=expanded?summary:summary.slice(0,44)+'…';e.target.textContent=expanded?'收起':'展开';};
    root.querySelectorAll('[data-toggle]').forEach(b=>b.onclick=()=>{const on=b.getAttribute('aria-pressed')!=='true';b.setAttribute('aria-pressed',String(on));toast(root,on?b.dataset.toggle:'已取消');});
    root.querySelector('[data-more]').onclick=()=>sheet(root,'更多操作',`<a class="choice-row" href="together.html">${icon('together')}一起看<span class="spacer"></span>${icon('next')}</a><button class="choice-row" data-download>${icon('download')}下载此影片<span class="spacer"></span>${icon('next')}</button><button class="choice-row" data-info>${icon('info')}查看媒体信息<span class="spacer"></span>${icon('next')}</button>`,(s,close)=>{s.querySelector('[data-download]').onclick=()=>{close();toast(root,'已加入下载队列（演示）');};s.querySelector('[data-info]').onclick=()=>{close();root.querySelector('.media-info').scrollIntoView({block:'center',behavior:'smooth'});};});
    root.querySelector('[data-versions]').onclick=()=>sheet(root,'选择播放版本',['Emby · 1080p H264','Jellyfin · 4K HEVC'].map((s,i)=>`<button class="choice-row ${i===0?'selected':''}" data-version="${i}">${UI.serverLogo(i?'Jellyfin':'Emby')}<span class="choice-text"><b>${s}</b><small>${i===0?'默认线路 · 237.92 MB':'备用版本 · 1.82 GB'}</small></span>${i===0?icon('check'):''}</button>`).join(''),(s,close)=>{s.querySelectorAll('[data-version]').forEach(b=>b.onclick=()=>{root.querySelector('[data-version-label]').textContent=Number(b.dataset.version)?'4K · HEVC':'1080p · H264';const provider=Number(b.dataset.version)?'Jellyfin':'Emby';root.querySelector('[data-version-server]').textContent=provider;root.querySelector('.detail-versions .server-logo').outerHTML=UI.serverLogo(provider);close();});});
    root.querySelector('[data-season]')?.addEventListener('click',()=>sheet(root,'选择季',[1,2,3,4].map(n=>`<button class="choice-row ${n===season?'selected':''}" data-season-choice="${n}"><span class="choice-text"><b>第 ${n} 季</b><small>${n===4?'更新至 '+episodeCount(n)+' 集':'共 '+episodeCount(n)+' 集 · 已完结'}</small></span>${n===season?icon('check'):''}</button>`).join(''),(s,close)=>s.querySelectorAll('[data-season-choice]').forEach(b=>b.onclick=()=>{season=Number(b.dataset.seasonChoice);currentEpisode=1;group=0;root.querySelector('[data-season-label]').textContent=`第 ${season} 季`;root.querySelector('[data-play-label]').textContent='播放 第 1 集';episodeCards();close();})));
    root.querySelector('[data-all-episodes]')?.addEventListener('click',()=>sheet(root,`第 ${season} 季 · 全部选集`,`<div class="episode-grid">${Array.from({length:episodeCount()},(_,i)=>`<button data-jump-episode="${i+1}" class="${i+1===currentEpisode?'selected':''}">${i+1}</button>`).join('')}</div>`,(s,close)=>s.querySelectorAll('[data-jump-episode]').forEach(b=>b.onclick=()=>{selectEpisode(Number(b.dataset.jumpEpisode));close();scrollToEpisode(currentEpisode);})));
  });
})();
