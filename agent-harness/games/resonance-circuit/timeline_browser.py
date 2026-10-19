from campaign_browser import setup,saved,ROOT
from playwright.sync_api import sync_playwright
import subprocess,json,sys
fixtures=json.loads(subprocess.check_output(['node','--input-type=module','-e',"import {createRun,runTap,chooseUpgrade} from './campaign.mjs';import {neighbors} from './engine.mjs';const r=createRun(7,false);for(const id of ['power','healing']){r.state.damage=9999;r.state.taps=1;runTap(r,1);chooseUpgrade(r,id);}r.panelLesson=null;const out={};for(const n of [1,6,10,42]){const q=structuredClone(r),s=q.state;s.board.forEach((t,i)=>{delete t.vine;t.kind='normal';t.color=['gold','blue','heal'][(Math.floor(i/7)+i%7)%3];});const order=[9],seen=new Set(order);for(const i of order)for(const j of neighbors(i))if(!seen.has(j)){seen.add(j);order.push(j);}for(const i of order.slice(0,n))s.board[i].color='coral';out[n]={version:1,run:q,learned:true,audio:{enabled:false,volume:.3}};}const q=structuredClone(out[1]),s=q.run.state;s.board.forEach(t=>t.color='gold');s.board[0].color='coral';s.board[1].kind='rainbow';s.board[7].kind='bomb';s.board[7].color='coral';s.board[8].vine=true;s.board[14].kind='bomb';s.board[14].color='blue';s.echo=[s.board[0].id,s.board[14].id];out.compound=q;console.log(JSON.stringify(out));"],cwd=ROOT,text=True))
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 for w,h in ([] if '--cancel-only' in sys.argv else [(360,800),(390,844),(1280,900)]):
  for motion in ['no-preference','reduce']:
   page=b.new_page(viewport={'width':w,'height':h},reduced_motion=motion,has_touch=True);errors=[];page.on('pageerror',lambda e:errors.append(str(e)));setup(page,True)
   for label,d in fixtures.items():
    page.evaluate('(d)=>localStorage.setItem("resonance-circuit-v1",JSON.stringify(d))',d);page.reload();page.evaluate("async()=>{window.oracle=await import('/engine.mjs');window.planner=await import('/timeline.mjs')}");page.locator('#continueRun').click();index=0 if label=='compound' else 9
    plan=page.evaluate('(i)=>{const s=JSON.parse(localStorage.getItem("resonance-circuit-v1")).run.state;return planner.planTimeline(s,i,oracle.preview(s,i))}',index)
    expected=page.evaluate('(i)=>{const s=JSON.parse(localStorage.getItem("resonance-circuit-v1")).run.state;oracle.tap(s,i);return s}',index)
    page.evaluate("()=>{window.starts=[];window.ends=[];const active=new Set();new MutationObserver(rows=>{for(const {target:e} of rows){if(!e.classList.contains('tile'))continue;const i=Number(e.dataset.index),now=performance.now();if(e.classList.contains('cleared')&&!active.has(i)){active.add(i);starts.push({i,id:Number(e.dataset.clearId),time:now});}else if(!e.classList.contains('cleared')&&active.has(i)){active.delete(i);ends.push({i,time:now});}}}).observe(document.querySelector('#board'),{subtree:true,attributes:true,attributeFilter:['class']});}")
    page.locator('.tile').nth(index).evaluate('e=>{e.click();e.click();}')
    if motion=='no-preference' and label=='10':
     page.wait_for_timeout(55);page.screenshot(path=str(ROOT/f'cascade-early-{w}.png'),full_page=True);page.evaluate('scrollBy(0,35)');page.wait_for_timeout(65);page.screenshot(path=str(ROOT/f'cascade-middle-{w}.png'),full_page=True)
    page.wait_for_function('(n)=>JSON.parse(localStorage.getItem("resonance-circuit-v1")).run.state.nextID===n',arg=expected['nextID']);page.wait_for_timeout(550)
    assert saved(page)['run']['state']==expected
    trace=page.evaluate('({starts,ends})');clears=[e for e in plan['events'] if e['type']=='clear']
    if motion=='no-preference':
     assert len(trace['starts'])==len(clears);assert len(set(x['id'] for x in trace['starts']))==len(clears)
     assert [x['id'] for x in trace['starts']]==[e['id'] for e in clears]
     assert min(x['time'] for x in trace['ends'])>=max(x['time'] for x in trace['starts'])+120,(label,trace,plan)
     if label in ['6','10']:assert trace['starts'][-1]['time']-trace['starts'][0]['time']>=100
    assert page.locator('.cleared,[data-clear-id],.fx-label').count()==0;assert page.locator('#effects').get_attribute('data-active')=='0'
    print(json.dumps({'width':w,'motion':motion,'case':label,'clearCount':len(clears),'scheduledLast':plan['lastStart'],'expectedTotal':plan['total'],'trace':trace if motion=='no-preference' and w==390 else 'checked','result':'PASS'}),flush=True)
   assert not errors,errors;page.close()
 # Cancellation: reset rolls back before apply; hide/motion finish the action once.
 for trigger in ['reset','hidden','motion']:
  page=b.new_page(viewport={'width':390,'height':844},has_touch=True,reduced_motion='no-preference');page.on('pageerror',lambda e:print('PAGEERROR',str(e),flush=True));setup(page,True);d=fixtures['42'];page.evaluate('(d)=>localStorage.setItem("resonance-circuit-v1",JSON.stringify(d))',d);page.reload();page.locator('#continueRun').click();page.locator('.tile').nth(9).tap();page.wait_for_timeout(60)
  if trigger=='reset':page.locator('#restart').click();page.locator('#cancelNew').click()
  elif trigger=='hidden':page.evaluate("()=>{Object.defineProperty(document,'hidden',{configurable:true,get:()=>true});document.dispatchEvent(new Event('visibilitychange'))}")
  else:
   page.emulate_media(reduced_motion='reduce');print('MEDIA',page.evaluate("({matches:matchMedia('(prefers-reduced-motion: reduce)').matches,hidden:document.hidden,body:document.body.className})"),flush=True);page.wait_for_function("document.body.classList.contains('fx-reduced')")
  page.wait_for_timeout(350);state=saved(page)['run']['state'];assert state['taps']==(3 if trigger=='reset' else 2),(trigger,state['taps'],page.locator('body').get_attribute('class'),page.locator('#board').get_attribute('data-resolving'));assert page.locator('.cleared,[data-clear-id],.fx-label').count()==0;assert page.locator('#effects').get_attribute('data-active')=='0'
  if trigger=='hidden':page.evaluate("()=>{Object.defineProperty(document,'hidden',{configurable:true,get:()=>false});document.dispatchEvent(new Event('visibilitychange'))}")
  page.locator('.tile').nth(0).tap();page.wait_for_timeout(850);assert saved(page)['run']['state']['taps']!=(3 if trigger=='reset' else 2);print('PASS cancellation and lock release',trigger,flush=True);page.close()
 b.close()
