from campaign_browser import ROOT,setup
from playwright.sync_api import sync_playwright
import json,sys
prefix=sys.argv[1] if len(sys.argv)>1 else 'neutral-after'
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 for w,h in ([(390,844)] if prefix=='neutral-before' else [(360,800),(390,844),(1280,900)]):
  for motion in (['no-preference'] if prefix=='neutral-before' else ['no-preference','reduce']):
   page=b.new_page(viewport={'width':w,'height':h},reduced_motion=motion);errors=[];page.on('pageerror',lambda e:errors.append(str(e)));setup(page,False)
   def shot(name):
    assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
    page.screenshot(path=str(ROOT/f'{prefix}-{name}-{w}-{motion}.png'))
   shot('start');page.locator('#startNew').click();shot('battle');page.locator('#skipLesson').click();page.locator('#feedbackHelp').click();shot('settings');page.locator('#closeFeedback').click();page.locator('#skillHelp').click();shot('skills');page.locator('#closeSkills').click()
   page.locator('#modeMenu').click();page.locator('#expeditionNew').click();shot('map')
   fixtures=page.evaluate("async()=>{const x=await import('/expedition.mjs');const e=x.createExpedition(7);x.enterRoom(e,x.availableRooms(e)[0].id);e.state.damage=9999;e.state.taps=1;x.expeditionTap(e,1);const reward=structuredClone(e);x.takeReward(e,x.rewards(e)[0]);x.enterRoom(e,x.availableRooms(e)[0].id);e.state.damage=9999;e.state.taps=1;x.expeditionTap(e,1);x.takeReward(e,x.rewards(e)[0]);x.enterRoom(e,x.availableRooms(e)[1].id);const room=structuredClone(e);x.resolveRoom(e,'rest');while(!['complete','defeat'].includes(e.phase)){if(e.phase==='map')x.enterRoom(e,x.availableRooms(e)[0].id);else if(e.phase==='room')x.resolveRoom(e,'rest');else if(e.phase==='reward')x.takeReward(e,x.rewards(e)[0]);else{e.state.damage=9999;e.state.taps=1;x.expeditionTap(e,1);}}return {reward,room,result:e};}")
   for name,e in fixtures.items():
    page.evaluate('(e)=>localStorage.setItem("resonance-expedition-v1",JSON.stringify(e))',e);page.reload();page.locator('#expeditionContinue').click();shot(name)
   if prefix!='neutral-before':
    # Actual rendered text and background contrast for neutral UI surfaces.
    contrast=page.evaluate('''()=>{const rgb=s=>s.match(/[\\d.]+/g).slice(0,3).map(Number),lum=a=>a.map(v=>{v/=255;return v<=.04045?v/12.92:((v+.055)/1.055)**2.4}).reduce((s,v,i)=>s+v*[.2126,.7152,.0722][i],0);return ['body','#ending','#again','#another','#endingMenu'].map(sel=>{const c=getComputedStyle(document.querySelector(sel)),a=lum(rgb(c.color)),b=lum(rgb(c.backgroundColor));return {sel,ratio:(Math.max(a,b)+.05)/(Math.min(a,b)+.05)}})}''')
    assert all(x['ratio']>=4.5 for x in contrast),contrast
    page.keyboard.press('Tab');page.locator('#endingMenu').focus();assert page.locator('#endingMenu').evaluate("e=>getComputedStyle(e).outlineStyle!=='none'")
    print(json.dumps({'width':w,'motion':motion,'screens':8,'contrast':contrast,'result':'PASS'}),flush=True)
   assert not errors,errors;page.close()
 b.close()
