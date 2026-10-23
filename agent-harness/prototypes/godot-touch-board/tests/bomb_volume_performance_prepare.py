"""Same first seven recorded normal inputs; native timing, no search/capture I/O.

At the first large supply the new physical shape intentionally changes trajectories.
Never require future board equality after that point or call it a rendering speedup.
"""
from pathlib import Path
import json,shutil
import performance_compare as common
common.DEST=Path('/tmp/chroma-volume-performance')
for label in ('before','after'):
    common.prepare(label,'2b32d63')
    dest=common.DEST/label
    for name in ['replay_impact_strength.gd','capture_quality_states.gd','test_bomb_volume_window.gd','bomb_volume_window_driver.py','x11_pointer.py']:
        shutil.copy2(common.PROJECT/'tests'/name,dest/'tests'/name)
    trace=json.loads((common.PROJECT/'evidence/bomb-body/normal/noa-risk-intent-aware-movie/trace.json').read_text())
    (dest/'tests/impact_strength_commands.json').write_text(json.dumps(trace))
    (dest/'evidence/bomb-volume').mkdir(parents=True,exist_ok=True)
    if label=='after':
        for name in ['board_bombs.gd','board_motion.gd','board_panel_view.gd','board_ui.gd']:
            shutil.copy2(common.PROJECT/'scripts'/name,dest/'scripts'/name)
print('Prepared 2b32d63 and current isolated sources with identical measurement wrappers.')
