from campaign_browser import setup,ROOT
from playwright.sync_api import sync_playwright
import json
fixtures=json.loads((ROOT/'fixtures/pre-evolution-saves.json').read_text())
cases=[('practice',k) for k in ['battle_0','tap_1','upgrade_1','complete_2']]+[('expedition',k) for k in ['1_0_battle','1_complete','2_0_map','2_0_battle','2_0_reward','2_2_room','2_3_battle','2_5_battle','2_complete']]
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True);page=b.new_page(viewport={'width':360,'height':640},reduced_motion='reduce');setup(page,True)
 for mode,key in cases:
  r=fixtures[mode][key];slot='resonance-circuit-v1' if mode=='practice' else 'resonance-expedition-v1';data={'version':1,'run':r,'learned':True,'audio':{'enabled':False,'volume':.3}} if mode=='practice' else r
  page.evaluate('([k,d])=>localStorage.setItem(k,JSON.stringify(d))',[slot,data]);page.reload();page.locator('#continueRun' if mode=='practice' else '#expeditionContinue').click()
  assert page.evaluate('(k)=>JSON.parse(localStorage.getItem(k))',slot)==data
  assert page.locator('html').get_attribute('data-board')=='flow'
  if r['phase']=='battle':
   i=next(i for i,t in enumerate(r['state']['board']) if not t.get('vine'));page.locator('.tile').nth(i).evaluate('e=>e.click()');page.wait_for_function("document.querySelector('#board').dataset.resolving==='false'")
   raw=page.evaluate('(k)=>JSON.parse(localStorage.getItem(k))',slot);restored=raw['run'] if mode=='practice' else raw
   assert 'rulesVersion' not in restored and 'rulesVersion' not in restored['state']
   assert page.locator('#saveStatus').inner_text()=='저장됨'
  if r['phase']=='reward':
   page.locator('[data-reward]').first.evaluate('e=>{e.click();e.click()}');restored=page.evaluate('(k)=>JSON.parse(localStorage.getItem(k))',slot);assert restored['depth']==r['depth']+1
  print(json.dumps({'mode':mode,'fixture':key,'oldFlowRules':'preserved','result':'PASS'}),flush=True)
 b.close()
