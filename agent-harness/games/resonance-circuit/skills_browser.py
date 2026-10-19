from campaign_browser import setup,saved,ROOT
from playwright.sync_api import sync_playwright
import json
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 for w,h,motion in [(360,800,'reduce'),(390,844,'no-preference'),(1280,900,'reduce')]:
  page=b.new_page(viewport={'width':w,'height':h},reduced_motion=motion,has_touch=True);errors=[];page.on('pageerror',lambda e:errors.append(str(e)));setup(page,True)
  page.locator('#startNew').click();page.locator('#skipLesson').click();page.locator('#skillHelp').click()
  assert '현재 대상' in page.locator('#skillDescriptions').inner_text();assert '쿨다운 3턴' in page.locator('#skillDescriptions').inner_text();assert '+30' in page.locator('#skillDescriptions').inner_text()
  page.screenshot(path=str(ROOT/f'skills-guide-{w}.png'),full_page=True);page.locator('#closeSkills').click()
  for k in range(3):
   page.locator(f'[data-skill="{k}"]').tap()
   assert page.locator('#skillCutin').is_visible();assert page.locator('#skillCutin').evaluate("e=>getComputedStyle(e).pointerEvents")=='none'
   assert saved(page)['run']['state']['taps']==3
   page.screenshot(path=str(ROOT/f'skills-cutin-{k}-{w}.png'),full_page=True)
  buffs={'prism':True,'ignition':True,'shield':18}
  assert saved(page)['run']['state']['buffs']==buffs;assert page.locator('.buff').count()==3
  before=saved(page)['run'];page.wait_for_timeout(650);assert not page.locator('#skillCutin').is_visible()
  page.reload();page.locator('#continueRun').click();assert saved(page)['run']==before
  page.screenshot(path=str(ROOT/f'skills-ready-{w}.png'),full_page=True)
  assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
  box=page.locator('#boost').bounding_box();assert box['y']+box['height']<=h
  # Explicit zero-candidate fixture: old ready effects must not be consumed/refreshed.
  data=saved(page);s=data['run']['state'];s['turn']=4;s['ready']=[4,4,4];s['echo']=[]
  for t in s['board']:t['color']='heal'
  page.evaluate('(d)=>localStorage.setItem("resonance-circuit-v1",JSON.stringify(d))',data);page.reload();page.locator('#continueRun').click()
  before=saved(page)['run']
  for k in range(3):page.locator(f'[data-skill="{k}"]').click();assert saved(page)['run']==before
  page.locator('#skillHelp').click();assert page.locator('#skillDescriptions').inner_text().count('현재 대상 0개')==3;page.locator('#closeSkills').click()
  # Legacy v1 is accepted without deleting progress or retroactively awarding skills.
  old=saved(page);del old['run']['state']['buffs'];del old['run']['state']['wardBroken']
  page.evaluate('(d)=>localStorage.setItem("resonance-circuit-v1",JSON.stringify(d))',old);page.reload();assert '이전 저장' in page.locator('#loadNote').inner_text();page.locator('#continueRun').click()
  assert page.locator('.buff').count()==0
  page.locator('#restart').click();page.locator('#confirmRestart').click();assert saved(page)['run']['state']['buffs']=={'prism':False,'ignition':False,'shield':0}
  assert not errors,errors
  print(json.dumps({'viewport':[w,h],'skills':3,'pending_restore':True,'zero_candidates':True,'legacy_v1':True,'cutin_cleanup':True,'errors':0}),flush=True);page.close()
 b.close()
