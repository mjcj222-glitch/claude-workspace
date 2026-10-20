from campaign_browser import setup,ROOT
from playwright.sync_api import sync_playwright
import json
KEY='resonance-circuit-v1'
def read(page):return page.evaluate('(k)=>JSON.parse(localStorage.getItem(k)).run',KEY)
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True);page=b.new_page(viewport={'width':390,'height':844},has_touch=True);setup(page,False);page.locator('#startNew').click();page.locator('#skipLesson').click();before=read(page)
 tile=page.locator('.tile').first;rect=tile.bounding_box();x=rect['x']+rect['width']/2;y=rect['y']+rect['height']/2
 tile.dispatch_event('pointerdown',{'pointerId':7,'button':0,'clientX':x,'clientY':y});tile.dispatch_event('pointercancel',{'pointerId':7});tile.dispatch_event('pointerup',{'pointerId':7,'button':0,'clientX':x,'clientY':y});assert read(page)==before
 # Corner lies outside the circular hit target even though it is inside its DOM box.
 tile.dispatch_event('pointerdown',{'pointerId':8,'button':0,'clientX':rect['x']+.1,'clientY':rect['y']+.1});tile.dispatch_event('pointerup',{'pointerId':8,'button':0,'clientX':rect['x']+.1,'clientY':rect['y']+.1});assert read(page)==before
 expected=page.evaluate('async r=>{const c=await import("/campaign.mjs");c.runTap(r,0);return r}',before)
 tile.tap();page.wait_for_function("document.querySelector('#board').dataset.falling==='true'");page.locator('[data-skill="0"]').evaluate('e=>e.click()');page.locator('#boost').evaluate('e=>e.click()');page.locator('.tile').nth(2).evaluate('e=>e.click()');page.locator('#menuOpen').click();page.set_viewport_size({'width':360,'height':640});page.wait_for_function("document.querySelector('#board').dataset.resolving==='false'");assert read(page)==expected;assert page.locator('#gameMenu').is_visible();page.locator('#menuClose').click()
 print(json.dumps({'pointercancel':'no tap','cornerHit':'rejected','fallInputs':'ignored','menuResize':'one settlement','result':'PASS'}))
 page.close();b.close()
