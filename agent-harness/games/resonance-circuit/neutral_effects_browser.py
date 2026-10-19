from campaign_browser import setup,ROOT
from playwright.sync_api import sync_playwright
import json,base64
exec((ROOT/'timeline_browser.py').read_text().split('with sync_playwright() as p:')[0])
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 for w,h in [(360,800),(390,844),(1280,900)]:
  page=b.new_page(viewport={'width':w,'height':h},reduced_motion='no-preference');setup(page,True)
  cdp=page.context.new_cdp_session(page)
  for count in ['6','42']:
   page.evaluate('(d)=>localStorage.setItem("resonance-circuit-v1",JSON.stringify(d))',fixtures[count]);page.reload();page.locator('#continueRun').click();page.locator('.tile').nth(9).evaluate('e=>e.click()');page.wait_for_timeout(65)
   for frame in [1,2]:
    data=cdp.send('Page.captureScreenshot',{'format':'png'});(ROOT/f'neutral-effects-{count}-{w}-{frame}.png').write_bytes(base64.b64decode(data['data']));page.wait_for_timeout(60)
   page.wait_for_function("document.querySelector('#board').dataset.resolving==='false'")
   assert page.locator('.cleared,[data-clear-id]').count()==0
  print('PASS effects contrast capture / cleanup',w,flush=True);page.close()
 b.close()
