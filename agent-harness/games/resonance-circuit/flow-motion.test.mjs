import test from 'node:test';import assert from 'node:assert/strict';
import {monotoneCurve,playbackFrames} from './flow-motion.mjs';
import {createGame,tap} from './engine.mjs';
test('render interpolation is bounded, continuous and ends at zero velocity',()=>{
 const times=[0,.2,.5,.85,1],values=[-300,20,22,32,44],f=monotoneCurve(times,values);
 for(let i=0;i<times.length-1;i++)for(let j=0;j<=50;j++){const t=times[i]+(times[i+1]-times[i])*j/50,v=f(t);assert(v>=values[i]-1e-8&&v<=values[i+1]+1e-8);}
 for(const t of times.slice(1,-1)){const h=1e-6,left=(f(t)-f(t-h))/h,right=(f(t+h)-f(t))/h;assert(Math.abs(left-right)<.03);}
 assert(Math.abs((f(1)-f(1-1e-6))/1e-6)<.01);
});
test('playback leaves authoritative frames/state byte-identical and preserves exact endpoints',()=>{
 for(const seed of [1,5,41,99]){const s=createGame(seed,{boardVersion:1}),r=tap(s,1),copy=JSON.stringify({s,r});const p=playbackFrames(r.flow);assert.equal(JSON.stringify({s,r}),copy);assert(p.duration>=460&&p.duration<=720);assert.equal(p.tracks.length,42);
  for(const track of p.tracks){const start=r.flow.frames[0].find(t=>t.id===track.id),end=s.board.find(t=>t.id===track.id);for(const k of ['x','y','angle']){assert.equal(track.frames[0][k],start[k]);assert.equal(track.frames.at(-1)[k],end[k]);}assert(track.frames.every(f=>['x','y','angle'].every(k=>Number.isFinite(f[k]))));}
 }
});
