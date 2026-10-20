"""Explicit saved stage fixtures exercise new panel UI; full runs are separate."""
from campaign_browser import setup,saved,idle,ROOT
from playwright.sync_api import sync_playwright
import json,subprocess
fixtures=json.loads(subprocess.check_output(['node','--input-type=module','-e',"import {createRun,runTap,chooseUpgrade} from './campaign.mjs';const r=createRun(7,false),out=[];for(const id of ['power','healing']){r.state.bossHP=1;r.state.damage=9999;r.state.taps=1;runTap(r,1);chooseUpgrade(r,id);out.push(structuredClone({version:1,run:r,learned:true,audio:{enabled:false,volume:.3}}));}console.log(JSON.stringify(out));"],cwd=ROOT,text=True))
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 for w,h in [(360,800),(390,844),(1280,900)]:
  for motion in ['reduce','no-preference']:
   page=b.new_page(viewport={'width':w,'height':h},reduced_motion=motion,has_touch=True);errors=[];page.on('pageerror',lambda e:errors.append(str(e)));setup(page,w!=390)
   for stage,d in enumerate(fixtures,1):
    page.evaluate('(d)=>localStorage.setItem("resonance-circuit-v1",JSON.stringify(d))',d);page.reload();page.evaluate("async()=>{window.oracle=await import('/engine.mjs')}");page.locator('#continueRun').click()
    assert page.locator('#coach').is_visible();assert ('덩굴 타일' if stage==1 else '무지개는') in page.locator('#coachText').inner_text()
    assert page.locator('.vine').count()==4;assert page.locator('.rainbow').count()==(2 if stage==2 else 0)
    page.screenshot(path=str(ROOT/f'panels-intro-{stage+1}-{w}-{motion}.png'),full_page=True)
    assert page.evaluate('document.documentElement.scrollWidth<=innerWidth')
    # A vine remains keyboard-focusable; neither keyboard nor real tap spends state.
    i=next(i for i,t in enumerate(d['run']['state']['board']) if t.get('vine'));before=saved(page)['run']
    page.locator('.tile').nth(i).focus();page.keyboard.press('Enter');assert saved(page)['run']==before
    page.locator('.tile').nth(i).tap();assert saved(page)['run']==before;assert '탭 소모 없음' in page.locator('#preview').inner_text()
    if stage==2:
     i=next(i for i,t in enumerate(before['state']['board']) if t['kind']=='rainbow');page.locator('.tile').nth(i).focus();assert '확정색' in page.locator('#preview').inner_text();assert saved(page)['run']==before
    else:
     i=page.evaluate("()=>{const s=JSON.parse(localStorage.getItem('resonance-circuit-v1')).run.state;return s.board.findIndex((_,i)=>oracle.preview(s,i).unlocked.length>0)}")
    page.locator('.tile').nth(i).focus();page.keyboard.press('Space');idle(page);assert saved(page)['run']['panelLesson'] is None
    after=saved(page)['run'];page.reload();page.locator('#continueRun').click();assert saved(page)['run']==after
    # Re-readable help includes both rules; no new modal during a panel tap.
    page.locator('#help').click();texts=[]
    for n in range(5):texts.append(page.locator('#guideText').inner_text());page.locator('#guideNext').click()
    assert any('덩굴 타일' in t for t in texts);assert any('무지개는' in t for t in texts)
    assert not page.locator('#guide').evaluate('(e)=>e.open')
   assert not errors,errors
   print(json.dumps({'viewport':[w,h],'motion':motion,'panel_intros':2,'invalid_vine':'keyboard+touch','rainbow_preview':True,'reload':True,'errors':0}),flush=True);page.close()
 b.close()
