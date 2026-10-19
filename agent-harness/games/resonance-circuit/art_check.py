"""Focused visual feedback checks; local route only, no server or state injection."""
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parent
with sync_playwright() as p:
 browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 for width in [360,1280]:
  page=browser.new_page(viewport={'width':width,'height':900},has_touch=True)
  errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
  def serve(route):
   route.fulfill(content_type='text/html',body=(ROOT/'standalone.html').read_text())
  page.route('http://resonance.test/**',serve);page.goto('http://resonance.test/')
  for _ in range(3):page.locator('#guideNext').click()
  page.wait_for_timeout(100)
  page.screenshot(path=str(ROOT/f'after-polish-{width}.png'),full_page=True)
  page.locator('.tile').nth(1).tap();page.wait_for_timeout(80)
  assert page.locator('.cleared').count()>=5
  assert int(page.locator('#effects').get_attribute('data-active') or 0)<=100
  page.screenshot(path=str(ROOT/f'chain-{width}.png'),full_page=True)
  page.wait_for_timeout(500)
  marked=page.locator('.marked').first;assert marked.count();marked.tap();page.wait_for_timeout(70)
  assert page.locator('.echo-label').filter(has_text='잔향 공명').count()==1
  page.screenshot(path=str(ROOT/f'echo-{width}.png'),full_page=True)
  page.wait_for_timeout(750)
  page.locator('[data-skill="1"]').click()
  bomb=page.locator('.tile').filter(has=page.locator('small',has_text='✹')).first
  assert bomb.count();bomb.tap();page.wait_for_timeout(60)
  assert int(page.locator('#effects').get_attribute('data-active') or 0)>0
  page.screenshot(path=str(ROOT/f'bomb-{width}.png'),full_page=True)
  page.wait_for_timeout(950)
  assert page.locator('.fx-label,.cleared,.hit,.skill-used').count()==0
  assert page.locator('#effects').get_attribute('data-active')=='0'
  assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
  page.locator('#restart').click()
  assert page.locator('#effects').get_attribute('data-active')=='0'
  assert not errors,errors
  print(f'PASS {width}px: sequential clear, marked echo activation, actual bomb, <=100 particles, cleanup, restart, no overflow/JS errors',flush=True)
  page.close()
 browser.close()
