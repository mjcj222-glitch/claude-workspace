import {C} from './config.mjs';
import {createGame,preview,tap,useSkill,overcharge,inputGate,moveFocus} from './engine.mjs';
const $=id=>document.getElementById(id), symbols={coral:'◆',gold:'✦',blue:'●',heal:'+'}, names={coral:'산호',gold:'금빛',blue:'파랑',heal:'회복'};
let state=createGame(), focus=1, pressed=null, guideStep=0;
const gate=inputGate(), reduced=matchMedia('(prefers-reduced-motion: reduce)');
const tiles=Array.from({length:42},(_,i)=>{const b=document.createElement('button');b.className='tile';b.style.setProperty('--c',Math.floor(i/7)+1);b.style.setProperty('--r',i%7+1);b.dataset.index=i;$('board').append(b);return b;});
function showPreview(i){if(gate.locked||state.status!=='playing')return;focus=i;const p=preview(state,i);tiles.forEach((b,j)=>{b.classList.toggle('selected',p.removed.includes(j));b.tabIndex=j===i?0:-1;});$('preview').textContent=`연결 ${p.initial.length} · 총 ${p.removed.length}칸 · 피해 +${p.damage} / 회복 +${p.healing}${p.echoHit?' · 잔향 연결!':''}`;}
function render(){
 tiles.forEach((b,i)=>{const t=state.board[i];b.className=`tile ${t.color} ${Math.floor(i/7)%2?'odd':''} ${state.echo.includes(t.id)?'marked':''}`;b.innerHTML=`${symbols[t.color]}${t.kind==='normal'?'':`<small>${t.kind==='bomb'?'✹':'ϟ'}</small>`}`;b.setAttribute('aria-label',`${Math.floor(i/7)+1}열 ${i%7+1}행 ${names[t.color]} ${t.kind==='bomb'?'폭탄':t.kind==='charge'?'차지':'일반'}${state.echo.includes(t.id)?' 잔향':''}`);b.tabIndex=i===focus?0:-1;b.disabled=state.status!=='playing';});
 $('boss').max=C.bossHP;$('boss').value=state.bossHP;$('bossText').textContent=`그림자 ${state.bossHP} / ${C.bossHP}`;$('incoming').textContent=`다음 공격 ${C.attacks[(state.turn-1)%2]}`;
 $('health').textContent=`온실 체력 ${state.hp} / ${C.hp}`;$('turn').textContent=`${state.turn}턴`;$('taps').textContent=`남은 탭 ${state.taps} / 3`;
 $('pending').textContent=`턴 끝 정산: 피해 ${state.damage} · 회복 ${state.healing}${state.boost?' · 과충전 중':''}`;
 $('echo').textContent=state.echo.length?`◌ 잔향 ${state.echo.length}개 — 다음 탭에 연결`:'5개 이상 연결하면 이웃에 잔향이 남습니다.';
 $('gauge').max=C.gauge;$('gauge').value=state.gauge;$('gaugeText').textContent=`${state.gauge} / ${C.gauge}`;
 $('boost').disabled=state.status!=='playing'||state.gauge<C.gauge||state.taps!==3||state.boost;
 document.querySelectorAll('[data-skill]').forEach((b,i)=>{b.disabled=state.status!=='playing'||state.turn<state.ready[i];b.title=state.turn<state.ready[i]?`${state.ready[i]}턴부터 재사용`:'지금 사용 가능';let status=b.querySelector('.cooldown');if(!status){status=document.createElement('span');status.className='cooldown';b.append(status);}status.textContent=state.turn<state.ready[i]?`${state.ready[i]-state.turn}턴 후`:'준비';});
}
const delay=ms=>new Promise(resolve=>setTimeout(resolve,reduced.matches?0:ms));
async function commit(i){
 if(state.status!=='playing'||$('guide').open||!gate.start())return;
 try {const p=preview(state,i);p.removed.forEach(j=>tiles[j].classList.add('cleared'));$('board').classList.toggle('blast',p.removed.length>=10);await delay(180);
 const result=tap(state,i);render();$('board').classList.remove('blast');$('board').classList.add('falling');await delay(220);$('board').classList.remove('falling');
 $('notice').textContent=`${result.removed.length}칸 해소${result.echoHit?' · 잔향 발동!':''}${result.special?' · 새 '+(result.special.kind==='bomb'?'폭탄':'차지'):''}${result.retaliation?' · 그림자 공격 '+result.retaliation:''}`;
 if(state.status!=='playing'){$('result').textContent=state.status==='won'?'온실에 빛이 돌아왔습니다':'잠시 꺼진 온실';$('stats').textContent=`${state.turn}턴 · 최대 연쇄 ${state.maxChain} · 잔향 발동 ${state.echoCount}회. 다음 회로에서는 어떤 빛을 남길까요?`;$('ending').showModal();}
 else tiles[focus].focus();
 } finally {gate.finish();if(state.status==='playing')showPreview(focus);}
}
for(const [i,b] of tiles.entries()){
 b.addEventListener('focus',()=>showPreview(i));
 b.addEventListener('pointerdown',e=>{if(gate.locked||e.button!==0)return;pressed={id:e.pointerId,i,x:e.clientX,y:e.clientY};showPreview(i);});
 b.addEventListener('pointerup',e=>{const p=pressed;pressed=null;if(p&&p.id===e.pointerId&&p.i===i&&Math.hypot(e.clientX-p.x,e.clientY-p.y)<12&&document.elementFromPoint(e.clientX,e.clientY)?.closest('.tile')===b)commit(i);});
 b.addEventListener('click',e=>{if(e.detail===0)commit(i);});
 b.addEventListener('keydown',e=>{if(e.repeat){e.preventDefault();return;}const move={ArrowUp:-1,ArrowDown:1,ArrowLeft:-7,ArrowRight:7}[e.key];if(move){e.preventDefault();if(!gate.locked){focus=moveFocus(i,e.key);tiles[focus].focus();}}});
}
window.addEventListener('pointercancel',()=>pressed=null);window.addEventListener('pointerup',()=>pressed=null);
window.addEventListener('pointermove',e=>{if(pressed&&Math.hypot(e.clientX-pressed.x,e.clientY-pressed.y)>=12)pressed=null;});
document.querySelectorAll('[data-skill]').forEach(b=>b.addEventListener('click',()=>{if(gate.locked)return;const ok=useSkill(state,Number(b.dataset.skill));render();showPreview(focus);$('notice').textContent=ok?'스킬 적용 · 탭은 소모하지 않습니다.':'대상이 없거나 재충전 중입니다.';}));
$('boost').onclick=()=>{if(!gate.locked&&overcharge(state)){render();showPreview(focus);$('notice').textContent='과충전! 이번 턴 피해 2배.';}};
function restart(fresh){if(gate.locked)return;state=createGame(fresh?crypto.getRandomValues(new Uint32Array(1))[0]:state.seed);if($('ending').open)$('ending').close();render();showPreview(1);tiles[1].focus();$('notice').textContent='새로운 빛 회로가 준비됐습니다.';}
$('restart').onclick=()=>restart(false);$('newSeed').onclick=()=>restart(true);$('again').onclick=()=>restart(false);$('another').onclick=()=>restart(true);
const guide=[['빛을 이어 주세요','같은 색은 모양도 같습니다. 누르면 연결을 미리 보고, 같은 자리에서 떼면 해소합니다. 드래그하면 취소됩니다. 방향키로 이동하고 Enter 또는 Space로 확정하세요.'],['다음 빛을 남기세요','공격색 5개 이상은 차지와 이웃 잔향 ◌을, 10개 이상은 폭탄을 만듭니다. 다음 탭의 같은 색 묶음이 ◌에 닿으면 이전 잔향 전체가 연결됩니다. 빗나가면 표식이 사라집니다.'],['온실을 지켜 주세요','3탭 뒤 피해·회복을 정산하고 그림자가 공격합니다. 스킬은 탭을 쓰지 않으며 3턴 뒤 돌아옵니다. 게이지가 차면 턴 첫 탭 전에 과충전하세요. 차지는 추가 피해, 폭탄은 주변 6칸도 해소합니다.']];
function tutorial(){const [title,body]=guide[guideStep];$('step').textContent=`FIELD NOTES / ${guideStep+1} OF 3`;$('guideTitle').textContent=title;$('guideText').textContent=body;$('guideNext').textContent=guideStep===2?'온실에 들어가기':'다음';if(!$('guide').open)$('guide').showModal();}
$('guideNext').onclick=()=>{if(guideStep<2){guideStep++;tutorial();}else{$('guide').close();tiles[1].focus();}};$('help').onclick=()=>{if(!gate.locked){guideStep=0;tutorial();}};
render();tutorial();
