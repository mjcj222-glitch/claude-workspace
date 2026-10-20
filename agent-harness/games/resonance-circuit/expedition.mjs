import {C,COLORS} from './config.mjs';
import {createGame,preview,tap,useSkill} from './engine.mjs';
import {createRun,skipTutorial,skipPanelLesson} from './campaign.mjs';
export const EXPEDITION_KEY='resonance-expedition-v1';
export const RELICS=[
 {id:'bell',name:'잔향 방울',text:'실제 잔향 발동: 보호6. 유물보호 최대12, 다음 반격에 소진.'},
 {id:'powder',name:'씨앗 화약',text:'소거한 기존 폭탄당 정산 회복3. 탭당 최대9.'},
 {id:'bottle',name:'무지개 병',text:'최초 연결에 무지개: 게이지5, 탭1회. 과충전 중 제외.'},
 {id:'tea',name:'덩굴 찻잎',text:'덩굴 해제당 정산 회복2. 탭당 최대6.'},
 {id:'lens',name:'긴빛 렌즈',text:'최초 연결8개 이상: 고정 피해16, 탭1회.'},
 {id:'petal',name:'꽃잎 변압기',text:'회복색 최초 연결4개 이상: 고정 피해12, 탭1회.'},
 {id:'brooch',name:'첫빛 브로치',text:'각 방 첫턴의 첫 성공스킬: 보호6, 방1회.'},
 {id:'umbrella',name:'반달 우산',text:'체력90 이하로 마지막 탭 시작: 보호6, 턴1회.'}
];
const legacyTypes=[['normal'],['normal','elite'],['rest','event'],['normal','elite'],['rest','event'],['boss']];
const types=[['normal'],['normal','elite'],['rest','event'],['midboss'],['rest','event'],['boss']];
export const COMBAT_TYPES=['normal','elite','midboss','boss'];
export function createExpedition(seed=C.seed,version=2){
 if(![1,2].includes(version))throw new RangeError('Unsupported expedition version');
 const e=createRun(seed,false);let rng=(seed^0xa3c59ac3)>>>0;const next=()=>rng=(Math.imul(rng,1664525)+1013904223)>>>0;
 e.version=version;e.mode='expedition';e.phase='map';e.depth=0;e.path=[];e.relics=[];e.shield=0;e.firstSkill=false;e.offer=[];e.log=[];e.total={turns:0,echoes:0,damage:0,taken:0,healed:0};
 e.map=(version===1?legacyTypes:types).map((row,depth)=>row.map((type,i)=>{const order=RELICS.map(r=>r.id);for(let j=order.length-1;j>0;j--){const k=next()%(j+1);[order[j],order[k]]=[order[k],order[j]];}return {id:`${depth}-${i}`,type,depth,seed:next(),order};}));return e;
}
export function roomRules(n){const stage=n.depth<1?0:n.depth<3?1:2,strong=['elite','midboss'].includes(n.type);return {...C,panelStage:stage,echoWard:strong,bossHP:n.type==='boss'?1000:n.depth===0?360:n.depth===1?(strong?600:500):(strong?780:650),attacks:n.type==='boss'?[16,24,34]:n.type==='midboss'?[14,22,26]:strong?[18,26]:[10,16]};}
export function currentRoom(e){return e.map.flat().find(n=>n.id===e.path.at(-1));}
export function availableRooms(e){return e.phase==='map'?(e.map[e.depth]??[]):[];}
export function enterRoom(e,id){
 const n=availableRooms(e).find(n=>n.id===id);if(!n)return false;e.path.push(id);e.offer=[];
 if(COMBAT_TYPES.includes(n.type)){
  const hp=e.state.hp,gauge=e.state.gauge;e.state=createGame(n.seed,roomRules(n));Object.assign(e.state,{hp,gauge});e.stage=e.state.rules.panelStage;e.phase='battle';e.shield=0;e.firstSkill=false;e.tutorial='done';e.panelLesson=e.stage&&!e.panelSeen[e.stage-1]?(e.stage===1?'vine':'rainbow'):null;
 }else {e.phase='room';e.offer=n.order.filter(id=>!e.relics.includes(id)).slice(0,1);}
 return true;
}
export function relicEffects(e,p){const has=id=>e.relics.includes(id);return {damage:(has('lens')&&p.initial.length>=8?16:0)+(has('petal')&&p.color==='heal'&&p.initial.length>=4?12:0),healing:(has('powder')?Math.min(3,p.bombs)*3:0)+(has('tea')?Math.min(3,p.unlocked.length)*2:0),gauge:has('bottle')&&!e.state.boost&&p.initial.some(i=>e.state.board[i].kind==='rainbow')?5:0,shield:(has('bell')&&p.echoHit?6:0)+(has('umbrella')&&e.state.taps===1&&e.state.hp<=90?6:0)};}
function heal(e,n){const amount=Math.min(180-e.state.hp,n);e.state.hp+=amount;e.total.healed+=amount;return amount;}
function advance(e){e.depth++;e.phase=e.depth===6?'complete':'map';e.offer=[];}
export function expeditionTap(e,index){
 if(e.phase!=='battle'||e.state.status!=='playing')return null;const s=e.state,p=preview(s,index);if(!p.initial.length)return null;
 const f=relicEffects(e,p),before=s.hp,boss=s.bossHP,ending=s.taps===1;e.shield=Math.min(12,e.shield+f.shield);s.damage+=f.damage;s.healing+=f.healing;if(ending)s.buffs.shield=Math.min(30,s.buffs.shield+e.shield);
 const actualHealing=ending?Math.min(180-before,s.healing+p.healing):0;const usedRainbow=p.initial.some(i=>s.board[i].kind==='rainbow'),result=tap(s,index);s.gauge=Math.min(C.gauge,s.gauge+f.gauge);result.relic=f;
 if(e.panelLesson==='vine'&&result.unlocked.length||e.panelLesson==='rainbow'&&usedRainbow)skipPanelLesson(e);
 if(ending){e.total.turns++;e.total.damage+=boss-s.bossHP;e.total.taken+=result.retaliation;e.total.healed+=actualHealing;}
 if(result.incoming||s.status!=='playing')e.shield=0;
 if(s.status!=='playing'){
  skipTutorial(e);e.log.push({id:currentRoom(e).id,turns:s.turn,echoes:s.echoCount,maxChain:s.maxChain,result:s.status});e.total.echoes+=s.echoCount;
  if(s.status==='lost'){e.phase='defeat';e.offer=[];}
  else if(currentRoom(e).type==='boss'){e.depth=6;e.phase='complete';}
  else {heal(e,['elite','midboss'].includes(currentRoom(e).type)?12:6);e.phase='reward';e.offer=currentRoom(e).order.filter(id=>!e.relics.includes(id)).slice(0,2);}
 }
 return result;
}
export function expeditionSkill(e,index){if(e.phase!=='battle'||!useSkill(e.state,index))return false;if(e.state.turn===1&&!e.firstSkill){e.firstSkill=true;if(e.relics.includes('brooch'))e.shield=Math.min(12,e.shield+6);}return true;}
export function rewards(e){if(e.phase!=='reward')return [];return e.relics.length===RELICS.length?['restore']:[...e.offer];}
export function takeReward(e,id){if(!rewards(e).includes(id))return false;if(id==='restore')heal(e,18);else if(!e.relics.includes(id))e.relics.push(id);else return false;advance(e);return true;}
export function resolveRoom(e,choice){
 if(e.phase!=='room')return false;const n=currentRoom(e);
 if(choice==='rest'){heal(e,n.type==='rest'?36:22);}else if(choice==='gift'&&n.type==='event'&&e.offer.length&&e.state.hp>18&&!e.relics.includes(e.offer[0])){e.state.hp-=18;e.relics.push(e.offer[0]);}else return false;
 e.log.push({id:n.id,choice});advance(e);return true;
}
const expInt=(n,a,b)=>Number.isInteger(n)&&n>=a&&n<=b;
export function decodeExpedition(raw){try{
 const e=JSON.parse(raw),s=e?.state;if(![1,2].includes(e?.version)||e.mode!=='expedition'||!expInt(e.seed,0,4294967295)||!['map','battle','reward','room','complete','defeat'].includes(e.phase)||!expInt(e.depth,0,6))return null;
 const generated=createExpedition(e.seed,e.version);if(JSON.stringify(e.map)!==JSON.stringify(generated.map))return null;
 if(!Array.isArray(e.path)||e.path.length>6||e.path.some((id,d)=>!e.map[d].some(n=>n.id===id))||e.path.length!==e.depth+(['battle','reward','room','defeat'].includes(e.phase)?1:0))return null;
 if(!Array.isArray(e.relics)||new Set(e.relics).size!==e.relics.length||e.relics.some(id=>!RELICS.some(r=>r.id===id))||!expInt(e.shield,0,12)||typeof e.firstSkill!=='boolean')return null;
 if(!Array.isArray(e.offer)||e.offer.length>2||new Set(e.offer).size!==e.offer.length||e.offer.some(id=>!RELICS.some(r=>r.id===id)||e.relics.includes(id)))return null;
 if(!e.total||Object.keys(e.total).sort().join(',')!=='damage,echoes,healed,taken,turns'||Object.values(e.total).some(v=>!expInt(v,0,10000000))||!Array.isArray(e.log)||e.log.length>6)return null;
 if(!Array.isArray(e.panelSeen)||e.panelSeen.length!==2||e.panelSeen.some(v=>typeof v!=='boolean')||![null,'vine','rainbow'].includes(e.panelLesson)||!['done'].includes(e.tutorial))return null;
 const battleNode=[...e.path].reverse().map(id=>e.map.flat().find(n=>n.id===id)).find(n=>COMBAT_TYPES.includes(n.type));const rules=battleNode?roomRules(battleNode):generated.state.rules;
 if(!s||!expInt(s.seed,0,4294967295)||s.seed!==(battleNode?.seed??e.seed)||!expInt(s.rng,0,4294967295)||!expInt(s.panelRng,0,4294967295)||!expInt(s.nextID,43,1000000)||!expInt(s.hp,0,180)||!expInt(s.bossHP,0,rules.bossHP)||!expInt(s.turn,1,10000)||!expInt(s.taps,0,3)||!expInt(s.gauge,0,55)||typeof s.boost!=='boolean'||typeof s.wardBroken!=='boolean')return null;
 if(!['playing','won','lost'].includes(s.status)||!s.buffs||typeof s.buffs.prism!=='boolean'||typeof s.buffs.ignition!=='boolean'||![0,18].includes(s.buffs.shield))return null;
 if(!Array.isArray(s.board)||s.board.length!==42||s.board.some(t=>!expInt(t.id,1,s.nextID-1)||!COLORS.includes(t.color)||!['normal','charge','bomb','rainbow'].includes(t.kind)||t.vine!==undefined&&typeof t.vine!=='boolean'||t.vine&&(t.kind!=='normal'||t.color==='heal'))||new Set(s.board.map(t=>t.id)).size!==42)return null;
 if(s.board.filter(t=>t.vine).length>4||s.board.filter(t=>t.kind==='rainbow').length>2||s.board.some(t=>t.vine&&!rules.panelStage||t.kind==='rainbow'&&rules.panelStage!==2))return null;
 if(!Array.isArray(s.echo)||s.echo.length>8||new Set(s.echo).size!==s.echo.length||s.echo.some(id=>!s.board.some(t=>t.id===id&&!t.vine&&t.color!=='heal'&&t.kind!=='rainbow')))return null;
 if(!Array.isArray(s.ready)||s.ready.length!==3||s.ready.some(v=>!expInt(v,1,s.turn+3)))return null;
 for(const k of ['damage','healing','echoCount','maxChain'])if(!expInt(s[k],0,1000000))return null;
 if(e.phase==='battle'&&(s.status!=='playing'||!s.hp||!s.bossHP||!s.taps))return null;
 if(e.phase==='defeat'&&(s.status!=='lost'||s.hp!==0||s.taps!==0))return null;
 if(e.phase==='complete'&&(e.depth!==6||s.status!=='won'||s.bossHP!==0))return null;
 if(e.phase==='reward'&&(s.status!=='won'||s.bossHP!==0))return null;
 if(!['defeat'].includes(e.phase)&&!s.hp)return null;
 const n=currentRoom(e);if(e.phase==='room'&&!['rest','event'].includes(n?.type))return null;
 if(['battle','reward'].includes(e.phase)&&!COMBAT_TYPES.includes(n?.type))return null;
 if(e.phase==='map'&&e.depth===6)return null;
 if(e.phase==='reward'&&JSON.stringify(e.offer)!==JSON.stringify(n.order.filter(id=>!e.relics.includes(id)).slice(0,2)))return null;
 if(!expInt(e.stage,0,2)||e.stage!==(rules.panelStage??0))return null;
 if(e.panelLesson&&(e.phase!=='battle'||e.stage!==(e.panelLesson==='vine'?1:2)||e.panelSeen[e.stage-1]))return null;
 if(e.log.some(h=>!h||!e.path.includes(h.id)||h.choice!==undefined&&!['rest','gift'].includes(h.choice)||h.result!==undefined&&(!['won','lost'].includes(h.result)||!expInt(h.turns,1,10000)||!expInt(h.echoes,0,1000000)||!expInt(h.maxChain,0,42)))||new Set(e.log.map(h=>h.id)).size!==e.log.length)return null;
 if(e.phase==='room'&&JSON.stringify(e.offer)!==JSON.stringify(n.order.filter(id=>!e.relics.includes(id)).slice(0,1)))return null;
 s.rules=rules;return e;
 }catch{return null;}}
export function saveExpedition(storage,e){try{const raw=JSON.stringify(e);if(!decodeExpedition(raw))return false;storage.setItem(EXPEDITION_KEY,raw);return true;}catch{return false;}}
export function loadExpedition(storage){try{return decodeExpedition(storage.getItem(EXPEDITION_KEY));}catch{return null;}}
