"""Explicit settlement fixtures inspect event routing and visible feedback, not balance."""
from campaign_browser import setup,saved,ROOT
from playwright.sync_api import sync_playwright
import json,subprocess
base=json.loads(subprocess.check_output(['node','--input-type=module','-e',"import {createRun,runTap,chooseUpgrade} from './campaign.mjs';const r=createRun(7,false);for(const id of ['power','healing']){r.state.damage=9999;r.state.taps=1;runTap(r,1);chooseUpgrade(r,id);}r.panelLesson=null;console.log(JSON.stringify({version:1,run:r,learned:true,audio:{enabled:false,volume:.3}}));"],cwd=ROOT,text=True))
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 for kind in ['large','heal','full-shield','partial-shield','hit-enemy','win','lose']:
  d=json.loads(json.dumps(base));s=d['run']['state'];s['taps']=1;s['hp']=80;s['echo']=[]
  for t in s['board']:t.pop('vine',None);t['kind']='normal';t['color']='heal' if kind=='heal' else 'coral'
  if 'shield' in kind:s['buffs']['shield']=18;s['turn']=1 if kind=='full-shield' else 2
  if kind=='win':s['bossHP']=1
  if kind=='lose':s['hp']=1
  page=b.new_page(viewport={'width':390,'height':844},has_touch=True);errors=[];page.on('pageerror',lambda e:errors.append(str(e)));setup(page,True)
  page.evaluate('(d)=>localStorage.setItem("resonance-circuit-v1",JSON.stringify(d))',d);page.reload();page.locator('#continueRun').click()
  page.locator('.tile').first.tap();page.wait_for_function("JSON.parse(localStorage.getItem('resonance-circuit-v1')).run.state.nextID>43")
  after=saved(page)['run']
  if kind=='full-shield':assert after['state']['hp']==80;assert page.locator('#health').get_attribute('data-fx')=='shield'
  if kind=='partial-shield':assert after['state']['hp']==72;assert page.locator('#health').get_attribute('data-fx')=='shield'
  if kind=='heal':assert after['state']['hp']==162;assert page.locator('#health').get_attribute('data-fx')=='heal'
  if kind=='win':assert after['phase']=='complete' and after['state']['hp']==80
  if kind=='lose':assert after['phase']=='defeat'
  page.screenshot(path=str(ROOT/f'feedback-event-{kind}.png'),full_page=True);page.wait_for_timeout(850)
  assert page.locator('#effects').get_attribute('data-active')=='0';assert page.locator('.fx-label,[data-fx],.cleared,.hit,.hurt,.guarded').count()==0;assert not errors
  print(json.dumps({'event':kind,'hp':after['state']['hp'],'phase':after['phase'],'errors':0}),flush=True);page.close()
 b.close()
