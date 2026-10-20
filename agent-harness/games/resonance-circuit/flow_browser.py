from campaign_browser import setup,ROOT
from playwright.sync_api import sync_playwright
import json
KEY='resonance-circuit-v1'
def state(page):return page.evaluate('(k)=>JSON.parse(localStorage.getItem(k)).run',KEY)
def idle(page):page.wait_for_function("document.querySelector('#board').dataset.resolving==='false'",timeout=15000)
def seed(page,number=61):
 r=page.evaluate('async n=>{const c=await import("/campaign.mjs");return c.createRun(n,false,1)}',number)
 page.evaluate('([k,r])=>localStorage.setItem(k,JSON.stringify({version:1,run:r,learned:true,audio:{enabled:false,volume:.3}}))',[KEY,r]);page.reload();page.locator('#continueRun').click();return r
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 expected=None;action_ids=[]
 for w,h,motion,standalone in [(360,640,'reduce',False),(360,640,'no-preference',True),(360,800,'reduce',True),(360,800,'no-preference',False),(390,844,'reduce',False),(390,844,'no-preference',True),(1280,900,'reduce',True),(1280,900,'no-preference',False)]:
  page=b.new_page(viewport={'width':w,'height':h},reduced_motion=motion,has_touch=True);errors=[];page.on('pageerror',lambda e:errors.append(str(e)));setup(page,standalone);initial=seed(page)
  assert state(page)==initial
  rects=page.evaluate('()=>Object.fromEntries(["enemy","board","boost"].map(k=>{const r=document.getElementById(k).getBoundingClientRect();return[k,{x:r.x,y:r.y,w:r.width,h:r.height}]}))')
  dock=page.locator('.party-dock').bounding_box();assert dock['y']>=rects['enemy']['y']+rects['enemy']['h']-.1
  assert dock['y']+dock['height']<rects['board']['y'];assert rects['boost']['y']>=rects['board']['y']+rects['board']['h']-.1
  assert page.evaluate('document.documentElement.scrollHeight===innerHeight&&document.documentElement.scrollWidth===innerWidth')
  geometry=page.evaluate('''()=>{const s=JSON.parse(localStorage.getItem('resonance-circuit-v1')).run.state,b=document.getElementById('board').getBoundingClientRect(),scale=Math.min(b.width/420,b.height/440),ox=(b.width-420*scale)/2,oy=b.height-440*scale;return [...document.querySelectorAll('.tile')].map((el,i)=>{const r=el.getBoundingClientRect(),t=s.board[i];return {error:Math.hypot(r.x+r.width/2-(b.x+ox+t.x*scale),r.y+r.height/2-(b.y+oy+t.y*scale)),size:r.width,inside:r.x>=b.x-.2&&r.y>=b.y-.2&&r.right<=b.right+.2&&r.bottom<=b.bottom+.2}})}''')
  assert all(t['error']<.1 and t['inside'] for t in geometry),geometry
  assert min(t['size'] for t in geometry)>=38
  # A cancelled pointer must not consume a tap.
  page.locator('.tile').first.dispatch_event('pointerdown',{'pointerId':9,'button':0,'clientX':0,'clientY':0});page.dispatch_event('body','pointercancel',{'pointerId':9});assert state(page)==initial
  for step in range(6):
   if expected is None:
    i=page.evaluate('async()=>{const e=await import("/engine.mjs"),s=JSON.parse(localStorage.getItem("resonance-circuit-v1")).run.state;let best=0;for(let i=1;i<42;i++)if(e.preview(s,i).damage>e.preview(s,best).damage)best=i;return best}')
    action_ids.append(state(page)['state']['board'][i]['id'])
   else:i=next(i for i,t in enumerate(state(page)['state']['board']) if t['id']==action_ids[step])
   page.locator('.tile').nth(i).evaluate('el=>{el.click();el.click()}');idle(page)
  final=state(page)
  assert page.locator('#saveStatus').inner_text()=='저장됨'
  if expected is None:expected=final
  else:assert final==expected,(w,h,motion)
  page.locator('.tile').nth(0).focus();old=state(page);page.keyboard.press('ArrowRight');assert state(page)==old
  page.screenshot(path=str(ROOT/f'flow-battle-{w}-{h}-{motion}.png'))
  assert not errors,errors;print(json.dumps({'size':[w,h],'motion':motion,'standalone':standalone,'minimumTarget':min(t['size'] for t in geometry),'sameIDActions':action_ids,'state':'identical','result':'PASS'}),flush=True);page.close()
 # Finish in-flight playback on visibility/reduced changes without changing the transaction.
 for interruption in ['hidden-clear','hidden-fall','reduced-fall','reload-fall','reset-clear','reset-fall']:
  page=b.new_page(viewport={'width':390,'height':844},has_touch=True);setup(page,False);before=seed(page,73)
  expected_one=page.evaluate('async r=>{const c=await import("/campaign.mjs");c.runTap(r,0);return r}',before)
  page.locator('.tile').first.evaluate('e=>e.click()')
  if interruption.endswith('fall'):page.wait_for_function("document.querySelector('#board').dataset.falling==='true'")
  if interruption.startswith('hidden'):
   page.evaluate("Object.defineProperty(document,'hidden',{configurable:true,value:true});document.dispatchEvent(new Event('visibilitychange'))")
  elif interruption=='reduced-fall':page.emulate_media(reduced_motion='reduce')
  elif interruption=='reload-fall':
   page.reload();page.locator('#continueRun').click()
  elif interruption.startswith('reset'):
   page.locator('#restart').evaluate('e=>e.click()')
  if interruption!='reload-fall':idle(page)
  expected_state=before if interruption=='reset-clear' else expected_one
  assert state(page)==expected_state,interruption
  print(json.dumps({'interruption':interruption,'settlements':0 if interruption=='reset-clear' else 1,'result':'PASS'}),flush=True);page.close()
 b.close()
