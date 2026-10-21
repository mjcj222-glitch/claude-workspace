"""Prepare isolated commits with identical measurement-only instrumentation.

No product source is changed. Outputs are written after interaction playback.
Run preparation once, then invoke Godot serially with the emitted paths.
"""
import io
import json
from pathlib import Path
import subprocess
import tarfile

PROJECT = Path(__file__).resolve().parents[1]
REPO = PROJECT.parents[2]
PREFIX = PROJECT.relative_to(REPO).as_posix()
DEST = Path('/tmp/chroma-performance')
VERSIONS = {'before': '86a827d', 'after': 'f0187ccc'}


def prepare(label, revision):
    dest = DEST / label
    dest.mkdir(parents=True, exist_ok=True)
    paths = [f'{PREFIX}/{p}' for p in ['scripts', 'assets', 'main.tscn', 'project.godot']]
    data = subprocess.check_output(['git', 'archive', revision, *paths], cwd=REPO)
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        for member in archive.getmembers():
            if not member.isfile():
                continue
            relative = Path(member.name).relative_to(PREFIX)
            target = dest / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(archive.extractfile(member).read())
    script = dest / 'scripts/main.gd'
    text = script.read_text()
    # Remove original timing stdout only. Array-based metrics remain identical.
    text = text.replace('print("TIMING ", JSON.stringify(metric))', 'pass # benchmark: no synchronous stdout')
    text = text.replace('var session = RunSession.new()', 'var bench: Dictionary = {}\nvar session = RunSession.new()')
    for name, args, call, bucket in [
        ('_draw', '', '', 'ui_draw_us'),
        ('draw_panels', 'canvas: CanvasItem', 'canvas', 'panels_draw_us'),
        ('_process', 'delta: float', 'delta', 'process_us'),
    ]:
        original = f'\nfunc {name}({args}) -> void:'
        replacement = (f'\nfunc {name}({args}) -> void:\n'
                       f'\tvar started := Time.get_ticks_usec()\n'
                       f'\t_bench_{name}({call})\n'
                       f'\tbench["{bucket}"] = bench.get("{bucket}",0)+Time.get_ticks_usec()-started\n\n'
                       f'func _bench_{name}({args}) -> void:')
        assert text.count(original) == 1, (label, original)
        text = text.replace(original, replacement)
    text = text.replace('presenter.UI.draw_details(presenter,self)',
                        'presenter.UI.draw_details(presenter,self)\n\t\t\tpresenter.bench["overlay_draw_us"]=Time.get_ticks_usec()-started')
    text = text.replace('class ModalSurface extends Node2D:\n\tvar presenter: Node2D\n\tfunc _draw() -> void:\n',
                        'class ModalSurface extends Node2D:\n\tvar presenter: Node2D\n\tfunc _draw() -> void:\n\t\tvar started:=Time.get_ticks_usec()\n')
    script.write_text(text)
    (dest / 'tests').mkdir(exist_ok=True)
    (dest / 'tests/performance_replay.gd').write_bytes((PROJECT / 'tests/performance_replay.gd').read_bytes())
    trace = json.loads((PROJECT / 'evidence/quality/capture-20261021-elite-pair0-intent-aware-live/trace.json').read_text())
    types = {'skill', 'clear', 'reward_chosen', 'route_chosen', 'shop_purchase', 'shop_exit'}
    commands = [{'type': e['type'], 'details': e['details']} for e in trace['events'] if e['type'] in types]
    (dest / 'tests/performance_commands.json').write_text(json.dumps(commands))
    print(label, revision, dest)


if __name__ == '__main__':
    for label, revision in VERSIONS.items():
        prepare(label, revision)
    prepare('fixed', VERSIONS['after'])
    # The retained fix is deliberately the only production difference.
    (DEST / 'fixed/scripts/board_skin.gd').write_bytes((PROJECT / 'scripts/board_skin.gd').read_bytes())
    for label in [*VERSIONS, 'fixed']:
        (DEST / label / 'tests/performance_idle.gd').write_bytes((PROJECT / 'tests/performance_idle.gd').read_bytes())
