from campaign_browser import setup,ROOT
from playwright.sync_api import sync_playwright
import json
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 page=b.new_page(viewport={'width':390,'height':844},has_touch=True);errors=[];page.on('pageerror',lambda e:errors.append(str(e)));setup(page,False)
 page.locator('#startNew').click();page.locator('#skipLesson').click();page.screenshot(path=str(ROOT/'flow-first-390.png'))
 print(json.dumps({'errors':errors,'save':page.locator('#saveStatus').inner_text(),'board':page.locator('#board').bounding_box(),'stage':page.locator('#enemy').bounding_box(),'dock':page.locator('.party-dock').bounding_box(),'tile':page.locator('.tile').first.bounding_box(),'body':page.evaluate('document.documentElement.scrollHeight'),'mode':page.evaluate("JSON.parse(localStorage.getItem('resonance-circuit-v1')).run.boardVersion")}))
 page.locator('.tile').first.tap();page.wait_for_function("document.querySelector('#board').dataset.resolving==='false'");print('after',page.locator('#saveStatus').inner_text(),errors);page.screenshot(path=str(ROOT/'flow-after-390.png'));b.close()
