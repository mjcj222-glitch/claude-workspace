from campaign_browser import setup,ROOT
from playwright.sync_api import sync_playwright
import json
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 for trigger in ['reset','hidden','motion']:
  page=b.new_page(viewport={'width':390,'height':844},reduced_motion='no-preference');setup(page,True)
  e=page.evaluate("async()=>{const x=await import('/expedition.mjs');const e=x.createExpedition(77);x.enterRoom(e,x.availableRooms(e)[0].id);e.relics=['brooch'];e.state.board.forEach(t=>t.color='coral');return e}")
  page.evaluate('(e)=>localStorage.setItem("resonance-expedition-v1",JSON.stringify(e))',e);page.reload();page.locator('#expeditionContinue').click()
  page.locator('.tile').nth(9).evaluate('e=>e.click()');page.wait_for_timeout(65)
  if trigger=='reset':page.locator('#restart').click();page.locator('#cancelNew').click()
  elif trigger=='hidden':page.evaluate("()=>{Object.defineProperty(document,'hidden',{configurable:true,get:()=>true});document.dispatchEvent(new Event('visibilitychange'))}")
  else:page.emulate_media(reduced_motion='reduce')
  page.wait_for_function("document.querySelector('#board').dataset.resolving==='false'");after=page.evaluate("JSON.parse(localStorage.getItem('resonance-expedition-v1'))")
  assert after['state']['taps']==(3 if trigger=='reset' else 2)
  assert page.locator('.cleared,[data-clear-id]').count()==0
  page.reload();page.locator('#expeditionContinue').click();assert page.evaluate("JSON.parse(localStorage.getItem('resonance-expedition-v1'))")==after
  page.locator('[data-skill="1"]').click();saved=page.evaluate("JSON.parse(localStorage.getItem('resonance-expedition-v1'))");assert saved['shield']==6
  page.reload();page.locator('#expeditionContinue').click();assert page.evaluate("JSON.parse(localStorage.getItem('resonance-expedition-v1')).shield")==6
  print('PASS expedition interruption, resume and first-skill dedup',trigger,flush=True);page.close()
 b.close()
