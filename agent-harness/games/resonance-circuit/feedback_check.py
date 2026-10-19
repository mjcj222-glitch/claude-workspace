from campaign_browser import setup,saved,ROOT
from playwright.sync_api import sync_playwright
import json,subprocess
fixture=json.loads(subprocess.check_output(['node','--input-type=module','-e',"import {createRun,runTap,chooseUpgrade} from './campaign.mjs';let r=createRun(7,false);for(const id of ['power','healing']){r.state.damage=9999;r.state.taps=1;runTap(r,1);chooseUpgrade(r,id);}const s=r.state;s.board.forEach(t=>{delete t.vine;t.color='gold';t.kind='normal';});s.board[0].color='coral';s.board[1].kind='rainbow';s.board[7].kind='bomb';s.board[7].color='coral';s.board[8].vine=true;s.board[14].color='blue';s.echo=[s.board[0].id,s.board[14].id];r.panelLesson=null;console.log(JSON.stringify({version:1,run:r,learned:true,audio:{enabled:false,volume:.3}}));"],cwd=ROOT,text=True))
with sync_playwright() as p:
 b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True)
 for w,h in [(360,800),(390,844),(1280,900)]:
  for motion in ['no-preference','reduce']:
   page=b.new_page(viewport={'width':w,'height':h},reduced_motion=motion,has_touch=True);errors=[];page.on('pageerror',lambda e:errors.append(str(e)));setup(page,True)
   page.evaluate('(d)=>localStorage.setItem("resonance-circuit-v1",JSON.stringify(d))',fixture);page.reload();page.locator('#continueRun').click()
   page.locator('.tile').first.tap();page.wait_for_timeout(30)
   if motion=='reduce':assert page.locator('#effects').get_attribute('data-active')=='0'
   else:assert 0<int(page.locator('#effects').get_attribute('data-active'))<=80
   page.screenshot(path=str(ROOT/f'feedback-compound-{w}-{motion}.png'),full_page=True)
   page.wait_for_timeout(750);assert page.locator('#effects').get_attribute('data-active')=='0';assert page.locator('.fx-label,[data-fx],.cleared').count()==0
   # Effects preference is session-only and does not change the save schema.
   before=saved(page);page.locator('#feedbackHelp').click();page.locator('#lessEffects').check();assert page.locator('body').evaluate("e=>e.classList.contains('fx-reduced')");assert saved(page)==before
   assert page.locator('[data-sound]').count()==17;page.locator('[data-sound="bomb"]').click();assert '소리 켜기' in page.locator('#soundHint').inner_text()
   page.locator('#previewEnable').click();page.locator('[data-sound="echo"]').click();page.locator('#closeFeedback').click();assert saved(page)['audio']['enabled']
   page.locator('.tile').nth(0).tap();page.wait_for_timeout(30);assert page.locator('#effects').get_attribute('data-active')=='0'
   # Live motion changes and visibility clear particles AND Web Animations.
   page.wait_for_timeout(400);page.locator('#feedbackHelp').click();page.locator('#lessEffects').uncheck();page.locator('#closeFeedback').click();page.emulate_media(reduced_motion='no-preference')
   page.locator('.tile').nth(1).tap();page.wait_for_timeout(25);page.emulate_media(reduced_motion='reduce');page.wait_for_function("document.body.classList.contains('fx-reduced') && document.querySelector('#effects').dataset.active==='0'")
   page.evaluate("()=>{Object.defineProperty(document,'hidden',{configurable:true,get:()=>true});document.dispatchEvent(new Event('visibilitychange'))}");page.wait_for_timeout(500)
   assert page.locator('#effects').get_attribute('data-active')=='0';assert page.evaluate("document.querySelectorAll('.tile').length===42 && [...document.querySelectorAll('.tile')].every(e=>e.getAnimations().length===0)")
   page.evaluate("()=>{Object.defineProperty(document,'hidden',{configurable:true,get:()=>false});document.dispatchEvent(new Event('visibilitychange'))}")
   page.locator('#restart').click();page.locator('#confirmRestart').click();assert page.locator('#effects').get_attribute('data-active')=='0';assert not page.locator('#skillCutin').is_visible()
   assert not errors,errors
   print(json.dumps({'viewport':[w,h],'motion':motion,'compound':'bomb+echo+vine+rainbow','sampleButtons':17,'cleanup':True,'errors':0}),flush=True);page.close()
 # Real WebAudio resumed first note and immediate master-volume reduction.
 page=b.new_page();setup(page,False)
 result=page.evaluate('''async()=>{const {createAudio}=await import('/audio.mjs');const c=new AudioContext(),a=createAudio({enabled:true,volume:1},{factory:()=>c});await c.suspend();a.unlock();a.play('win',{id:'resume'});await new Promise(r=>setTimeout(r,40));const played=a.stats.events;for(let i=0;i<30;i++)a.play(['bomb','echo','vine','rainbow'][i%4],{id:i});const peak=a.stats; a.volume(0);a.hide();await new Promise(r=>setTimeout(r,70));return {played,peak,after:a.stats,state:c.state};}''')
 assert result['played']==1;assert result['peak']['peakVoices']<=8;assert result['after']['voices']==0 and result['after']['nodes']==2;assert result['state']=='suspended';print(json.dumps(result),flush=True)
 # A dedicated canvas stress check confirms bounded particles and timers.
 result=page.evaluate('''async()=>{const {createEffects}=await import('/effects.mjs');const c=document.createElement('canvas');document.body.append(c);const m={matches:false},f=createEffects(c,m),e=document.querySelector('.tile');for(let i=0;i<100;i++){f.burst(e);f.ring(e);f.link(e,e);f.label(e,'1');}const peak=f.stats;f.clear();m.matches=true;f.burst(e);const reduced=f.stats;f.clear();return {peak,reduced,clean:f.stats};}''')
 assert result['peak']['peakParticles']==80 and result['peak']['labels']<=3;assert result['reduced']['particles']==0;assert result['clean']['marks']==0;print(json.dumps(result),flush=True)
 # Render an in-flight mute: scheduled notes after the volume drop must stay silent.
 result=page.evaluate("""async()=>{const {createAudio}=await import('/audio.mjs');const c=new OfflineAudioContext(1,48000,48000),a=createAudio({enabled:true,volume:1},{factory:()=>c,offline:true});a.unlock();a.play('win');const suspended=c.suspend(.064);const rendering=c.startRendering();await suspended;a.volume(0);c.resume();const data=(await rendering).getChannelData(0);let before=0,after=0;for(let i=0;i<data.length;i++){if(i<2400)before=Math.max(before,Math.abs(data[i]));if(i>7200)after=Math.max(after,Math.abs(data[i]));}return {before,after};}""")
 assert result['before']>.001 and result['after']<.00001;print(json.dumps({'inFlightVolume':result}),flush=True)
 page.close();b.close()
