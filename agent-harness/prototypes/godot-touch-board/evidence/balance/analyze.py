"""Aggregate immutable normal-run evidence; does not alter game state."""
from pathlib import Path
import collections, hashlib, json, sys
folder=Path(sys.argv[1] if len(sys.argv)>1 else 'evidence/balance/baseline')
rows=[json.loads(p.read_text())|{'path':str(p)} for p in sorted(folder.glob('seed*-*.json'))]
all_rows=rows
rows=[r for r in all_rows if r['pair_index']==0]
supplemental=[r for r in all_rows if r['pair_index']!=0]
before=json.loads((folder/'source-before.json').read_text())
after_path=folder/'source-after.json'
if after_path.exists(): after=json.loads(after_path.read_text())
else:
 after={n:hashlib.sha256(Path(n).read_bytes()).hexdigest() for n in before}
 after_path.write_text(json.dumps(after,indent=2)+'\n')
errors=[]
preboss_groups=collections.defaultdict(list)
for r in rows:
 prefix=[]
 for e in r['events']:
  prefix.append(e)
  if e['type']=='next_fight' and e['combat']['encounter']==2:break
 preboss_groups[(r['seed'],r['route'],r['pair_index'])].append((r['policy'],prefix))
for key, group in preboss_groups.items():
 if any(prefix!=group[0][1] for _,prefix in group):errors.append({'early_fights_differ':key})
def threshold(e,key):
 context=e.get("combat_context",e.get("combat",{}).get("damage_context",{}))
 if key in context:return context[key]
 if folder.name=="baseline":return {"slam_weak_required":2,"slam_normal_required":8}[key]
 raise ValueError("missing published candidate threshold: "+key)
policies={}
for policy in ['immediate-damage','intent-aware','avoid-intent']:
 selected=[r for r in rows if r['policy']==policy]
 clears=[e for r in selected for e in r['events'] if e['type']=='clear' and e['before_combat']['encounter']==2]
 turns=[e for r in selected for e in r['events'] if e['type']=='boss_turn_start']
 attacks=[e for e in clears if e.get('phase')=='enemy_attack']
 latches=[e for e in clears if not e['before_combat']['mitigation_success'] and e.get('combat',{}).get('mitigation_success')]
 activechoices=[e for e in clears if e['before_combat']['mitigation_active'] and not e['before_combat']['mitigation_success']]
 policies[policy]={
  'runs':len(selected),'terminal':dict(collections.Counter(r['terminal'] for r in selected)),
  'boss_clears':len(clears),'total_run_actions':sum(r['carry']['actions'] for r in selected),
  'final_hp': [r['carry']['hp'] for r in selected],
  'turns':len(turns),'slam_turns':sum(e['combat']['damage_context']['intent']=='slam' for e in turns),
  'fallback_turns':sum(e['combat']['fallback_plain'] for e in turns),
  'attacks':len(attacks),'attack_damage_histogram':dict(collections.Counter(e['combat']['last_attack_damage'] for e in attacks)),
  'hp_lost_to_attacks':sum(min(e['before']['hp']+e['heal_effective'],e['combat']['last_attack_damage']) for e in attacks),
  'mitigation_latches':len(latches),'incidental_latches':len(latches) if policy=='immediate-damage' else None,
  'active_unlatched_clear_count':len(activechoices),'active_unlatched_qualifying_choices':sum(e['mitigates_intent'] for e in activechoices),
  'turn_start_legal_unique_sets':sum(e['unique_removal_sets'] for e in turns),
  'turn_start_eligible_unique_sets':sum(e['eligible_unique_removal_sets'] for e in turns),
  'turns_with_raw_threshold_opportunity':sum((e.get('raw_eligible_unique_removal_sets',e['eligible_unique_removal_sets']) or 0)>0 for e in turns),
  'turns_with_nonqualifying_alternatives':sum(e['unique_removal_sets']>e['eligible_unique_removal_sets'] for e in turns),
  'active_slam_turns_with_nonmitigating_alternatives':sum(e['combat']['damage_context']['intent']=='slam' and e['unique_removal_sets']>e['eligible_unique_removal_sets'] for e in turns),
  'opportunity_fraction':sum((e.get('raw_eligible_unique_removal_sets',e['eligible_unique_removal_sets']) or 0)>0 for e in turns)/len(turns) if turns else 0,
  'weak_bonus_total':sum(e['weak_bonus'] for e in clears),
  'chosen_weak_histogram':dict(collections.Counter(e['weak_count'] for e in clears)),
  'chosen_normal_histogram':dict(collections.Counter(e['normal_count'] for e in clears)),
  'active_qualifying_by_weak_only':sum(e['weak_count']>=threshold(e,'slam_weak_required') and e['normal_count']<threshold(e,'slam_normal_required') for e in activechoices),
  'active_qualifying_by_normal_only':sum(e['weak_count']<threshold(e,'slam_weak_required') and e['normal_count']>=threshold(e,'slam_normal_required') for e in activechoices),
  'active_qualifying_by_both':sum(e['weak_count']>=threshold(e,'slam_weak_required') and e['normal_count']>=threshold(e,'slam_normal_required') for e in activechoices),
 }
report={'incomplete_events':[{'path':r['path'],'terminal':r['terminal'],'event_type':e['type'],'phase':e.get('phase'),'start_id':e.get('start_id'),'reason':'No after-state exists for incomplete refill; not a defeat or completed audit'} for r in rows for e in r['events'] if e['type']=='clear' and 'after' not in e], 'method':'Pure fixed-step normal simulation, no injections, GPU or realtime evidence. All three policies share exact first-two-fight selector, max-connection skill, and route/shop flow. Avoid-intent is adversarial diagnostic, not human ability.', 'source_changes':[n for n in before if before[n]!=after[n]],'runs':len(rows),'expected_runs':18,'supplemental_completed':len(supplemental),'scope_note':('Parent bounded core to 3 seeds x2 routes x pair0 x3 policies. Initial broad batch was interrupted only after seed21 full18 files completed (exit130); completed non-pair0 files retained as supplemental. Missing core seeds then run via CLI.' if folder.name=='baseline' else 'One candidate, same18 matched core cases; no parameter sweep.'),'early_fight_groups_checked':len(preboss_groups),'early_fight_errors':errors,'audit_available_runs':sum(bool(r['audit']) for r in rows),'audit_checks':sum(r['audit'].get('checks',0) for r in rows),'run_errors':[r['path'] for r in rows if r['errors'] or r['audit'].get('errors',['audit unavailable'])],'policies':policies,'comparison_limit':'Same initial seeds AND identical first-two-fight events checked. Boss choices cause later RNG/board divergence; not an identical-board causal skill comparison. No balance/win-rate generalization from 3 deterministic seeds.','supplemental_index':[{'path':r['path'],'terminal':r['terminal'],'errors':r['errors'],'audit':r['audit']} for r in supplemental],'runs_index':[{'path':r['path'],'policy':r['policy'],'terminal':r['terminal'],'hp':r['carry']['hp'],'actions':r['carry']['actions'],'boss':r['boss_summary']} for r in rows]}
(folder/'analysis.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in report.items() if k!='runs_index'},ensure_ascii=False,indent=2))
