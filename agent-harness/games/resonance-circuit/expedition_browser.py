from campaign_browser import setup,ROOT
from playwright.sync_api import sync_playwright
import json,sys
KEY='resonance-expedition-v1'
def read(page):return page.evaluate('(k)=>JSON.parse(localStorage.getItem(k))',KEY)
def idle(page):page.wait_for_function("document.querySelector('#board').dataset.resolving!=='true'")
def run(b,w,h,motion,standalone):
 page=b.new_page(viewport={'width':w,'height':h},reduced_motion=motion,has_touch=True);errors=[];page.on('pageerror',lambda e:errors.append(str(e)));setup(page,standalone)
 page.locator('#startNew').click();page.locator('#menuOpen').click();page.locator('#modeMenu').click();practice=page.evaluate("localStorage.getItem('resonance-circuit-v1')")
 page.locator('#expeditionNew').click();page.locator('#journey').wait_for(state='visible');seed=read(page)['seed'];before=read(page)
 page.locator('#journeyNew').click();page.locator('#cancelNew').click();assert read(page)==before
 seen=set();n=0
 while n<350:
  e=read(page);phase=e['phase'];assert page.locator('#saveStatus').inner_text()=='저장됨',(phase,e)
  assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
  if phase in ['complete','defeat']:break
  if phase not in seen:
   if phase!='battle':page.locator('#journey').wait_for(state='visible')
   page.screenshot(path=str(ROOT/f'expedition-{phase}-{w}-{motion}.png'),full_page=True);seen.add(phase)
   # Resume at map/reward/room/battle without regenerating offers or entry effects.
   before=read(page);page.reload();page.evaluate("async()=>window.oracle=await import('/engine.mjs')");page.locator('#expeditionContinue').click();assert read(page)==before
  if phase=='map':
   depth=e['depth'];index=1 if depth==4 else 0
   page.locator(f'[data-room="{depth}-{index}"]').click();page.locator('#roomEnter').evaluate('e=>{e.click();e.click()}')
  elif phase=='reward':page.locator('[data-reward]').first.evaluate('e=>{e.click();e.click()}')
  elif phase=='room':
   choice='gift' if e['map'][e['depth']][int(e['path'][-1][-1])]['type']=='event' and e['state']['hp']>60 and e['offer'] else 'rest'
   page.locator(f'[data-event="{choice}"]').evaluate('e=>{e.click();e.click()}')
  elif phase=='battle':
   if e['depth']==5 and 'boss' not in seen:page.screenshot(path=str(ROOT/f'expedition-boss-{w}-{motion}.png'),full_page=True);seen.add('boss')
   if e['state']['hp']<110 and page.locator('[data-skill="2"]').is_enabled():page.locator('[data-skill="2"]').click()
   for selector in ['[data-skill="0"]','[data-skill="1"]','#boost']:
    if page.locator(selector).is_enabled():page.locator(selector).click()
   index=page.evaluate("async()=>{const {relicEffects}=await import('/expedition.mjs');const e=JSON.parse(localStorage.getItem('resonance-expedition-v1')),s=e.state;let best=-1,index=0;for(let i=0;i<42;i++){const p=oracle.preview(s,i);if(!p.initial.length)continue;const f=relicEffects(e,p),score=p.damage+f.damage+Math.min(p.healing+f.healing,Math.max(0,180-s.hp-s.healing))*1.5+(p.echoHit?12:0)+f.shield;if(score>best){best=score;index=i}}return index}")
   page.locator('.tile').nth(index).tap();idle(page)
  n+=1
 e=read(page);assert e['phase']=='complete',(seed,e['phase'],e['total']);page.locator('#ending').wait_for(state='visible');assert page.locator('#retryBattle').is_hidden();page.screenshot(path=str(ROOT/f'expedition-result-{w}-{motion}.png'),full_page=True)
 assert page.evaluate("localStorage.getItem('resonance-circuit-v1')")==practice
 page.locator('#another').click();page.locator('#cancelNew').click();assert read(page)==e
 # Deterministic lethal fixture tests terminal save, no retry, and reload cannot revive.
 dead=page.evaluate("async()=>{const x=await import('/expedition.mjs');const e=x.createExpedition(53);x.enterRoom(e,x.availableRooms(e)[0].id);e.state.hp=1;e.state.taps=1;e.state.board.forEach((t,i)=>{t.color=['coral','blue','gold'][(Math.floor(i/7)+i%7)%3];t.kind='normal';});return e}")
 page.evaluate('(e)=>localStorage.setItem("resonance-expedition-v1",JSON.stringify(e))',dead);page.reload();page.locator('#expeditionContinue').click();page.locator('.tile').nth(0).tap();idle(page);page.locator('#ending').wait_for(state='visible');assert read(page)['phase']=='defeat';lost=read(page)
 page.reload();page.locator('#expeditionContinue').click();assert read(page)==lost;assert page.locator('#retryBattle').is_hidden();page.screenshot(path=str(ROOT/f'expedition-defeat-{w}-{motion}.png'),full_page=True)
 page.locator('#endingMenu').click();page.locator('#continueRun').click();assert page.evaluate("localStorage.getItem('resonance-circuit-v1')")==practice
 assert not errors,errors
 print(json.dumps({'size':[w,h],'motion':motion,'standalone':standalone,'seed':seed,'rooms':e['path'],'relics':e['relics'],'total':e['total'],'result':'PASS'},ensure_ascii=False),flush=True);page.close()
if __name__=='__main__':
 cases=[(360,800,'reduce',False),(390,844,'reduce',True),(1280,900,'reduce',False),(360,800,'no-preference',True),(390,844,'no-preference',False),(1280,900,'no-preference',True)]
 with sync_playwright() as p:
  b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
  for i in ([int(sys.argv[1])] if len(sys.argv)>1 else range(6)):run(b,*cases[i])
  b.close()
