from campaign_browser import setup,ROOT
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True);page=b.new_page(viewport={'width':360,'height':800});setup(page,True)
 page.locator('#startNew').click();page.locator('#modeMenu').click();practice=page.evaluate("localStorage.getItem('resonance-circuit-v1')")
 page.locator('#expeditionNew').click();page.locator('#journeyRelicHelp').click();assert page.locator('#relicList strong').count()==8;page.locator('#closeRelics').click()
 page.locator('[data-room="0-0"]').focus();page.keyboard.press('Enter');assert page.evaluate("JSON.parse(localStorage.getItem('resonance-expedition-v1')).phase")=='battle'
 page.locator('#restart').click();page.locator('#cancelNew').click();assert page.evaluate("JSON.parse(localStorage.getItem('resonance-expedition-v1')).path.length")==1
 page.locator('#newSeed').click();page.locator('#confirmRestart').click();assert page.evaluate("JSON.parse(localStorage.getItem('resonance-expedition-v1')).path.length")==0
 assert page.evaluate("localStorage.getItem('resonance-circuit-v1')")==practice
 box=page.locator('#journey').bounding_box();assert box['y']>=0 and box['y']+box['height']<=801,box
 page.screenshot(path=str(ROOT/'expedition-map-viewport-360.png'))
 print('PASS keyboard room entry, relic help, new expedition confirmation/acceptance, practice isolation, viewport dialog bounds');b.close()
