import {C, COLORS} from './config.mjs';
export function neighbors(i) {
  const c=Math.floor(i/C.rows), r=i%C.rows, out=[];
  for(const [dc,dr] of [[0,-1],[0,1],[-1,0],[1,0],[-1,c%2?1:-1],[1,c%2?1:-1]]) {
    const x=c+dc,y=r+dr; if(x>=0&&x<C.cols&&y>=0&&y<C.rows) out.push(x*C.rows+y);
  } return out;
}
function random(s) { s.rng=(Math.imul(s.rng,1664525)+1013904223)>>>0; return s.rng/4294967296; }
function tile(s,color) {return {id:s.nextID++,color:color??COLORS[Math.floor(random(s)*4)],kind:'normal'};}
export function createGame(seed=C.seed) {
 const s={seed:seed>>>0,rng:seed>>>0,nextID:1,board:[],echo:[],hp:C.hp,bossHP:C.bossHP,turn:1,taps:3,damage:0,healing:0,gauge:0,boost:false,ready:[1,1,1],status:'playing',maxChain:0,echoCount:0};
 s.board=Array.from({length:42},()=>tile(s));
 // A guaranteed opening cluster, next to surviving attack tiles.
 for(const i of [1,2,3,8,9,10]) s.board[i].color='coral';
 for(const i of [0,4,7,11,15,16,17]) s.board[i].color='blue';
 return s;
}
export function group(s,index) {
 if(!s.board[index]) return [];
 const found=new Set([index]), queue=[index], color=s.board[index].color;
 for(const i of queue) for(const n of neighbors(i)) if(!found.has(n)&&s.board[n].color===color){found.add(n);queue.push(n);}
 return queue;
}
export function preview(s,index) {
 const initial=group(s,index); if(!initial.length) return {initial:[],removed:[],echoHit:false,damage:0,healing:0};
 const echoHit=initial.some(i=>s.echo.includes(s.board[i].id));
 const removed=new Set(initial), queue=[...initial];
 if(echoHit) s.board.forEach((t,i)=>{if(s.echo.includes(t.id)&&!removed.has(i)){removed.add(i);queue.push(i);}});
 for(const i of queue) if(s.board[i].kind==='bomb') for(const n of neighbors(i)) if(!removed.has(n)){removed.add(n);queue.push(n);}
 let damage=0,healing=0;
 for(const i of removed){const t=s.board[i]; if(t.color==='heal') healing+=C.heal; else damage+=C.attack; if(t.kind==='charge') damage+=C.charge;}
 return {initial,removed:[...removed],echoHit,damage:damage*(s.boost?2:1),healing};
}
export function tap(s,index) {
 if(s.status!=='playing'||!s.board[index]) return null;
 const p=preview(s,index), removed=new Set(p.removed), original=s.board, selected=original[index];
 const make=selected.color!=='heal'&&p.initial.length>=5;
 const candidates=new Set(p.initial.flatMap(neighbors));
 s.echo=make?[...candidates].sort((a,b)=>a-b).filter(i=>!removed.has(i)&&original[i].kind==='normal'&&original[i].color!=='heal').slice(0,8).map(i=>original[i].id):[];
 s.board=original.map((t,i)=>removed.has(i)?null:t);
 let special=null;
 if(make){special=tile(s,selected.color);special.kind=p.initial.length>=10?'bomb':'charge';s.board[index]=special;}
 for(let c=0;c<C.cols;c++) {
   const survivors=s.board.slice(c*7,c*7+7).filter(Boolean), fresh=Array.from({length:7-survivors.length},()=>tile(s));
   s.board.splice(c*7,7,...fresh,...survivors);
 }
 s.damage+=p.damage;s.healing+=p.healing;s.maxChain=Math.max(s.maxChain,p.removed.length);s.echoCount+=Number(p.echoHit);
 if(!s.boost)s.gauge=Math.min(C.gauge,s.gauge+p.removed.length);
 s.taps--;
 let retaliation=0;
 if(s.taps===0){
   s.hp=Math.min(C.hp,s.hp+s.healing);s.bossHP=Math.max(0,s.bossHP-s.damage);
   if(s.bossHP===0)s.status='won';
   else {retaliation=C.attacks[(s.turn-1)%2];s.hp=Math.max(0,s.hp-retaliation);if(!s.hp)s.status='lost';}
   if(s.status==='playing'){s.turn++;s.taps=3;s.damage=0;s.healing=0;s.boost=false;}
 }
 return {...p,special,retaliation};
}
export function useSkill(s,k) {
 if(s.status!=='playing'||!Number.isInteger(k)||k<0||k>2||s.turn<s.ready[k])return false;
 let candidates=s.board.filter(t=>k===0?t.color==='blue':t.kind==='normal'&&t.color!=='heal');
 if(k>0)candidates=candidates.slice(0,k===1?2:6);
 if(!candidates.length)return false;
 for(const t of candidates){if(k===1)t.kind='bomb';else {t.color=k===0?'coral':'heal';if(k===2)s.echo=s.echo.filter(id=>id!==t.id);}}
 s.ready[k]=s.turn+C.cooldown;return true;
}
export function overcharge(s) {
 if(s.status!=='playing'||s.taps!==3||s.boost||s.gauge<C.gauge)return false;
 s.gauge=0;s.boost=true;return true;
}
export function inputGate() {let locked=false;return {get locked(){return locked;},start(){if(locked)return false;locked=true;return true;},finish(){locked=false;}};}

export function moveFocus(index,key) {
 const col=Math.floor(index/C.rows), row=index%C.rows;
 const delta={ArrowUp:[0,-1],ArrowDown:[0,1],ArrowLeft:[-1,0],ArrowRight:[1,0]}[key];
 if(!delta)return index;
 return Math.max(0,Math.min(C.cols-1,col+delta[0]))*C.rows+Math.max(0,Math.min(C.rows-1,row+delta[1]));
}
