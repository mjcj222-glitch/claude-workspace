"""Valid fixtures isolate decorative choices; complete runs are verified separately."""
from campaign_browser import setup,ROOT
from playwright.sync_api import sync_playwright
import json
KEY='resonance-expedition-v1'
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 for w,h,motion,standalone in [(360,640,'no-preference',False),(360,640,'reduce',True),(390,844,'no-preference',True),(390,844,'reduce',False)]:
  page=b.new_page(viewport={'width':w,'height':h},reduced_motion=motion,has_touch=True);errors=[];page.on('pageerror',lambda e:errors.append(str(e)));setup(page,standalone)
  for kind in ['reward','elite','rest','event']:
   fixture=page.evaluate("""async kind=>{const x=await import('/expedition.mjs');const e=x.createExpedition(41,2,1,1);
    while(true){if(e.phase==='map')x.enterRoom(e,x.availableRooms(e)[kind==='elite'&&e.depth===1||kind==='event'&&e.depth===2?1:0].id);
     if(e.phase==='room')break;
     if(e.phase==='battle'){e.state.damage=9999;e.state.taps=1;x.expeditionTap(e,e.state.board.findIndex(t=>!t.vine));}
     if(e.phase==='reward'&&(kind==='reward'||kind==='elite'&&e.depth===1))break;
     x.takeReward(e,x.rewards(e)[0]);}
    if(!x.decodeExpedition(JSON.stringify(e)))throw Error('invalid fixture');return e;}""",kind)
   page.evaluate('([k,e])=>localStorage.setItem(k,JSON.stringify(e))',[KEY,fixture]);page.reload();page.locator('#expeditionContinue').click()
   assert page.locator('#journey').is_visible()
   area=page.locator('#journey .reward-vignette' if kind in ['reward','elite'] else '#roomScene')
   assert area.is_visible()
   selector='[data-reward]' if kind in ['reward','elite'] else '[data-event]'
   choice=page.locator(selector).first;assert choice.is_enabled()
   choice.focus();assert choice.evaluate('e=>document.activeElement===e')
   before=page.evaluate('(k)=>JSON.parse(localStorage.getItem(k))',KEY)
   assert before==fixture
   if motion=='reduce':assert area.locator('.choice-atmosphere').evaluate("e=>e.getAnimations({subtree:true}).length")==0
   else:
    assert area.locator('.choice-atmosphere').evaluate("e=>e.getAnimations({subtree:true}).some(a=>a.playState==='running')")
    # A background tab pauses ornamentation and never applies a choice.
    page.evaluate("Object.defineProperty(document,'hidden',{configurable:true,value:true});document.dispatchEvent(new Event('visibilitychange'))")
    assert area.locator('.choice-atmosphere').evaluate("e=>e.getAnimations({subtree:true}).every(a=>a.playState==='paused')")
    assert page.evaluate('(k)=>JSON.parse(localStorage.getItem(k))',KEY)==before
    page.evaluate("Object.defineProperty(document,'hidden',{configurable:true,value:false});document.dispatchEvent(new Event('visibilitychange'))")
   assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
   page.screenshot(path=str(ROOT/f'evolution-choice-{kind}-{w}-{motion}.png'))
   # Actual callback on the stale button twice: only first choice can change state.
   choice.evaluate('e=>{e.click();e.click()}')
   after=page.evaluate('(k)=>JSON.parse(localStorage.getItem(k))',KEY);assert after['depth']==before['depth']+1
   if kind in ['reward','elite']:assert len(after['relics'])==len(before['relics'])+1
   page.reload();page.locator('#expeditionContinue').click();assert page.evaluate('(k)=>JSON.parse(localStorage.getItem(k))',KEY)==after
   page.locator(f'[data-room="{after["depth"]}-0"]').click();assert page.locator('#roomDetail').is_visible();page.locator('#roomBack').click()
   assert page.evaluate('(k)=>JSON.parse(localStorage.getItem(k))',KEY)==after
   print(json.dumps({'size':[w,h],'motion':motion,'standalone':standalone,'scene':kind,'result':'PASS'}),flush=True)
  assert not errors,errors;page.close()
 b.close()
