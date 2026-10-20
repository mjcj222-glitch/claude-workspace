// Deterministic strategy probes, not a claim about human enjoyment or optimal play.
import {createExpedition,availableRooms,enterRoom,rewards,takeReward,resolveRoom,expeditionTap,expeditionSkill,relicEffects} from './expedition.mjs';
import {preview,overcharge} from './engine.mjs';
const strategies=['burst','echo','sustain','random'],seeds=Array.from({length:Number(process.argv[2]??4)},(_,i)=>41+i*7919);
const preferences={burst:['lens','powder','brooch'],echo:['bell','bottle','umbrella'],sustain:['petal','tea','umbrella'],random:[]};
for(const version of (process.argv[3]==='new'?[1]:[0,1]))for(const strategy of strategies)for(const seed of seeds){
 const e=createExpedition(seed,2,1,version);let count=0,made=0,used=0,chosen8=0,chosen10=0,opportunity8=0,opportunity10=0,rng=seed,compute=0,madeColors={coral:0,gold:0,blue:0},usedColors={coral:0,gold:0,blue:0};
 while(!['complete','defeat'].includes(e.phase)&&count<260){
  if(e.phase==='map'){enterRoom(e,availableRooms(e)[0].id);continue;}
  if(e.phase==='reward'){const ids=rewards(e);takeReward(e,preferences[strategy].find(id=>ids.includes(id))??ids[0]);continue;}
  if(e.phase==='room'){resolveRoom(e,'rest');continue;}
  const s=e.state;
  if(strategy!=='random'){
   if(s.hp<(strategy==='sustain'?150:110))expeditionSkill(e,2);
   const blueReady=strategy==='echo'&&s.board.some((t,i)=>t.color==='blue'&&preview(s,i).promotion==='mega');
   if(!blueReady&&(strategy!=='sustain'||s.hp>100))expeditionSkill(e,0);
   expeditionSkill(e,1);overcharge(s);
  }
  const choices=s.board.flatMap((t,i)=>{const p=preview(s,i);return p.initial.length?[{i,p,f:relicEffects(e,p)}]:[]});
  const maxDirect=Math.max(...choices.filter(c=>c.p.color!=='heal').map(c=>c.p.initial.length),0);
  opportunity8+=Number(maxDirect>=8);opportunity10+=Number(maxDirect>=10);
  let best;
  if(strategy==='random'){rng=(Math.imul(rng,1664525)+1013904223)>>>0;best=choices[rng%choices.length];}
  else best=choices.map(c=>({...c,score:c.p.damage+c.f.damage+Math.min(c.p.healing+c.f.healing,Math.max(0,180-s.hp-s.healing))*(strategy==='sustain'?3.3:1.5)+(c.p.echoHit?(strategy==='echo'?45:12):0)+(c.p.promotion==='mega'?(strategy==='burst'?30:14):0)+c.f.shield})).sort((a,b)=>b.score-a.score||a.i-b.i)[0];
  chosen8+=Number(best.p.color!=='heal'&&best.p.initial.length>=8);chosen10+=Number(best.p.color!=='heal'&&best.p.initial.length>=10);
  for(const i of best.p.removed)if(s.board[i].kind==='mega')usedColors[s.board[i].color]++;
  const start=performance.now(),result=expeditionTap(e,best.i);compute+=performance.now()-start;made+=Number(result.special?.kind==='mega');used+=result.megas??0;if(result.special?.kind==='mega')madeColors[result.special.color]++;count++;
 }
 console.log(JSON.stringify({version,strategy,seed,result:e.phase,taps:count,turns:e.total.turns,hp:e.state.hp,healed:e.total.healed,taken:e.total.taken,echoes:e.total.echoes,made,used,chosen8,chosen10,opportunity8,opportunity10,madeColors,usedColors,computeMs:Math.round(compute),relics:e.relics,rooms:e.log}));
}
