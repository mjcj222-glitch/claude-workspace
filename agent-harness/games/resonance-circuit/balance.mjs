import {createRun,runTap,runSkill,runBoost,chooseUpgrade,nextAttack} from './campaign.mjs';
import {preview} from './engine.mjs';
export function simulate(seed,strategy='planned',choices=['power','healing']){
 const run=createRun(seed,false);let taps=0;
 while(taps<600&&['battle','upgrade'].includes(run.phase)){
  if(run.phase==='upgrade'){chooseUpgrade(run,choices[run.stage]);continue;}
  const s=run.state;
  if(strategy==='planned'){
   if(s.hp<s.rules.hp*.65||(s.taps===1&&nextAttack(run).damage>=30))runSkill(run,2);
   runSkill(run,0);runSkill(run,1);runBoost(run);
  }
  const scores=s.board.map((t,i)=>{const p=preview(s,i);if(strategy==='smallest')return -p.initial.length;
   if(strategy==='largest')return p.initial.length;
   return p.damage+Math.min(p.healing,Math.max(0,s.rules.hp-s.hp-s.healing))*1.3+(p.echoHit?12:0);
  });
  runTap(run,scores.indexOf(Math.max(...scores)));taps++;
 }
 return {seed,strategy,choices,result:run.phase,turns:run.history.map(h=>h.turns),echoes:run.history.map(h=>h.echoes),hp:run.state.hp,taps};
}
if(import.meta.url===`file://${process.argv[1]}`){
 for(const seed of [20261019,1,7,42,99,314,777,12345,98765,4294967295])for(const strategy of ['planned','largest','smallest'])console.log(JSON.stringify(simulate(seed,strategy)));
}
