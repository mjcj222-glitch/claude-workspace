import json,os,time,subprocess,sys
from pathlib import Path
marker=Path('/tmp/chroma-small-click.json')
marker.unlink(missing_ok=True)
width,height=map(int,sys.argv[1:3]); base=Path(__file__).resolve().parents[1]
log=(base/f'evidence/polish/small-{width}x{height}.log').open('w')
p=subprocess.Popen(['godot','--path',str(base),'--position','20,20','--script','tests/small_window_probe.gd','--',str(width),str(height)],stdout=log,stderr=subprocess.STDOUT)
seen=set();end=time.monotonic()+80
while p.poll() is None and time.monotonic()<end:
 if marker.exists():
  try:d=json.loads(marker.read_text())
  except json.JSONDecodeError:time.sleep(.05);continue
  stage=d['stage']
  if stage not in seen:
   seen.add(stage)
   if stage=='done':break
   if stage=='color':
    pos=d['window_position']; size=d['window_size']
    subprocess.run(['ffmpeg','-y','-f','x11grab','-video_size',f'{size[0]}x{size[1]}','-i',f'{os.environ["DISPLAY"]}+{pos[0]},{pos[1]}','-frames:v','1',str(base/f'evidence/polish/window-{width}x{height}.png')],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=True)
   subprocess.run(['python3',str(base/'tests/x11_pointer.py'),'click',str(round(d['x'])),str(round(d['y']))],check=True)
 time.sleep(.05)
try:rc=p.wait(timeout=5)
except subprocess.TimeoutExpired:p.terminate();rc=124
print(width,height,'stages',sorted(seen),'exit',rc);sys.exit(rc)
