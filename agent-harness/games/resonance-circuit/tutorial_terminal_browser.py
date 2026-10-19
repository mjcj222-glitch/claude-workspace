"""Regression: unfinished coaching must not prevent terminal autosave/reload."""
from campaign_browser import setup,saved,idle,ROOT
from playwright.sync_api import sync_playwright
import subprocess,json
fixture=json.loads(subprocess.check_output(['node','--input-type=module','-e',"import {createRun} from './campaign.mjs';const run=createRun();run.state.bossHP=1;run.state.damage=100;run.state.taps=1;console.log(JSON.stringify({version:1,run,learned:false,audio:{enabled:false,volume:.3}}));"],cwd=ROOT,text=True))
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 for standalone in [False,True]:
  for outcome in ['defeat','upgrade']:
   page=b.new_page(viewport={'width':390,'height':844},reduced_motion='reduce',has_touch=True)
   errors=[];page.on('pageerror',lambda e:errors.append(str(e)));setup(page,standalone)
   if outcome=='upgrade':
    page.evaluate('(d)=>localStorage.setItem("resonance-circuit-v1",JSON.stringify(d))',fixture);page.reload();page.evaluate("async()=>{window.oracle=await import('/engine.mjs')}");page.locator('#continueRun').click()
   else:page.locator('#startNew').click()
   for n in range(200):
    r=saved(page)['run']
    if r['phase']!='battle':break
    assert r['tutorial']=='chain'
    index=page.evaluate("()=>{const s=JSON.parse(localStorage.getItem('resonance-circuit-v1')).run.state;const sizes=s.board.map((_,i)=>oracle.group(s,i).length);return sizes.indexOf(Math.min(...sizes))}")
    page.locator('.tile').nth(index).tap();idle(page)
   final=saved(page)['run'];assert final['phase']==outcome;assert final['tutorial']=='done';assert final['tutorialIDs']==[]
   if outcome=='defeat':assert final['state']['turn']==18
   dialog='#ending' if outcome=='defeat' else '#upgrade';page.locator(dialog).wait_for(state='visible')
   assert page.locator('#saveStatus').inner_text()=='저장됨'
   page.reload();page.locator('#continueRun').click();page.locator(dialog).wait_for(state='visible')
   assert saved(page)['run']==final
   page.screenshot(path=str(ROOT/f'tutorial-terminal-{outcome}-{standalone}.png'),full_page=True)
   assert not errors,errors
   print(json.dumps({'standalone':standalone,'phase':outcome,'turn':final['state']['turn'],'tutorial':final['tutorial'],'reload':'same terminal state','errors':0}),flush=True)
   page.close()
 b.close()
