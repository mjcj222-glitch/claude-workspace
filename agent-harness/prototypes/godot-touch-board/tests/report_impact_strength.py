from pathlib import Path
import json,statistics,re,math
p=Path(__file__).resolve().parents[1]/'evidence/impact-strength';out=p/'performance'
def stats(a):
 a=sorted(a)
 return {'n':len(a),'median':round(statistics.median(a),3),'min':round(a[0],3),'max':round(a[-1],3),'p95':round(a[min(len(a)-1,math.ceil(len(a)*.95)-1)],3)} if a else {}
report={'method':'Six serial native llvmpipe/Dummy audio runs, same recorded7 normal inputs, A-B-B-A-A-B; no policy/search/screenshots/output files inside playback. Warmup excluded. Fixedfps captures are separate. First6 actions preserve rules; action7 adds one intentional bomb supply body kind, without movement/RNG changes. No human/mobile claim.','groups':{},'paired_states':[]}
for label in ('before','after'):
 rows=[];frames=[];metrics=[];gestures=[];per=[];board_draw=[]
 for i in range(1,4):
  x=json.loads((out/f'{label}-{i}.json').read_text());assert not x['errors'] and x['clears']==7
  last_gesture=None
  for row in x['rows']:
   if row['event']=='gesture':last_gesture=row
   elif row['event']=='resolved':board_draw.append(last_gesture['draw_us']/1000)
  m=[r for r in x['timings'] if r['event']=='commit_to_ready'];metrics+=m;frames+=x['frames'];gestures += [r for r in x['rows'] if r['event']=='gesture'];rows += [r for r in x['rows'] if r['event']=='resolved']
  per.append({'run':i,'commit_to_ready_ms':stats([r['wall_ms'] for r in m])})
 report['groups'][label]={'board_clear_press_to_draw_ms':stats(board_draw),'ordinary_commit_ready_ms':stats([r['wall_ms'] for r in metrics if r['specials']==0]),'core_commit_ready_ms':stats([r['wall_ms'] for r in metrics if r['specials']>0]),'all_commit_ready_ms':stats([r['wall_ms'] for r in metrics]),'press_to_draw_ms':stats([r['draw_us']/1000 for r in gestures]),'process_cpu_ms_per_frame':stats([r['cpu'].get('process_us',0)/1000 for r in frames]),'draw_cpu_ms_per_frame':stats([sum(r['cpu'].get(k,0) for k in ('ui_us','panels_us','overlay_us'))/1000 for r in frames]),'render_cpu_ms_per_frame':stats([r['render_cpu_ms'] for r in frames]),'motion_cpu_ms_per_action':stats([(r['profile']['anchor_us']+r['profile']['solve_us']+r['profile']['spawn_us'])/1000 for r in metrics]),'repeats':per}
for i in range(1,4):
 a=json.loads((out/f'before-{i}.json').read_text());b=json.loads((out/f'after-{i}.json').read_text())
 aa=[r for r in a['rows'] if r['event']=='resolved'];bb=[r for r in b['rows'] if r['event']=='resolved']
 for x,y in zip(aa,bb):
  for key in ('direct','removed','activated','damage','base_damage','weak_bonus','heal_effective','converted','spawn'):
   assert x['plan'][key]==y['plan'][key],(i,x['clear'],key)
  for key in ('hp','gold','charge','requirement','ash','relics','actions','enemy_hp','rng'):
   assert x['state'][key]==y['state'][key],(i,x['clear'],key)
  pa={q['id']:q for q in x['state']['panels']};pb={q['id']:q for q in y['state']['panels']};assert pa.keys()==pb.keys()
  distances=[];kinds=[]
  for id in pa:
   v=[float(t) for t in re.findall(r'-?[0-9]+(?:\.[0-9]+)?',pa[id]['pos'])];w=[float(t) for t in re.findall(r'-?[0-9]+(?:\.[0-9]+)?',pb[id]['pos'])]
   distances.append(math.dist(v,w))
   if pa[id]['kind']!=pb[id]['kind']:kinds.append(id)
  assert not kinds or (x['clear']==7 and len(kinds)==1)
  report['paired_states'].append({'repeat':i,'clear':x['clear'],'max_position_difference_px':max(distances),'intentional_new_bomb_ids':kinds})
x=json.loads((out/'after-bomb-run.json').read_text());assert not x['errors'] and x['clears']==19
bombs=[r for r in x['rows'] if r['event']=='resolved' and r['plan'].get('blasts')]
report['new_bomb_native_run']={'errors':x['errors'],'clears':x['clears'],'phase':x['final']['phase'],'bomb_actions':[{'clear':r['clear'],'wall_ms_including_retaliation_if_any':r['wall_ms'],'blasts':r['plan']['blasts']} for r in bombs],'caveat':'After-only19-input replay, no equivalent pre-feature bomb action; not a paired speedup.'}
(out/'summary.json').write_text(json.dumps(report,indent=2))
for label,g in report['groups'].items():print(label,'ordinary',g['ordinary_commit_ready_ms'],'core',g['core_commit_ready_ms'],'firstdraw',g['press_to_draw_ms'])
print('native bomb run',len(bombs),'bomb actions;max position delta',max(r['max_position_difference_px'] for r in report['paired_states']))
