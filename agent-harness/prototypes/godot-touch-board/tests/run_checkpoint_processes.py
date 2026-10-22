"""Fresh child processes and isolated save dirs; no ordinary user-data writes."""
import json, os, subprocess, tempfile
from pathlib import Path
base=Path(__file__).resolve().parents[1]
out=base/os.environ.get('CHROMA_PROCESS_OUT','evidence/run-lifecycle/processes');out.mkdir(parents=True,exist_ok=True)
root=Path(tempfile.mkdtemp(prefix='chroma-lifecycle-'))
env=dict(os.environ,XDG_DATA_HOME=str(root/'data'),XDG_CONFIG_HOME=str(root/'config'),XDG_CACHE_HOME=str(root/'cache'))
results=[]
def run(tag,slot,steps=0,seed=20261021,interrupt='',hero='rio'):
    output=root/(tag+'.json')
    args=['godot','--headless','--path',str(base),'--fixed-fps','30','--script',os.environ.get('CHROMA_PROCESS_SCRIPT','tests/test_checkpoint_process.gd'),'--','--save-dir='+str(root/slot),'--steps='+str(steps),'--output='+str(output),'--hero='+hero]
    if seed is not None:args+=['--seed='+str(seed)]
    if interrupt:args+=['--interrupt='+interrupt]
    p=subprocess.run(args,env=env,cwd=base,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=120)
    (out/(tag+'.log')).write_text(p.stdout)
    assert p.returncode==0,(tag,p.stdout[-2500:])
    data=json.loads(Path(str(output)+'.summary.json').read_text())
    assert not data['errors'],(tag,data)
    results.append(dict(tag=tag,**data));print(tag,data['phase'],data['actions'],flush=True)
    (out/'summary.json').write_text(json.dumps(results,indent=2))
    return data
for hero in ['rio','noa']:
    continuous=run(hero+'-continuous',hero+'-continuous-slot',60,hero=hero)
    for n in range(60):
        segmented=run(hero+'-part-'+str(n),hero+'-segmented-slot',1,hero=hero)
        if segmented['phase'] in ['victory','defeat']: break
    assert 'ready:boss' in continuous['visited'], hero+' boss reached'
    assert continuous['state_hash']==segmented['state_hash'],hero+' continuation parity'
for mode in ['held','busy','attack']:
    stopped=run(mode+'-interrupted',mode+'-slot',20,interrupt=mode)
    resumed=run(mode+'-resumed',mode+'-slot')
    assert resumed['state_hash']==stopped['saved_hash'],mode+' rollback to last commit'
a=run('new-seed-a','new-a',seed=None);b=run('new-seed-b','new-b',seed=None)
assert a['seed']!=b['seed']
a=run('fixed-a','fixed-a');b=run('fixed-b','fixed-b')
assert a['state_hash']==b['state_hash']
print('PASS cross-process continuation, interruptions, seed variation and fixed-seed identity')
