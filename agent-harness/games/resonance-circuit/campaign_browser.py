"""Campaign E2E: real UI actions; saved-state reads are a strategy oracle, not mutations."""
from pathlib import Path
from playwright.sync_api import sync_playwright
import json,sys
ROOT=Path(__file__).resolve().parent
KEY='resonance-circuit-v1'

def setup(page, standalone):
 def serve(route):
  name=route.request.url.split('resonance.test/')[-1].split('?')[0] or 'index.html'
  f=ROOT/('standalone.html' if standalone and name=='index.html' else name)
  if not f.resolve().is_relative_to(ROOT) or not f.is_file():route.fulfill(status=404,body='missing');return
  mime='image/png' if f.suffix=='.png' else 'text/javascript' if f.suffix=='.mjs' else 'text/css' if f.suffix=='.css' else 'text/html'
  route.fulfill(content_type=mime,body=f.read_bytes())
 page.route('http://resonance.test/**',serve)
 page.goto('http://resonance.test/')
 page.evaluate("async()=>{window.oracle=await import('/engine.mjs')}")

def saved(page):return page.evaluate("JSON.parse(localStorage.getItem('resonance-circuit-v1'))")
def idle(page):page.wait_for_function("document.querySelector('#board').dataset.resolving!=='true' && !document.querySelector('.cleared') && document.querySelector('#saveStatus').textContent==='저장됨'");page.wait_for_timeout(430 if page.evaluate("matchMedia('(prefers-reduced-motion: reduce)').matches") is False else 20)

def full_run(browser,w,h,motion,standalone):
 page=browser.new_page(viewport={'width':w,'height':h},reduced_motion=motion,has_touch=True)
 errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
 setup(page,standalone)
 assert page.locator('#start').evaluate('(e)=>e.open')
 page.locator('#startNew').click()
 assert page.locator('#coach').is_visible()
 page.locator('.lesson-target').first.tap();idle(page)
 assert saved(page)['run']['tutorial']=='echo'
 page.locator('.lesson-target').first.tap();idle(page)
 assert saved(page)['learned'] and not page.locator('#coach').is_visible()
 # New-game cancellation must preserve the board and progress.
 before=saved(page)['run'];page.locator('#newSeed').click();page.locator('#cancelNew').click();assert saved(page)['run']==before
 # Reload resumes the exact board, phase and RNG. No automatic gameplay.
 page.reload();page.evaluate("async()=>{window.oracle=await import('/engine.mjs')}");page.locator('#continueRun').click();assert saved(page)['run']==before
 # Arrow boundaries and keyboard confirmation, touch cancellation (synthetic browser PointerEvent).
 for index,key in [(7,'ArrowUp'),(6,'ArrowDown'),(3,'ArrowLeft'),(35,'ArrowRight')]:
  page.locator('.tile').nth(index).focus();page.keyboard.press(key);assert page.evaluate('Number(document.activeElement.dataset.index)')==index
 tile=page.locator('.tile').nth(0);before=saved(page)['run']
 tile.evaluate("e=>{const r=e.getBoundingClientRect();for(const type of ['pointerdown','pointercancel','pointerup'])e.dispatchEvent(new PointerEvent(type,{bubbles:true,pointerId:99,pointerType:'touch',button:0,clientX:r.x+r.width/2,clientY:r.y+r.height/2}));}")
 assert saved(page)['run']==before
 tile.evaluate("e=>{const r=e.getBoundingClientRect();e.dispatchEvent(new PointerEvent('pointerdown',{bubbles:true,pointerId:99,pointerType:'touch',button:0,clientX:r.x+20,clientY:r.y+20}));window.dispatchEvent(new PointerEvent('pointermove',{pointerId:99,clientX:r.x+50,clientY:r.y+20}));e.dispatchEvent(new PointerEvent('pointerup',{bubbles:true,pointerId:99,button:0,clientX:r.x+20,clientY:r.y+20}));}")
 assert saved(page)['run']==before
 # Audio opt in + volume save; keep muted during bulk automated battle.
 assert page.locator('#sound').get_attribute('aria-pressed')=='false'
 page.locator('#sound').click();assert saved(page)['audio']['enabled'];page.locator('#volume').fill('20');page.locator('#volume').dispatch_event('input');assert saved(page)['audio']['volume']==.2
 page.locator('#sound').click();assert not saved(page)['audio']['enabled']
 captured=set();upgrades=0
 for n in range(350):
  r=saved(page)['run']
  if r['phase']=='complete':break
  if r['phase']=='defeat':raise AssertionError(f'unexpected loss {w} {motion} stage {r["stage"]}')
  if r['phase']=='upgrade':
   page.locator('#upgrade').wait_for(state='visible')
   page.reload();page.evaluate("async()=>{window.oracle=await import('/engine.mjs')}");page.locator('#continueRun').click();assert saved(page)['run']==r
   page.locator('#upgrade').wait_for(state='visible');page.screenshot(path=str(ROOT/f'run-upgrade-{w}-{motion}.png'),full_page=True)
   # Two click events in one task select only once.
   choice='power' if r['stage']==0 else 'healing'
   page.locator(f'[data-choice="{choice}"]').evaluate('e=>{e.click();e.click();}')
   assert saved(page)['run']['stage']==r['stage']+1;upgrades+=1
   continue
  stage=r['stage']
  if stage not in captured:
   page.screenshot(path=str(ROOT/f'run-battle-{stage+1}-{w}-{motion}.png'),full_page=True);captured.add(stage)
   assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
  s=r['state']
  if s['hp']<s['rules']['hp']*.65 and page.locator('[data-skill="2"]').is_enabled():page.locator('[data-skill="2"]').click()
  for selector in ['[data-skill="0"]','[data-skill="1"]','#boost']:
   if page.locator(selector).is_enabled():page.locator(selector).click()
  index=page.evaluate("()=>{const s=JSON.parse(localStorage.getItem('resonance-circuit-v1')).run.state;const scores=s.board.map((_,i)=>{const p=oracle.preview(s,i);return p.damage+Math.min(p.healing,Math.max(0,s.rules.hp-s.hp-s.healing))*1.3+(p.echoHit?12:0)});return scores.indexOf(Math.max(...scores))}")
  if n==0:
   page.locator('.tile').nth(index).focus();page.keyboard.press('Enter')
  else:page.locator('.tile').nth(index).tap()
  idle(page)
 assert saved(page)['run']['phase']=='complete'
 page.locator('#ending').wait_for(state='visible');page.wait_for_timeout(900)
 assert upgrades==2
 assert page.locator('.fx-label,.cleared,.hit,.hurt,.skill-used').count()==0
 assert page.locator('#effects').get_attribute('data-active') in ['0',None]
 assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
 page.screenshot(path=str(ROOT/f'run-result-{w}-{motion}.png'),full_page=True)
 print(json.dumps({'viewport':[w,h],'motion':motion,'standalone':standalone,'history':saved(page)['run']['history'],'result':'PASS'},ensure_ascii=False),flush=True)
 page.locator('#again').click();assert saved(page)['run']['stage']==0;assert saved(page)['run']['tutorial']=='done'
 assert not errors,errors
 page.close()

if __name__=='__main__':
 with sync_playwright() as p:
  b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
  cases=[(360,800,'reduce',False),(390,844,'reduce',True),(1280,900,'reduce',False),(360,800,'no-preference',True),(390,844,'no-preference',False),(1280,900,'no-preference',True)]
  if len(sys.argv)>1:cases=[cases[int(sys.argv[1])]]
  for args in cases:full_run(b,*args)
  b.close()
