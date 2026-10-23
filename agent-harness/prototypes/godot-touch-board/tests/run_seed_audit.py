"""A deliberately bounded reproducible sample, not a human win-rate estimate."""
import itertools,json,os,subprocess,tempfile,time,sys
from pathlib import Path
base=Path(__file__).resolve().parents[1]
out=base/'evidence/seed-audit';out.mkdir(exist_ok=True)
root=Path(tempfile.mkdtemp(prefix='chroma-seed-audit-'))
env=dict(os.environ,XDG_DATA_HOME=str(root/'data'),XDG_CONFIG_HOME=str(root/'config'),XDG_CACHE_HOME=str(root/'cache'))
results=[]
shop='--shop-controls' in sys.argv
cases=itertools.product([1,42] if shop else [1,42,314159,20261021],['rio','noa'],['safe-shop'] if shop else ['safe','safe-shop','risk'])
for seed,hero,route in cases:
 tag=f'{seed}-{hero}-{route}'+('-buy' if shop else '')
 args=['godot','--headless','--path',str(base),'--fixed-fps','30','--script','tests/audit_seeds.gd','--',f'--seed={seed}',f'--hero={hero}',f'--path-choice={route}',f'--case={tag}','--no-shots',f'--save-dir={root/tag}']
 if shop:args+=['--audit-shop-buy']
 start=time.monotonic()
 try:
  run=subprocess.run(args,cwd=base,env=env,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=120)
  code,log=run.returncode,run.stdout
 except subprocess.TimeoutExpired as e:code,log=124,(e.stdout or b'').decode()
 (out/(tag+'.log')).write_text(log)
 paths=list((out/'runs'/tag).glob('*/trace.json'))
 data=json.loads(paths[0].read_text()) if paths else {}
 terminal=data.get('terminal',{})
 row={'seed':seed,'hero':hero,'route':route,'strategy':data.get('policy','intent-aware')+('+shop-buy' if shop else ''),'exit':code,'phase':terminal.get('phase'),'hp':terminal.get('hp'),'clears':terminal.get('actions'),'history':terminal.get('history',[]),'failed_criteria':data.get('errors',['no completed trace']),'wall_seconds':round(time.monotonic()-start,2),'command':args}
 if 'SCRIPT ERROR' in log or '\nERROR:' in log:row['failed_criteria'].append('engine/script error')
 turns=[x for x in data.get('events',[]) if x['type']=='intent_audit']
 row['turns']=len(turns);row['active_intents']=sum(x['mitigation_active'] for x in turns);row['fallback_turns']=sum(x['fallback_plain'] for x in turns)
 row['preview_checks']=sum(x['type']=='clear' for x in data.get('events',[]));row['shop_purchases']=sum(x['type']=='shop_purchase' for x in data.get('events',[]))
 results.append(row);(out/('shop-summary.json' if shop else 'summary.json')).write_text(json.dumps(results,ensure_ascii=False,indent=2))
 print(tag,row['phase'],row['clears'],row['failed_criteria'],flush=True)
 if code or row['failed_criteria']:break
raise SystemExit(any(x['exit'] or x['failed_criteria'] for x in results))
