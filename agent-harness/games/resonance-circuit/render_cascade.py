from campaign_browser import setup,ROOT
from playwright.sync_api import sync_playwright
import json,base64,wave
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True);page=b.new_page();setup(page,False)
 results=page.evaluate('''async()=>{
 const {createAudio}=await import('/audio.mjs'),{createGame,neighbors,preview}=await import('/engine.mjs'),{planTimeline}=await import('/timeline.mjs');const out=[];
 for(const count of [6,10,42]){
  const s=createGame(7);s.board.forEach(t=>t.color='gold');const order=[9],seen=new Set(order);for(const i of order)for(const j of neighbors(i))if(!seen.has(j)){seen.add(j);order.push(j);}for(const i of order.slice(0,count))s.board[i].color='coral';const plan=planTimeline(s,9,preview(s,9));
  const c=new OfflineAudioContext(1,48000,48000),a=createAudio({enabled:true,volume:1},{factory:()=>c,offline:true});a.unlock();a.beginSequence();if(count===42){a.play('echo');a.play('bomb');}
  const pauses=plan.audio.map((n,i)=>c.suspend(Math.max(0,n.at/1000)).then(()=>{a.tick(n.note,'tile-'+i);return c.resume();}));const render=c.startRendering();await Promise.all(pauses);const data=(await render).getChannelData(0);let peak=0,sum=0,clip=0;const pcm=new Int16Array(data.length);for(let i=0;i<data.length;i++){peak=Math.max(peak,Math.abs(data[i]));sum+=data[i]**2;if(Math.abs(data[i])>=1)clip++;pcm[i]=Math.round(data[i]*32767);}let bytes='';for(const v of new Uint8Array(pcm.buffer))bytes+=String.fromCharCode(v);out.push({count,noteTimes:plan.audio.map(n=>n.at),peak,rms:Math.sqrt(sum/data.length),clip,stats:a.stats,pcm:btoa(bytes)});
 }return out;
}''')
 for r in results:
  raw=base64.b64decode(r.pop('pcm'))
  with wave.open(str(ROOT/'samples'/f'cascade-{r["count"]}.wav'),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(48000);f.writeframes(raw)
  assert r['clip']==0 and r['peak']<.7 and r['rms']>.0001;assert r['stats']['dropped']==0;assert r['stats']['peakVoices']<=8;print(json.dumps(r),flush=True)
 (ROOT/'cascade-audio-metrics.json').write_text(json.dumps(results,indent=2)+'\n');b.close()
