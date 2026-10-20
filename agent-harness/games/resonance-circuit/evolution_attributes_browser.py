"""Controlled legal mega fixtures compare exact visible blast targets, not ordinary runs."""
from campaign_browser import setup,ROOT
from playwright.sync_api import sync_playwright
import json
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 for w,h,motion,standalone in [(390,844,'no-preference',True),(360,640,'reduce',False)]:
  page=b.new_page(viewport={'width':w,'height':h},reduced_motion=motion);errors=[];page.on('pageerror',lambda e:errors.append(str(e)));setup(page,standalone)
  for color in ['coral','gold','blue']:
   f=page.evaluate("""async color=>{const c=await import('/campaign.mjs'),engine=await import('/engine.mjs'),storage=await import('/storage.mjs'),r=c.createRun(41,false,1,1);r.megaSeen=[true,true];r.megaLesson=null;r.state.board.forEach(t=>{t.kind='normal';t.color='heal';delete t.vine});const i=r.state.board.reduce((best,t,i,b)=>Math.hypot(t.x-210,t.y-280)<Math.hypot(b[best].x-210,b[best].y-280)?i:best,0);r.state.board[i].kind='mega';r.state.board[i].color=color;const data={version:1,run:r,learned:true,audio:{enabled:false,volume:.3}};if(!storage.decodeSave(JSON.stringify(data)))throw Error('invalid fixture');return {data,i,p:engine.preview(r.state,i)};}""",color)
   page.evaluate('(d)=>localStorage.setItem("resonance-circuit-v1",JSON.stringify(d))',f['data']);page.reload();page.locator('#continueRun').click();tile=page.locator('.tile').nth(f['i']);tile.focus()
   indices=page.locator('.tile.selected').evaluate_all('els=>els.map(e=>Number(e.dataset.index))');assert set(indices)==set(f['p']['removed'])
   badge=tile.locator('small').bounding_box();box=tile.bounding_box();assert abs(badge['x']+badge['width']/2-(box['x']+box['width']/2))<1
   page.screenshot(path=str(ROOT/f'evolution-attribute-{color}-{w}.png'))
   tile.evaluate('e=>{e.click();e.click()}');page.wait_for_function("document.querySelector('#board').dataset.resolving==='false'")
   saved=page.evaluate("JSON.parse(localStorage.getItem('resonance-circuit-v1')).run");assert saved['state']['taps']==2
   assert page.locator('#saveStatus').inner_text()=='저장됨'
   print(json.dumps({'size':[w,h],'color':color,'removed':len(indices),'previewMatches':'PASS','result':'PASS'}),flush=True)
  assert not errors,errors;page.close()
 b.close()
