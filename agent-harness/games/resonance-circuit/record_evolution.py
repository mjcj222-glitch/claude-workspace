"""Actual browser scenes; gaps between battles omitted, retained scenes run at original time."""
from campaign_browser import setup,ROOT
from expedition_browser import read,idle
from playwright.sync_api import sync_playwright
from pathlib import Path
import tempfile,base64,subprocess,json
folder=Path(tempfile.mkdtemp(prefix='resonance-expedition-'));frames=[];active=False;base=None;offset=0;scenes=[]
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True);page=b.new_page(viewport={'width':390,'height':844},has_touch=True);setup(page,True);cdp=page.context.new_cdp_session(page)
 def frame(event):
  global base
  if active:
   if base is None:base=event['metadata']['timestamp']
   path=folder/f'{len(frames):05d}.jpg';path.write_bytes(base64.b64decode(event['data']));frames.append((path,offset+event['metadata']['timestamp']-base))
  cdp.send('Page.screencastFrameAck',{'sessionId':event['sessionId']})
 def scene(name):
  global active,base,offset
  if active:return
  offset=frames[-1][1]+.15 if frames else 0;base=None;active=True;scenes.append({'name':name,'start':offset})
 def pause():
  global active
  active=False
 cdp.on('Page.screencastFrame',frame);cdp.send('Page.startScreencast',{'format':'jpeg','quality':78,'maxWidth':390,'maxHeight':844,'everyNthFrame':1})
 scene('새 탐험과 지도');page.locator('#expeditionNew').click();page.wait_for_timeout(900)
 battle_counts={}
 for step in range(350):
  e=read(page);phase=e['phase']
  if phase in ['complete','defeat']:scene('탐험 결과');page.wait_for_timeout(1000);break
  if phase=='map':
   page.emulate_media(reduced_motion='no-preference');scene('경로 선택');page.wait_for_timeout(400);index=1 if e['depth']==4 else 0;page.locator(f'[data-room="{e["depth"]}-{index}"]').click();page.wait_for_timeout(450);page.locator('#roomEnter').click();page.wait_for_timeout(250)
  elif phase=='reward':
   page.emulate_media(reduced_motion='no-preference');scene('유물 보상');page.wait_for_timeout(1000);page.locator('[data-reward]').first.click();page.wait_for_timeout(300)
  elif phase=='room':
   page.emulate_media(reduced_motion='no-preference');scene('쉼터와 선택 이벤트');page.wait_for_timeout(3500);choice='gift' if e['map'][e['depth']][int(e['path'][-1][-1])]['type']=='event' and e['offer'] and e['state']['hp']>60 else 'rest';page.locator(f'[data-event="{choice}"]').click();page.wait_for_timeout(300)
  else:
   count=battle_counts.get(e['depth'],0);battle_counts[e['depth']]=count+1
   if count<2:
    page.emulate_media(reduced_motion='no-preference');scene('전투 '+str(e['depth']+1))
   else:
    pause();page.emulate_media(reduced_motion='reduce')
   if count>=2 and e['state']['hp']<110 and page.locator('[data-skill="2"]').is_enabled():page.locator('[data-skill="2"]').click()
   for selector in ['[data-skill="0"]','[data-skill="1"]','#boost']:
    if count>=2 and page.locator(selector).is_enabled():page.locator(selector).click()
   index=page.evaluate("()=>{const s=JSON.parse(localStorage.getItem('resonance-expedition-v1')).state;let best=-1,index=0;for(let i=0;i<42;i++){const p=oracle.preview(s,i),score=p.damage+Math.min(p.healing,Math.max(0,180-s.hp-s.healing))*1.5+(p.echoHit?12:0);if(score>best){best=score;index=i}}return index}")
   if count==0:index=page.evaluate("()=>{const s=JSON.parse(localStorage.getItem('resonance-expedition-v1')).state;return s.board.findIndex((t,i)=>t.color==='coral'&&oracle.preview(s,i).promotion==='mega')}")
   elif count==1:index=page.evaluate("()=>JSON.parse(localStorage.getItem('resonance-expedition-v1')).state.board.findIndex(t=>t.kind==='mega')")
   page.locator('.tile').nth(index).tap();idle(page)
 page.wait_for_timeout(200);cdp.send('Page.stopScreencast');final=read(page);b.close()
assert final['phase']=='complete',final['phase']
lines=[]
for i,(path,t) in enumerate(frames):
 lines.append("file '"+str(path)+"'");lines.append('duration '+str(max(.001,min(2,frames[i+1][1]-t)) if i+1<len(frames) else .2))
lines.append("file '"+str(frames[-1][0])+"'");(folder/'frames.txt').write_text('\n'.join(lines))
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-f','concat','-safe','0','-i',str(folder/'frames.txt'),'-vf','fps=60','-c:v','libx264','-pix_fmt','yuv420p','-movflags','+faststart',str(ROOT/'evolution-play.mp4')],check=True)
print(json.dumps({'frames':len(frames),'seconds':frames[-1][1],'scenes':scenes,'seed':final['seed'],'result':final['phase'],'audio':'muted','editing':'Actual CDP scenes at original speed; unrecorded middle taps use reduced motion and are omitted; retained scenes original speed, no fabricated/composited frames'},ensure_ascii=False))
