"""Summarize actual normal traces, separate from explicit OS fixtures."""
from pathlib import Path
import json,subprocess
from PIL import Image,ImageChops
base=Path(__file__).resolve().parents[1];p=base/'evidence/bomb-body';s={'baseline':'001548a48a9d0d3747cb12ec21928a174e1f610e','visual_radius':{'normal_chip':37,'normal_bomb':30,'large_bomb':48},'physical_bomb_radius':37,'blast_radius':{'bomb':98,'big_bomb':164},'scripts':48,'failures':0,'body_checks':15,'OS_checks_each':24,'OS_sizes':['720x1080','360x640','390x844'],'normal_runs':[],'same_input_comparison':[],'limitations':['Visual shell can extend behind neighbors and board wall; it is not an enlarged collider.','Existing ordinary nearest-body selection is preserved; no claim of pixel-perfect hit on all alpha shapes.','Fixedfps automated movie is not human fun, mobile or real-time performance evidence.','No new dedicated performance benchmark; earlier timing tails remain documented.','Shared temporary hero portrait, old Windows/Web packages and no save/resume remain.']}
rows=json.loads((p/'regression/results.json').read_text());assert len(rows)==48 and all(x['exit']==0 and not x['errors'] for x in rows)
for hero in ('noa','rio'):
 f=p/f'normal/{hero}-risk-intent-aware-movie/trace.json';x=json.loads(f.read_text());assert not x['errors'] and x['terminal']['phase']=='victory' and x['returned']
 mode='movie' if hero=='noa' else 'live'
 old=base/f'evidence/impact-strength/normal/{hero}-risk-intent-aware-{mode}/trace.json'
 old=json.loads(Path(str(old)).read_text())
 a=[e for e in old['events'] if e['type']=='clear'];b=[e for e in x['events'] if e['type']=='clear'];assert len(a)==len(b)
 for aa,bb in zip(a,b):
  for key in ('start_id','damage','removed','blasts','bomb_supply'):assert aa['details'][key]==bb['details'][key],(hero,bb['actions'],key)
 for key in ('hp','gold','actions','relics','charge','charge_required','ash_reserved'):assert old['terminal'][key]==x['terminal'][key],(hero,key)
 fall=[e['details'] for e in x['events'] if e['type']=='falling_bomb']
 assert fall and all(d['physical_radius']==37 and d['visual_radius']==(48 if d['kind']=='big_bomb' else 30) for d in fall)
 s['normal_runs'].append({'hero':hero,'actions':x['terminal']['actions'],'hp':x['terminal']['hp'],'gold':x['terminal']['gold'],'errors':x['errors'],'falling_samples':fall})
 s['same_input_comparison'].append({'hero':hero,'all_clear_ID_damage_blast_supply_equal':True,'resources_relic_charge_equal':True,'actions':len(a)})
for size in s['OS_sizes']:
 assert 'checks=24 failures=0' in (p/f'windows/states-{size}.log').read_text()
 a=Image.open(p/f'windows/states-{size}-01-dense-size-fixture.png');b=Image.open(p/f'windows/states-{size}-03-reduced-same-size.png')
 # Same rectangle in source logical screen, mapped via known fitted viewport.
 scale=min(a.width/720,a.height/1080);offset=((a.width-720*scale)/2,(a.height-1080*scale)/2)
 rect=(round(offset[0]+160*scale),round(offset[1]+655*scale),round(offset[0]+420*scale),round(offset[1]+782*scale))
 diff=ImageChops.difference(a.crop(rect).convert('RGB'),b.crop(rect).convert('RGB'))
 s.setdefault('reduced_body_pixel_difference',{})[size]=diff.getbbox()
 assert diff.getbbox() is None,(size,'reduced body changed')
for file in ('scripts/board_motion.gd','scripts/board_rules.gd','scripts/board_bombs.gd','scripts/board_audio.gd','scripts/board_combat.gd','scripts/board_area_session.gd'):
 expected=subprocess.check_output(['git','show','001548a:agent-harness/prototypes/godot-touch-board/'+file],cwd=base)
 assert expected==(base/file).read_bytes(),file
(p/'summary.json').write_text(json.dumps(s,ensure_ascii=False,indent=2));print('BODY_SUMMARY',s['same_input_comparison'],s['reduced_body_pixel_difference'])
