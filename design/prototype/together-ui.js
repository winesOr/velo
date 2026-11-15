(() => {
 document.querySelectorAll('[data-status]').forEach(n=>n.innerHTML=UI.status());
 document.querySelectorAll('.room-intro').forEach(n=>n.insertAdjacentHTML('afterbegin',UI.icon('together')));
 UI.hydrate();
})();
