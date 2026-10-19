"""Create an offline HTML and ZIP from unchanged ES module sources (stdlib only)."""
from pathlib import Path
import re
import base64
import zipfile

ROOT = Path(__file__).resolve().parent
modules = ['config.mjs', 'panels.mjs', 'skills.mjs', 'engine.mjs', 'campaign.mjs', 'storage.mjs', 'expedition.mjs','expedition-ui.mjs', 'audio.mjs', 'feedback.mjs', 'timeline.mjs', 'effects.mjs', 'skill-ui.mjs', 'app.mjs']
code = '\n'.join((ROOT / name).read_text() for name in modules)
code = re.sub(r'^import .*?;\s*$', '', code, flags=re.MULTILINE)
code = re.sub(r'^export ', '', code, flags=re.MULTILINE)
assert '</script' not in code.lower()
html = (ROOT / 'index.html').read_text()
css=(ROOT/'style.css').read_text()
characters=(ROOT/'assets/characters.css').read_text()
data='data:image/png;base64,'+base64.b64encode((ROOT/'assets/approved-concept.png').read_bytes()).decode()
characters=characters.replace("url('approved-concept.png')", "url('"+data+"')")
css=css.replace("@import url('assets/characters.css');",characters)
html = html.replace('<link rel="stylesheet" href="style.css">', '<style>\n' + css + '\n</style>')
html = html.replace('<script type="module" src="app.mjs"></script>', '<script>\n(() => {\n' + code + '\n})();\n</script>')
(ROOT / 'standalone.html').write_text(html)
sound_code=(ROOT/'audio.mjs').read_text()+'\n'+(ROOT/'sound_check.mjs').read_text()
sound_code=re.sub(r'^import .*?;\s*$', '', sound_code, flags=re.MULTILINE)
sound_code=re.sub(r'^export ', '', sound_code, flags=re.MULTILINE)
sound_html='<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>잔향 회로 · 사운드 체크</title><style>body{font:16px system-ui;background:#123d47;color:#effff7;max-width:600px;margin:24px auto;padding:12px}button{padding:12px;margin:4px;background:#285761;color:white;border:1px solid #b3e2d7;border-radius:8px}#samples{display:grid;grid-template-columns:repeat(3,1fr)}</style><h1>잔향 회로 · 사운드 체크</h1><p>기본 무음. 소리를 켠 뒤 각 합성음을 직접 확인하세요. 배경음악·외부 음원 없음.</p><button id="toggle">소리 켜기</button><label>음량 <input id="volume" aria-label="음량" type="range" min="0" max="100" value="30"></label><p id="status" role="status">1초 WAV 샘플은 samples 폴더에 있습니다.</p><div id="samples"></div><script>'+sound_code+'</script></html>'
(ROOT/'sound-check.html').write_text(sound_html)
files = ['sound-check.html','sound_check.mjs','standalone.html' , 'index.html', 'style.css', *modules, 'OFFLINE.md','SOFT-CASCADE-REPORT.md','EXPEDITION-DESIGN.md','EXPEDITION-REPORT.md', 'assets/approved-concept.png', 'assets/characters.css', 'assets/manifest.json']
files += [n for n in ['audio-metrics.json','feedback-play.mp4','cascade-audio-metrics.json','cascade-play.mp4','soft-cascade-play.mp4','expedition-play.mp4'] if (ROOT/n).exists()]
files += [str(p.relative_to(ROOT)) for p in sorted((ROOT/'samples').glob('*.wav'))]
with zipfile.ZipFile(ROOT / 'resonance-circuit.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for name in files:
        archive.write(ROOT / name, 'resonance-circuit/' + name)
print('Created standalone.html and resonance-circuit.zip; existing sources unchanged.')
