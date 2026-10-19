"""Toggle settings during real clears; assert no resurrection or duplicate settlement."""
from campaign_browser import setup,saved,ROOT
from playwright.sync_api import sync_playwright
import json
exec((ROOT/'timeline_browser.py').read_text().split('with sync_playwright() as p:')[0])
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 for n in ['6','42']:
  for control in ['sound','skipLesson','both']:
   page=b.new_page(viewport={'width':390,'height':844},reduced_motion='no-preference');setup(page,True)
   d=json.loads(json.dumps(fixtures[n]));d['run']['panelLesson']='rainbow';d['audio']['enabled']=n=='42'
   page.evaluate('(d)=>localStorage.setItem("resonance-circuit-v1",JSON.stringify(d))',d);page.reload();page.locator('#continueRun').click()
   page.evaluate("async()=>{window.oracle=await import('/engine.mjs')}")
   expected=page.evaluate('()=>{const s=JSON.parse(localStorage.getItem("resonance-circuit-v1")).run.state;oracle.tap(s,9);return s}')
   page.evaluate('''(control)=>{window.failures=[];window.elapsed=0;const board=document.querySelector('#board');const start=performance.now();let acted=false;new MutationObserver(()=>{if(!acted&&board.querySelectorAll('.cleared').length>=2){acted=true;const before=[...board.querySelectorAll('.cleared')].map(e=>[e,e.dataset.clearId]);for(const id of control==='both'?['sound','skipLesson']:[control])document.getElementById(id).click();for(const [e,id] of before)if(!e.classList.contains('cleared')||e.dataset.clearId!==id)failures.push('resurrection');window.applied=JSON.parse(localStorage.getItem('resonance-circuit-v1')).audio.enabled;}if(board.dataset.resolving==='false')elapsed=performance.now()-start;}).observe(board,{subtree:true,attributes:true});document.querySelectorAll('.tile')[9].click();}''',control)
   page.wait_for_function("document.querySelector('#board').dataset.resolving==='false'")
   result=page.evaluate('({failures,elapsed,applied})');assert result['failures']==[],result
   assert saved(page)['run']['state']==expected
   assert result['applied']==((n=='42') if control=='skipLesson' else (n!='42'))
   if control!='sound':assert saved(page)['run']['panelLesson'] is None
   assert page.locator('.cleared,[data-clear-id]').count()==0
   index=page.evaluate("()=>{const s=JSON.parse(localStorage.getItem('resonance-circuit-v1')).run.state;return s.board.findIndex((t,i)=>oracle.preview(s,i).initial.length>0)}");page.locator('.tile').nth(index).evaluate('e=>e.click()');page.wait_for_function("document.querySelector('#board').dataset.resolving==='false'");assert saved(page)['run']['state']['taps']==1
   print(json.dumps({'count':n,'control':control,**result,'result':'PASS'}),flush=True);page.close()
 b.close()
