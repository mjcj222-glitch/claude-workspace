import test from 'node:test';
import assert from 'node:assert/strict';
import {createGame,tap,preview} from './engine.mjs';
import {playbackFrames} from './flow-motion.mjs';
import {skillAvailability} from './skills.mjs';
function onscreenPenetration(frames,board){
 const byID=new Map(board.map(t=>[t.id,t]));let worst=0;
 for(const frame of frames)for(let i=0;i<frame.length;i++)for(let j=0;j<i;j++){
  const a=frame[i],b=frame[j],ar=byID.get(a.id).r,br=byID.get(b.id).r;
  if(a.y<ar||b.y<br)continue;
  worst=Math.max(worst,ar+br-Math.hypot(a.x-b.x,a.y-b.y));
 }
 return worst;
}
test('shared-time playback introduces no extra onscreen penetration on the reported seeds',()=>{
 for(const seed of [1,41,73]){
  const s=createGame(seed,{boardVersion:1,rulesVersion:1});
  for(let n=0;n<7;n++){
   const index=s.board.map((_,i)=>({i,damage:preview(s,i).damage})).sort((a,b)=>b.damage-a.damage)[0].i;
   const result=tap(s,index);if(!result.flow)break;
   const before=JSON.stringify({s,flow:result.flow}),raw=onscreenPenetration(result.flow.frames,s.board),p=playbackFrames(result.flow);
   const frames=p.tracks[0].frames.map((_,i)=>p.tracks.map(t=>({id:t.id,...t.frames[i]})));
   assert(onscreenPenetration(frames,s.board)<=raw+.05,`seed ${seed} tap ${n}: playback added collision overlap`);
   assert.equal(JSON.stringify({s,flow:result.flow}),before);
  }
 }
});
test('skill label and enabled state use the same availability decision',()=>{
 const s=createGame(41,{boardVersion:1,rulesVersion:1});
 for(let k=0;k<3;k++){
  assert.deepEqual(skillAvailability(s,k,{locked:true}),{disabled:true,ready:false,label:'정산 중'});
  assert.deepEqual(skillAvailability(s,k,{locked:true,falling:true}),{disabled:true,ready:false,label:'낙하 중'});
  assert.deepEqual(skillAvailability(s,k),{disabled:false,ready:true,label:'사용 가능'});
 }
 s.board.forEach(t=>{t.color='heal';t.kind='normal';});
 assert.deepEqual(skillAvailability(s,0),{disabled:true,ready:false,label:'대상 없음'});
 s.ready[0]=3;assert.equal(skillAvailability(s,0).label,'2턴 후');
 assert.equal(skillAvailability(s,0,{phase:'reward'}).label,'전투 대기');
});
