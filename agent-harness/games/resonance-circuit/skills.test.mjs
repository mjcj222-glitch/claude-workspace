import test from 'node:test';
import assert from 'node:assert/strict';
import {createGame,preview,tap,useSkill,overcharge} from './engine.mjs';
import {createRun,runTap,runSkill,chooseUpgrade,retryBattle} from './campaign.mjs';
import {decodeSave} from './storage.mjs';
const empty={prism:false,ignition:false,shield:0};
function fixture(){const s=createGame(7);s.board.forEach((t,i)=>{t.color=['blue','gold','heal'][(Math.floor(i/7)+i%7)%3];t.kind='normal';});return s;}
function saved(r){return JSON.stringify({version:1,run:r,learned:true,audio:{enabled:false,volume:.3}});}
test('prism augments existing conversion, preview is pure, next attack only, echo doubles fixed bonus',()=>{
 const s=fixture();assert(useSkill(s,0));assert.equal(s.buffs.prism,true);const heal=s.board.findIndex(t=>t.color==='heal');assert.equal(preview(s,heal).prismBonus,0);tap(s,heal);assert(s.buffs.prism);
 const i=s.board.findIndex(t=>t.color!=='heal');s.echo=[s.board[i].id];const before=structuredClone(s);const p=preview(s,i);assert.equal(p.prismBonus,24);assert.deepEqual(s,before);tap(s,i);assert.equal(s.buffs.prism,false);assert.equal(preview(s,0).prismBonus,0);
});
test('ignition requires actual pre-existing bomb, overlaps count once, cap three',()=>{
 const s=fixture();assert(useSkill(s,1));assert(s.buffs.ignition);const heal=s.board.findIndex(t=>t.color==='heal');
 for(const t of s.board)t.kind='normal';tap(s,heal);assert(s.buffs.ignition);
 s.board.forEach(t=>{t.color='coral';t.kind='bomb';});const p=preview(s,0);assert.equal(p.bombs,42);assert.equal(p.ignitionBonus,30);const r=tap(s,0);assert.equal(r.ignitionBonus,30);assert.equal(s.buffs.ignition,false);
});
test('new special is not ignition event and pending ignition survives normal taps',()=>{
 const s=fixture();useSkill(s,1);s.board.forEach(t=>{t.color='coral';t.kind='normal';});const r=tap(s,0);assert.equal(r.special.kind,'bomb');assert.equal(r.bombs,0);assert.equal(r.ignitionBonus,0);assert(s.buffs.ignition);
});
test('shield applies once after healing, floor zero, announced raw attack preserved',()=>{
 const s=fixture();s.rules={hp:180,bossHP:9999,attack:5,heal:6,charge:24,attacks:[14,40]};s.bossHP=9999;assert(useSkill(s,2));s.taps=1;s.hp=1;s.healing=8;const r=tap(s,0);assert.equal(r.incoming,14);assert.equal(r.blocked,14);assert.equal(r.retaliation,0);assert.equal(s.buffs.shield,0);assert(s.hp>=9);
 s.taps=1;const r2=tap(s,0);assert.equal(r2.incoming,40);assert.equal(r2.blocked,0);assert.equal(r2.retaliation,40);
});
test('zero candidates spend neither cooldown nor buff; reapply refreshes without stacking',()=>{
 for(let k=0;k<3;k++){const s=fixture();s.board.forEach(t=>t.color='heal');const before=structuredClone(s);assert.equal(useSkill(s,k),false);assert.deepEqual(s,before);}
 const s=fixture();useSkill(s,2);assert.equal(useSkill(s,2),false);s.turn=4;assert(useSkill(s,2));assert.equal(s.buffs.shield,18);assert.equal(s.ready[2],7);
});
test('overcharge doubles base damage only, prism/ignition stay additive',()=>{
 const s=fixture();useSkill(s,0);useSkill(s,1);s.echo=[s.board[0].id];const a=preview(s,0);s.gauge=55;assert(overcharge(s));const b=preview(s,0);assert.equal(b.damage,(a.damage-a.prismBonus-a.ignitionBonus)*2+a.prismBonus+a.ignitionBonus);assert.equal(b.prismBonus,a.prismBonus);assert.equal(b.ignitionBonus,a.ignitionBonus);
});
test('all buffs expire on win/loss, transition and exact checkpoint retry',()=>{
 const r=createRun(7,false);runSkill(r,0);runSkill(r,1);runSkill(r,2);r.state.bossHP=1;r.state.damage=100;r.state.taps=1;runTap(r,0);assert.deepEqual(r.state.buffs,empty);chooseUpgrade(r,'power');assert.deepEqual(r.state.buffs,empty);
 runSkill(r,0);runSkill(r,1);runSkill(r,2);r.state.hp=1;r.state.healing=0;r.state.board.forEach(t=>t.color='coral');r.state.turn=2;r.state.taps=1;r.state.bossHP=9999;runTap(r,0);assert.equal(r.phase,'defeat');assert.deepEqual(r.state.buffs,empty);retryBattle(r);assert.deepEqual(r.state.buffs,empty);
});
test('save restores pending buffs, accepts old v1 without fields, rejects malformed fields',()=>{
 const r=createRun(42,false);runSkill(r,0);runSkill(r,1);runSkill(r,2);assert.deepEqual(decodeSave(saved(r)).run.state.buffs,r.state.buffs);
 const old=JSON.parse(saved(r));delete old.run.state.buffs;delete old.run.state.wardBroken;const restored=decodeSave(JSON.stringify(old));assert(restored);assert.deepEqual(restored.run.state.buffs,empty);assert.equal(restored.run.state.wardBroken,false);assert.deepEqual(restored.run.state.board,r.state.board);assert.deepEqual(restored.run.state.ready,r.state.ready);
 for(const bad of [null,{prism:1,ignition:false,shield:0},{prism:false,ignition:false,shield:99}]){const d=JSON.parse(saved(r));d.run.state.buffs=bad;assert.equal(decodeSave(JSON.stringify(d)),null);}
});
test('stage-two ward is partial, echo removes it for entire turn, resets next turn',()=>{
 const r=createRun(7,false);r.state.bossHP=1;r.state.damage=100;r.state.taps=1;runTap(r,0);chooseUpgrade(r,'power');assert.equal(r.state.rules.echoWard,true);
 const s=r.state;s.taps=1;s.damage=100;s.bossHP=1100;s.echo=[];const p=preview(s,0),result=runTap(r,0);assert.equal(result.wardAbsorbed,Math.ceil((100+p.damage)*.2));assert.equal(s.wardBroken,false);
 s.echo=[s.board[0].id];runTap(r,0);assert(s.wardBroken);s.taps=1;const end=runTap(r,0);assert.equal(end.wardAbsorbed,0);assert.equal(s.wardBroken,false);
});
test('failed use preserves already pending buffs and cooldown, retry refresh is not additive',()=>{
 const s=fixture();useSkill(s,0);useSkill(s,1);useSkill(s,2);s.turn=4;s.board.forEach(t=>t.color='heal');
 for(let k=0;k<3;k++){const before=structuredClone(s);assert.equal(useSkill(s,k),false);assert.deepEqual(s,before);}
 s.board[0].color='blue';assert(useSkill(s,0));assert.equal(preview(s,0).prismBonus,12);assert.equal(s.buffs.shield,18);
});
test('save after consuming bonuses on second/third tap never awards them again',()=>{
 for(const taps of [2,1]){
  const r=createRun(7,false);runSkill(r,0);runSkill(r,1);r.state.taps=taps;
  const p=runTap(r,0);assert(p.prismBonus>0&&p.ignitionBonus>0);
  const restored=decodeSave(saved(r)).run;assert.equal(restored.state.buffs.prism,false);assert.equal(restored.state.buffs.ignition,false);
  const a=runTap(r,0),b=runTap(restored,0);assert.deepEqual(a,b);assert.equal(b.prismBonus,0);assert.equal(b.ignitionBonus,0);assert.deepEqual(restored,r);
 }
});
test('winning turn expires shield without reporting a blocked retaliation',()=>{
 const s=fixture();useSkill(s,2);s.bossHP=1;s.damage=999;s.taps=1;const p=tap(s,0);assert.equal(s.status,'won');assert.equal(p.incoming,0);assert.equal(p.blocked,0);assert.deepEqual(s.buffs,empty);
});
test('old stage-two save keeps queued damage unguarded this turn; new turn restores ward',()=>{
 const r=createRun(7,false);r.state.bossHP=1;r.state.damage=100;r.state.taps=1;runTap(r,0);chooseUpgrade(r,'power');r.state.damage=75;r.state.taps=2;
 const old=JSON.parse(saved(r));delete old.run.state.buffs;delete old.run.state.wardBroken;
 const restored=decodeSave(JSON.stringify(old)).run;assert(restored.state.wardBroken);assert.equal(restored.state.damage,75);assert.equal(restored.state.taps,2);
 runTap(restored,0);const result=runTap(restored,0);assert.equal(result.wardAbsorbed,0);assert.equal(restored.state.wardBroken,false);
});
