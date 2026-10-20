// Cancellable visual projection only: never defers gameplay or owns saved state.
export function createPresentation(reduced){
 const $=id=>document.getElementById(id),meter=document.createElement('div');meter.className='boss-meter';meter.setAttribute('aria-hidden','true');meter.innerHTML='<span id="bossTrail"></span><span id="bossFill"></span>';$('enemy').append(meter);
 // Preserve last-child HUD selectors by keeping its existing line last.
 $('enemy').append($('bossText').parentElement);
 const healthDelta=document.createElement('span');healthDelta.id='healthDelta';healthDelta.setAttribute('aria-hidden','true');$('health').append(healthDelta);
 const running=new Set(),timers=new Set();let previous=null,identity=null,lastPhase=null,lastRatio=1,choice=null,healthVersion=0;
 const quiet=()=>reduced.matches||document.hidden;
 function animate(el,frames,options){if(quiet())return;const a=el.animate(frames,options);running.add(a);const done=()=>running.delete(a);a.onfinish=()=>{done();a.cancel();};a.oncancel=done;}
 function later(fn,ms){const id=setTimeout(()=>{timers.delete(id);fn();},ms);timers.add(id);}
 function clear(){document.querySelectorAll('.presentation-enter').forEach(el=>el.classList.remove('presentation-enter'));document.querySelectorAll('dialog').forEach(el=>el.getAnimations().forEach(a=>a.cancel()));for(const a of running)a.cancel();running.clear();for(const t of timers)clearTimeout(t);timers.clear();choice?.remove();choice=null;healthVersion++;healthDelta.textContent='';for(const id of ['bossFill','bossTrail']){const el=$(id);el.style.transform=`scaleX(${lastRatio})`;el.dataset.ratio=String(lastRatio);}}
 function transition(el){if(quiet())return;el.classList.add('presentation-enter');later(()=>el.classList.remove('presentation-enter'),160);}
 function update(s,phase){
  const changed=identity!==s,ratio=Math.max(0,Math.min(1,s.bossHP/s.rules.bossHP)),old=lastRatio;
  if(changed){clear();previous=null;identity=s;}
  lastRatio=ratio;
  if(changed||old!==ratio)for(const [id,duration,delay] of [['bossFill',160,0],['bossTrail',320,110]]){const el=$(id);el.getAnimations().forEach(a=>a.cancel());el.style.transform=`scaleX(${ratio})`;el.dataset.ratio=String(ratio);if(!changed&&old!==ratio)animate(el,[{transform:`scaleX(${old})`},{transform:`scaleX(${ratio})`}],{duration:ratio<old?duration:160,delay:ratio<old?delay:0,easing:'cubic-bezier(.2,.7,.3,1)',fill:'backwards'});}
  $('taps').dataset.dots='●'.repeat(s.taps)+'○'.repeat(3-s.taps);
  $('boost').dataset.state=s.boost?'active':s.gauge>=55&&s.taps===3?'ready':'charging';$('gaugeText').textContent=s.boost?'발동 중':$('boost').dataset.state==='ready'?'사용 가능':`${s.gauge}/55`;
  const ready=[...document.querySelectorAll('[data-skill]')].map((b,i)=>{const yes=phase==='battle'&&s.turn>=s.ready[i];b.dataset.ready=String(yes);if(previous&&yes&&!previous.ready[i])animate(b,[{background:'#e6d2a9'},{background:getComputedStyle(b).backgroundColor}],{duration:220});return yes;});
  if(previous&&previous.hp!==s.hp){$('health').append(healthDelta);healthDelta.textContent=`${s.hp>previous.hp?'+':'−'}${Math.abs(s.hp-previous.hp)}`;healthDelta.dataset.change=s.hp>previous.hp?'heal':'hurt';animate(healthDelta,[{opacity:1},{opacity:0}],{duration:480,delay:100});const version=++healthVersion;later(()=>{if(version===healthVersion)healthDelta.textContent='';},600);}
  if(changed&&phase==='battle')transition($('enemy'));
  if(phase!==lastPhase){if(!changed)clear();const target=phase==='battle'?$('board'):phase==='upgrade'?$('upgrade'):['complete','defeat'].includes(phase)?$('ending'):$('journey');transition(target);lastPhase=phase;}
  previous={hp:s.hp,ready};
 }
 function selected(text){choice?.remove();choice=document.createElement('span');choice.className='presentation-choice';choice.textContent='✓ '+text;choice.setAttribute('role','status');const host=document.querySelector('dialog[open]')??document.querySelector('main');host.append(choice);animate(choice,[{opacity:0},{opacity:1,offset:.25},{opacity:0}],{duration:260});const selectedChoice=choice;later(()=>{selectedChoice.remove();if(choice===selectedChoice)choice=null;},300);}
 document.addEventListener('visibilitychange',()=>{if(document.hidden)clear();});
 return {update,clear,selected};
}
