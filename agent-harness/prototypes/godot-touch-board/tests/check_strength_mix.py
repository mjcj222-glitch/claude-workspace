"""Check native channel-preserving decoded PCM. No mono downmix gain."""
from pathlib import Path
import json,subprocess,numpy as np
p=Path(__file__).resolve().parents[1]/'evidence/impact-strength';results={}
for name in ('before.mp4','after.mp4','normal-full.mp4','impact-and-bombs.mp4'):
 raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(p/name),'-vn','-f','f32le','pipe:1'])
 a=np.frombuffer(raw,dtype='<f4');peak=float(np.max(abs(a)))
 results[name]={'sample_peak_dbfs':float(20*np.log10(peak)),'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(a*a)))),'full_scale_samples':int(np.sum(abs(a)>=1)),'nan_inf':int(np.sum(~np.isfinite(a)))}
 assert results[name]['full_scale_samples']==0 and results[name]['nan_inf']==0
(p/'actual-mix-check.json').write_text(json.dumps({'method':'Original decoded channels preserved; no -ac1 mono downmix gain. Digital sample peaks; EBU oversampled true peaks in separate logs. No human listening.','files':results},indent=2))
print(json.dumps(results,indent=2))
