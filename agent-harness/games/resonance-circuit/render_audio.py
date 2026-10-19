"""OfflineAudioContext renders the SAME live synthesis, with measurable PCM output."""
from campaign_browser import setup,ROOT
from playwright.sync_api import sync_playwright
import json,base64,wave
(ROOT/'samples').mkdir(exist_ok=True)
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True);page=b.new_page();setup(page,False)
 results=page.evaluate('''async()=>{
 const {createAudio,SOUND_EVENTS}=await import('/audio.mjs'),out=[];
 for(const kind of [...Object.keys(SOUND_EVENTS),'stress','mute']){
  const context=new OfflineAudioContext(1,48000,48000),settings={enabled:true,volume:kind==='mute'?0:1},audio=createAudio(settings,{factory:()=>context,offline:true});audio.unlock();
  if(kind==='stress')for(const [i,k] of Object.keys(SOUND_EVENTS).entries())audio.play(k,{id:i,chain:12});else audio.play(kind==='mute'?'bomb':kind,{chain:kind==='large'?12:3});
  const before=audio.stats,rendered=await context.startRendering(),data=rendered.getChannelData(0);let peak=0,sum=0,clipping=0,last=0;const pcm=new Int16Array(data.length);
  for(let i=0;i<data.length;i++){const v=data[i];peak=Math.max(peak,Math.abs(v));sum+=v*v;if(Math.abs(v)>=1)clipping++;if(Math.abs(v)>.0001)last=i;pcm[i]=Math.round(Math.max(-1,Math.min(1,v))*32767);}
  let binary='';for(const byte of new Uint8Array(pcm.buffer))binary+=String.fromCharCode(byte);
  out.push({kind,peak,rms:Math.sqrt(sum/data.length),audibleSeconds:last/48000,clipping,scheduled:before,after:audio.stats,pcm:btoa(binary)});
 }
 return out;
}''')
 for result in results:
  raw=base64.b64decode(result.pop('pcm'))
  with wave.open(str(ROOT/'samples'/f'{result["kind"]}.wav'),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(48000);f.writeframes(raw)
  assert result['clipping']==0 and result['peak']<.7
  assert result['scheduled']['peakVoices']<=8 and result['scheduled']['peakNodes']<=26
  assert result['scheduled']['bufferBytes']<=67200 and result['after']['voices']==0
  if result['kind']=='mute':assert result['peak']==0
  else:assert result['rms']>.0001 and result['audibleSeconds']<.9
  print(json.dumps(result),flush=True)
 (ROOT/'audio-metrics.json').write_text(json.dumps(results,indent=2)+'\n')
 b.close()
