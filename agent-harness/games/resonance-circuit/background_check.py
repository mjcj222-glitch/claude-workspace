from campaign_browser import setup,saved,ROOT
from playwright.sync_api import sync_playwright
import subprocess,json
fixtures=json.loads(subprocess.check_output(['node','--input-type=module','-e',"import {createRun,runTap,chooseUpgrade} from './campaign.mjs';const r=createRun(7,false),out=[structuredClone(r)];for(const id of ['power','healing']){r.state.bossHP=1;r.state.damage=9999;r.state.taps=1;runTap(r,1);chooseUpgrade(r,id);out.push(structuredClone(r));}console.log(JSON.stringify(out));"],cwd=ROOT,text=True))
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 for w,h in [(360,800),(390,844),(1280,900)]:
  page=b.new_page(viewport={'width':w,'height':h},reduced_motion='reduce',has_touch=True);errors=[];page.on('pageerror',lambda e:errors.append(str(e)));setup(page,True)
  heights=[]
  for stage,r in enumerate(fixtures):
   page.evaluate('(r)=>localStorage.setItem("resonance-circuit-v1",JSON.stringify({version:1,run:r,learned:true,audio:{enabled:false,volume:.3}}))',r);page.reload();page.locator('#continueRun').click()
   assert page.evaluate('scrollY')==0
   art=page.locator('.concept-boss').bounding_box();heights.append(art['height']);assert art['height']>=170
   assert abs(art['width']/art['height']-940/492)<.02
   page.screenshot(path=str(ROOT/f'background-stage-{stage+1}-{w}.png'),full_page=True)
   assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
   assert page.locator('.tile').first.bounding_box()['height']>=40
   # First tile focus is already set without moving the view. Arrow down stays visible.
   before=page.evaluate('scrollY');page.keyboard.press('ArrowDown');assert page.evaluate('scrollY')==before
   # Lower controls remain reachable by scrolling; return from help must not jump to a tile.
   page.locator('#help').click();before=page.evaluate('scrollY')
   for n in range(5):page.locator('#guideNext').click()
   assert abs(page.evaluate('scrollY')-before)<2
  assert max(heights)-min(heights)<1
  print(json.dumps({'viewport':[w,h],'scene_heights':heights,'stages':3,'errors':len(errors)}),flush=True);assert not errors;page.close()
 b.close()
