"""Create an offline HTML and ZIP from unchanged ES module sources (stdlib only)."""
from pathlib import Path
import re
import base64
import zipfile
import hashlib
import json

ROOT = Path(__file__).resolve().parent
modules = ['flow.mjs','config.mjs', 'panels.mjs', 'skills.mjs', 'engine.mjs', 'campaign.mjs', 'storage.mjs', 'expedition.mjs','encounters.mjs','expedition-ui.mjs', 'audio.mjs', 'feedback.mjs', 'timeline.mjs', 'effects.mjs', 'skill-ui.mjs','mobile-ui.mjs','presentation.mjs','encounter-ui.mjs','flow-ui.mjs', 'app.mjs']
code = '\n'.join((ROOT / name).read_text() for name in modules)
code = re.sub(r'^import .*?;\s*$', '', code, flags=re.MULTILINE)
code = re.sub(r'^export ', '', code, flags=re.MULTILINE)
assert '</script' not in code.lower()
html = (ROOT / 'index.html').read_text()
packed_assets={};asset_manifest={}
def bundle_css(name):
    path=ROOT/name
    source=path.read_text()
    source=re.sub(r"@import url\('([^']+)'\);",lambda m:bundle_css(str(Path(name).parent/m.group(1))),source)
    def embed(match):
        relative=Path(name).parent/match.group(1);asset=ROOT/relative
        raw=asset.read_bytes();digest=hashlib.sha256(raw).hexdigest();key='a'+digest[:16]
        mime='image/svg+xml' if asset.suffix=='.svg' else 'image/webp' if asset.suffix=='.webp' else 'image/png'
        packed_assets[key]={'mime':mime,'data':base64.b64encode(raw).decode()}
        asset_manifest[key]={'path':str(relative),'sha256':digest,'bytes':len(raw),'mime':mime}
        return 'var(--asset-'+key+')'
    return re.sub(r"url\('([^']+)'\)",embed,source)
html=re.sub(r'<link rel="stylesheet" href="([^"]+)">',lambda m:'<style>\n'+bundle_css(m.group(1))+'\n</style>',html)
loader='<script>(()=>{const packedAssets='+json.dumps(packed_assets,separators=(',',':'))+';\n'
loader+="""for(const [key,item] of Object.entries(packedAssets)){const raw=atob(item.data),bytes=new Uint8Array(raw.length);for(let i=0;i<raw.length;i++)bytes[i]=raw.charCodeAt(i);const url=URL.createObjectURL(new Blob([bytes],{type:item.mime}));document.documentElement.style.setProperty("--asset-"+key,'url("'+url+'")');}})();</script>"""
html=html.replace('<style>',loader+'<style>',1)
html = html.replace('<script type="module" src="app.mjs"></script>', '<script>\n(() => {\n' + code + '\n})();\n</script>')
(ROOT / 'standalone.html').write_text(html)
(ROOT/'standalone-assets.json').write_text(json.dumps(asset_manifest,ensure_ascii=False,indent=2)+'\n')
sound_code=(ROOT/'audio.mjs').read_text()+'\n'+(ROOT/'sound_check.mjs').read_text()
sound_code=re.sub(r'^import .*?;\s*$', '', sound_code, flags=re.MULTILINE)
sound_code=re.sub(r'^export ', '', sound_code, flags=re.MULTILINE)
sound_html='<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>잔향 회로 · 사운드 체크</title><style>body{font:16px system-ui;background:#f3f0e9;color:#292930;max-width:600px;margin:24px auto;padding:12px}button{padding:12px;margin:4px;background:#64509b;color:white;border:1px solid transparent;border-radius:8px}#samples{display:grid;grid-template-columns:repeat(3,1fr)}</style><h1>잔향 회로 · 사운드 체크</h1><p>기본 무음. 소리를 켠 뒤 각 합성음을 직접 확인하세요. 배경음악·외부 음원 없음.</p><button id="toggle">소리 켜기</button><label>음량 <input id="volume" aria-label="음량" type="range" min="0" max="100" value="30"></label><p id="status" role="status">1초 WAV 샘플은 samples 폴더에 있습니다.</p><div id="samples"></div><script>'+sound_code+'</script></html>'
(ROOT/'sound-check.html').write_text(sound_html)
files = ['standalone-assets.json','sound-check.html','sound_check.mjs','standalone.html','index.html','style.css','neutral.css','mobile.css','presentation.css','fantasy.css','encounter.css','flow.css','assets/art-slots.css','assets/encounters.css',*modules,'README.md','OFFLINE.md','FLOW-REPORT.md','FLOW-DESIGN.md','assets/manifest.json']
files += ['assets/enemy-foreground-sheet.png','assets/portraits-cute.webp','assets/storybook-battle.webp',*[f'assets/encounter-{n}.webp' for n in ['mob','midboss','boss','event','rest']],*[f'assets/rune-{c}.svg' for c in ['coral','blue','gold','heal']]]
files += [n for n in ['flow-play.mp4'] if (ROOT/n).exists()]
files += [str(p.relative_to(ROOT)) for p in sorted((ROOT/'samples').glob('*.wav'))]
with zipfile.ZipFile(ROOT / 'resonance-circuit.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
    for name in files:
        archive.write(ROOT / name, 'resonance-circuit/' + name)
print('Created standalone.html and resonance-circuit.zip; existing sources unchanged.')
