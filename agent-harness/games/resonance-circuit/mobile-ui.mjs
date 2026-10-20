// Screen composition only. No game state, RNG or save mutations.
export function setupMobileUI(){
 const $=id=>document.getElementById(id),header=document.querySelector('header'),heading=document.createElement('div');heading.className='stage-heading';heading.append($('stageName'),$('turn'));$('menuActions').prepend($('skillHelp'));header.replaceChildren(heading,$('menuOpen'));

 for(const id of ['pending','preview','notice'])$('battleDetails').append($(id));$('battleDetails').append(document.querySelector('.echo-row'));
 $('enemy').prepend($('coach'));
 const dock=document.querySelector('.skills');dock.classList.add('party-dock');document.querySelector('main').insertBefore(dock,document.querySelector('.circuit'));
 $('boost').firstChild.textContent='OVERDRIVE · 과충전 '; $('boost').setAttribute('aria-label','과충전: 이번 턴 피해 두 배');$('boost').append($('gaugeText'));$('gauge').setAttribute('aria-label','과충전 게이지');
 $('menuOpen').onclick=()=>$('gameMenu').showModal();$('menuClose').onclick=()=>$('gameMenu').close();$('gameMenu').addEventListener('close',()=>{if(!document.querySelector('dialog[open]'))$('menuOpen').focus({preventScroll:true});});
 $('gameMenu').addEventListener('click',e=>{if(['modeMenu','restart','newSeed','help','skillHelp','feedbackHelp','relicHelp'].includes(e.target.closest('button')?.id))$('gameMenu').close();},true);
}
