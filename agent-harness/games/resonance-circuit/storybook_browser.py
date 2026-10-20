"""Check rendered artwork loads, exact sprite thirds and self-contained packaging."""
from campaign_browser import setup,ROOT
from playwright.sync_api import sync_playwright
import json
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 for standalone in [False,True]:
  page=b.new_page(viewport={'width':390,'height':844},reduced_motion='reduce');setup(page,standalone)
  page.locator('#startNew').click();page.locator('#skipLesson').click()
  images=page.evaluate('''async()=>{const selectors=['.concept-boss','.portrait-0','.portrait-1','.portrait-2','.coral .gem','.blue .gem','.gold .gem','.heal .gem'];return await Promise.all(selectors.map(async selector=>{const el=document.querySelector(selector),c=getComputedStyle(el),src=c.backgroundImage.slice(5,-2),im=new Image();im.src=src;await im.decode();return {selector,w:im.naturalWidth,h:im.naturalHeight,position:c.backgroundPosition,size:c.backgroundSize,inline:src.startsWith('data:')}}))}''')
  assert images[0]['w']==1774 and images[0]['h']==887
  assert [(x['w'],x['h']) for x in images[1:4]]==[(2172,724)]*3
  assert [x['position'] for x in images[1:4]]==['0% 0px','50% 0px','100% 0px']
  assert all(x['size']=='300% 100%' for x in images[1:4])
  assert all(x['w']==64 and x['h']==64 for x in images[4:])
  if standalone:assert all(x['inline'] for x in images)
  page.screenshot(path=str(ROOT/f'storybook-battle-390-{standalone}.png'))
  page.locator('#menuOpen').click();page.screenshot(path=str(ROOT/f'storybook-menu-390-{standalone}.png'))
  print(json.dumps({'standalone':standalone,'loaded_images':len(images),'sprite_thirds':'exact','result':'PASS'}),flush=True)
  page.close()
 b.close()
