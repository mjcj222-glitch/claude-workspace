"""Isolate saved0b4e0a7 and current combat feedback for identical native replay.

Shared instrumentation matches performance_compare.py. No policy/capture runs
inside the measurement windows. This does not claim mobile performance.
"""
from pathlib import Path
import shutil
import performance_compare as common

common.DEST = Path('/tmp/chroma-character-performance')
common.prepare('before', '0b4e0a7')
common.prepare('after', '0b4e0a7')
dest = common.DEST / 'after'
for source in (common.PROJECT/'scripts').glob('*.gd'):
    shutil.copy2(source, dest/'scripts'/source.name)
shutil.copytree(common.PROJECT/'assets', dest/'assets', dirs_exist_ok=True)

main = dest/'scripts/main.gd'
text = main.read_text().replace('print("TIMING ", JSON.stringify(metric))', 'pass # benchmark: no synchronous stdout')
text = text.replace('var session = RunSession.new()', 'var bench: Dictionary = {}\nvar session = RunSession.new()')
for name, args, call, bucket in [('_draw', '', '', 'ui_draw_us'),
                                 ('draw_panels', 'canvas: CanvasItem', 'canvas', 'panels_draw_us'),
                                 ('_process', 'delta: float', 'delta', 'process_us')]:
    original=f'\nfunc {name}({args}) -> void:'
    replacement=(f'\nfunc {name}({args}) -> void:\n\tvar started := Time.get_ticks_usec()\n'
                 f'\t_bench_{name}({call})\n\tbench["{bucket}"] = bench.get("{bucket}",0)+Time.get_ticks_usec()-started\n\n'
                 f'func _bench_{name}({args}) -> void:')
    assert text.count(original)==1
    text=text.replace(original,replacement)
text=text.replace('presenter.UI.draw_details(presenter,self)', 'presenter.UI.draw_details(presenter,self)\n\t\t\tpresenter.bench["overlay_draw_us"]=Time.get_ticks_usec()-started')
text=text.replace('class ModalSurface extends Node2D:\n\tvar presenter: Node2D\n\tfunc _draw() -> void:\n',
                  'class ModalSurface extends Node2D:\n\tvar presenter: Node2D\n\tfunc _draw() -> void:\n\t\tvar started:=Time.get_ticks_usec()\n')
main.write_text(text)
print('Current production sources/assets copied; only shared timing wrappers added to main.')

import json
trace=json.loads((common.PROJECT/'evidence/impact/after/capture-20261021-elite-pair0-intent-aware-movie/trace.json').read_text())
types={'skill','clear','reward_chosen','route_chosen','shop_purchase','shop_exit'}
commands=[{'type':e['type'],'details':e['details']} for e in trace['events'] if e['type'] in types]
for label in ['before','after']:
    (common.DEST/label/'tests/performance_commands.json').write_text(json.dumps(commands))
print('Same recorded16-action route; import both copies before timing.')

for label in ["before","after"]:
    shutil.copy2(common.PROJECT/"tests/enter_adventure.gd", common.DEST/label/"tests/enter_adventure.gd")
