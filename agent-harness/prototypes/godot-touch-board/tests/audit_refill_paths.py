"""Validate revised current trajectories without claiming old byte equivalence.

Run test_motion_paths.gd, archive its new output as current-path-traces.json.gz,
then restore the immutable historical trace before running this comparison.
"""
import gzip
import hashlib
import json
import math
from pathlib import Path

root = Path(__file__).resolve().parents[1]
old_raw = (root / 'evidence/motion-fix/path-traces.json').read_bytes()
new_raw = gzip.decompress((root / 'evidence/refill-stall/current-path-traces.json.gz').read_bytes())
old, new = json.loads(old_raw), json.loads(new_raw)
assert hashlib.sha256(old_raw).hexdigest() == 'e8df397a4f51546fe4e558ea78d73c26fe60bce42758599e6688aca0e3289087'
report = {'old_sha256': hashlib.sha256(old_raw).hexdigest(),
          'new_sha256': hashlib.sha256(new_raw).hexdigest(), 'cases': {}}
for name, case in new.items():
    assert case['ready'] and case['max_overlap'] < .2 and case['swept_overlap'] < .6
    assert case['max_step'] < 20 and case['uncaused_sideways'] == 0 and case['floor_drift'] < .1
    panels = case['frames'][-1]
    assert len(panels) == 48 and all(p[2] - 37 >= 289.8 for p in panels)
    supported = {p[0] for p in panels if abs(p[2] + 37 - 820) < .2}
    for _ in panels:
        for p in panels:
            if any(q[0] in supported and q[2] > p[2] + .1
                   and math.hypot(q[1]-p[1], q[2]-p[2]) <= 74.2 for q in panels):
                supported.add(p[0])
    assert len(supported) == 48, f'{name}: unsupported READY body'
    report['cases'][name] = {'all48_supported': True,
                             'historical_frames_identical': case['frames'] == old[name]['frames'],
                             'seconds': case['seconds']}
(root / 'evidence/refill-stall/path-audit.json').write_text(json.dumps(report, indent=2)+'\n')
print(json.dumps(report, indent=2))
print('Revised trajectory invariants: PASS; old byte equivalence is NOT asserted.')
