import test from 'node:test';import assert from 'node:assert/strict';import {readFileSync} from 'node:fs';
import {createGame,preview,tap,adjacent,useSkill} from './engine.mjs';
import {createRun,runTap,chooseUpgrade,retryBattle} from './campaign.mjs';
import {createExpedition,enterRoom,expeditionTap,rewards,takeReward,decodeExpedition,relicEffects} from './expedition.mjs';
import {planTimeline} from './timeline.mjs';
import {decodeSave} from './storage.mjs';
import {MEGA_AT,blastTargets,prepareOpening} from './mechanics.mjs';
import {validFlowBoard} from './flow.mjs';
const encode=run=>JSON.stringify({version:1,run,learned:true,audio:{enabled:false,volume:.3}});
const opening=s=>s.board.findIndex((t,i)=>t.color==='coral'&&preview(s,i).initial.length>=MEGA_AT);
test('new fixed opening guarantees creation then use, vines and a rainbow bridge without RNG changes',()=>{
 for(let seed=1;seed<=30;seed++)for(const panelStage of [0,1,2]){
  const s=createGame(seed,{boardVersion:1,rulesVersion:1,panelStage}),rng=s.rng,coords=s.board.map(({id,x,y,r,angle})=>({id,x,y,r,angle}));
  prepareOpening(s);assert.equal(s.rng,rng);assert.deepEqual(s.board.map(({id,x,y,r,angle})=>({id,x,y,r,angle})),coords);
  assert(validFlowBoard(s.board));const i=opening(s);assert(i>=0);assert.equal(preview(s,i).initial.length,MEGA_AT);
  if(panelStage)assert(s.board.some((t,j)=>t.kind==='bomb'&&adjacent(s,j).some(k=>s.board[k].vine)));
  if(panelStage===2){const j=s.board.findIndex(t=>t.kind==='rainbow'),p=preview(s,j);assert.equal(p.color,'gold');assert.equal(p.initial.length,8);const split=structuredClone(s);split.board[j].kind='normal';split.board[j].color='blue';const gold=split.board.flatMap((t,i)=>t.color==='gold'?[i]:[]);assert.equal(gold.length,7);assert(gold.every(i=>[3,4].includes(preview(split,i).initial.length)));}
  const result=tap(s,i);assert.equal(result.special.kind,'mega');assert.equal(result.megas,0);const j=s.board.findIndex(t=>t.id===result.special.id);assert(j>=0);assert(preview(s,j).megas>=1);assert(tap(s,j).megas>=1);assert(validFlowBoard(s.board));
 }
});
test('three attribute ranges use frozen geometry; chained bombs and vines settle each ID once',()=>{
 for(const color of ['coral','gold','blue']){
  const s=createGame(5,{boardVersion:1,rulesVersion:1});s.board.forEach(t=>{t.color='heal';t.kind='normal';delete t.vine;});
  const i=s.board.findIndex(t=>Math.abs(t.x-210)<40&&t.y>200&&t.y<340);s.board[i].color=color;s.board[i].kind='mega';
  const targets=blastTargets(s,i,adjacent),p=preview(s,i);assert.deepEqual(new Set(p.removed),new Set([i,...targets]));assert.equal(p.megas,1);assert.equal(p.bombs,1);
  const next=targets[0],vine=targets[1];s.board[next].kind='bomb';s.board[next].color='blue';s.board[vine].vine=true;s.board[vine].color='blue';
  const copy=structuredClone(s),q=preview(s,i);assert.deepEqual(s,copy);assert(q.unlocked.includes(vine));assert(!q.removed.includes(vine));assert.equal(new Set(q.removed).size,q.removed.length);
  assert.deepEqual(tap(s,i).removed,q.removed);
 }
});
test('promotion counts only direct connections, retains tapped color/new ID; heal never promotes',()=>{
 const s=createGame(7,{boardVersion:1,rulesVersion:1});const i=opening(s),p=preview(s,i),next=s.nextID,color=p.color;const r=tap(s,i);assert.equal(r.special.id,next);assert.equal(r.special.color,color);assert.equal(r.megas,0);assert.equal(r.bombs,0);assert(s.board.some(t=>t.id===next&&t.kind==='mega'));
 const q=createGame(8,{boardVersion:1,rulesVersion:1});q.board.forEach(t=>{t.color='heal';t.kind='normal';delete t.vine;});const h=tap(q,0);assert.equal(h.special,null);assert.equal(h.damage,0);assert.equal(q.echo.length,0);
 const x=createGame(9,{boardVersion:1,rulesVersion:1});x.board.forEach(t=>{t.color='blue';t.kind='normal';});x.board[0].kind='mega';x.board[0].color='coral';x.echo=x.board.slice(1,9).map(t=>t.id);const z=preview(x,0);assert(!z.echoHit);assert(z.removed.length>z.initial.length);assert.equal(tap(x,0).special,null);
});
test('mega color is stable under prism; old bomb conversion still preserves identity and echo',()=>{
 const s=createGame(3,{boardVersion:1,rulesVersion:1});s.board[0].kind='mega';s.board[0].color='blue';const before=structuredClone(s.board[0]);assert(useSkill(s,0));assert.deepEqual(s.board[0],before);
});
test('overlapping megas count existing bombs once, cap ignition/relics, and never count the new bomb',()=>{
 const e=createExpedition(17,2,1,1);enterRoom(e,'0-0');const s=e.state;
 s.board.forEach((t,i)=>{t.color='blue';t.kind=i<3?'mega':'normal';delete t.vine;});
 s.buffs.ignition=true;s.echo=[s.board[1].id,s.board[2].id];e.relics=['powder'];
 const p=preview(s,0);assert.equal(p.bombs,3);assert.equal(p.megas,3);assert.equal(p.removed.length,42);assert.equal(p.ignitionBonus,30);assert.equal(p.damage,42*5+30);assert.equal(relicEffects(e,p).healing,9);
 const plan=planTimeline(s,0,p);assert(plan.events.every(x=>Number.isFinite(x.at)));const next=s.nextID,r=expeditionTap(e,0);assert.equal(r.bombs,3);assert.equal(r.special.id,next);assert.equal(r.special.kind,'mega');assert.equal(s.echoCount,1);assert.equal(s.healing,9);
});
test('stripe-hit vine timeline remains finite even when no adjacent tile is removed',()=>{
 const s=createGame(83,{boardVersion:1,rulesVersion:1,panelStage:1});s.board.forEach(t=>{t.kind='normal';t.color='heal';delete t.vine;});
 const i=20;s.board[i].kind='mega';s.board[i].color='gold';const target=blastTargets(s,i,adjacent).at(-1);s.board[target].vine=true;s.board[target].color='blue';
 const p=preview(s,i),plan=planTimeline(s,i,p);assert(p.unlocked.includes(target));assert(plan.events.every(x=>Number.isFinite(x.at)));assert(plan.total<=838);
});
test('new rules and mega survive both save modes; version forgery and heal mega rejected',()=>{
 const r=createRun(23,false,1,1);runTap(r,opening(r.state));assert.deepEqual(decodeSave(encode(r)).run,r);
 const e=createExpedition(23,2,1,1);enterRoom(e,'0-0');expeditionTap(e,opening(e.state));assert.deepEqual(decodeExpedition(JSON.stringify(e)),e);
 for(const mutate of [x=>delete x.rulesVersion,x=>x.rulesVersion=2,x=>delete x.state.rulesVersion,x=>x.state.board.find(t=>t.kind==='mega').color='heal']){
  const a=structuredClone(r);mutate(a);assert.equal(decodeSave(encode(a)),null);const b=structuredClone(e);mutate(b);assert.equal(decodeExpedition(JSON.stringify(b)),null);
 }
});
test('new rewards are deterministic, normal two/elite three, choose once, retry retains rules',()=>{
 const e=createExpedition(44,2,1,1);enterRoom(e,'0-0');e.state.damage=9999;e.state.taps=1;expeditionTap(e,0);assert.equal(rewards(e).length,2);assert(rewards(e).every(x=>['lens','bell','petal'].includes(x)));assert.deepEqual(decodeExpedition(JSON.stringify(e)),e);
 const id=rewards(e)[0];assert(takeReward(e,id));const copy=structuredClone(e);assert(!takeReward(e,id));assert.deepEqual(e,copy);enterRoom(e,'1-1');e.state.damage=9999;e.state.taps=1;expeditionTap(e,0);assert.equal(rewards(e).length,3);assert.deepEqual(decodeExpedition(JSON.stringify(e)),e);
 const r=createRun(44,false,1,1),entry=structuredClone(r.state);r.phase='defeat';r.state.status='lost';assert(retryBattle(r));assert.deepEqual(r.state,entry);
 r.state.damage=9999;r.state.taps=1;runTap(r,0);chooseUpgrade(r,'power');assert.equal(r.state.rulesVersion,1);assert.deepEqual(decodeSave(encode(r)).run,r);
});
const old=JSON.parse(readFileSync(new URL('./fixtures/pre-evolution-saves.json',import.meta.url)));
test('all pre-evolution flow saves roundtrip without introducing new rules or changing offers',()=>{
 for(const r of Object.values(old.practice))assert.deepEqual(decodeSave(encode(r)).run,r);
 for(const e of Object.values(old.expedition))assert.deepEqual(decodeExpedition(JSON.stringify(e)),e);
});
