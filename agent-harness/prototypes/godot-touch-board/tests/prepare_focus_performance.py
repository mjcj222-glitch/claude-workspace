"""Identical native replay wrappers; no capture/search inside timed windows."""
import json,shutil
from pathlib import Path
import performance_compare as common
common.DEST=Path('/tmp/chroma-focus/performance')
for label in ['before','after']:
 common.prepare(label,'b4186b4')
 dest=common.DEST/label
 for name in ['replay_impact_strength.gd']:
  shutil.copy2(common.PROJECT/'tests'/name,dest/'tests'/name)
 trace=json.loads((common.PROJECT/'evidence/disc-bombs/normal/noa-risk-intent-aware-movie/trace.json').read_text())
 (dest/'tests/impact_strength_commands.json').write_text(json.dumps(trace))
 if label=='after':
  for name in ['board_audio.gd','board_feedback.gd']:
   shutil.copy2(common.PROJECT/'scripts'/name,dest/'scripts'/name)
  p=dest/'scripts/main.gd';s=p.read_text();s=s.replace('if sound:\n\t\tfor voice in sound.voices: voice.stop()\n\t\tsound.cursor = 0','if sound:\n\t\tsound.reset_feedback()');p.write_text(s)
