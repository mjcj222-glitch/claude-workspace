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
evidence = base / 'evidence/bomb-volume/windows'
evidence.mkdir(parents=True, exist_ok=True)
request = Path('/tmp/chroma-quality-window-request.json')
ack = Path('/tmp/chroma-quality-window-ack.json')
request.unlink(missing_ok=True)
ack.unlink(missing_ok=True)
log = (evidence / f'states-{width}x{height}{log_suffix}.log').open('w')
process = subprocess.Popen(['godot', '--path', str(base), '--audio-driver', 'Dummy', '--position', '0,0', '--script', 'tests/test_bomb_volume_window.gd', '--', str(width), str(height)] + (["--effects-only"] if effects_only else []) + (["--comparison-only"] if "--comparison-only" in sys.argv else []), stdout=log, stderr=subprocess.STDOUT)
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
                    subprocess.run(['ffmpeg', '-y', '-f', 'x11grab', '-video_size', f'{size[0]}x{size[1]}', '-i', f'{os.environ["DISPLAY"]}+{pos[0]},{pos[1]}', '-frames:v', '1', str(evidence / f'states-{width}x{height}-{data["capture"]}.png')], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
                xy = [str(round(data['x'])), str(round(data['y']))]
                if data['action'] == 'click':
                    subprocess.run(pointer + ['click'] + xy, check=True)
                elif data['action'] != 'capture':
                    subprocess.run(pointer + ['move'] + xy, check=True)
                    if data['action'] != 'move':
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
