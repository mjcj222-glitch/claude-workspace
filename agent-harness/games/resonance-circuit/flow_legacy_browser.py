from campaign_browser import setup,ROOT
from playwright.sync_api import sync_playwright
import json
f=json.loads((ROOT/'fixtures/pre-flow-saves.json').read_text())
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 page=b.new_page(viewport={'width':360,'height':640},reduced_motion='reduce');setup(page,False)
 cases=[('practice',k) for k in ['battle_0','upgrade_0','complete_2','defeat']]+[('expedition',k) for k in ['1_map','1_0_battle','1_0_reward','1_2_room','1_5_complete','2_map','2_0_battle','2_0_reward','2_2_room','2_5_complete']]
 for mode,key in cases:
  fixture=f[mode][key];slot='resonance-circuit-v1' if mode=='practice' else 'resonance-expedition-v1';data={'version':1,'run':fixture,'learned':True,'audio':{'enabled':False,'volume':.3}} if mode=='practice' else fixture
  page.evaluate('([k,v])=>localStorage.setItem(k,JSON.stringify(v))',[slot,data]);page.reload();page.locator('#continueRun' if mode=='practice' else '#expeditionContinue').click()
  restored=page.evaluate('(k)=>JSON.parse(localStorage.getItem(k))',slot);assert restored==data,(mode,key)
  assert page.locator('html').get_attribute('data-board')=='legacy'
  if fixture['phase']=='battle':
   page.locator('.tile').nth(0).evaluate('e=>e.click()');page.wait_for_function("document.querySelector('#board').dataset.resolving==='false'");s=page.evaluate('(k)=>JSON.parse(localStorage.getItem(k))',slot);run=s['run'] if mode=='practice' else s;assert 'boardVersion' not in run and 'boardVersion' not in run['state'];assert page.locator('#saveStatus').inner_text()=='저장됨'
  if fixture['phase']=='reward':
   page.locator('[data-reward]').first.evaluate('e=>{e.click();e.click()}');run=page.evaluate('(k)=>JSON.parse(localStorage.getItem(k))',slot);assert run['depth']==fixture['depth']+1 and len(run['relics'])==len(fixture['relics'])+1
  print(json.dumps({'mode':mode,'fixture':key,'legacyState':'preserved','result':'PASS'}),flush=True)
 page.close();b.close()
