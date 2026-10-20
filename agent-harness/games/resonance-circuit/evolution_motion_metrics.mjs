import assert from 'node:assert/strict';
import {createGame,tap,preview} from './engine.mjs';
import {playbackFrames} from './flow-motion.mjs';
import {validFlowBoard} from './flow.mjs';
let samples=0,maxProjection=0,projectionOver5=0,minSettle=Infinity,maxSettle=0,minDuration=Infinity,maxDuration=0,totalCompute=0,maxCompute=0;
for(let seed=1;seed<=24;seed++){
 const s=createGame(seed,{boardVersion:1,rulesVersion:1,panelStage:seed%3});
 for(let n=0;n<6&&s.status==='playing';n++){
  let best=0;for(let i=1;i<42;i++)if(preview(s,i).damage>preview(s,best).damage)best=i;
  const start=performance.now(),result=tap(s,best),compute=performance.now()-start;
  assert(validFlowBoard(s.board));const frozen=JSON.stringify({s,result}),playback=playbackFrames(result.flow);assert.equal(JSON.stringify({s,result}),frozen);
  for(const track of playback.tracks){const body=s.board.find(t=>t.id===track.id);for(const k of ['x','y','angle'])assert.equal(track.frames.at(-1)[k],body[k]);}
  maxProjection=Math.max(maxProjection,playback.projectionDistance);
  if(playback.projectionDistance>5){projectionOver5++;minSettle=Math.min(minSettle,playback.settlingMs);maxSettle=Math.max(maxSettle,playback.settlingMs);}
  minDuration=Math.min(minDuration,playback.duration);maxDuration=Math.max(maxDuration,playback.duration);totalCompute+=compute;maxCompute=Math.max(maxCompute,compute);samples++;
 }
}
console.log(JSON.stringify({seeds:24,samples,validBoard:'PASS',unchangedStateAndTrace:'PASS',exactFinalPose:'PASS',maxProjection,projectionOver5,settlingMsOver5:[minSettle,maxSettle],playbackMs:[minDuration,maxDuration],nodeComputeMs:{mean:totalCompute/samples,max:maxCompute},environment:'shared development container; not a phone performance benchmark'}));
