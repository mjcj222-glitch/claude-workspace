"""Record actual Chromium frames during real UI actions; no composited game images."""
from campaign_browser import setup,saved,ROOT
from playwright.sync_api import sync_playwright
from pathlib import Path
import tempfile,base64,subprocess,json
frames=[];folder=Path(tempfile.mkdtemp(prefix='resonance-feedback-'))
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True);page=b.new_page(viewport={'width':390,'height':844},has_touch=True);setup(page,True)
 cdp=page.context.new_cdp_session(page)
 def frame(event):
  path=folder/f'{len(frames):05d}.jpg';path.write_bytes(base64.b64decode(event['data']));frames.append((path,event['metadata']['timestamp']));cdp.send('Page.screencastFrameAck',{'sessionId':event['sessionId']})
 cdp.on('Page.screencastFrame',frame);cdp.send('Page.startScreencast',{'format':'jpeg','quality':85,'maxWidth':390,'maxHeight':844,'everyNthFrame':1})
 page.locator('#startNew').click();page.wait_for_timeout(600)
 page.locator('.lesson-target').first.tap();page.wait_for_timeout(650);page.locator('.lesson-target').first.tap();page.wait_for_timeout(650)
 for n in range(6):
  r=saved(page)['run']
  if r['phase']!='battle':break
  if n in [0,3]:
   for k in [0,1,2]:
    btn=page.locator(f'[data-skill="{k}"]')
    if btn.is_enabled():btn.click();page.wait_for_timeout(550)
  i=page.evaluate("()=>{const s=JSON.parse(localStorage.getItem('resonance-circuit-v1')).run.state;let best=0,score=-1;for(let i=0;i<42;i++){const p=oracle.preview(s,i);if(p.damage+p.healing>score){score=p.damage+p.healing;best=i}}return best}")
  page.locator('.tile').nth(i).tap();page.wait_for_timeout(650)
 page.wait_for_timeout(400);cdp.send('Page.stopScreencast');b.close()
assert len(frames)>10
lines=[]
for i,(path,t) in enumerate(frames):
 lines.append("file '"+str(path)+"'");lines.append('duration '+str(max(.001,min(2,frames[i+1][1]-t)) if i+1<len(frames) else .1))
lines.append("file '"+str(frames[-1][0])+"'");(folder/'frames.txt').write_text('\n'.join(lines))
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-f','concat','-safe','0','-i',str(folder/'frames.txt'),'-vf','fps=24','-c:v','libx264','-pix_fmt','yuv420p','-movflags','+faststart',str(ROOT/'feedback-play.mp4')],check=True)
print(json.dumps({'frames':len(frames),'recorded_seconds':frames[-1][1]-frames[0][1],'file':'feedback-play.mp4','audio':'muted actual browser capture','source':'Chromium CDP screencast during real taps'}))
