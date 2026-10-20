"""Exercise presentation controller boundaries in the real browser, without game timing."""
from campaign_browser import setup,ROOT
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 for motion in ['no-preference','reduce']:
  page=b.new_page(viewport={'width':390,'height':844},reduced_motion=motion);setup(page,False)
  page.evaluate('''async()=>{
   document.body.innerHTML='<main><section id="enemy"><div><span id="bossText"></span></div></section><span id="health"></span><span id="taps"></span><button id="boost"></button><span id="gaugeText"></span><button data-skill="0"></button><button data-skill="1"></button><button data-skill="2"></button><div id="board"></div><dialog id="upgrade"></dialog><dialog id="ending"></dialog><dialog id="journey"></dialog></main>';
   window.pref={matches:matchMedia('(prefers-reduced-motion:reduce)').matches};window.ui=(await import('/presentation.mjs')).createPresentation(pref);
   window.s={bossHP:100,rules:{bossHP:100},hp:80,taps:3,boost:false,gauge:0,turn:1,ready:[2,2,2]};ui.update(s,'battle');ui.clear();
  }''')
  result=page.evaluate('''()=>{s.bossHP=40;s.hp=65;s.taps=2;ui.update(s,'battle');const a=document.querySelector('#bossTrail').getAnimations();return {n:a.length,delay:a[0]?.effect.getTiming().delay,ratio:document.querySelector('#bossFill').dataset.ratio,delta:document.querySelector('#healthDelta').textContent}}''')
  assert result['ratio']=='0.4' and result['delta']=='−15',result
  assert result['n']==(0 if motion=='reduce' else 1),result
  if motion!='reduce':assert result['delay']==110
  page.evaluate("()=>{s.bossHP=100;s.hp=95;s.taps=3;s.gauge=55;s.turn=2;ui.update(s,'battle')}")
  assert page.locator('#boost').get_attribute('data-state')=='ready'
  assert page.locator('[data-skill="0"]').get_attribute('data-ready')=='true'
  assert page.locator('#healthDelta').inner_text()=='+30'
  if motion!='reduce':assert page.evaluate("document.querySelector('#bossTrail').getAnimations()[0].effect.getTiming().duration")==160
  page.evaluate("()=>{s.boost=true;s.bossHP=0;ui.update(s,'battle');ui.selected('시험');Object.defineProperty(document,'hidden',{configurable:true,get:()=>true});document.dispatchEvent(new Event('visibilitychange'))}")
  assert page.locator('#boost').get_attribute('data-state')=='active'
  assert page.locator('#bossTrail').get_attribute('data-ratio')=='0'
  assert page.locator('.presentation-choice').count()==0
  assert page.evaluate("document.querySelector('#bossTrail').getAnimations().length")==0
  page.evaluate("()=>{Object.defineProperty(document,'hidden',{configurable:true,get:()=>false});s={...s,bossHP:100};ui.update(s,'battle');pref.matches=true;ui.clear();ui.update(s,'map')}")
  assert page.locator('#bossTrail').get_attribute('data-ratio')=='1'
  assert page.locator('#healthDelta').inner_text()==''
  assert page.locator('.presentation-enter').count()==0
  print('PASS damage / heal / zero / max / ready / boost / hide / new identity / reduced toggle',motion,flush=True)
  page.close()
 b.close()
