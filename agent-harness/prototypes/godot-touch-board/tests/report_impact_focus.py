"""Exact game-state comparison and decoded audio validation for actual runs."""
import json,subprocess,array,math
from pathlib import Path
base=Path(__file__).resolve().parents[1];out=base/'evidence/impact-focus'
ignore={'wall_ms','process_frame','scene_seconds'}
def canonical(x):
 if isinstance(x,dict):return {k:canonical(v) for k,v in x.items() if k not in ignore}
 if isinstance(x,list):return [canonical(v) for v in x]
 return x
results=[]
for hero in ['rio','noa']:
 a=json.loads((out/f'baseline/{hero}.json').read_text())
 folder=f'{hero}-risk-intent-aware-movie'+('-free' if hero=='rio' else '')
 b=json.loads((out/'normal'/folder/'trace.json').read_text())
 rows=[i for i,(x,y) in enumerate(zip(a['events'],b['events'])) if canonical(x)!=canonical(y)]
 result={'hero':hero,'before_events':len(a['events']),'after_events':len(b['events']),'mismatches':rows,'terminal_equal':canonical(a['terminal'])==canonical(b['terminal']),'terminal':b['terminal']['phase'],'actions':b['terminal']['actions'],'hp':b['terminal']['hp'],'errors':b['errors'],'baseline':'fresh b4186b4 recording' if hero=='rio' else 'unchanged b4186b4 archived disc-bombs recording'}
 result['impact_events_equal']=[e for e in a['timings'] if e['event']=='attack_impact']==[e for e in b['timings'] if e['event']=='attack_impact']
 result['refill_frame_counts_equal']=[e['frames'] for e in a['timings'] if e['event']=='commit_to_ready']==[e['frames'] for e in b['timings'] if e['event']=='commit_to_ready']
 result['pass']=not rows and result['before_events']==result['after_events'] and result['terminal_equal'] and not a['errors'] and not b['errors'] and result['impact_events_equal'] and result['refill_frame_counts_equal']
 results.append(result)
(out/'state-comparison.json').write_text(json.dumps(results,indent=2));assert all(r['pass'] for r in results)
audio=[]
for name in ['before-full.mp4','after-full.mp4','before-preview.mp4','after-preview.mp4','impact-focus-before-after.mp4']:
 p=out/name
 data=subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-vn','-f','f32le','-acodec','pcm_f32le','-'])
 values=array.array('f');values.frombytes(data)
 peak=max(abs(x) for x in values);rms=math.sqrt(sum(x*x for x in values)/len(values))
 row={'file':name,'samples':len(values),'peak_dbfs':20*math.log10(peak),'rms_dbfs':20*math.log10(rms),'clipped_samples':sum(abs(x)>=1 for x in values),'nonfinite_samples':sum(not math.isfinite(x) for x in values)}
 audio.append(row);assert row['clipped_samples']==0 and row['nonfinite_samples']==0 and rms>0
(out/'audio-validation.json').write_text(json.dumps(audio,indent=2))
print(json.dumps({'state':results,'audio':audio},indent=2))
