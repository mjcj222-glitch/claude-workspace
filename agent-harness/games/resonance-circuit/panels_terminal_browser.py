"""Terminal saves and exact retry while new-panel coaching is unfinished."""
from campaign_browser import setup,saved,idle,ROOT
from playwright.sync_api import sync_playwright
import subprocess,json
fixtures=json.loads(subprocess.check_output(['node','--input-type=module','-e',"import {createRun,runTap,chooseUpgrade} from './campaign.mjs';const r=createRun(7,false),out=[];for(const id of ['power','healing']){r.state.bossHP=1;r.state.damage=9999;r.state.taps=1;runTap(r,1);chooseUpgrade(r,id);out.push(structuredClone({version:1,run:r,learned:true,audio:{enabled:false,volume:.3}}));}console.log(JSON.stringify(out));"],cwd=ROOT,text=True))
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 for standalone in [False,True]:
  for source in fixtures:
   for win in [False,True]:
    d=json.loads(json.dumps(source));s=d['run']['state'];s['taps']=1
    if win:s['damage']=9999
    else:
     s['hp']=1;s['healing']=0
     for t in s['board']:t['color']='coral'
    page=b.new_page(viewport={'width':390,'height':844},reduced_motion='reduce',has_touch=True);errors=[];page.on('pageerror',lambda e:errors.append(str(e)));setup(page,standalone)
    page.evaluate('(d)=>localStorage.setItem("resonance-circuit-v1",JSON.stringify(d))',d);page.reload();page.locator('#continueRun').click();assert page.locator('#coach').is_visible()
    page.locator('.tile').nth(1).tap();idle(page);end=saved(page)['run'];assert end['phase']!='battle';assert end['panelLesson'] is None
    page.reload();page.locator('#continueRun').click();assert saved(page)['run']==end
    if not win:
     page.locator('#retryBattle').click();again=saved(page)['run'];assert again['state']==source['run']['state'];assert again['panelLesson'] is None;assert not page.locator('#coach').is_visible()
    assert not errors,errors
    print(json.dumps({'standalone':standalone,'stage':source['run']['stage']+1,'phase':end['phase'],'terminal_restore':True,'retry':not win,'errors':0}),flush=True);page.close()
 b.close()
