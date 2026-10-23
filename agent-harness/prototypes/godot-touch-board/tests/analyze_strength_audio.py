"""Objective PCM/mix checks; these are not a human listening evaluation."""
import json,wave,os
os.environ.setdefault("MPLCONFIGDIR","/tmp/chroma-tools/matplotlib")
os.environ.setdefault("XDG_CACHE_HOME","/tmp/chroma-tools/cache")
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
base=Path(__file__).resolve().parents[1]/'evidence/impact-strength'
def load(p):
 with wave.open(str(p)) as f:return np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(float)/32768,f.getframerate()
def metrics(a,sr):
 spectrum=np.abs(np.fft.rfft(a))**2;freq=np.fft.rfftfreq(len(a),1/sr)
 return {'peak':float(np.max(np.abs(a))),'rms':float(np.sqrt(np.mean(a*a))),'full_scale_samples':int(np.sum(np.abs(a)>=.999)),'low_50_220_fraction':float(spectrum[(freq>=50)&(freq<220)].sum()/spectrum.sum()),'high_1500_8000_fraction':float(spectrum[(freq>=1500)&(freq<8000)].sum()/spectrum.sum())}
report={'method':'Raw synthesized16bit PCM and conservative summed six-voice bounds; no physical listening. Actual movie mix checked separately.','variants':{}}
for label in ('before','after'):
 report['variants'][label]={}
 for f in sorted((base/'audio'/label).glob('*.wav')):
  a,sr=load(f);report['variants'][label][f.stem]=metrics(a,sr)
new=report['variants']['after']
report['after_conservative_peak_bound']=max(new[f'normal-{i}']['peak'] for i in range(24))*10**(-16/20)*4+max(new[k]['peak'] for k in ('core-0','strong-0','bomb-0','big_bomb-0'))*10**(-13/20)+max(v['peak'] for k,v in new.items() if k.startswith('impact'))*10**(-8/20)
(base/'audio-analysis.json').write_text(json.dumps(report,indent=2))
assert report['after_conservative_peak_bound']<1
assert all(v['full_scale_samples']==0 for m in report['variants'].values() for v in m.values())
fig,axes=plt.subplots(3,2,figsize=(10,7),layout='constrained')
for row,(name,title) in enumerate([('normal-15','Clear15'),('impact-0-0','Basic impact'),('impact-2-1','Large weakness impact')]):
 for label,color in [('before','#777777'),('after','#8d3fd2')]:
  a,sr=load(base/'audio'/label/(name+'.wav'));axes[row,0].plot(np.arange(len(a))/sr,a,label=label,color=color,alpha=.7,linewidth=.7)
  # RMS normalization is intentional: compare timbre, not just gain.
  z=a/np.sqrt(np.mean(a*a));f=np.fft.rfftfreq(len(a),1/sr);v=np.abs(np.fft.rfft(z*np.hanning(len(z))));axes[row,1].plot(f,20*np.log10(np.maximum(v,1e-6)),label=label,color=color,alpha=.8,linewidth=.8)
 axes[row,0].set(title=title,xlabel='seconds',ylabel='PCM amplitude');axes[row,1].set(xlim=(40,6000),xlabel='Hz (equal RMS)',ylabel='spectral magnitude dB');axes[row,1].set_xscale('log');axes[row,0].legend()
fig.savefig(base/'audio-waveforms.png',dpi=140)
(base/'audio-analysis.json').write_text(json.dumps(report,indent=2))
print('variants',*[len(m) for m in report['variants'].values()],'conservative_peak_bound',report['after_conservative_peak_bound'])
