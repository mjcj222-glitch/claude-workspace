from campaign_browser import setup,ROOT
from playwright.sync_api import sync_playwright
import json
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 for w,h in [(360,640),(360,800),(390,844),(1280,900)]:
  for motion in ['reduce','no-preference']:
   page=b.new_page(viewport={'width':w,'height':h},reduced_motion=motion,has_touch=True);errors=[];page.on('pageerror',lambda e:errors.append(str(e)));setup(page,False);page.locator('#startNew').click()
   assert page.locator('#menuOpen').count()==1,'mobile menu missing'
   dimensions=page.evaluate("()=>({w:innerWidth,h:innerHeight,sw:document.documentElement.scrollWidth,sh:document.documentElement.scrollHeight,tiles:[...document.querySelectorAll('.tile')].map(e=>{const r=e.getBoundingClientRect();return {x:r.x,y:r.y,w:r.width,h:r.height}}),dock:[...document.querySelectorAll('[data-skill],#boost')].map(e=>{const r=e.getBoundingClientRect();return {x:r.x,y:r.y,w:r.width,h:r.height}}),art:(()=>{const r=document.querySelector('.concept-boss').getBoundingClientRect();return {w:r.width,h:r.height}})()})")
   assert dimensions['sw']<=w and dimensions['sh']<=h,dimensions
   for box in dimensions['tiles']+dimensions['dock']:assert box['x']>=0 and box['y']>=0 and box['x']+box['w']<=w+1 and box['y']+box['h']<=h+1 and box['h']>=39,box
   assert page.locator('#incoming').is_visible() and page.locator('#bossText').is_visible()
   assert abs(dimensions['art']['w']/dimensions['art']['h']-940/492)<.01
   page.screenshot(path=str(ROOT/f'mobile-battle-{w}-{h}-{motion}.png'))
   page.locator('#skipLesson').click();page.screenshot(path=str(ROOT/f'mobile-combat-{w}-{h}-{motion}.png'));before=page.evaluate("localStorage.getItem('resonance-circuit-v1')")
   for n in range(3):
    page.locator('#menuOpen').click();assert page.locator('#gameMenu').is_visible();page.locator('.tile').nth(1).evaluate('e=>e.click()');assert page.evaluate("localStorage.getItem('resonance-circuit-v1')")==before
    page.locator('#menuClose').click();assert page.locator('#gameMenu').is_hidden()
   page.keyboard.press('Tab');page.locator('#menuOpen').focus();page.keyboard.press('Enter');page.keyboard.press('Escape');assert page.locator('#menuOpen').evaluate('e=>e===document.activeElement')
   page.locator('[data-skill="0"]').click();assert page.locator('#saveStatus').inner_text()=='저장됨'
   page.locator('.tile').nth(1).evaluate('e=>{e.click();e.click()}');page.locator('#menuOpen').click();page.wait_for_function("document.querySelector('#board').dataset.resolving==='false'");assert page.evaluate("JSON.parse(localStorage.getItem('resonance-circuit-v1')).run.state.taps")==2;page.locator('#menuClose').click()
   page.locator('#menuOpen').click();page.screenshot(path=str(ROOT/f'mobile-menu-{w}-{h}-{motion}.png'));page.locator('#modeMenu').click();page.locator('#expeditionNew').click();page.screenshot(path=str(ROOT/f'mobile-map-{w}-{h}-{motion}.png'))
   page.locator('[data-room="0-0"]').click();assert page.locator('#roomDetail').is_visible();assert page.evaluate("JSON.parse(localStorage.getItem('resonance-expedition-v1')).phase")=='map';page.locator('#roomBack').click();page.locator('[data-room="0-0"]').click();page.screenshot(path=str(ROOT/f'mobile-route-detail-{w}-{h}-{motion}.png'));page.locator('#roomEnter').click();assert page.evaluate("JSON.parse(localStorage.getItem('resonance-expedition-v1')).phase")=='battle'
   assert not errors,errors
   print(json.dumps({'size':[w,h],'motion':motion,'tileMinHeight':min(x['h'] for x in dimensions['tiles']),'art':dimensions['art'],'pageHeight':dimensions['sh'],'result':'PASS'}),flush=True);page.close()
 b.close()
