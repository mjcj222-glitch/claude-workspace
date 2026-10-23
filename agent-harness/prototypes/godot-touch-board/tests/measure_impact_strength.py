"""Serial same-environment native A/B runs, no concurrent capture/policy/files in windows."""
from pathlib import Path
import os,subprocess,json,time
p=Path(__file__).resolve().parents[1];out=p/'evidence/impact-strength/performance';out.mkdir(exist_ok=True)
order=['before','after','after','before','before','after'];counts={'before':0,'after':0};runs=[]
for label in order:
 counts[label]+=1;name=f'{label}-{counts[label]}'
 cmd=['godot','--path',f'/tmp/chroma-impact-strength/{label}','--audio-driver','Dummy','--position','0,0','--script','tests/replay_impact_strength.gd','--','--limit=7',f'--result={out/name}.json']
 started=time.time()
 with (out/f'{name}.log').open('w') as log:r=subprocess.run(cmd,stdout=log,stderr=subprocess.STDOUT,timeout=95)
 data=json.loads((out/f'{name}.json').read_text())
 runs.append({'name':name,'exit':r.returncode,'errors':data['errors'],'clears':data['clears'],'started_unix':started,'total_wall_s':time.time()-started})
 (out/'runs.json').write_text(json.dumps(runs,indent=2));print(name,r.returncode,data['errors'],flush=True)
 if r.returncode or data['errors']:raise SystemExit(1)
