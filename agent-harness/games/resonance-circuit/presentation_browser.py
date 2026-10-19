from campaign_browser import setup,ROOT
from playwright.sync_api import sync_playwright
import json
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 for reduced in ['no-preference','reduce']:
  page=b.new_page(viewport={'width':390,'height':844},reduced_motion=reduced);setup(page,False)
  assert page.locator('#bossTrail').count()==1,'HP trail missing'
  page.locator('#startNew').click();page.locator('#skipLesson').click()
  # Valid deterministic save fixture: next tap settles damage and reaches cooldown readiness.
  e=page.evaluate("()=>{const d=JSON.parse(localStorage.getItem('resonance-circuit-v1'));d.run.state.taps=1;d.run.state.damage=120;d.run.state.hp=80;d.run.state.healing=15;d.run.state.ready=[2,2,2];return d}")
  page.evaluate('(d)=>localStorage.setItem("resonance-circuit-v1",JSON.stringify(d))',e);page.reload();page.locator('#continueRun').click();page.locator('.tile').nth(1).evaluate('e=>e.click()');page.wait_for_function("document.querySelector('#board').dataset.resolving==='false'");page.wait_for_timeout(500)
  state=page.evaluate("JSON.parse(localStorage.getItem('resonance-circuit-v1')).run.state")
  assert page.locator('#bossFill').get_attribute('data-ratio')==str(state['bossHP']/state['rules']['bossHP'])
  assert page.locator('[data-skill="0"]').get_attribute('data-ready')=='true'
  assert page.locator('#taps').get_attribute('data-dots')=='●●●'
  page.screenshot(path=str(ROOT/f'presentation-hud-{reduced}.png'))
  # Capture a real HP decrease from full bar, and interrupt its ghost via hide.
  page.locator('#menuOpen').click();page.locator('#restart').click();page.locator('#confirmRestart').click();page.locator('#menuOpen').click();page.locator('#modeMenu').click();page.locator('#continueRun').click()
  assert page.locator('#bossFill').get_attribute('data-ratio')=='1'
  assert page.locator('#bossTrail').get_attribute('data-ratio')=='1'
  page.evaluate("()=>{Object.defineProperty(document,'hidden',{configurable:true,get:()=>true});document.dispatchEvent(new Event('visibilitychange'))}")
  assert page.evaluate("document.querySelectorAll('.presentation-choice').length")==0
  assert page.evaluate("[...document.querySelectorAll('#bossFill,#bossTrail')].every(e=>!e.getAnimations().length)")
  page.evaluate("()=>{Object.defineProperty(document,'hidden',{configurable:true,get:()=>false});document.dispatchEvent(new Event('visibilitychange'))}")
  assert page.evaluate('document.documentElement.scrollHeight===innerHeight')
  print('PASS HP settlement / readiness / restart / hidden',reduced,flush=True);page.close()
 b.close()
