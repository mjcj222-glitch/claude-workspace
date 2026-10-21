"""Run after test_motion_paths.gd; pin the pre-optimization substep trajectory."""
import hashlib
import json
import math
from pathlib import Path

root = Path(__file__).resolve().parents[1]
raw = (root / 'evidence/motion-fix/path-traces.json').read_bytes()
expected = 'e8df397a4f51546fe4e558ea78d73c26fe60bce42758599e6688aca0e3289087'
assert hashlib.sha256(raw).hexdigest() == expected, 'Trajectory differs from dccbfe7'
for name, case in json.loads(raw).items():
    panels = case['frames'][-1]
    supported = {p[0] for p in panels if abs(p[2] + 37 - 820) < .2}
    for _ in panels:
        for p in panels:
            if any(q[0] in supported and q[2] > p[2] + .1
                   and math.hypot(q[1]-p[1], q[2]-p[2]) <= 75.5 for q in panels):
                supported.add(p[0])
    assert len(supported) == len(panels), f'{name}: floating READY body'
print('Exact substep equivalence and READY downward contact paths: PASS')
