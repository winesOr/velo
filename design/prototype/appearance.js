/* Prototype appearance preference; independent of media artwork and Flutter settings. */
window.AppTheme=(()=>{
  const key='plezy-prototype-appearance',system=matchMedia('(prefers-color-scheme: dark)'),labels={system:'跟随系统',light:'浅色',dark:'深色'};
  let mode='system';try{const value=localStorage.getItem(key);if(value in labels)mode=value;}catch{/* Storage is optional. */}
  const resolved=()=>mode==='system'?(system.matches?'dark':'light'):mode;
  function apply(){const actual=resolved();document.documentElement.dataset.appearance=actual;document.documentElement.dataset.appearanceMode=mode;document.documentElement.style.colorScheme=actual;window.dispatchEvent(new CustomEvent('appearancechange',{detail:{mode,resolved:actual}}));}
  function setMode(value){if(!(value in labels))return;mode=value;try{localStorage.setItem(key,value);}catch{/* Private browsing may disable storage. */}apply();}
  system.addEventListener('change',()=>{if(mode==='system')apply();});
  window.addEventListener('storage',e=>{if(e.key===key){mode=e.newValue in labels?e.newValue:'system';apply();}});
  apply();return{getMode:()=>mode,resolved,setMode,label:()=>labels[mode],labels};
})();
