/* Own prototype implementation. Do not attribute these exact values to VidHub source. */
window.ArtTheme=(()=>{
  const cache=new Map(),fallback=[22,25,29],duration=560;
  const reduced=()=>matchMedia('(prefers-reduced-motion: reduce)').matches;
  const rgb=c=>`rgb(${c.map(Math.round).join(' ')})`;
  async function sample(src){
    if(cache.has(src))return cache.get(src);
    const work=(async()=>{
      const image=new Image();image.src=src;await image.decode();
      const canvas=document.createElement('canvas');canvas.width=canvas.height=32;
      const ctx=canvas.getContext('2d',{willReadFrequently:true});
      // The supplied tall reference contains a full page; sample only its artwork.
      const sourceHeight=image.height/image.width>4?image.width*1.18:image.height;
      ctx.drawImage(image,0,0,image.width,sourceHeight,0,0,32,32);
      const data=ctx.getImageData(0,0,32,32).data,sum=[0,0,0];let n=0;
      for(let i=0;i<data.length;i+=4){const a=data[i+3],r=data[i],g=data[i+1],b=data[i+2],hi=Math.max(r,g,b),lo=Math.min(r,g,b),sat=hi?(hi-lo)/hi:0;
        if(a<128||hi/255<.12||sat<.12||(sat<.18&&hi/255>.85))continue;
        sum[0]+=r;sum[1]+=g;sum[2]+=b;n++;
      }
      const mean=n?sum.map(x=>x/n):fallback;
      // Preserve the artwork brightness. Compress only highly saturated colors
      // so an orange poster becomes a quiet surface rather than a neon skin.
      const hi=Math.max(...mean),lo=Math.min(...mean),sat=hi?(hi-lo)/hi:0,gray=mean[0]*.2126+mean[1]*.7152+mean[2]*.0722;
      const compression=sat>.55?.22:0;
      return {image,color:mean.map(x=>Math.round(x*(1-compression)+gray*compression))};
    })().catch(()=>({image:null,color:fallback}));cache.set(src,work);return work;
  }
  function controller(root){
    let current=[...fallback],raw=null,generation=0,animation=0,motion=0;
    const surface=color=>AppTheme.resolved()==='light'?color.map((v,i)=>v*.32+[249,249,251][i]*.68):color.map((v,i)=>v*.76+[22,25,29][i]*.24);
    const paint=c=>{current=c;root.style.setProperty('--home-bg',rgb(c));root.style.backgroundColor=rgb(c);root.dataset.palette=rgb(c);const probe=document.querySelector(`[data-theme-for="${root.id}"]`);if(probe)probe.innerHTML=`<i style="background:${rgb(c)}"></i>海报取色 · ${AppTheme.resolved()==='light'?'浅色':'深色'} · 共用过渡`;};
    function animate(color){cancelAnimationFrame(animation);const token=++motion,from=[...current],target=surface(color),t0=performance.now();root.dataset.artPalette=rgb(color);
      function step(t){if(token!==motion)return;const p=reduced()?1:Math.min(1,(t-t0)/duration),ease=1-Math.pow(1-p,3);paint(from.map((v,i)=>v+(target[i]-v)*ease));if(p<1)animation=requestAnimationFrame(step);}
      animation=requestAnimationFrame(step);
    }
    paint(surface(fallback));window.addEventListener('appearancechange',()=>{if(raw)animate(raw);else paint(surface(fallback));});
    return async(src,onReady)=>{const ticket=++generation;const {image,color}=await sample(src);if(ticket!==generation)return;onReady?.(image);raw=color;animate(color);return color;};
  }
  return {sample,controller,duration,reduced};
})();
