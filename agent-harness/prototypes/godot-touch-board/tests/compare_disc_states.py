"""Compare actual normal-run states/boards/plans, excluding timing metadata only."""
import json
from pathlib import Path
base=Path(__file__).resolve().parents[1]
ignored={'wall_ms','process_frame','scene_seconds'}
def canonical(value):
    if isinstance(value,dict):return {k:canonical(v) for k,v in value.items() if k not in ignored}
    if isinstance(value,list):return [canonical(v) for v in value]
    return value
results=[]
for hero in ['noa','rio']:
    relative=f'evidence/disc-bombs/normal/{hero}-risk-intent-aware-movie/trace.json'
    old=base/f'evidence/disc-bombs/baseline/{hero}.json'
    new=base/relative
    if not old.exists() or not new.exists():continue
    a,b=json.loads(old.read_text()),json.loads(new.read_text())
    rows=[{'event':i,'equal':canonical(x)==canonical(y)} for i,(x,y) in enumerate(zip(a['events'],b['events']))]
    result={'hero':hero,'events_before':len(a['events']),'events_after':len(b['events']),'mismatches':[r['event'] for r in rows if not r['equal']], 'terminal_equal':canonical(a['terminal'])==canonical(b['terminal']), 'errors_before':a['errors'],'errors_after':b['errors']}
    result['pass']=not result['mismatches'] and result['events_before']==result['events_after'] and result['terminal_equal'] and not a['errors'] and not b['errors']
    results.append(result)
(base/'evidence/disc-bombs/state-comparison.json').write_text(json.dumps(results,indent=2))
print(json.dumps(results,indent=2))
assert results and all(r['pass'] for r in results)
