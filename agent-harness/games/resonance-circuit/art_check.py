"""Actual campaign echo/bomb visuals with clean-up verification."""
from playwright.sync_api import sync_playwright
from campaign_browser import setup,saved,ROOT
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 for w in [360,1280]:
  page=b.new_page(viewport={'width':w,'height':900},has_touch=True)
  errors=[];page.on('pageerror',lambda e:errors.append(str(e)));setup(page,True);page.locator('#startNew').click();page.locator('#skipLesson').click()
  page.locator('.tile').nth(1).tap();page.wait_for_timeout(80);assert page.locator('.cleared').count()>=5
  assert int(page.locator('#effects').get_attribute('data-active') or 0)<=100
  page.screenshot(path=str(ROOT/f'run-chain-{w}.png'),full_page=True);page.wait_for_timeout(500)
  page.locator('.marked').first.tap();page.wait_for_timeout(70);page.screenshot(path=str(ROOT/f'run-echo-{w}.png'),full_page=True);page.wait_for_timeout(750)
  assert saved(page)['run']['state']['echoCount']==1
  page.locator('[data-skill="1"]').click();page.locator('.tile').filter(has=page.locator('small',has_text='✹')).first.tap();page.wait_for_timeout(60)
  assert int(page.locator('#effects').get_attribute('data-active') or 0)>0;page.screenshot(path=str(ROOT/f'run-bomb-{w}.png'),full_page=True);page.wait_for_timeout(950)
  assert page.locator('.fx-label,.cleared,.hit,.hurt,.skill-used').count()==0;assert page.locator('#effects').get_attribute('data-active')=='0'
  assert page.evaluate('document.documentElement.scrollWidth<=innerWidth');assert not errors
  print('PASS campaign visual feedback and cleanup',w,flush=True);page.close()
 b.close()
