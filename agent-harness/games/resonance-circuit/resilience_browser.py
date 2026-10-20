"""Controlled failure fixtures supplement natural full-run tests; never production state."""
from campaign_browser import setup,saved,idle,ROOT
from playwright.sync_api import sync_playwright
import subprocess,json
fixtures=json.loads(subprocess.check_output(['node','--input-type=module','-e',"""
import {createRun,rulesFor} from './campaign.mjs';import {createGame} from './engine.mjs';
const fixtures=[];for(let stage=0;stage<3;stage++){const run=createRun(42,false);run.stage=stage;run.upgrades=['power','healing'].slice(0,stage);run.history=Array.from({length:stage},(_,i)=>({stage:i,turns:4,echoes:2,maxChain:20,result:'won'}));run.state=createGame((42+stage*7919)>>>0,rulesFor(stage,run.upgrades));run.state.hp=1;run.state.taps=1;run.state.board.forEach(t=>t.color='coral');fixtures.push({version:1,run,learned:true,audio:{enabled:false,volume:.3}})}console.log(JSON.stringify(fixtures));
"""],cwd=ROOT,text=True))
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 for stage,fixture in enumerate(fixtures):
  page=b.new_page(reduced_motion='reduce',has_touch=True);setup(page,True)
  page.evaluate('(d)=>localStorage.setItem("resonance-circuit-v1",JSON.stringify(d))',fixture);page.reload();page.locator('#continueRun').click()
  page.locator('.tile').first.tap();idle(page);page.locator('#ending').wait_for(state='visible')
  assert saved(page)['run']['phase']=='defeat'
  page.locator('#retryBattle').click();r=saved(page)['run'];assert r['stage']==stage and r['state']['hp']==180 and r['retries'][stage]==1 and r['state']['taps']==3
  assert len(r['history'])==stage
  print('PASS defeat/retry UI stage',stage+1,flush=True);page.close()
 # Corrupt data gracefully falls back; tutorial skip recorded; confirmation really resets.
 page=b.new_page(reduced_motion='reduce',has_touch=True);setup(page,False);page.evaluate("localStorage.setItem('resonance-circuit-v1','bad')");page.reload()
 assert '형식' in page.locator('#loadNote').inner_text();page.locator('#startNew').click();page.locator('#skipLesson').click();assert saved(page)['learned']
 page.locator('.tile').first.evaluate('e=>{e.click();e.click();}');idle(page);assert saved(page)['run']['state']['taps']==2;page.locator('#restart').click();page.locator('#confirmRestart').click();assert saved(page)['run']['state']['taps']==3;assert not page.locator('#coach').is_visible()
 # Actual AudioContext opt-in then controlled visibility event: it must suspend.
 page.evaluate("()=>{const Original=window.AudioContext;window.AudioContext=class extends Original{constructor(){super();window.observedAudio=this;}}}")
 page.locator('#sound').click();page.wait_for_function("window.observedAudio?.state==='running'")
 page.evaluate("()=>{Object.defineProperty(document,'hidden',{configurable:true,get:()=>true});document.dispatchEvent(new Event('visibilitychange'))}")
 page.wait_for_function("observedAudio.state==='suspended'");page.close();print('PASS corrupted save, tutorial skip, confirmed restart, audio opt-in/suspend',flush=True)
 # localStorage throws and audio unavailable: input must continue without unhandled errors.
 page=b.new_page(reduced_motion='reduce',has_touch=True);errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
 page.add_init_script("Object.defineProperty(window,'localStorage',{get(){throw new Error('blocked storage')}});window.AudioContext=class{constructor(){throw new Error('no audio')}};window.webkitAudioContext=undefined;")
 setup(page,True);page.locator('#startNew').click();page.locator('#skipLesson').click();page.locator('#sound').click();page.locator('.tile').first.click();page.wait_for_timeout(100)
 assert '2/3' in page.locator('#taps').inner_text();assert '저장 불가' in page.locator('#saveStatus').inner_text();assert not errors,errors;page.close();print('PASS unavailable storage/audio: playable, no JS errors',flush=True)
 b.close()
