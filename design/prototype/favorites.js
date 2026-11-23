(() => {
  const {icon,poster}=UI;
  // [title, image, subtitle, score, kind, server] — 演示收藏，按“最近收藏”排列
  const items=[['沙丘：第二部','dune','2024','8.3','电影','Jellyfin'],['一念永恒','detail-reference','共3季','8.5','剧集','Emby'],['星际穿越','interstellar','2014','9.4','电影','Plex'],['一瓯春','hero-reference','共1季','9.5','剧集','Emby'],['千与千寻','spirited','2001','9.4','电影','Emby'],['银翼杀手 2049','blade','2017','8.3','电影','Jellyfin']];
  document.querySelectorAll('[data-favorites]').forEach(root=>{
    const tv=root.classList.contains('tv');
    let kind='全部';
    root.innerHTML=`<div class="device-scroll">${UI.status()}<header class="screen-heading"><div class="toolbar"><h3>收藏</h3><span class="spacer" style="flex:1"></span><a class="icon-button" href="library.html" aria-label="搜索">${icon('search')}</a><button class="icon-button" data-sort aria-label="排序：最近收藏">${icon('sort')}</button></div></header><div class="search-filters"><div class="chip-row" role="group" aria-label="类型">${['全部','电影','剧集'].map(k=>`<button data-kind="${k}" class="${k===kind?'active':''}" aria-pressed="${k===kind}">${k}</button>`).join('')}</div></div><p class="library-count" role="status" style="display:block;margin:0 17px 10px;font-size:11px;opacity:.7"></p><div class="poster-grid"></div></div><nav data-app-nav></nav><div class="home-indicator"></div>`;
    UI.hydrate(root);
    function render(){
      const r=items.filter(x=>kind==='全部'||x[4]===kind);
      root.querySelector('.library-count').textContent=`${r.length} 部 · 最近收藏在前`;
      root.querySelector('.poster-grid').innerHTML=r.map(x=>poster(x[0],x[1],x[2],`${x[3]}分`,x[5])).join('');
    }
    root.querySelectorAll('[data-kind]').forEach(b=>b.onclick=()=>{kind=b.dataset.kind;root.querySelectorAll('[data-kind]').forEach(n=>{const on=n.dataset.kind===kind;n.classList.toggle('active',on);n.setAttribute('aria-pressed',String(on));});render();});
    root.querySelector('[data-sort]').onclick=()=>UI.toast(root,'排序：最近收藏 / 片名 / 上映时间 / 评分（演示）');
    render();
    if(tv)root.querySelector('.poster-grid').style.gridTemplateColumns='repeat(7,minmax(0,1fr))';
  });
})();
