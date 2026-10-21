"""Compare the single bounded candidate with archived baseline."""
from pathlib import Path
import json,sys
base=Path('evidence/balance')
label=sys.argv[1] if len(sys.argv)>1 else 'candidate-a'
load=lambda label:{(r['seed'],r['route'],r['pair_index'],r['policy']):r for p in (base/label).glob('seed*-*.json') if 'pair0-' in p.name for r in [json.loads(p.read_text())]}
before=load('baseline');after=load(label)
def prefix(r):
 selected=[]
 for e in r['events']:
  if e['type'] in ['skill','clear']:selected.append((e['type'],e.get('start_id'),e.get('color'),e.get('direct_ids'),e.get('removed_ids')))
  if e['type']=='next_fight' and e['combat']['encounter']==2:return selected,e['before'],e['rng_state']
 return selected,None,None
changed_early=[key for key in before if key in after and prefix(before[key])!=prefix(after[key])]
metrics={label:json.loads((base/label/'analysis.json').read_text())['policies'] for label in ['baseline',label]}
examples=[]
for key,r in after.items():
 if r['policy']!='immediate-damage':continue
 attacks=[e for e in r['events'] if e['type']=='clear' and e['before_combat']['encounter']==2 and e.get('phase')=='enemy_attack']
 examples.append({'seed':r['seed'],'route':r['route'],'terminal':r['terminal'],'hp':r['carry']['hp'],'boss_attacks':[e['combat']['last_attack_damage'] for e in attacks],'natural_failed_slam':any(e['combat']['last_attack_damage']==10 for e in attacks),'actual_mitigated_slam':any(e['combat']['last_attack_damage']==4 for e in attacks),'summary':r['boss_summary']})
policy_pairs=[]
for key,r in after.items():
 if r['policy']!='immediate-damage':continue
 other=after.get((r['seed'],r['route'],r['pair_index'],'intent-aware'))
 if not other:continue
 choices=lambda x:[(e['type'],e.get('start_id'),e.get('color')) for e in x['events'] if e['type'] in ['skill','clear']]
 policy_pairs.append({'seed':r['seed'],'route':r['route'],'choices_identical':choices(r)==choices(other),'immediate_summary':r['boss_summary'],'intent_summary':other['boss_summary'],'immediate_hp':r['carry']['hp'],'intent_hp':other['carry']['hp']})
choices=lambda x:[(e['type'],e.get('start_id'),e.get('color')) for e in x['events'] if e['type'] in ['skill','clear']]
choice_changes=[{'seed':key[0],'route':key[1],'pair':key[2],'policy':key[3]} for key in before if key in after and choices(before[key])!=choices(after[key])]
result={'candidate_vs_baseline_changed_choices':choice_changes,'policy_pair_comparison':policy_pairs,'baseline_core':len(before),'candidate_core':len(after),'changed_early_selection_or_boss_entry':changed_early,'policy_metrics':metrics,'candidate_immediate_examples':examples,'candidate_has_immediate_natural_failed_slam':any(e['natural_failed_slam'] for e in examples),'candidate_has_same_run_failure_and_mitigation':any(e['natural_failed_slam'] and e['actual_mitigated_slam'] for e in examples),'scope':'Bounded candidate comparison; HP48 and 10→4/plain6 unchanged. Baseline stall remains incomplete, not defeat. No forced example; bounded candidate batch only.','limitation':'Same initial seeds and first-two-fight choices/resources/RNG confirmed above; later boss choices/boards can diverge. No human-skill or balance claim.'}
(base/('comparison.json' if label=='candidate-a' else 'comparison-'+label+'.json')).write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k!='policy_metrics'},ensure_ascii=False,indent=2))
