"""Summarize the entire serial A-B-B-A block, including tails."""
import json,statistics
from pathlib import Path
out=Path(__file__).resolve().parents[1]/'evidence/impact-focus'
runs=[json.loads(p.read_text()) for p in sorted((out/'performance').glob('*.json'))]
assert len(runs)==4 and all(not r['errors'] and r['clears']==8 for r in runs)
baseline=[r for r in runs[0]['rows'] if r['event']=='resolved']
for run in runs:
 rows=[r for r in run['rows'] if r['event']=='resolved']
 assert all(a['state']==b['state'] and a['plan']==b['plan'] for a,b in zip(baseline,rows))
def stats(v):return {'median':statistics.median(v),'minimum':min(v),'maximum':max(v),'samples':len(v)}
result={'method':'Serial A-B-B-A, 8 identical pre-recorded normal Noa inputs per run. No policy search/screenshots/writes inside measured playback. Cloud llvmpipe, not physical-device latency.','all_states_plans_rng_equal':True,'results':{}}
for label,indices in [('before',[0,3]),('after',[1,2])]:
 rows=[row for i in indices for row in runs[i]['rows']]
 result['results'][label]={'press_to_draw_ms':stats([r['draw_us']/1000 for r in rows if r['event']=='gesture']),'resolution_ms_including_counterattack':stats([r['wall_ms'] for r in rows if r['event']=='resolved']),'refill_complete_ms':stats([t['wall_ms'] for i in indices for t in runs[i]['timings'] if t['event']=='commit_to_ready'])}
(out/'performance-summary.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
