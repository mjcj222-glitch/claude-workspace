import {C} from './config.mjs';
import {createSkillUI} from './skill-ui.mjs';
import {preview,inputGate,moveFocus,pendingDamage} from './engine.mjs';
import {createRun,runTap,runSkill,runBoost,chooseUpgrade,retryBattle,nextAttack,tutorialTargets,skipTutorial,canRunTap,STAGES,CHOICES,PANEL_HELP} from './campaign.mjs';
import {loadProgress,saveProgress} from './storage.mjs';
import {createAudio} from './audio.mjs';
import {createEffects} from './effects.mjs';
const $=id=>document.getElementById(id),names={coral:'불꽃',gold:'별빛',blue:'물방울',heal:'회복 잎'};
let storage;try{storage=localStorage;}catch{storage=null;}
const loaded=loadProgress(storage);
let run=loaded.data?.run??createRun(),state=run.state,learned=loaded.data?.learned??false;
let started=!!loaded.data?.run,sessionPlaying=false,focus=1,pressed=null,guideStep=0,pendingFresh=false;
const settings=loaded.data?.audio??{enabled:false,volume:.3};
const sound=createAudio(settings),gate=inputGate(),reduced=matchMedia('(prefers-reduced-motion: reduce)'),fx=createEffects($('effects'),reduced);
const skillUI=createSkillUI(()=>state);
const tiles=Array.from({length:42},(_,i)=>{
 const b=document.createElement('button');b.className='tile';b.style.setProperty('--c',Math.floor(i/7)+1);b.style.setProperty('--r',i%7+1);b.dataset.index=i;$('board').append(b);return b;
});
function persist(){if(run.tutorial==='done'&&started)learned=true;const ok=saveProgress(storage,started?run:null,learned,settings);$('saveStatus').textContent=ok?'저장됨':'저장 불가 · 플레이 가능';return ok;}
function blocked(){return !sessionPlaying||gate.locked||['guide','start','upgrade','confirmNew','ending','skillGuide'].some(id=>$(id).open);}
function showPreview(i){
 if(gate.locked||run.phase!=='battle')return;
 focus=i;const p=preview(state,i);
 tiles.forEach((b,j)=>{b.classList.toggle('selected',p.removed.includes(j));b.tabIndex=j===i?0:-1;});
 $('preview').textContent=!p.initial.length?'덩굴 보호 · 옆 타일로 해제 · 탭 소모 없음':`${state.board[i].kind==='rainbow'?'확정색 '+names[p.color]+' · ':''}연결 ${p.initial.length} · 총 ${p.removed.length}칸 · 적립 +${p.damage} / 회복 +${p.healing}${p.echoHit?' · 잔향 연결!':''}${p.unlocked.length?' · 덩굴 해제 '+p.unlocked.length:''}`;
}
function render(){
 state=run.state;const rules=state.rules,targets=tutorialTargets(run);
 tiles.forEach((b,i)=>{
  const t=state.board[i];b.className=`tile ${t.color} ${t.vine?'vine':''} ${t.kind==='rainbow'?'rainbow':''} ${Math.floor(i/7)%2?'odd':''} ${state.echo.includes(t.id)?'marked':''} ${targets.includes(i)?'lesson-target':''}`;
  b.innerHTML=`<span class="gem" aria-hidden="true"></span>${t.vine?'<span class=vine-wrap aria-hidden=true></span>':''}${t.kind==='normal'||t.kind==='rainbow'?'':`<small>${t.kind==='bomb'?'✹':'ϟ'}</small>`}`;
  b.setAttribute('aria-label',`${Math.floor(i/7)+1}열 ${i%7+1}행 ${t.kind==='rainbow'?'무지개 · 가장 큰 연결색 자동 선택':names[t.color]} ${t.vine?'덩굴 · 직접 탭 무효, 이웃 소거로 해제':t.kind==='bomb'?'폭탄':t.kind==='charge'?'차지':'일반'}${state.echo.includes(t.id)?' 잔향':''}`);
  b.tabIndex=i===focus?0:-1;b.disabled=run.phase!=='battle';
 });
 document.body.classList.toggle('overcharged',state.boost);document.body.classList.toggle('learning',run.tutorial!=='done'||!!run.panelLesson);document.body.classList.toggle('panel-learning',!!run.panelLesson);
 $('stageName').textContent=`${run.stage+1}/3 · ${STAGES[run.stage].name}`;
 $('boss').max=rules.bossHP;$('boss').value=state.bossHP;$('bossText').textContent=`적 ${state.bossHP}/${rules.bossHP}`;
 const attack=nextAttack(run);$('incoming').textContent=`${attack.name} ${attack.damage} · ${attack.pattern}`;
 $('health').textContent=`체력 ${state.hp}/${rules.hp}`;$('turn').textContent=`${state.turn}턴`;$('taps').textContent=`남은 탭 ${state.taps}/3`;
 $('pending').textContent=`턴 끝: 피해 ${pendingDamage(state)} · 회복 ${state.healing}${state.boost?' · 과충전 중':''}`;
 $('echo').textContent=state.echo.length?`◌ 잔향 ${state.echo.length}개 · 다음 연결로 발동`:'공격색 5개 이상 → 잔향 · 다음 연결을 준비하세요.';
 $('gauge').max=C.gauge;$('gauge').value=state.gauge;$('gaugeText').textContent=`${state.gauge}/${C.gauge}`;
 $('boost').disabled=run.phase!=='battle'||state.gauge<C.gauge||state.taps!==3||state.boost;
 document.querySelectorAll('[data-skill]').forEach((b,i)=>{
  b.disabled=run.phase!=='battle'||state.turn<state.ready[i];b.title=state.turn<state.ready[i]?`${state.ready[i]}턴부터 재사용`:'지금 사용 가능';
  let status=b.querySelector('.cooldown');if(!status){status=document.createElement('span');status.className='cooldown';b.append(status);}status.textContent=state.turn<state.ready[i]?`${state.ready[i]-state.turn}턴 후`:'준비';
 });
 $('coach').hidden=(run.tutorial==='done'&&!run.panelLesson)||run.phase!=='battle';$('skipLesson').textContent=run.panelLesson?'알겠어요':'안내 건너뛰기';
 $('coachText').textContent=run.panelLesson?PANEL_HELP[run.panelLesson]:run.tutorial==='chain'?'빛나는 큰 묶음을 눌러 잔향을 남겨 보세요.':'◌ 표식 타일을 연결해 남겨 둔 빛을 깨워 보세요.';
 $('sound').textContent=settings.enabled?'소리 켜짐':'소리 꺼짐';$('sound').setAttribute('aria-pressed',String(settings.enabled));$('volume').value=settings.volume*100;skillUI.render();
}
function phaseDialog(){
 if(run.phase==='upgrade'){
  $('upgradeTitle').textContent=`${STAGES[run.stage].name} 복구! 하나를 선택하세요.`;$('choices').replaceChildren();
  for(const choice of CHOICES[run.stage]){const b=document.createElement('button');b.dataset.choice=choice.id;const title=document.createElement('strong'),desc=document.createElement('span');title.textContent=choice.name;desc.textContent=choice.description;b.append(title,desc);b.onclick=()=>{
   if(gate.locked||!chooseUpgrade(run,choice.id))return;
   $('upgrade').close();fx.clear();skillUI.clear();persist();render();showPreview(1);tiles[1].focus();$('notice').textContent=STAGES[run.stage].lesson;
  };$('choices').append(b);}if(!$('upgrade').open)$('upgrade').showModal();
 }else if(['complete','defeat'].includes(run.phase)){
  $('ending').className=run.phase==='complete'?'victory':'defeat';$('result').textContent=run.phase==='complete'?'세 정원에 빛이 돌아왔습니다':'다시 피어날 수 있어요';
  const stages=run.history.map(h=>`${h.stage+1}전투: ${h.turns}턴 · 잔향 ${h.echoes}회 · 재도전 ${run.retries[h.stage]}회`).join('\n');
  const upgrades=run.upgrades.map(id=>CHOICES.flat().find(c=>c.id===id).name).join(' / ')||'아직 없음';
  $('stats').textContent=`${stages}\n성장: ${upgrades}\n최대 연쇄 ${Math.max(...run.history.map(h=>h.maxChain),0)}`;
  $('retryBattle').hidden=run.phase!=='defeat';if(!$('ending').open)$('ending').showModal();
 }
}
const delay=ms=>new Promise(resolve=>setTimeout(resolve,reduced.matches?0:ms));
async function commit(i){
 if(blocked()||!canRunTap(run,i)||!gate.start())return;
 sound.unlock();
 try{
  const p=preview(state,i),oldHP=state.bossHP,positions=new Map(state.board.map((t,j)=>[t.id,fx.point(tiles[j])]));
  const bombs=p.removed.filter(j=>state.board[j].kind==='bomb');
  p.removed.forEach((j,n)=>{tiles[j].style.setProperty('--stagger',Math.min(n*9,90)+'ms');tiles[j].classList.add('cleared');if(n<12)fx.burst(tiles[j],state.board[j].color==='heal'?'#b6e8b4':'#ffe1b0');});
  if(p.echoHit)for(const j of p.removed)if(state.echo.includes(state.board[j].id))fx.link(tiles[i],tiles[j]);
  for(const j of bombs)fx.ring(tiles[j]);sound.play(bombs.length?'bomb':p.echoHit?'echo':'chain');
  await delay(180);
  const result=runTap(run,i);persist();render();
  if(!reduced.matches)state.board.forEach((t,j)=>{const old=positions.get(t.id),now=fx.point(tiles[j]),dy=old?old.y-now.y:-28;if(dy)tiles[j].animate([{translate:`0 ${dy}px`,opacity:old?1:0},{translate:'0 0',opacity:1}],{duration:200,easing:'cubic-bezier(.2,.7,.3,1)'});});
  if(state.bossHP<oldHP){fx.label($('enemy'),`−${oldHP-state.bossHP}`);$('enemy').classList.add('hit');setTimeout(()=>$('enemy').classList.remove('hit'),420);fx.link(tiles[i],$('enemy'),'#ffe4a9');}
  if(result.incoming){sound.play('enemy');const reaction=result.retaliation?'hurt':'guarded';$('health').classList.add(reaction);setTimeout(()=>$('health').classList.remove(reaction),420);}
  await delay(220);
  $('notice').textContent=`${result.removed.length}칸${result.unlocked.length?' · 덩굴 해제 '+result.unlocked.length:''}${result.echoHit?' · 잔향 발동':''}${bombs.length?' · 폭탄 '+bombs.length:''}${result.retaliation?' · 적 공격 −'+result.retaliation:''}${result.blocked?' · 보호 −'+result.blocked:''}${result.prismBonus?' · 링크 +'+result.prismBonus:''}${result.ignitionBonus?' · 점화 +'+result.ignitionBonus:''}${result.wardAbsorbed?' · 장막 −'+result.wardAbsorbed:''}`;
  if(run.phase!=='battle'){await delay(320);phaseDialog();}else tiles[focus].focus();
 }finally{gate.finish();if(run.phase==='battle')showPreview(focus);}
}
for(const [i,b] of tiles.entries()){
 b.addEventListener('focus',()=>showPreview(i));
 b.addEventListener('pointerdown',e=>{if(blocked()||e.button!==0)return;pressed={id:e.pointerId,i,x:e.clientX,y:e.clientY};showPreview(i);});
 b.addEventListener('pointerup',e=>{const p=pressed;pressed=null;if(p&&p.id===e.pointerId&&p.i===i&&Math.hypot(e.clientX-p.x,e.clientY-p.y)<12&&document.elementFromPoint(e.clientX,e.clientY)?.closest('.tile')===b)commit(i);});
 b.addEventListener('click',e=>{if(e.detail===0)commit(i);});
 b.addEventListener('keydown',e=>{if(e.repeat){e.preventDefault();return;}if(['ArrowUp','ArrowDown','ArrowLeft','ArrowRight'].includes(e.key)){e.preventDefault();if(!blocked()){focus=moveFocus(i,e.key);tiles[focus].focus();}}});
}
window.addEventListener('pointercancel',()=>pressed=null);window.addEventListener('pointerup',()=>pressed=null);
window.addEventListener('pointermove',e=>{if(pressed&&Math.hypot(e.clientX-pressed.x,e.clientY-pressed.y)>=12)pressed=null;});
document.querySelectorAll('[data-skill]').forEach(b=>b.onclick=()=>{
 if(blocked())return;sound.unlock();const ok=runSkill(run,Number(b.dataset.skill));persist();render();showPreview(focus);
 if(ok){skillUI.show(Number(b.dataset.skill));sound.play(['prism','ignite','garden'][Number(b.dataset.skill)]);fx.burst(b);b.classList.add('skill-used');setTimeout(()=>b.classList.remove('skill-used'),450);}
 $('notice').textContent=ok?'스킬 적용 · 탭 유지':'대상이 없거나 재충전 중입니다.';
});
$('boost').onclick=()=>{if(!blocked()&&runBoost(run)){sound.unlock();sound.play('boost');persist();render();showPreview(focus);fx.ring($('board'));$('notice').textContent='과충전 · 이번 턴 피해 2배';}};
function begin(fresh){
 fx.clear();skillUI.clear();pressed=null;run=createRun(fresh?crypto.getRandomValues(new Uint32Array(1))[0]:run.seed,!learned);state=run.state;started=true;sessionPlaying=true;
 for(const id of ['start','ending','confirmNew','upgrade'])if($(id).open)$(id).close();persist();render();showPreview(1);tiles[1].focus();$('notice').textContent=STAGES[0].lesson;
}
function askNew(fresh){if(gate.locked)return;pendingFresh=fresh;if(started&&['battle','upgrade'].includes(run.phase))$('confirmNew').showModal();else begin(fresh);}
$('restart').onclick=()=>askNew(false);$('newSeed').onclick=()=>askNew(true);$('again').onclick=()=>begin(false);$('another').onclick=()=>begin(true);
$('cancelNew').onclick=()=>$('confirmNew').close();$('confirmRestart').onclick=()=>begin(pendingFresh);
$('retryBattle').onclick=()=>{if(gate.locked||!retryBattle(run))return;$('ending').close();fx.clear();skillUI.clear();persist();render();showPreview(1);tiles[1].focus();$('notice').textContent='진입 당시 체력·게이지·보드로 재도전합니다.';};
$('skipLesson').onclick=()=>{skipTutorial(run);learned=true;persist();render();showPreview(focus);};
$('sound').onclick=()=>{sound.enable(!settings.enabled);persist();render();if(!sound.available)$('notice').textContent='이 환경에서는 음향을 사용할 수 없습니다. 플레이는 계속됩니다.';};
$('volume').oninput=e=>{sound.volume(Number(e.target.value)/100);persist();};
document.addEventListener('visibilitychange',()=>{if(document.hidden){pressed=null;sound.hide();}});
const guide=[['빛을 이어 주세요','같은 색·모양을 눌러 미리 보고 같은 자리에서 떼면 확정. 방향키 이동, Enter/Space 확정. 드래그하면 취소됩니다.'],['다음 빛을 남기세요','공격색 5개 이상이면 이웃에 ◌ 잔향. 다음 최초 연결에 표식이 있으면 이전 잔향 전체가 발동합니다. 놓쳐도 플레이는 계속됩니다.'],['세 정원을 복구하세요','3탭 후 회복·피해·예고 공격을 정산합니다. 스킬은 탭을 쓰지 않고 3턴 뒤 재사용. 게이지가 차면 턴 첫 탭 전 과충전. 승리하면 성장 하나를 선택하고 체력45 회복·게이지 유지로 다음 전투에 갑니다.'],['덩굴을 벗기세요',PANEL_HELP.vine+' 직접 누르면 탭을 쓰지 않습니다. 해제한 타일은 다음 행동부터 연결돼요.'],['무지개를 이으세요',PANEL_HELP.rainbow+' 동률이면 불꽃·별빛·물방울·회복 순입니다. 미리보기의 확정색을 확인하세요.']];
function tutorial(){const [title,body]=guide[guideStep];$('step').textContent=`규칙 ${guideStep+1}/${guide.length}`;$('guideTitle').textContent=title;$('guideText').textContent=body;$('guideNext').textContent=guideStep===guide.length-1?'돌아가기':'다음';if(!$('guide').open)$('guide').showModal();}
$('guideNext').onclick=()=>{if(guideStep<guide.length-1){guideStep++;tutorial();}else{$('guide').close();tiles[focus].focus();}};
$('skillHelp').onclick=()=>{if(!gate.locked)skillUI.describe();};$('closeSkills').onclick=()=>$('skillGuide').close();
$('help').onclick=()=>{if(!gate.locked){guideStep=0;tutorial();}};
$('continueRun').disabled=!started;$('continueRun').onclick=()=>{sessionPlaying=true;$('start').close();sound.unlock();render();phaseDialog();if(run.phase==='battle')tiles[focus].focus();};
$('startNew').onclick=()=>askNew(false);
$('loadNote').textContent=loaded.reason==='migrated'?'이전 저장을 보존해 이어갑니다. 새 스킬 효과는 재사용부터 적용되며, 이전 스킬 저장의 2전투 방어는 다음 턴부터, 새 패널은 다음 전투부터 적용됩니다.':loaded.reason==='invalid'?'저장 데이터 형식이 맞지 않아 새 탐험으로 시작합니다.':loaded.reason==='unavailable'?'저장소를 사용할 수 없지만 플레이할 수 있습니다.':'자동 저장 · 기본 무음 · 인터넷 불필요';
for(const id of ['start','upgrade'])$(id).addEventListener('cancel',e=>e.preventDefault());
render();$('start').showModal();
