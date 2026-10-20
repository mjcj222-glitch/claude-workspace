"""Targeted valid-save scene fixtures; full gameplay is tested separately."""
from campaign_browser import setup,ROOT
from playwright.sync_api import sync_playwright
import hashlib,base64,json
files={'normal':'encounter-mob.webp','elite':'storybook-battle.webp','midboss':'encounter-midboss.webp','boss':'encounter-boss.webp','rest':'encounter-rest.webp','event':'encounter-event.webp'}
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 for w,h,motion,standalone in [(390,844,'no-preference',False),(360,640,'reduce',True)]:
  page=b.new_page(viewport={'width':w,'height':h},reduced_motion=motion);setup(page,standalone)
  for kind,depth,index in [('normal',0,0),('elite',1,1),('rest',2,0),('event',2,1),('midboss',3,0),('boss',5,0)]:
   state=page.evaluate('''async([depth,index])=>{const x=await import('/expedition.mjs'),e=x.createExpedition(41);for(let d=0;d<=depth;d++){x.enterRoom(e,x.availableRooms(e)[d===depth?index:0].id);if(d===depth)break;if(e.phase==='battle'){e.state.damage=9999;e.state.taps=1;x.expeditionTap(e,1);x.takeReward(e,x.rewards(e)[0]);}else x.resolveRoom(e,'rest');}if(!x.decodeExpedition(JSON.stringify(e)))throw Error('Invalid fixture');return e}''',[depth,index])
   page.evaluate('(e)=>localStorage.setItem("resonance-expedition-v1",JSON.stringify(e))',state);page.reload();page.locator('#expeditionContinue').click()
   selector='#roomScene .room-scene-art' if kind in ['rest','event'] else '.concept-boss'
   src=page.locator(selector).evaluate('async e=>{const src=getComputedStyle(e).backgroundImage.slice(5,-2),im=new Image();im.src=src;await im.decode();return src}')
   if standalone:
    key='--asset-a'+hashlib.sha256((ROOT/'assets'/files[kind]).read_bytes()).hexdigest()[:16]
    assert page.evaluate('(key)=>getComputedStyle(document.documentElement).getPropertyValue(key).trim().slice(5,-2)',key)==src
   else:assert src.endswith(files[kind]),(kind,src)
   assert page.locator('#enemy').get_attribute('data-encounter')==kind
   if kind in ['rest','event']:
    assert page.locator('#routeRows').is_hidden();assert page.locator('#roomChoices').is_visible();assert page.locator('#roomScene').is_visible()
   else:
    size=page.locator('.skills .portrait').first.bounding_box();assert size['width']>=60 and size['height']>=60,size
    if motion=='reduce':assert not page.locator('#encounterEntrance').inner_text()
   if kind=='boss' and motion!='reduce':
    assert page.locator('#encounterEntrance').inner_text().startswith('최종보스')
    page.screenshot(path=str(ROOT/f'encounter-boss-arrival-{w}.png'),type='png')
   page.wait_for_timeout(750 if motion!='reduce' else 20)
   assert page.evaluate('document.documentElement.scrollHeight===innerHeight')
   page.screenshot(path=str(ROOT/f'encounter-{kind}-{w}-{motion}.png'),type='png')
   # Enter animation never owns gameplay or leaves an input-blocking overlay.
   if kind in ['midboss','boss']:
    assert not page.locator('#encounterEntrance').inner_text()
    page.locator('.tile').nth(1).evaluate('e=>{e.click();e.click()}');page.wait_for_function("document.querySelector('#board').dataset.resolving==='false'")
    saved=page.evaluate("JSON.parse(localStorage.getItem('resonance-expedition-v1'))");assert saved['state']['taps']==2
   print(json.dumps({'size':[w,h],'kind':kind,'motion':motion,'standalone':standalone,'result':'PASS'}),flush=True)
  # The new cute sheet is loaded in the actual skill dock.
  src=page.locator('.portrait-0').first.evaluate('e=>getComputedStyle(e).backgroundImage.slice(5,-2)')
  if standalone:
   key='--asset-a'+hashlib.sha256((ROOT/'assets/portraits-cute.webp').read_bytes()).hexdigest()[:16]
   assert page.evaluate('(key)=>getComputedStyle(document.documentElement).getPropertyValue(key).trim().slice(5,-2)',key)==src
  else:assert src.endswith('portraits-cute.webp')
  crops=page.locator('.skills .portrait').evaluate_all('els=>els.map(e=>({size:getComputedStyle(e).backgroundSize,pos:getComputedStyle(e).backgroundPosition}))')
  assert [c['pos'] for c in crops]==['6.25% 50%','50% 50%','93.75% 50%']
  assert all(c['size']=='420% 140%' for c in crops)
  page.close()
 b.close()
