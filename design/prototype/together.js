(() => {
  document.querySelectorAll('[data-together]').forEach(root=>{
    const content=root.querySelector('.page-content');
    let title='周五电影夜', film='一念永恒', host=true, ready=false;
    function home(){
      content.innerHTML='<div class="together-layout"><section class="room-intro"><div class="eyebrow">WATCH TOGETHER</div><h4>隔着距离，<br>也能一起入戏。</h4><p class="subtle">邀请朋友加入房间，同步播放与暂停。<br>各自连接媒体服务器。</p><div class="room-actions"><button class="btn pri" data-create>创建房间</button><button class="btn sec" data-join>邀请码加入</button></div></section><section><div class="results-head"><b>我的房间</b><span class="subtle">最近</span></div><article class="room-card"><span class="tag">等待开始 · 3 位成员</span><h4>周五电影夜</h4><p class="subtle">一念永恒 · 第 7 集</p><footer><div class="avatars"><span>W</span><span>A</span><span>L</span></div><button class="text-button" data-enter>进入房间 →</button></footer></article><p class="subtle">房间仅通过邀请加入。</p></section></div>';
      content.querySelector('[data-create]').onclick=()=>form(true);content.querySelector('[data-join]').onclick=()=>form(false);content.querySelector('[data-enter]').onclick=()=>{title='周五电影夜';film='一念永恒';host=true;ready=false;lobby();};
    }
    function form(create){
      content.innerHTML=`<button class="text-button" data-back>‹ 返回一起看</button><h4 class="lobby-title">${create?'创建房间':'加入房间'}</h4><form class="room-form">${create?'<label>房间名称<input name="title" maxlength="30" required value="周五电影夜"></label><label>选择影片<select name="film"><option>一念永恒</option><option>一瓯春</option><option>青苔之岛</option></select></label><p class="subtle">你将成为房主，控制播放与暂停。</p>':'<label>邀请码<input name="code" required pattern="[0-9]{6}" maxlength="6" inputmode="numeric" placeholder="输入 6 位邀请码"></label><p class="subtle">输入朋友分享的 6 位邀请码</p>'}<p class="room-error" role="alert"></p><button class="btn pri" type="submit" style="margin-top:16px">${create?'创建并进入':'加入房间'}</button></form>`;
      content.querySelector('[data-back]').onclick=home;
      content.querySelector('form').onsubmit=e=>{e.preventDefault();const data=new FormData(e.target);if(!create&&data.get('code')!=='246810'){content.querySelector('[role=alert]').textContent='未找到房间，请检查邀请码后重试。';return;}host=create;title=create?data.get('title').trim():'周五电影夜';if(!title){content.querySelector('[role=alert]').textContent='请输入房间名称。';return;}film=create?data.get('film'):'一念永恒';ready=false;lobby();UI.toast(root,create?`已创建房间“${title}”`:`已加入“${title}”`,{type:'success'});};
    }
    function lobby(){
      content.innerHTML='<button class="text-button" data-leave>‹ 离开房间</button><h4 class="lobby-title" data-title></h4><p class="subtle">邀请码 246810</p><div class="room-card"><span class="tag">待播放</span><h4 data-film></h4><p class="subtle">已找到媒体 · 等待成员准备</p></div><div class="lobby-member"><span>wines · 你'+(host?' · 房主':'')+'</span><small>'+(host?'已准备':ready?'已准备':'未准备')+'</small></div><div class="lobby-member"><span>Alex'+(!host?' · 房主':'')+'</span><small>已准备</small></div><div class="lobby-member"><span>Lin</span><small>已准备</small></div><div class="lobby-actions">'+(host?'<a class="btn pri" href="player.html">开始一起看</a>':'<button class="btn pri" data-ready>'+(ready?'取消准备':'我准备好了')+'</button>')+'<button class="btn sec" data-invite>查看邀请信息</button></div><p class="subtle" data-invite-info style="margin-top:16px"></p>';
      content.querySelector('[data-title]').textContent=title;content.querySelector('[data-film]').textContent=film;
      content.querySelector('[data-leave]').onclick=()=>{home();UI.toast(root,`已离开“${title}”`,{action:{label:'撤销',run:()=>{lobby();UI.toast(root,'已回到房间',{type:'success'});}}});};content.querySelector('[data-invite]').onclick=()=>{content.querySelector('[data-invite-info]').textContent='演示邀请：在“一起看 → 邀请码加入”输入 246810。不会发送真实邀请。';UI.toast(root,'邀请码 246810 已复制（演示）',{type:'success'});};
      const toggle=content.querySelector('[data-ready]');if(toggle)toggle.onclick=()=>{ready=!ready;lobby();};
    }
    home();
  });
})();
