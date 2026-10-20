import {flowNeighbors} from './flow.mjs';
export const MEGA_AT=8;
export const MEGA_NAMES={coral:'불꽃 · 주변 두 겹',gold:'별빛 · 가로 띠',blue:'물방울 · 세로 띠'};
export const isBomb=t=>t?.kind==='bomb'||t?.kind==='mega';
export function promotion(s,p){
 if(p.color==='heal'||p.initial.length<5)return null;
 return s.rulesVersion===1?(p.initial.length>=MEGA_AT?'mega':'charge'):(p.initial.length>=10?'bomb':'charge');
}
export function blastTargets(s,i,adjacent){
 const t=s.board[i];if(t.kind!=='mega')return adjacent(s,i);
 if(t.color==='coral')return [...new Set(adjacent(s,i).flatMap(j=>[j,...adjacent(s,j)]))].filter(j=>j!==i).sort((a,b)=>a-b);
 const axis=t.color==='gold'?'y':'x';
 return s.board.flatMap((u,j)=>j!==i&&Math.abs(t[axis]-u[axis])<=t.r+u.r*.5?[j]:[]);
}
// One bounded graph pass after settlement; no retries, RNG changes or movement.
export function prepareOpening(s){
 if(s.rulesVersion!==1)return;
 const b=s.board,adj=i=>flowNeighbors(b,i),reserved=new Set();
 for(const t of b){delete t.vine;t.kind='normal';}
 if(s.rules.panelStage===2){
  const order=b.map((t,i)=>i).sort((a,c)=>b[a].y-b[c].y||b[a].id-b[c].id);
  outer:for(const center of order)for(const a of adj(center))for(const c of adj(center)){
   if(a===c||adj(a).includes(c))continue;
   for(const t of b)if(t.color==='gold')t.color='blue';
   b[a].color=b[c].color='gold';b[center].kind='rainbow';b[center].color='coral';
   [center,a,c].forEach(i=>reserved.add(i));break outer;
  }
 }
 const order=b.map((t,i)=>i).filter(i=>!reserved.has(i)).sort((a,c)=>Math.hypot(b[a].x-210,b[a].y-300)-Math.hypot(b[c].x-210,b[c].y-300)||a-c);
 let cluster=[];
 // At most 42 finite BFS traversals; choose the first component with room for the lesson.
 for(const start of order){const found=new Set([start]),queue=[start];for(const i of queue)for(const j of adj(i))if(!reserved.has(j)&&!found.has(j)){found.add(j);queue.push(j);}
  if(queue.length>=MEGA_AT){cluster=queue.slice(0,MEGA_AT);break;}}
 const protectedTiles=new Set([...reserved,...cluster]);
 for(const i of cluster)b[i].color='coral';
 for(const i of cluster)for(const j of adj(i))if(!protectedTiles.has(j)&&b[j].color==='coral')b[j].color='blue';
 if(s.rules.panelStage){
  const candidates=order.filter(i=>!protectedTiles.has(i));
  const bomb=candidates.find(i=>adj(i).some(j=>!protectedTiles.has(j)&&j!==i));
  if(bomb!==undefined){b[bomb].kind='bomb';b[bomb].color='blue';protectedTiles.add(bomb);
   const vine=adj(bomb).find(i=>!protectedTiles.has(i));b[vine].vine=true;b[vine].color='blue';protectedTiles.add(vine);}
  for(const i of candidates)if(!protectedTiles.has(i)&&b.filter(t=>t.vine).length<4){b[i].vine=true;b[i].color='blue';}
 }
}
export function freshMechanics(){return {rulesVersion:1,megaSeen:[false,false],megaLesson:'create'};}
export function validMechanics(run){
 const v=run.rulesVersion??0;if(![0,1].includes(v)||v!==(run.state?.rulesVersion??0))return false;
 if(!v)return run.megaSeen===undefined&&run.megaLesson===undefined;
 return run.boardVersion===1&&Array.isArray(run.megaSeen)&&run.megaSeen.length===2&&run.megaSeen.every(v=>typeof v==='boolean')&&[null,'create','use'].includes(run.megaLesson)&&(!run.megaLesson||run.phase==='battle'||run.mode==='expedition'&&run.phase==='map'&&run.depth===0)&&!(run.megaLesson&&run.megaSeen[run.megaLesson==='create'?0:1]);
}
export function skipMega(run){if(run.megaLesson)run.megaSeen[run.megaLesson==='create'?0:1]=true;if(run.rulesVersion)run.megaLesson=null;}
export function advanceMega(run,result){
 if(run.rulesVersion!==1)return;
 if(result.special?.kind==='mega'){run.megaSeen[0]=true;if(!run.megaSeen[1])run.megaLesson='use';else run.megaLesson=null;}
 if(result.megas){run.megaSeen[1]=true;run.megaLesson=null;}
}
export function megaHelp(run){
 if(run.megaLesson==='use')return '대형 폭탄을 다음 탭에 연결하세요. 불꽃 주변 · 별빛 가로 · 물방울 세로.';
 return `공격색 ${MEGA_AT}개 직접 연결 → 같은 속성 대형 폭탄. 폭발·잔향 추가 수는 제외해요.`;
}
