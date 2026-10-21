"""Report all pre-registered clean native repeats, including slow tails.

Earlier exploratory runs overlapped artifact probes/a final unit recheck. Keep
those raw files but exclude them by the clean prefix, never by their numbers.
"""
from pathlib import Path
import json,statistics
p=Path(__file__).resolve().parents[1]/'evidence/bomb-volume'
versions={}
for label in ('before','after'):
    runs=[json.loads((p/f'performance/clean-{label}-{i}.json').read_text()) for i in (1,2,3)]
    assert all(not x['errors'] and x['clears']==7 and not x['movie'] for x in runs)
    ordinary=[];special=[];draw=[];process=[];seventh=[]
    for x in runs:
        for t in x['timings']:
            if t['event']=='commit_to_ready':
                (special if t['specials'] else ordinary).append(t['wall_ms'])
        for i,r in enumerate(x['rows']):
            if r['event']=='resolved':
                assert x['rows'][i-1]['event']=='gesture'
                draw.append(x['rows'][i-1]['draw_us']/1000)
                if r['clear']==7:seventh.append(r['wall_ms'])
        process.extend(f['process_ms'] for f in x['frames'])
    def stats(values):
        return {'n':len(values),'median_ms':statistics.median(values),'min_ms':min(values),'max_ms':max(values)}
    versions[label]={'ordinary_commit_to_ready':stats(ordinary),'special_commit_to_ready':stats(special),'clear_press_to_draw':stats(draw),'process_frame':stats(process),'seventh_large_supply':stats(seventh),'per_run':[{'ordinary': [t['wall_ms'] for t in x['timings'] if t['event']=='commit_to_ready' and not t['specials']], 'special':[t['wall_ms'] for t in x['timings'] if t['event']=='commit_to_ready' and t['specials']]} for x in runs]}
    for bucket in ('process_us','ui_draw_us','panels_draw_us','overlay_draw_us'):
        values=[f['cpu'][bucket]/1000 for x in runs for f in x['frames'] if bucket in f['cpu']]
        if values:versions[label][bucket.replace('_us','_cpu_ms')]=stats(values)
    motion_cpu=[]
    for run in runs:
        last=[t for t in run['timings'] if t['event']=='commit_to_ready'][-1]
        motion_cpu.append(sum(last['profile'][k] for k in ('anchor_us','spawn_us','solve_us'))/1000)
    versions[label]['seventh_motion_cpu']=stats(motion_cpu)
for i in (1,2,3):
    a=json.loads((p/f'performance/clean-before-{i}.json').read_text());b=json.loads((p/f'performance/clean-after-{i}.json').read_text())
    aa=[r for r in a['rows'] if r['event']=='resolved'];bb=[r for r in b['rows'] if r['event']=='resolved']
    assert [r['plan'] for r in aa]==[r['plan'] for r in bb]
    assert [r['state'] for r in aa[:6]]==[r['state'] for r in bb[:6]]
    assert aa[-1]['state']['panels']!=bb[-1]['state']['panels']
normal_before=json.loads((p.parent/'bomb-body/new-motion-regressions/path-traces.json').read_text())
normal_after=json.loads((p/'new-motion-regressions/path-traces.json').read_text())
normal_trace_equal={k: normal_before[k]['frames']==normal_after[k]['frames'] for k in normal_before}
assert all(normal_trace_equal.values())
result={'baseline':'2b32d639788611f511fb32d0c3584ee6307289f5','method':'Same cloud native llvmpipe, preloaded first7 normal inputs, 3 repeats/version in A-B-B-A-A-B order. No search, capture or file writes in measured replay; no other test/render processes in clean block. First six exploratory files retained but excluded because artifact probing/unit work overlapped them. No selection by results. Not fixedfps capture or mobile evidence.','versions':versions,'same_all_7_plans':True,'same_first_6_states':True,'seventh_state_differs_by_large_body_physics':True,'normal_only_intermediate_trace_equal':normal_trace_equal,'limitations':['Small sample, single cloud software renderer; no proof of performance parity or improvement.','Seventh action has a new physical body and intentionally different collision trajectories, not a pure rendering microbenchmark.','GPU timing support is limited under Compatibility/llvmpipe.']}
(p/'performance-summary.json').write_text(json.dumps(result,ensure_ascii=False,indent=2));print(json.dumps(result,ensure_ascii=False,indent=2))
