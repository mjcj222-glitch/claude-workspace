import test from 'node:test';
import assert from 'node:assert/strict';
import {C} from './config.mjs';
import {createRun,runTap,runSkill,runBoost,chooseUpgrade,retryBattle,nextAttack,tutorialTargets,skipTutorial,STAGES} from './campaign.mjs';
import {decodeSave,loadProgress,saveProgress,SAVE_KEY} from './storage.mjs';
import {createAudio} from './audio.mjs';
import {simulate} from './balance.mjs';
const settings={enabled:false,volume:.3};
const encoded=r=>JSON.stringify({version:1,run:r,learned:false,audio:settings});
function win(r){r.state.bossHP=1;r.state.damage=100;r.state.taps=1;return runTap(r,0);}
test('three battles, carry heal/gauge, upgrade effects and duplicate prevention',()=>{
 const r=createRun(7,false);r.state.hp=70;r.state.gauge=40;win(r);const hp=r.state.hp,gauge=r.state.gauge;
 assert.equal(r.phase,'upgrade');assert.equal(runTap(r,0),null);assert.equal(runSkill(r,0),false);assert(chooseUpgrade(r,'power'));assert.equal(chooseUpgrade(r,'power'),false);assert.equal(r.state.hp,Math.min(C.hp,hp+45));assert.equal(r.state.gauge,gauge);assert.equal(r.state.rules.attack,6);assert.equal(r.state.damage,0);assert.deepEqual(r.state.echo,[]);assert.equal(r.state.boost,false);assert.deepEqual(r.state.ready,[1,1,1]);
 win(r);assert(chooseUpgrade(r,'healing'));assert.equal(r.stage,2);assert.equal(r.state.rules.heal,9);win(r);assert.equal(r.phase,'complete');assert.equal(r.history.length,3);assert.equal(chooseUpgrade(r,'charge'),false);
});
test('all battles loss and exact checkpoint retry; no hidden heal or shuffle',()=>{
 const r=createRun(42,false);
 for(let i=0;i<3;i++){
  const original=structuredClone(r.state);r.state.hp=1;r.state.taps=1;r.state.board.forEach(t=>t.color='coral');r.state.damage=0;r.state.bossHP=10000;runTap(r,0);assert.equal(r.phase,'defeat');assert(retryBattle(r));assert.equal(retryBattle(r),false);assert.deepEqual(r.state,original);assert.equal(r.retries[i],1);win(r);if(i<2)chooseUpgrade(r,i===0?'vitality':'charge');
 }
 assert.equal(r.phase,'complete');assert.equal(r.state.rules.hp,230);assert.equal(r.state.rules.charge,44);
});
test('tutorial tracks surviving IDs, miss does not block and skip persists',()=>{
 const r=createRun();assert(tutorialTargets(r).length>=5);runTap(r,1);assert.equal(r.tutorial,'echo');const ids=[...r.tutorialIDs];assert(ids.every(id=>r.state.board.some(t=>t.id===id)));const target=tutorialTargets(r)[0];assert(ids.includes(r.state.board[target].id));runTap(r,target);assert.equal(r.tutorial,'done');
 const miss=createRun();assert(runTap(miss,41));skipTutorial(miss);assert.equal(miss.tutorial,'done');assert.deepEqual(miss.tutorialIDs,[]);
});
test('visible pattern and actual retaliation agree in every stage',()=>{
 const r=createRun(99,false);for(let stage=0;stage<3;stage++){
 for(let turn=1;turn<=6;turn++){r.state.turn=turn;r.state.taps=1;r.state.hp=10000;r.state.bossHP=10000;r.state.damage=0;const expected=nextAttack(r).damage;assert.equal(runTap(r,0).retaliation,expected);}
 win(r);if(stage<2)chooseUpgrade(r,stage===0?'power':'charge');
 }
});
test('roundtrip battle, tutorial, upgrades, ending, retries and audio; unknown fields stripped',()=>{
 const r=createRun();runTap(r,1);let s=decodeSave(encoded(r));assert.deepEqual(s.run,r);
 skipTutorial(r);win(r);assert.equal(decodeSave(encoded(r)).run.phase,'upgrade');chooseUpgrade(r,'power');r.hacked=true;s=decodeSave(encoded(r));assert.equal(s.run.hacked,undefined);win(r);chooseUpgrade(r,'charge');win(r);assert.equal(decodeSave(encoded(r)).run.phase,'complete');
});
test('reject corrupt, unsupported, out of range, duplicate tile, malformed rules and phases',()=>{
 assert.equal(decodeSave('{'),null);for(const change of [d=>d.version=2,d=>d.audio.volume=2,d=>d.run.stage=8,d=>d.run.state.board.pop(),d=>d.run.state.board[1].id=d.run.state.board[0].id,d=>d.run.state.hp=-1,d=>d.run.state.rng='oops',d=>d.run.phase='complete',d=>d.run.upgrades=['hacked'],d=>d.run.entry.hp=0]){const d=JSON.parse(encoded(createRun()));change(d);assert.equal(decodeSave(JSON.stringify(d)),null);}
 const d=JSON.parse(encoded(createRun()));d.run.state.rules.attack=999;assert.equal(decodeSave(JSON.stringify(d)).run.state.rules.attack,5);
});
test('storage errors never prevent run, learned and mute saved',()=>{
 const bad={getItem(){throw Error();},setItem(){throw Error();}};assert.equal(loadProgress(bad).reason,'unavailable');const r=createRun();assert.equal(saveProgress(bad,r,false,settings),false);assert(runTap(r,1));
 const memory=new Map(),storage={getItem:k=>memory.get(k),setItem:(k,v)=>memory.set(k,v)};assert(saveProgress(storage,r,true,{enabled:true,volume:.2}));assert.equal(loadProgress(storage).data.audio.enabled,true);assert.equal(loadProgress(storage).data.learned,true);memory.set(SAVE_KEY,'broken');assert.equal(loadProgress(storage).reason,'invalid');
});
test('seed restart deterministic; planned strategies complete several seeds, poor strategy loses',()=>{for(const seed of [1,7,42]){assert.deepEqual(createRun(seed),createRun(seed));assert.equal(simulate(seed).result,'complete');assert.equal(simulate(seed,'smallest').result,'defeat');}});
test('audio default off, gesture enable, bounded voices, hide stops, unavailable safe',()=>{
 let resumed=0,suspended=0,started=0,stopped=0;
 const param={setValueAtTime(){},exponentialRampToValueAtTime(){},linearRampToValueAtTime(){}};
 const context={state:'running',currentTime:0,destination:{},resume(){resumed++;return Promise.resolve();},suspend(){suspended++;return Promise.resolve();},createOscillator(){return {frequency:param,connect(){},disconnect(){},start(){started++;},stop(){stopped++;}};},createGain(){return {gain:param,connect(){},disconnect(){}};}};
 const opts={enabled:false,volume:.3},audio=createAudio(opts,{factory:()=>context});assert.equal(audio.play('chain'),false);assert.equal(resumed,0);audio.enable(true);assert.equal(resumed,1);for(let i=0;i<20;i++)audio.play('echo');assert(audio.voices<=8);assert(started>0);audio.hide();assert.equal(audio.voices,0);assert(stopped>0);assert(suspended>0);audio.volume(2);assert.equal(opts.volume,1);audio.enable(false);assert.equal(audio.play('bomb'),false);
 const unavailable=createAudio({enabled:true,volume:.3},{factory:()=>{throw Error();}});assert.equal(unavailable.unlock(),false);assert.equal(unavailable.play('chain'),false);
});
