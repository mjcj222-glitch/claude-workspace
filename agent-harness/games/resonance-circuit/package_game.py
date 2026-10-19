"""Create an offline HTML and ZIP from unchanged ES module sources (stdlib only)."""
from pathlib import Path
import re
import base64
import zipfile

ROOT = Path(__file__).resolve().parent
modules = ['config.mjs', 'engine.mjs', 'campaign.mjs', 'storage.mjs', 'audio.mjs', 'effects.mjs', 'app.mjs']
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
files = ['standalone.html', 'index.html', 'style.css', *modules, 'OFFLINE.md', 'assets/approved-concept.png', 'assets/characters.css', 'assets/manifest.json']
with zipfile.ZipFile(ROOT / 'resonance-circuit.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for name in files:
        archive.write(ROOT / name, 'resonance-circuit/' + name)
print('Created standalone.html and resonance-circuit.zip; existing sources unchanged.')
