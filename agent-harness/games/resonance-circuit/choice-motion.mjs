// Decorative only: no access to game mutations, storage or choice handlers.
export function createChoiceMotion(reduced){
 const $=id=>document.getElementById(id),journey=$('journey'),upgrade=$('upgrade');
 const decorate=(host,kind)=>{
  const layer=document.createElement('div');layer.className='choice-atmosphere';layer.setAttribute('aria-hidden','true');layer.dataset.kind=kind;
  layer.innerHTML='<span class="choice-halo"></span><i class="choice-spark one"></i><i class="choice-spark two"></i><i class="choice-spark three"></i><span class="choice-leaf">❧</span>';
  host.append(layer);return layer;
 };
 const roomLayer=decorate($('roomScene'),'rest');
 const reward=document.createElement('div');reward.className='reward-vignette';reward.setAttribute('aria-hidden','true');reward.innerHTML='<span class="reward-crystal">✧</span>';journey.insertBefore(reward,$('roomChoices'));decorate(reward,'reward');
 const growth=reward.cloneNode(true);upgrade.insertBefore(growth,$('choices'));
 let key='';
 function refresh(){
  for(const dialog of [journey,upgrade])dialog.classList.toggle('motion-live',dialog.open&&!reduced.matches&&!document.hidden);
 }
 function render(run){
  const next=[run.mode??'practice',run.phase,run.depth??run.stage,run.path?.at(-1)??''].join(':');
  if(next!==key){key=next;for(const d of [journey,upgrade]){d.classList.remove('choice-arrival');void d.offsetWidth;d.classList.add('choice-arrival');}}
  reward.hidden=run.mode!=='expedition'||run.phase!=='reward';roomLayer.dataset.kind=$('roomScene').dataset.encounter??'rest';
  refresh();
 }
 const observer=new MutationObserver(refresh);for(const dialog of [journey,upgrade])observer.observe(dialog,{attributes:true,attributeFilter:['open']});
 document.addEventListener('visibilitychange',refresh);
 return {render,refresh};
}
