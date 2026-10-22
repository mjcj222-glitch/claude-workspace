import subprocess,os,time,json,tempfile
from PIL import Image
from pathlib import Path
b=Path(__file__).resolve().parents[1];out=b/os.environ.get('CHROMA_NATIVE_OUT','evidence/run-lifecycle/native');out.mkdir(exist_ok=True)
root=Path(tempfile.mkdtemp(prefix='chroma-native-lifecycle-'));slot=root/'save'
env=dict(os.environ,DISPLAY=':81',XAUTHORITY='/tmp/chroma-disc/Xauthority',XDG_DATA_HOME=str(root/'data'),XDG_CONFIG_HOME=str(root/'config'),XDG_CACHE_HOME=str(root/'cache'))
pointer=['python3',str(b/'tests/x11_pointer.py')]
def point(*args):subprocess.run(pointer+list(map(str,args)),env=env,check=True)
def shot(name):subprocess.run(['ffmpeg','-y','-f','x11grab','-video_size','720x1080','-i',':81','-frames:v','1',str(out/(name+'.png'))],env=env,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=True)
def start(n,seed):
 f=(out/(n+'.log')).open('w');p=subprocess.Popen(['godot','--audio-driver','Dummy','--path',str(b),'--position','0,0','--resolution','720x1080','--','--save-dir='+str(slot),'--seed='+str(seed)],env=env,stdout=f,stderr=subprocess.STDOUT);
 deadline=time.monotonic()+45
 while time.monotonic()<deadline:
  time.sleep(.5);shot('startup-probe')
  im=Image.open(out/'startup-probe.png').convert('RGB')
  if sum(1 for r,g,blue in im.crop((15,15,160,45)).getdata() if r>130 and g>90 and blue<180)>100:return p,f
 p.terminate();p.wait();f.close();raise RuntimeError('visible header did not become ready')
p,f=start('first',20261021)
shot('00-departure')
try:
 for x,y in [(360,370),(360,835),(360,268),(360,990)]:point('click',x,y);time.sleep(.65)
 shot('01-ready');before=(slot/'current.json').read_bytes()
 point('move',170,600);point('down');time.sleep(.2);shot('02-held')
finally:p.terminate();p.wait(timeout=8);f.close();point('up')
p,f=start('second',777)
try:
 shot('03-resume-menu');point('click',360,485);time.sleep(.7)
 point('up');assert (slot/'current.json').read_bytes()==before
 shot('04-resumed');point('click',170,600);time.sleep(4)
 after=(slot/'current.json').read_bytes();assert before!=after;shot('05-new-clear')
 (out/'summary.json').write_text(json.dumps({'method':'normal project executable; authenticated X11 pointer; process terminated while board held; restart with different requested new seed; resume then clear','checkpoint_unchanged_until_fresh_input':True,'new_clear_checkpoint_changed':True,'save_dir':str(slot)},indent=2))
finally:p.terminate();p.wait(timeout=8);f.close();point('up')
print('PASS native project kill/restart/resume/new input',slot)
