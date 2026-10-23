import itertools,json,os,subprocess,tempfile
from pathlib import Path
b=Path(__file__).resolve().parents[1];out=b/'evidence/petal';root=Path(tempfile.mkdtemp(prefix='chroma-petal-play-'))
env=dict(os.environ,XDG_DATA_HOME=str(root/'data'),XDG_CONFIG_HOME=str(root/'config'),XDG_CACHE_HOME=str(root/'cache'))
rows=[]
for seed,hero,route in itertools.product([1,20261021],['rio','noa'],['safe','risk']):
 tag=f'{seed}-{hero}-{route}'
 args=['godot','--headless','--path',str(b),'--fixed-fps','30','--script','tests/play_petal.gd','--',f'--seed={seed}',f'--hero={hero}',f'--path-choice={route}',f'--case={tag}','--no-shots',f'--save-dir={root/tag}']
 p=subprocess.run(args,env=env,cwd=b,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=180);(out/(tag+'.log')).write_text(p.stdout)
 files=list((out/'normal'/tag).glob('*/trace.json'));d=json.loads(files[0].read_text()) if files else {}
 row={'seed':seed,'hero':hero,'route':route,'exit':p.returncode,'errors':d.get('errors',['no trace']),'terminal':{k:d.get('terminal',{}).get(k) for k in ['phase','hp','actions','relics']},'guards':sum(e['type']=='petal_guard' for e in d.get('events',[]))}
 rows.append(row);(out/'play-summary.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2));print(row,flush=True)
 if p.returncode or row['errors']:break
raise SystemExit(any(r['exit'] or r['errors'] for r in rows))
