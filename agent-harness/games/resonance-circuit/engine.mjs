import {isBomb,blastTargets,promotion,prepareOpening} from './mechanics.mjs';
import {FLOW,seedBodies,settleBodies,flowNeighbors,spatialFocus} from './flow.mjs';
import {panelSeed,initialPanels,refillPanels} from './panels.mjs';
import {C, COLORS} from './config.mjs';
import {freshBuffs,skillCandidates} from './skills.mjs';
export function neighbors(i) {
  const c=Math.floor(i/C.rows), r=i%C.rows, out=[];
  for(const [dc,dr] of [[0,-1],[0,1],[-1,0],[1,0],[-1,c%2?1:-1],[1,c%2?1:-1]]) {
    const x=c+dc,y=r+dr; if(x>=0&&x<C.cols&&y>=0&&y<C.rows) out.push(x*C.rows+y);
  } return out;
}
export function adjacent(s,i){return s.boardVersion===1?flowNeighbors(s.board,i):neighbors(i);}
function random(s) { s.rng=(Math.imul(s.rng,1664525)+1013904223)>>>0; return s.rng/4294967296; }
function tile(s,color) {return {id:s.nextID++,color:color??COLORS[Math.floor(random(s)*4)],kind:'normal'};}
export function createGame(seed=C.seed, overrides=null) {
 const s={seed:seed>>>0,rng:seed>>>0,nextID:1,board:[],echo:[],hp:C.hp,bossHP:C.bossHP,turn:1,taps:3,damage:0,healing:0,gauge:0,boost:false,ready:[1,1,1],status:'playing',maxChain:0,echoCount:0,buffs:freshBuffs(),wardBroken:false,panelRng:panelSeed(seed)};
 if(overrides?.rulesVersion===1)s.rulesVersion=1;
 if(overrides){s.rules={...C,...overrides};s.hp=s.rules.hp;s.bossHP=s.rules.bossHP;}
 s.board=Array.from({length:42},()=>tile(s));
 // A guaranteed opening cluster, next to surviving attack tiles.
 for(const i of [1,2,3,8,9,10]) s.board[i].color='coral';
 for(const i of [0,4,7,11,15,16,17]) s.board[i].color='blue';
 initialPanels(s);
 if(overrides?.boardVersion===1){s.boardVersion=1;s.board=seedBodies(s.board,s.seed);const start=s.board.findIndex(t=>!t.vine&&t.kind==='normal'),cluster=[start],seen=new Set(cluster);for(const i of cluster){for(const j of adjacent(s,i))if(!seen.has(j)&&!s.board[j].vine&&s.board[j].kind==='normal'&&cluster.length<6){seen.add(j);cluster.push(j);}if(cluster.length>=6)break;}for(const i of cluster)s.board[i].color='coral';}
 prepareOpening(s);
 return s;
}
function colorGroup(s,index,color){
 if(!s.board[index]||s.board[index].vine)return [];
 const found=new Set([index]),queue=[index];
 for(const i of queue)for(const n of adjacent(s,i)){const t=s.board[n];if(!found.has(n)&&!t.vine&&(t.color===color||t.kind==='rainbow')){found.add(n);queue.push(n);}}
 return queue;
}
function connection(s,index){
 const t=s.board[index];if(!t||t.vine)return {color:null,initial:[]};
 if(t.kind!=='rainbow')return {color:t.color,initial:colorGroup(s,index,t.color)};
 let best={color:'coral',initial:[]};
 for(const color of ['coral','gold','blue','heal']){const initial=colorGroup(s,index,color);if(initial.length>best.initial.length)best={color,initial};}
 return best;
}
export function group(s,index){return connection(s,index).initial;}
export function preview(s,index) {
 const {initial,color}=connection(s,index);
 if(!initial.length)return {initial:[],removed:[],unlocked:[],color:null,echoHit:false,bombs:0,prismBonus:0,ignitionBonus:0,damage:0,healing:0};
 const echoHit=initial.some(i=>s.echo.includes(s.board[i].id));
 const removed=new Set(initial),queue=[...initial],unlocked=new Set();
 const hit=i=>{if(s.board[i].vine){unlocked.add(i);return;}if(!removed.has(i)){removed.add(i);queue.push(i);}};
 if(echoHit)s.board.forEach((t,i)=>{if(s.echo.includes(t.id))hit(i);});
 for(const i of queue){
  for(const n of adjacent(s,i))if(s.board[n].vine)unlocked.add(n);
  if(isBomb(s.board[i]))for(const n of blastTargets(s,i,adjacent))hit(n);
 }
 const rules=s.rules??C,initialSet=new Set(initial);
 let damage=0,healing=0;
 for(const i of removed){const t=s.board[i],resolved=t.kind==='rainbow'?(initialSet.has(i)?color:'coral'):t.color;if(resolved==='heal')healing+=rules.heal;else damage+=rules.attack;if(t.kind==='charge')damage+=rules.charge;}
 const bombs=[...removed].filter(i=>isBomb(s.board[i])).length;const megas=[...removed].filter(i=>s.board[i].kind==='mega').length;
 const prismBonus=s.buffs?.prism&&color!=='heal'?(echoHit?24:12):0;
 const ignitionBonus=s.buffs?.ignition?Math.min(bombs,3)*10:0;
 return {initial,color,...(s.rulesVersion===1?{megas,promotion:promotion(s,{initial,color})}:{}),removed:[...removed],unlocked:[...unlocked].sort((a,b)=>a-b),echoHit,bombs,prismBonus,ignitionBonus,damage:damage*(s.boost?2:1)+prismBonus+ignitionBonus,healing};
}
export function pendingDamage(s){return s.rules?.echoWard&&!s.wardBroken?Math.floor(s.damage*.8):s.damage;}
export function tap(s,index) {
 if(s.status!=='playing'||!s.board[index]||s.board[index].vine) return null;
 const rules=s.rules??C;
 const p=preview(s,index), removed=new Set(p.removed), original=s.board;
 s.buffs??=freshBuffs();if(p.prismBonus)s.buffs.prism=false;if(p.ignitionBonus)s.buffs.ignition=false;
 if(rules.echoWard&&p.echoHit)s.wardBroken=true;
 const specialKind=promotion(s,p),make=!!specialKind;
 const candidates=new Set(p.initial.flatMap(i=>adjacent(s,i)));
 s.echo=make?[...candidates].sort((a,b)=>s.boardVersion===1?original[a].x-original[b].x||original[a].y-original[b].y||original[a].id-original[b].id:a-b).filter(i=>!removed.has(i)&&!original[i].vine&&original[i].kind==='normal'&&original[i].color!=='heal').slice(0,8).map(i=>original[i].id):[];
 for(const i of p.unlocked)delete original[i].vine;
 s.board=original.map((t,i)=>removed.has(i)?null:t);
 let special=null;
 if(make){special=tile(s,p.color);special.kind=specialKind;if(s.boardVersion===1)for(const k of ['x','y','r','angle'])special[k]=original[index][k];s.board[index]=special;}
 const refills=[];let flow=null;
 if(s.boardVersion===1){s.board=s.board.filter(Boolean);while(s.board.length<42){const t=tile(s);s.board.push(t);refills.push(t);}}else for(let c=0;c<C.cols;c++) {
   const survivors=s.board.slice(c*7,c*7+7).filter(Boolean), fresh=Array.from({length:7-survivors.length},()=>tile(s));
   refills.push(...fresh);s.board.splice(c*7,7,...fresh,...survivors);
 }
 refillPanels(s,refills);
 if(s.boardVersion===1){flow=settleBodies(s.board,s.seed,{trace:true});s.board=flow.board;}
 s.damage+=p.damage;s.healing+=p.healing;s.maxChain=Math.max(s.maxChain,p.removed.length);s.echoCount+=Number(p.echoHit);
 if(!s.boost)s.gauge=Math.min(C.gauge,s.gauge+p.removed.length);
 s.taps--;
 let retaliation=0,incoming=0,blocked=0,wardAbsorbed=0;
 if(s.taps===0){
   s.hp=Math.min(rules.hp,s.hp+s.healing);wardAbsorbed=s.damage-pendingDamage(s);s.bossHP=Math.max(0,s.bossHP-pendingDamage(s));
   if(s.bossHP===0)s.status='won';
   else {incoming=rules.attacks[(s.turn-1)%rules.attacks.length];blocked=Math.min(incoming,s.buffs.shield);retaliation=incoming-blocked;s.buffs.shield=0;s.hp=Math.max(0,s.hp-retaliation);if(!s.hp)s.status='lost';}
   if(s.status==='playing'){s.turn++;s.taps=3;s.damage=0;s.healing=0;s.boost=false;s.wardBroken=false;}
   else{s.buffs=freshBuffs();}
 }
 return {...p,special,retaliation,incoming,blocked,wardAbsorbed,...(flow?{flow}:{} )};
}
export function useSkill(s,k) {
 if(s.status!=='playing'||!Number.isInteger(k)||k<0||k>2||s.turn<s.ready[k])return false;
 const candidates=skillCandidates(s,k);
 if(!candidates.length)return false;
 for(const t of candidates){if(k===1)t.kind='bomb';else {t.color=k===0?'coral':'heal';if(k===2)s.echo=s.echo.filter(id=>id!==t.id);}}
 s.buffs??=freshBuffs();if(k===0)s.buffs.prism=true;else if(k===1)s.buffs.ignition=true;else s.buffs.shield=18;
 s.ready[k]=s.turn+C.cooldown;return true;
}
export function overcharge(s) {
 if(s.status!=='playing'||s.taps!==3||s.boost||s.gauge<C.gauge)return false;
 s.gauge=0;s.boost=true;return true;
}
export function inputGate() {let locked=false;return {get locked(){return locked;},start(){if(locked)return false;locked=true;return true;},finish(){locked=false;}};}

export function moveFocus(index,key,s=null) {
 if(s?.boardVersion===1)return spatialFocus(s.board,index,key);
 const col=Math.floor(index/C.rows), row=index%C.rows;
 const delta={ArrowUp:[0,-1],ArrowDown:[0,1],ArrowLeft:[-1,0],ArrowRight:[1,0]}[key];
 if(!delta)return index;
 return Math.max(0,Math.min(C.cols-1,col+delta[0]))*C.rows+Math.max(0,Math.min(C.rows-1,row+delta[1]));
}
