// Independent stream: panel decoration never advances the ordinary refill RNG.
export function panelSeed(seed){return (seed^0x9e3779b9)>>>0;}
function panelRandom(s){s.panelRng=(Math.imul(s.panelRng,1664525)+1013904223)>>>0;return s.panelRng/4294967296;}
export function initialPanels(s){
 if(!s.rules?.panelStage)return;
 const protectedCells=new Set([0,1,2,3,4,7,8,9,10,11,15,16,17]);
 const candidates=s.board.map((t,i)=>({t,i})).filter(({t,i})=>!protectedCells.has(i)&&t.color!=='heal').map(x=>({...x,rank:panelRandom(s)})).sort((a,b)=>a.rank-b.rank||a.i-b.i);
 candidates.slice(0,4).forEach(({t})=>t.vine=true);
 if(s.rules.panelStage===2)candidates.slice(4,6).forEach(({t})=>{t.kind='rainbow';t.color='coral';});
}
export function refillPanels(s,tiles){
 if(!s.rules?.panelStage)return;
 let vines=s.board.filter(t=>t.vine).length,rainbows=s.board.filter(t=>t.kind==='rainbow').length;
 for(const t of tiles){const roll=panelRandom(s);
  if(roll<.08){if(vines<4&&t.color!=='heal'){t.vine=true;vines++;}}
  else if(roll<.14&&s.rules.panelStage===2&&rainbows<2){t.kind='rainbow';t.color='coral';rainbows++;}
 }
}
