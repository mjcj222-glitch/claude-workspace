from playwright.sync_api import sync_playwright
from campaign_browser import setup,ROOT
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 for w,h in [(360,800),(390,844),(1280,900)]:
  page=b.new_page(viewport={'width':w,'height':h},reduced_motion='reduce',has_touch=True)
  setup(page,True);page.screenshot(path=str(ROOT/f'run-start-{w}.png'),full_page=True);page.locator('#startNew').click()
  for tutorial in [True,False]:
   if not tutorial:page.locator('#skipLesson').click()
   page.screenshot(path=str(ROOT/f'run-layout-{w}-{tutorial}.png'),full_page=True)
   assert page.locator('.tile').count()==42
   assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
   box=page.locator('#boost').bounding_box();print(w,h,'tutorial',tutorial,'boost bottom',round(box['y']+box['height']),flush=True)
   assert box['height']>=32
   page.locator('#boost').scroll_into_view_if_needed();assert page.locator('#boost').is_visible()
  page.close()
 b.close()
