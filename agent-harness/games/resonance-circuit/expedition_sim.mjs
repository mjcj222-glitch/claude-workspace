import {createExpedition,availableRooms,enterRoom,expeditionTap,expeditionSkill,rewards,takeReward,resolveRoom,relicEffects,decodeExpedition} from './expedition.mjs';
import {preview,overcharge} from './engine.mjs';
export function strategyAction(e,strategy){
 if(e.phase==='map'){const choices=availableRooms(e);return enterRoom(e,strategy==='bold'?choices.at(-1).id:choices[0].id);}
 if(e.phase==='reward'){const rank=strategy==='bold'?['lens','petal','bottle','powder','bell','brooch','tea','umbrella']:['bell','powder','tea','umbrella','brooch','petal','lens','bottle'];return takeReward(e,rewards(e).sort((a,b)=>rank.indexOf(a)-rank.indexOf(b))[0]);}
 if(e.phase==='room')return resolveRoom(e,strategy==='bold'&&e.offer.length&&e.state.hp>75?'gift':'rest');
 if(e.phase==='battle'){
  const s=e.state;if(strategy==='weak'){let index=0,size=43;for(let i=0;i<42;i++){const p=preview(s,i);if(p.initial.length&&p.initial.length<size){size=p.initial.length;index=i;}}return expeditionTap(e,index);}if(s.hp<110)expeditionSkill(e,2);expeditionSkill(e,0);expeditionSkill(e,1);overcharge(s);
  let index=0,best=-Infinity;for(let i=0;i<42;i++){const p=preview(s,i);if(!p.initial.length)continue;const f=relicEffects(e,p),score=p.damage+f.damage+Math.min(p.healing+f.healing,Math.max(0,180-s.hp-s.healing))*(strategy==='bold'?1.2:1.7)+(p.echoHit?12:0)+f.shield*1.3+f.gauge*.7;if(score>best){best=score;index=i;}}
  return expeditionTap(e,index);
 }
}
if(process.argv[1]?.endsWith('expedition_sim.mjs')){
 const rows=[];for(const seed of [1,7,19,42,117,999,20261019,735])for(const strategy of ['safe','bold','weak']){const e=createExpedition(seed),relicTotals={damage:0,healing:0,gauge:0,shield:0};let actions=0;while(!['complete','defeat'].includes(e.phase)&&actions++<800){const result=strategyAction(e,strategy);if(result?.relic)for(const k of Object.keys(relicTotals))relicTotals[k]+=result.relic[k];if(!decodeExpedition(JSON.stringify(e)))throw Error(`save invalid ${seed} ${strategy} ${e.phase} ${actions}`);}rows.push({seed,strategy,phase:e.phase,hp:e.state.hp,path:e.path,relics:e.relics,relicTotals,...e.total});}console.log(JSON.stringify(rows,null,2));}
