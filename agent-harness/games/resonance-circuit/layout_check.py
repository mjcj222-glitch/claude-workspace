from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path(__file__).resolve().parent
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 for w,h in [(360,800),(390,844),(1280,900)]:
  page=b.new_page(viewport={'width':w,'height':h},reduced_motion='reduce',has_touch=True)
  errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
  page.route('http://resonance.test/**',lambda route:route.fulfill(content_type='text/html',body=(ROOT/'standalone.html').read_text()))
  page.goto('http://resonance.test/')
  for _ in range(3):page.locator('#guideNext').click()
  page.wait_for_timeout(250)
  page.screenshot(path=str(ROOT/f'concept-ui-{w}.png'),full_page=True)
  assert page.locator('.tile').count()==42
  assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
  bounds=page.locator('#boost').bounding_box()
  print(w,h,'boost bottom',round(bounds['y']+bounds['height']), 'tile',page.locator('.tile').first.bounding_box(),flush=True)
  assert bounds['y']+bounds['height']<=h
  assert not errors
  page.close()
 b.close()
