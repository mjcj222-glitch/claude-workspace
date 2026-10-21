"""Actual XTest clicks in small windows; growth offers use explicit state fixtures.

Natural 3/6/9 action progression is verified separately by play_growth.
"""
import json
import os
import subprocess
import sys
import time
from pathlib import Path

marker = Path('/tmp/chroma-small-click.json')
ack = Path('/tmp/chroma-small-ack.json')
marker.unlink(missing_ok=True)
ack.unlink(missing_ok=True)
width, height = map(int, sys.argv[1:3])
base = Path(__file__).resolve().parents[1]
evidence = base / 'evidence/growth'
evidence.mkdir(parents=True, exist_ok=True)
log = (evidence / f'small-{width}x{height}.log').open('w')
p = subprocess.Popen(
    ['godot', '--path', str(base), '--audio-driver', 'Dummy', '--position', '20,20',
     '--script', 'tests/small_window_probe.gd', '--', str(width), str(height)],
    stdout=log, stderr=subprocess.STDOUT)
seen = set()
end = time.monotonic() + 180
pointer = [sys.executable, str(base / 'tests/x11_pointer.py')]

def capture_window(data, suffix):
    pos, size = data['window_position'], data['window_size']
    subprocess.run(
        ['ffmpeg', '-y', '-f', 'x11grab', '-video_size', f'{size[0]}x{size[1]}',
         '-i', f'{os.environ["DISPLAY"]}+{pos[0]},{pos[1]}', '-frames:v', '1',
         str(evidence / f'small-{width}x{height}-window-{suffix}.png')],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)

try:
    while p.poll() is None and time.monotonic() < end:
        if marker.exists():
            try:
                data = json.loads(marker.read_text())
            except json.JSONDecodeError:
                time.sleep(.05)
                continue
            stage = data['stage']
            if stage not in seen:
                seen.add(stage)
                if stage == 'done':
                    break
                suffix = data.get('capture') or ('palette' if stage == 'color' else '')
                if suffix:
                    capture_window(data, suffix)
                action = data.get('action', 'click')
                coordinates = [str(round(data['x'])), str(round(data['y']))]
                if action == 'down':
                    subprocess.run(pointer + ['move'] + coordinates, check=True)
                    subprocess.run(pointer + ['down'], check=True)
                elif action == 'up':
                    subprocess.run(pointer + ['move'] + coordinates, check=True)
                    subprocess.run(pointer + ['up'], check=True)
                else:
                    subprocess.run(pointer + ['click'] + coordinates, check=True)
                # Atomic acknowledgement prevents a partially read JSON file.
                tmp = ack.with_suffix('.tmp')
                tmp.write_text(json.dumps({'stage': stage}))
                tmp.replace(ack)
        time.sleep(.05)
    try:
        rc = p.wait(timeout=5)
    except subprocess.TimeoutExpired:
        p.terminate()
        p.wait(timeout=5)
        rc = 124
finally:
    # Leave the shared X display with no mouse button held on failure.
    subprocess.run(pointer + ['up'], check=False)
    if p.poll() is None:
        p.terminate()
        p.wait(timeout=5)
    log.close()
print(width, height, 'stages', sorted(seen), 'exit', rc)
sys.exit(rc)
