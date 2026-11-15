(() => {
  const {icon,serverLogo,thumb,poster,sheet}=UI;
  const slides=[
    {title:'一瓯春',english:'SPRING OF THE BLADE',year:'2026',genre:'剧情 · 家庭',score:'9.5',image:'hero-reference',calligraphy:true},
    {title:'一念永恒',english:'A WILL ETERNAL',year:'2026',genre:'动画 · 奇幻',score:'8.5',image:'detail-reference',tall:true},
    {title:'沙丘：第二部',english:'DUNE · PART TWO',year:'2024',genre:'科幻 · 冒险',score:'8.3',image:'dune'},
    {title:'星际穿越',english:'INTERSTELLAR',year:'2014',genre:'科幻 · 剧情',score:'9.4',image:'interstellar'}
  ];
  const posters=poster('沙丘：第二部','dune','2024 · 电影','8.3')+poster('千与千寻','spirited','2001 · 电影','9.4')+poster('星际穿越','interstellar','2014 · 电影','9.4')+poster('银翼杀手 2049','blade','2017 · 电影','');
  document.querySelectorAll('[data-home]').forEach(root=>{
    root.innerHTML=`<div class="device-scroll"><section class="home-hero" aria-label="推荐影片"><div class="hero-image"></div><div class="hero-scrim"></div>${UI.status()}<div class="toolbar home-toolbar"><button class="pill" data-account><span data-home-server-logo>${serverLogo(UI.currentServer())}</span><span data-home-server-name>${UI.currentServer()}</span> ${icon('down')}</button><span class="spacer"></span><a href="library.html" class="icon-button glass" aria-label="搜索">${icon('search')}</a><button class="icon-button glass" data-more aria-label="首页选项">${icon('more')}</button></div><div class="home-copy" aria-live="polite"><div class="home-original"></div><a href="detail.html"><h3 class="home-title"></h3></a><div class="home-meta"></div><div class="tv-hero-actions"><a class="btn pri" href="player.html">${icon('play')}继续观看</a><a class="btn sec" href="detail.html">查看详情</a></div></div><div class="hero-dots" aria-label="推荐影片切换">${slides.map((s,i)=>`<button data-slide="${i}" aria-label="切换到${s.title}" aria-pressed="false"></button>`).join('')}</div></section><section class="section"><h3>继续观看<a href="library.html">全部 ${icon('next')}</a></h3><div class="h-scroll">${thumb('现在就出发','continue-reference','S4:E7 · 正片 第2期下',30)}${thumb('我不是大师','continue-second','S1:E11 · 拜托了前辈',45)}${thumb('星际穿越','interstellar-backdrop','电影 · 剩余 1 小时 42 分钟',36)}</div></section><section class="section"><h3>最近添加<a href="library.html">全部 ${icon('next')}</a></h3><div class="h-scroll">${posters}</div></section><section class="section"><h3>为你推荐<a href="library.html">全部 ${icon('next')}</a></h3><div class="h-scroll">${posters}</div></section><section class="section"><a class="together-banner" href="together.html">${icon('together')}<span><b>好故事，一起看</b><small>创建房间，邀请朋友同步观看</small></span><span class="spacer"></span>${icon('next')}</a></section></div><nav data-app-nav></nav><div class="home-indicator"></div>`;
    UI.hydrate(root);
    const theme=ArtTheme.controller(root),dots=[...root.querySelectorAll('[data-slide]')];let current=-1,request=0;
    async function show(index){index=(index+slides.length)%slides.length;const ticket=++request,s=slides[index],src=`assets/${s.image}.jpg`;
      // Preserve the outgoing image at its current opacity on interrupted transitions.
      const color=await theme(src,image=>{
        if(ticket!==request)return;
        current=index;root.dataset.current=String(index);
        const art=root.querySelector('.hero-image'),layer=document.createElement('img');layer.src=image?.src||src;layer.alt=s.title+'推荐海报';
        if(s.tall){layer.classList.add('screenshot-image');layer.style.height='auto';layer.style.objectFit='initial';}else{layer.style.height='100%';layer.style.objectFit='cover';}
        layer.style.position='absolute';layer.style.inset='0';layer.style.opacity='0';art.append(layer);
        const animation=layer.animate([{opacity:0},{opacity:1}],{duration:ArtTheme.reduced()?0:ArtTheme.duration,easing:'cubic-bezier(.22,.68,0,1)',fill:'forwards'});
        animation.finished.then(()=>{if(ticket===request){[...art.children].filter(n=>n!==layer).forEach(n=>n.remove());layer.style.opacity='1';animation.cancel();}}).catch(()=>{});
        root.querySelector('.home-title').parentElement.href='detail.html?media='+({'hero-reference':'spring','detail-reference':'eternal'}[s.image]||s.image);root.querySelector('.home-title').textContent=s.title;root.querySelector('.home-title').classList.toggle('calligraphy',!!s.calligraphy);root.querySelector('.home-original').textContent=s.english;
        root.querySelector('.home-meta').innerHTML=`<button class="score-link" data-rating-details aria-label="评分 ${s.score}，查看来源说明"><span class="star">★</span><span data-score-value>${s.score}</span></button><i>│</i>${s.year}<i>│</i>${s.genre}`;
        dots.forEach((b,i)=>{b.classList.toggle('active',i===index);b.setAttribute('aria-pressed',String(i===index));});
      });return color;
    }
    dots.forEach(b=>b.onclick=()=>show(Number(b.dataset.slide)));
    let pointerX=0,pointerY=0,tracking=false,swiped=false;const hero=root.querySelector('.home-hero');
    hero.style.touchAction='pan-y';hero.tabIndex=0;hero.setAttribute('aria-roledescription','轮播图');hero.setAttribute('aria-label','推荐影片，左右滑动切换');
    hero.addEventListener('pointerdown',e=>{if(e.target.closest('button,input,select'))return;pointerX=e.clientX;pointerY=e.clientY;tracking=true;swiped=false;});
    hero.addEventListener('pointermove',e=>{if(tracking&&Math.abs(e.clientX-pointerX)>12&&Math.abs(e.clientY-pointerY)<Math.abs(e.clientX-pointerX)*.7){swiped=true;hero.setPointerCapture(e.pointerId);}});
    hero.addEventListener('pointerup',e=>{if(!tracking)return;tracking=false;const delta=e.clientX-pointerX;if(Math.abs(delta)>45&&Math.abs(e.clientY-pointerY)<Math.abs(delta)*.7){swiped=true;show(current+(delta<0?1:-1));}});
    hero.addEventListener('pointercancel',()=>{tracking=false;swiped=false;});
    hero.addEventListener('click',e=>{if(swiped){e.preventDefault();e.stopPropagation();swiped=false;}},true);
    hero.addEventListener('keydown',e=>{if(e.target!==hero)return;if(e.key==='ArrowLeft'||e.key==='ArrowRight'){e.preventDefault();e.stopPropagation();show(current+(e.key==='ArrowRight'?1:-1));}});
    const updateServer=()=>{root.querySelector('[data-home-server-logo]').innerHTML=serverLogo(UI.currentServer());root.querySelector('[data-home-server-name]').textContent=UI.currentServer();};
    window.addEventListener('serverchange',updateServer);
    root.querySelector('[data-account]').onclick=()=>sheet(root,'媒体服务器',['Emby','Jellyfin','Plex'].map(name=>`<button class="choice-row ${name===UI.currentServer()?'selected':''}" data-home-server="${name}">${serverLogo(name)}<span class="choice-text"><b>${name}</b><small>${name==='Emby'?'家里的 Emby':'已连接'}</small></span>${name===UI.currentServer()?icon('check'):''}</button>`).join('')+`<a class="choice-row" href="settings.html">${icon('settings')}管理服务器与线路<span class="spacer"></span>${icon('next')}</a>`,(s,close)=>s.querySelectorAll('[data-home-server]').forEach(b=>b.onclick=()=>{UI.selectServer(b.dataset.homeServer);close();}),{anchor:root.querySelector('[data-account]')});
    root.querySelector('[data-more]').onclick=()=>sheet(root,'首页选项',`<a class="choice-row" href="library.html">${icon('library')}浏览全部媒体<span class="spacer"></span>${icon('next')}</a><a class="choice-row" href="settings.html">${icon('palette')}外观与首页布局<span class="spacer"></span>${icon('next')}</a>`,null,{anchor:root.querySelector('[data-more]')});
    // Focused TV media drives the same background state. No automatic carousel surprises.
    if(root.classList.contains('tv'))root.querySelectorAll('.poster-card').forEach((n,i)=>n.addEventListener('focus',()=>show(i===0?2:i===2?3:0)));
    show(0);slides.slice(1).forEach(s=>ArtTheme.sample(`assets/${s.image}.jpg`));
  });
})();
