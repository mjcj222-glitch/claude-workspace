"""Authenticated OS clicks; explicit quality presentation fixtures, no claimed natural run."""
import json
import os
import subprocess
import sys
import time
from pathlib import Path

base = Path(__file__).resolve().parents[1]
width, height = map(int, sys.argv[1:3])
effects_only = "--effects-only" in sys.argv
premium = "--premium" in sys.argv
impact = "--impact" in sys.argv
log_suffix = "-effects" if effects_only else ""
evidence = base / 'evidence' / ('impact/windows' if impact else ('premium' if premium else 'quality'))
if "--validation-repair" in sys.argv:
    evidence = base / 'evidence/validation-repair/windows'
    if "--short-run" in sys.argv: log_suffix += "-short"
if '--lifecycle' in sys.argv:
    evidence = base / 'evidence/run-lifecycle/windows'
if '--lifecycle-ui' in sys.argv:
    evidence = base / 'evidence/run-lifecycle/windows'
    log_suffix += '-lifecycle'
if '--save-failure' in sys.argv:log_suffix += '-failure'
script = 'tests/capture_petal.gd' if '--petal' in sys.argv else ('tests/capture_lifecycle_states.gd' if '--lifecycle-ui' in sys.argv else 'tests/capture_quality_states.gd')
if '--petal' in sys.argv:log_suffix += '-petal'
if '--prism' in sys.argv:
    script='tests/capture_prism.gd'
    log_suffix += '-prism'
if "--short-run" in sys.argv and "-short" not in log_suffix:log_suffix += "-short"
if os.environ.get('CHROMA_WINDOW_OUT'):evidence=base/os.environ['CHROMA_WINDOW_OUT']
evidence.mkdir(parents=True, exist_ok=True)
request = Path('/tmp/chroma-quality-window-request.json')
ack = Path('/tmp/chroma-quality-window-ack.json')
request.unlink(missing_ok=True)
ack.unlink(missing_ok=True)
log = (evidence / f'states-{width}x{height}{log_suffix}.log').open('w')
process = subprocess.Popen(['godot', '--path', str(base), '--audio-driver', 'Dummy', '--position', '0,0', '--script', script, '--', str(width), str(height), '--seed=20261021', '--no-save'] + (["--effects-only"] if effects_only else []) + (["--hit-controls"] if impact else []) + (["--save-failure"] if '--save-failure' in sys.argv else []) + (["--short-run"] if "--short-run" in sys.argv else []), stdout=log, stderr=subprocess.STDOUT)
pointer = [sys.executable, str(base / 'tests/x11_pointer.py')]
seen = set()
deadline = time.monotonic() + 220
try:
    while process.poll() is None and time.monotonic() < deadline:
        if request.exists():
            try:
                data = json.loads(request.read_text())
            except json.JSONDecodeError:
                time.sleep(.03)
                continue
            stage = data['stage']
            if stage not in seen:
                seen.add(stage)
                if data['capture']:
                    pos, size = data['window_position'], data['window_size']
                    subprocess.run(['ffmpeg', '-y', '-f', 'x11grab', '-video_size', f'{size[0]}x{size[1]}', '-i', f'{os.environ["DISPLAY"]}+{pos[0]},{pos[1]}', '-frames:v', '1', str(evidence / f'states-{width}x{height}{log_suffix}-{data["capture"]}.png')], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
                xy = [str(round(data['x'])), str(round(data['y']))]
                if data['action'] == 'click':
                    subprocess.run(pointer + ['click'] + xy, check=True)
                elif data['action'] != 'capture':
                    subprocess.run(pointer + ['move'] + xy, check=True)
                    subprocess.run(pointer + [data['action']], check=True)
                temporary = ack.with_suffix('.tmp')
                temporary.write_text(json.dumps({'stage': stage}))
                temporary.replace(ack)
        time.sleep(.03)
    if process.poll() is None:
        process.terminate()
    code = process.wait(timeout=5)
finally:
    subprocess.run(pointer + ['up'], check=False)
    if process.poll() is None:
        process.terminate()
        process.wait(timeout=5)
    log.close()
print(width, height, 'stages', len(seen), 'exit', code)
sys.exit(code)
