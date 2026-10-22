"""Make a portable save-adapter candidate; no publishing and no overwrite.
Usage: python docs/save-adapter-errors/package.py ABSOLUTE_OUTPUT_ZIP
"""
from pathlib import Path
import hashlib
import json
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
target=Path(sys.argv[1])
assert target.is_absolute() and not target.exists(), 'Choose a new absolute output path'
receipt=json.loads((OUT/'receipt.json').read_text(encoding='utf-8'))
assert receipt['offline_gates_pass'] and receipt['online_store_gate_pass'], 'Offline and isolated online verification must finish before packaging'
paths=set()
for sub in ['roblox_port/src','roblox_port/tests','roblox_port/tools','roblox_port/assets','docs/audit','docs/save-compaction','docs/life-retirement','docs/save-adapter-errors','docs/performance-pass','.github/workflows']:
    for p in (ROOT/sub).rglob('*'):
        if p.is_file() and p.name != 'portable-package.json' and '__pycache__' not in p.parts and p.suffix not in {'.pyc','.tmp'}:
            paths.add(p)
for sub in ['README.md','.gitattributes','.gitignore','chet/foundation-audit.md','chet/save-compaction.md','chet/life-retirement.md','chet/save-adapter-errors.md','docs/DECISIONS.md','docs/NOTEBOOK_SOURCES.md','data/notebook/pages.json']:
    p=ROOT/sub
    if p.is_file():paths.add(p)
for p in (ROOT/'roblox_port').iterdir():
    if p.is_file() and (p.name.endswith('.project.json') or p.suffix=='.rbxlx' or p.name=='README.md'):
        paths.add(p)
rows=[]
target.parent.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(target,'x',zipfile.ZIP_DEFLATED) as archive:
    for p in sorted(paths):
        data=p.read_bytes();name=p.relative_to(ROOT).as_posix()
        rows.append(dict(path=name,bytes=len(data),sha256=hashlib.sha256(data).hexdigest()))
        archive.writestr(name,data)
    manifest=dict(candidate=receipt['candidate'],published=receipt['published'],
                  offline_gates_pass=receipt['offline_gates_pass'],publication_ready=receipt['publication_ready'],
                  performance_matrix_complete=receipt['performance_matrix_complete'],files=rows)
    archive.writestr('SAVE_ADAPTER_PACKAGE_MANIFEST.json',json.dumps(manifest,indent=2))
with zipfile.ZipFile(target) as archive:
    assert archive.testzip() is None
    for row in rows:
        assert hashlib.sha256(archive.read(row['path'])).hexdigest()==row['sha256'],row['path']
result=dict(path=str(target),files=len(rows)+1,bytes=target.stat().st_size,sha256=hashlib.sha256(target.read_bytes()).hexdigest())
(OUT/'portable-package.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result,indent=2))
