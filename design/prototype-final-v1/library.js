(() => {
  const {icon,poster,sheet}=UI;
  // [title, category, genre, year, region, server, seasons, score, image]; array order stands in for "recently updated".
  const items=[['一念永恒','动漫','动画','2026','中国大陆','Emby',3,8.5,'detail-reference'],['一瓯春','电视剧','剧情','2026','中国大陆','Emby',1,9.5,'hero-reference'],['沙丘：第二部','电影','科幻','2024','美国','Jellyfin',0,8.3,'dune'],['星际穿越','电影','科幻','2014','美国','Plex',0,9.4,'interstellar'],['千与千寻','动漫','动画','2001','日本','Emby',0,9.4,'spirited'],['银翼杀手 2049','电影','科幻','2017','美国','Jellyfin',0,8.3,'blade'],['星际穿越 · 原声带','音乐','原声','2014','美国','Plex',0,9.5,'interstellar'],['沙丘 · 原声带','音乐','原声','2024','美国','Emby',0,8.6,'dune']];
  const kinds=['全部','电视剧','电影','动漫','综艺','演唱会','纪录','音乐'];
  const sorts=[['updated','最新更新'],['released','最新上映'],['score','影片评分']];
  // Row label doubles as "no restriction" for that dimension.
  const facets=[['genre','类型',2,['剧情','科幻','动画','喜剧','动作','爱情','惊悚','犯罪','原声']],['region','地区',4,['中国大陆','中国香港','中国台湾','日本','韩国','美国','欧洲']],['year','年份',3,['2020年代','2026','2025','2024','2023','2010年代','2000年代']]];
  const matchYear=(year,value)=>value.endsWith('年代')?year.startsWith(value.slice(0,3)):year===value;
  document.querySelectorAll('[data-library]').forEach(root=>{
    const tv=root.classList.contains('tv');
    let kind='全部',query='',sort='updated',server='',filters={};
    const chips=(group,values,selected,label)=>`<div class="chip-row" role="group" aria-label="${label}">${values.map(([value,text])=>`<button data-${group}="${value}" class="${value===selected?'active':''}" aria-pressed="${value===selected}">${text}</button>`).join('')}</div>`;
    const searchInput=`<div class="search-box">${icon('search')}<input type="search" placeholder="输入影片名称搜索" aria-label="搜索媒体"></div>`;
    root.innerHTML=`<div class="device-scroll">${UI.status()}<header class="screen-heading"><div class="toolbar"><h3>搜索</h3>${tv?searchInput:''}<button class="icon-button" data-server aria-label="选择服务器">${icon('server')}</button></div>${tv?'':`<div class="library-controls">${searchInput}</div>`}</header><div class="search-filters">${chips('kind',kinds.map(k=>[k,k]),kind,'媒体类型')}${chips('sort',sorts,sort,'排序')}${facets.map(([group,label,,values])=>chips(group,[['',label],...values.map(v=>[v,v])],'',label)).join('')}</div><p class="library-count" role="status"></p><div class="poster-grid"></div></div><nav data-app-nav></nav><div class="home-indicator"></div>`;
    UI.hydrate(root);
    function render(){
      const result=items.filter(x=>(kind==='全部'||x[1]===kind)&&x[0].includes(query)&&(!server||x[5]===server)&&facets.every(([group,,index])=>!filters[group]||(group==='year'?matchYear(x[index],filters[group]):x[index]===filters[group])));
      if(sort!=='updated')result.sort((a,b)=>sort==='score'?b[7]-a[7]:Number(b[3])-Number(a[3]));
      root.querySelector('.library-count').textContent=query||server||Object.values(filters).some(Boolean)?`${result.length} 部作品`:'';
      root.querySelector('.poster-grid').innerHTML=result.map(x=>poster(x[0],x[8],x[6]?`共${x[6]}季`:x[3],`${x[7]}分`,x[5])).join('')||`<div class="empty-state">没有符合条件的作品<p style="font-size:11px;margin:8px 0 15px">试试其他条件，或清空筛选</p><button class="btn sec" data-reset>清空筛选</button></div>`;
      root.querySelector('[data-reset]')?.addEventListener('click',()=>{kind='全部';filters={};query='';root.querySelectorAll('input[type=search]').forEach(n=>n.value='');sync();render();});
    }
    function sync(){
      const pick=(group,value)=>root.querySelectorAll(`[data-${group}]`).forEach(n=>{const on=n.dataset[group]===value;n.classList.toggle('active',on);n.setAttribute('aria-pressed',String(on));});
      pick('kind',kind);pick('sort',sort);facets.forEach(([group])=>pick(group,filters[group]||''));
    }
    root.querySelectorAll('input[type=search]').forEach(input=>input.oninput=e=>{query=e.target.value.trim();render();});
    root.querySelectorAll('[data-kind]').forEach(b=>b.onclick=()=>{kind=b.dataset.kind;sync();render();});
    root.querySelectorAll('[data-sort]').forEach(b=>b.onclick=()=>{sort=b.dataset.sort;sync();render();});
    facets.forEach(([group])=>root.querySelectorAll(`[data-${group}]`).forEach(b=>b.onclick=()=>{filters[group]=b.dataset[group];sync();render();}));
    root.querySelector('[data-server]').onclick=()=>sheet(root,'选择服务器',['所有服务器','Emby','Jellyfin','Plex'].map((v,i)=>`<button class="choice-row" data-server-choice="${i?v:''}">${i?UI.serverLogo(v):icon('server')}<span class="choice-text"><b>${v}</b><small>${i?'已连接':'合并显示 3 台服务器'}</small></span></button>`).join(''),(s,close)=>s.querySelectorAll('[data-server-choice]').forEach(b=>b.onclick=()=>{server=b.dataset.serverChoice;root.querySelector('[data-server]').innerHTML=server?UI.serverLogo(server):icon('server');render();close();}));
    render();
  });
})();
