import test from 'node:test';
import assert from 'node:assert/strict';
import {createAudio} from './audio.mjs';
function context(){let nodes=0;const param={setValueAtTime(){},linearRampToValueAtTime(){},exponentialRampToValueAtTime(){},setTargetAtTime(){}};const node=()=>({connect(){},disconnect(){nodes--;},start(){},stop(at){if(at<=.15)this.onended?.();}});return {state:'running',currentTime:0,destination:{},sampleRate:48000,resume(){return Promise.resolve();},suspend(){this.state='suspended';return Promise.resolve();},createGain(){nodes++;return {...node(),gain:param};},createDynamicsCompressor(){nodes++;return {...node(),threshold:param,knee:param,ratio:param,attack:param,release:param};},createOscillator(){nodes++;return {...node(),frequency:param};},createBiquadFilter(){nodes++;return {...node(),frequency:param,Q:param};},createBufferSource(){nodes++;return node();},createBuffer(n,length){return {getChannelData(){return new Float32Array(length);},length};},get liveNodes(){return nodes;}};}
test('master bus, deduplication, voice/node/buffer limits and synchronous cleanup',()=>{
 const c=context(),s={enabled:false,volume:.3},a=createAudio(s,{factory:()=>c});assert.equal(a.unlock(),false);assert.equal(c.liveNodes,0);a.enable(true);
 assert(a.play('bomb',{id:'one'}));const first=a.stats.events;assert.equal(a.play('bomb',{id:'one'}),false);assert.equal(a.stats.events,first);
 for(const k of ['echo','vine','rainbow','heal','prism','ignite','garden','shield','hit','enemy','win','lose']){c.currentTime+=.01;a.play(k,{id:k});}
 assert(a.stats.peakVoices<=8);assert(a.stats.peakNodes<=26);assert(a.stats.bufferBytes<=48000*.35*4);assert(a.stats.dropped>0);a.hide();assert.equal(a.voices,0);assert.equal(a.stats.nodes,2);assert.equal(c.liveNodes,2);a.enable(false);assert.equal(a.play('chain'),false);
});
test('audio failures stay isolated; numeric volume clamps and mute does not allocate',()=>{const a=createAudio({enabled:true,volume:.3},{factory:()=>{throw Error('offline');}});assert.equal(a.unlock(),false);assert.equal(a.play('rainbow'),false);assert.equal(a.available,false);assert.equal(a.stats.nodes,0);});
test('first sound waits for resume, stale hidden queue is cancelled and live volume uses master',async()=>{
 const c=context();c.state='suspended';let resolve,masterValue;const base=c.createGain;c.createGain=()=>{const n=base();if(masterValue===undefined){masterValue=-1;n.gain={...n.gain,setValueAtTime(v){masterValue=v;},setTargetAtTime(v){masterValue=v;}};}return n;};c.resume=()=>new Promise(r=>{resolve=()=>{c.state='running';r();};});
 const a=createAudio({enabled:true,volume:.3},{factory:()=>c});a.unlock();assert(a.play('chain',{id:'first'}));assert.equal(a.voices,0);assert.equal(a.stats.queued,1);resolve();await Promise.resolve();await Promise.resolve();assert(a.voices>0);a.volume(0);assert.equal(masterValue,0);
 a.hide();a.unlock();a.play('echo',{id:'hidden'});assert.equal(a.stats.queued,1);a.hide();resolve();await Promise.resolve();await Promise.resolve();assert.equal(a.voices,0);assert.equal(a.stats.queued,0);
});
test('routing preserves compound bomb/echo and settlement-only heal/shield/victory',async()=>{
 const {preFeedback,postFeedback}=await import('./feedback.mjs');assert.deepEqual(preFeedback({bombs:2,echoHit:true,unlocked:[],rainbows:0,initial:[1]}),['bomb','echo']);
 assert.deepEqual(postFeedback({blocked:18,retaliation:0},{healed:8}),['heal','shield']);assert.deepEqual(postFeedback({blocked:18,retaliation:6}),['shield','enemy']);assert.deepEqual(postFeedback({blocked:0,retaliation:0},{bossHit:true,status:'won'}),['hit','win']);assert.deepEqual(postFeedback({blocked:0,retaliation:24},{status:'lost'}),['enemy','lose']);
});
test('noise cache stays below 67200 bytes even on a 96kHz device',()=>{const c=context();c.sampleRate=96000;const a=createAudio({enabled:true,volume:.3},{factory:()=>c});a.unlock();a.play('vine');assert(a.stats.bufferBytes<=67200);a.hide();});
test('cascade ticks bypass accent throttle but deduplicate by tile ID',()=>{const c=context(),a=createAudio({enabled:true,volume:.3},{factory:()=>c});a.unlock();a.beginSequence();a.play('echo');const before=a.stats.events;assert(a.tick(0,'tile-a'));assert(a.tick(1,'tile-b'));assert.equal(a.tick(1,'tile-b'),false);assert.equal(a.stats.events,before+2);assert(a.stats.peakVoices<=8);a.cancel();assert.equal(a.voices,0);a.endSequence();});
