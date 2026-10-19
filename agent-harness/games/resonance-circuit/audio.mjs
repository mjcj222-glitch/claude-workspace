// Soft synthesized accents only; no assets, autoplay or game-state dependency.
export function createAudio(settings,{factory=()=>new (globalThis.AudioContext||globalThis.webkitAudioContext)()}={}){
 let context=null;const voices=new Set();let available=true;
 function stop(){for(const v of voices){try{v.stop();}catch{}}voices.clear();}
 function unlock(){if(!settings.enabled)return false;try{context??=factory();const promise=context.resume();promise?.catch(()=>{available=false;});return true;}catch{available=false;return false;}}
 function tone(frequency,when,length,level,type='sine'){
  if(voices.size>=8)return;
  const osc=context.createOscillator(),gain=context.createGain();osc.type=type;osc.frequency.setValueAtTime(frequency,when);osc.frequency.exponentialRampToValueAtTime(frequency*.85,when+length);
  gain.gain.setValueAtTime(0,when);gain.gain.linearRampToValueAtTime(level*settings.volume,when+.018);gain.gain.exponentialRampToValueAtTime(.0001,when+length);osc.connect(gain);gain.connect(context.destination);voices.add(osc);
  osc.onended=()=>{voices.delete(osc);osc.disconnect();gain.disconnect();};osc.start(when);osc.stop(when+length+.03);
 }
 function play(kind){if(!settings.enabled||!context||context.state!=='running')return false;try{
  const now=context.currentTime;
  if(kind==='bomb'){tone(82,now,.3,.12);tone(123,now,.22,.035,'triangle');}
  else if(kind==='enemy')tone(110,now,.22,.065);
  else if(kind==='echo'||kind==='boost'){[220,277,330].forEach((f,i)=>tone(f,now+i*.055,.17,.045));}
  else{tone(165,now,.13,.07);tone(247,now+.025,.1,.025);}
  return true;
 }catch{available=false;return false;}}
 function enable(value){settings.enabled=!!value;if(value)unlock();else{stop();try{context?.suspend()?.catch(()=>{});}catch{}}}
 function volume(value){settings.volume=Math.max(0,Math.min(1,Number(value)||0));}
 function hide(){stop();try{context?.suspend()?.catch(()=>{});}catch{}}
 return {unlock,play,enable,volume,hide,get available(){return available;},get voices(){return voices.size;}};
}
