import {RELICS,availableRooms,currentRoom,roomRules,enterRoom,rewards,takeReward,resolveRoom} from './expedition.mjs';
export const ROOM_NAMES={normal:'새싹 수호자',elite:'정예 · 수정 파수꾼',rest:'이슬 쉼터',event:'종이새의 선물',boss:'최종 · 온실의 여왕'};
export function roomDescription(n){if(n.type==='rest')return '안전 · 체력36 회복 (최대180)';if(n.type==='event')return '선택 · 체력18을 유물로 / 체력22 회복';const r=roomRules(n);return `적 체력${r.bossHP} · 반격 ${r.attacks.join('→')}${r.echoWard?' · 장막20%, 잔향으로 해제':''} · ${n.type==='boss'?'탐험 완주':`승리 회복${n.type==='elite'?12:6} + 유물 선택`}`;}
export function createExpeditionUI(getRun,onChange){
 const $=id=>document.getElementById(id);
 function button(text,description,action){const b=document.createElement('button'),strong=document.createElement('strong'),small=document.createElement('small');strong.textContent=text;small.textContent=description;b.append(strong,small);b.onclick=()=>{if(action())onChange();};return b;}
 function render(){
  const e=getRun();if(!e||e.mode!=='expedition')return;
  $('journeyHealth').textContent=`체력 ${e.state.hp}/180 · 보호 ${e.shield} · 시드 ${e.seed}`;
  $('journeyTitle').textContent=e.phase==='reward'?'빛의 유물 하나를 골라요':e.phase==='room'?ROOM_NAMES[currentRoom(e).type]:'다음 정원으로';
  $('journeyHint').textContent=e.phase==='map'?'한 층에서 한 길만 선택해요. 선택 전 위험과 보상을 확인하세요.':e.phase==='reward'?'미소유 유물만 제시합니다. 선택하면 다음 층으로 이어집니다.':'결과를 확인하고 한 번만 선택하세요.';
  $('routeRows').replaceChildren();
  for(const [d,row] of e.map.entries()){const line=document.createElement('div');line.className='route-row';const label=document.createElement('span');label.textContent=`${d+1}`;line.append(label);for(const n of row){const selected=e.path.includes(n.id),available=availableRooms(e).some(r=>r.id===n.id);const b=button(`${selected?'✓ ':d<e.path.length?'— ':''}${ROOM_NAMES[n.type]}`,roomDescription(n),()=>enterRoom(e,n.id));b.dataset.room=n.id;b.dataset.route=selected?'chosen':d<e.path.length?'missed':available?'available':'future';b.disabled=!available;b.setAttribute('aria-label',`${d+1}층 ${ROOM_NAMES[n.type]}. ${roomDescription(n)}. ${selected?'선택한 길':d<e.path.length?'지나간 다른 길':available?'진입 가능':'아직 잠김'}`);line.append(b);}$('routeRows').append(line);}
  $('roomChoices').replaceChildren();
  if(e.phase==='reward')for(const id of rewards(e)){const relic=RELICS.find(r=>r.id===id);const b=button(relic?.name??'유물 모두 보유',relic?.text??'대체 보상: 체력18 회복 (최대180)',()=>takeReward(e,id));b.dataset.reward=id;$('roomChoices').append(b);}
  if(e.phase==='room'){const n=currentRoom(e);if(n.type==='event'&&e.offer.length){const relic=RELICS.find(r=>r.id===e.offer[0]),b=button(`${relic.name} 받기 · 체력−18`,relic.text,()=>resolveRoom(e,'gift'));b.dataset.event='gift';b.disabled=e.state.hp<=18;$('roomChoices').append(b);}const b=button(n.type==='rest'?'잠깐 쉬어 가기':'따뜻한 차 마시기',`체력 +${n.type==='rest'?36:22}, 최대180${n.type==='event'&&!e.offer.length?' · 유물 모두 보유':''}`,()=>resolveRoom(e,'rest'));b.dataset.event='rest';$('roomChoices').append(b);}
  $('journeyRelics').textContent=e.relics.length?e.relics.map(id=>RELICS.find(r=>r.id===id).name).join(' · '):'아직 유물이 없어요. 첫 전투를 마치면 선택합니다.';
  if(['map','reward','room'].includes(e.phase)&&!$('journey').open)$('journey').showModal();
  if(!['map','reward','room'].includes(e.phase)&&$('journey').open)$('journey').close();
 }
 function describe(){const e=getRun();$('relicList').replaceChildren();for(const r of RELICS){const p=document.createElement('p'),strong=document.createElement('strong');strong.textContent=(e.relics.includes(r.id)?'✓ ':'')+r.name;p.append(strong,document.createElement('br'),document.createTextNode(r.text));$('relicList').append(p);}$('relicGuide').showModal();}
 return {render,describe};
}
