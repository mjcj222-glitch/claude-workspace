"""Archive baseline/current into isolated /tmp copies, shared measurement wrappers only."""
from pathlib import Path
import json,io,subprocess,tarfile,shutil
p=Path(__file__).resolve().parents[1];repo=p.parents[2];prefix=p.relative_to(repo)
for label in ('before','after'):
 dest=Path('/tmp/chroma-impact-strength')/label
 data=subprocess.check_output(['git','archive','2089b392',str(prefix/'scripts'),str(prefix/'assets'),str(prefix/'project.godot'),str(prefix/'main.tscn')],cwd=repo)
 with tarfile.open(fileobj=io.BytesIO(data)) as a:
  for m in a.getmembers():
   if m.isfile():
    f=dest/Path(m.name).relative_to(prefix);f.parent.mkdir(parents=True,exist_ok=True);f.write_bytes(a.extractfile(m).read())
 if label=='after':shutil.copytree(p/'scripts',dest/'scripts',dirs_exist_ok=True)
 text=(dest/'scripts/main.gd').read_text()
 text=text.replace('var session = RunSession.new()', 'var bench:Dictionary={}\nvar session = RunSession.new()')
 text=text.replace('print("TIMING ", JSON.stringify(metric))','pass # shared measurement: no stdout')
 for name,args,call,bucket in [('_draw','','','ui_us'),('draw_panels','canvas: CanvasItem','canvas','panels_us'),('_process','delta: float','delta','process_us')]:
  old=f'\nfunc {name}({args}) -> void:'
  assert text.count(old)==1
  text=text.replace(old,f'\nfunc {name}({args}) -> void:\n\tvar begin:=Time.get_ticks_usec()\n\t_bench_{name}({call})\n\tbench["{bucket}"]=bench.get("{bucket}",0)+Time.get_ticks_usec()-begin\n\nfunc _bench_{name}({args}) -> void:')
 text=text.replace('presenter.UI.draw_details(presenter,self)','presenter.UI.draw_details(presenter,self)\n\t\t\tpresenter.bench["overlay_us"]=Time.get_ticks_usec()-begin')
 text=text.replace('class ModalSurface extends Node2D:\n\tvar presenter: Node2D\n\tfunc _draw() -> void:', 'class ModalSurface extends Node2D:\n\tvar presenter: Node2D\n\tfunc _draw() -> void:\n\t\tvar begin:=Time.get_ticks_usec()')
 (dest/'scripts/main.gd').write_text(text)
 (dest/'tests').mkdir(exist_ok=True)
 for name in ('enter_adventure.gd','replay_impact_strength.gd'):shutil.copy2(p/'tests'/name,dest/'tests'/name)
 shutil.copy2(p/'evidence/area/noa-risk-intent-aware-movie/trace.json',dest/'tests/impact_strength_commands.json')
 print(label,dest)
