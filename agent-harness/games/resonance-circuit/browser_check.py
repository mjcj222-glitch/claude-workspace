"""Optional browser smoke test using already-installed Playwright/Chromium. No server."""
from pathlib import Path
from playwright.sync_api import sync_playwright
import json
ROOT = Path(__file__).resolve().parent

def run():
 with sync_playwright() as p:
  browser = p.chromium.launch(executable_path='/usr/bin/chromium', headless=True)
  for width, height, motion in [(360,800,'reduce'),(1280,900,'reduce'),(360,800,'no-preference')]:
   page = browser.new_page(viewport={'width':width,'height':height}, reduced_motion=motion, has_touch=True)
   errors=[]
   page.on('pageerror', lambda error: errors.append(str(error)))
   def serve(route):
    name=route.request.url.split('resonance.test/')[-1] or 'index.html'
    file=ROOT/name
    if file.parent!=ROOT or not file.is_file():
     route.fulfill(status=404,body='Not found'); return
    mime='text/javascript' if file.suffix=='.mjs' else 'text/css' if file.suffix=='.css' else 'text/html'
    route.fulfill(status=200,content_type=mime,body=file.read_text())
   page.route('http://resonance.test/**',serve)
   page.goto('http://resonance.test/')
   assert page.locator('#guide').evaluate('(e)=>e.open')
   for _ in range(3): page.locator('#guideNext').click()
   assert page.locator('.tile').count()==42
   assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
   tile=page.locator('.tile').nth(1)
   box=tile.bounding_box(); x=box['x']+box['width']/2; y=box['y']+box['height']/2
   page.mouse.move(x,y);page.mouse.down();page.mouse.move(x+20,y);page.mouse.move(x,y);page.mouse.up()
   assert '3 / 3' in page.locator('#taps').inner_text()
   # Two keyboard activations in the same JS task must yield only one tap.
   tile.evaluate("e=>{e.click();e.click();}")
   page.wait_for_timeout(450)
   assert '2 / 3' in page.locator('#taps').inner_text()
   page.locator('#restart').click()
   tile.focus();page.keyboard.press('ArrowDown');page.keyboard.press('Enter');page.wait_for_timeout(450)
   assert '2 / 3' in page.locator('#taps').inner_text()
   page.locator('#restart').click()
   # Pick groups by visible tile colors, using the same hex topology but no private game state.
   page.locator('.tile').nth(1).tap();page.wait_for_timeout(450)
   assert '2 / 3' in page.locator('#taps').inner_text()
   page.locator('#restart').click()
   for mode in (['largest','smallest'] if motion=='reduce' else []):
    page.locator('#restart').click()
    for step in range(120):
     if page.locator('#ending').evaluate('(e)=>e.open'): break
     if mode=='largest':
      for selector in ['[data-skill="0"]','[data-skill="1"]','#boost']:
       b=page.locator(selector)
       if b.is_enabled(): b.click()
     idx=page.evaluate('''mode=>{const b=[...document.querySelectorAll('.tile')];const colors=b.map(e=>['coral','gold','blue','heal'].find(c=>e.classList.contains(c)));const sizes=b.map((_,i)=>{const seen=new Set([i]),q=[i];for(const k of q){const c=Math.floor(k/7),r=k%7;for(const [dc,dr] of [[0,-1],[0,1],[-1,0],[1,0],[-1,c%2?1:-1],[1,c%2?1:-1]]){const x=c+dc,y=r+dr,n=x*7+y;if(x>=0&&x<6&&y>=0&&y<7&&!seen.has(n)&&colors[n]===colors[i]){seen.add(n);q.push(n);}}}return seen.size;});return sizes.indexOf(mode==='largest'?Math.max(...sizes):Math.min(...sizes));}''',mode)
     page.locator('.tile').nth(idx).evaluate('e=>e.click()');page.wait_for_timeout(35 if motion=='reduce' else 450)
    assert page.locator('#ending').evaluate('(e)=>e.open'), 'No ending within 120 taps'
    result=page.locator('#result').inner_text()
    assert ('돌아왔습니다' in result) if mode=='largest' else ('꺼진' in result)
    print(json.dumps({'viewport':width,'strategy':mode,'result':result,'stats':page.locator('#stats').inner_text()},ensure_ascii=False))
    page.locator('#again').click();assert '3 / 3' in page.locator('#taps').inner_text()
   if motion=='reduce': page.screenshot(path=str(ROOT/f'preview-{width}.png'),full_page=True)
   assert not errors, errors
   print(f'PASS {width}px motion={motion}: tutorial, layout, drag cancel, duplicate input, keyboard, touch, no JS errors; endings tested in reduced-motion cases')
   page.close()
  browser.close()
if __name__=='__main__': run()
