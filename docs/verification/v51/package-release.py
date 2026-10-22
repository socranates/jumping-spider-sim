"""Package the active Roblox release only after terminal receipts exist."""
from pathlib import Path
import hashlib
import json
import subprocess
import zipfile

repo=Path(__file__).resolve().parents[3]
out=Path(__file__).resolve().parent
receipt=json.loads((out/'release.json').read_text(encoding='utf-8'))
assert receipt['published'] is True and receipt['ci_conclusion']=='success'
assert receipt['suites_passed']==59
assert receipt['native_preserve']=={'pass':274,'fail':0,'skip':0}
assert receipt['native_source_comparison']=={'matched':215,'expected':215}
assert (repo/receipt['dashboard_proof']).is_file()
files=set()
for name in ['roblox_port/src','roblox_port/tests','roblox_port/tools','roblox_port/assets','docs/verification/v51']:
 for p in (repo/name).rglob('*'):
  if not p.is_file() or p.suffix.lower() in {'.zip','.pyc'} or p.name=='portable-package.json': continue
  if any(x in {'__pycache__','reports','captures','snapshots'} for x in p.relative_to(repo).parts): continue
  files.add(p)
for name in ['roblox_port/default.project.json','roblox_port/tests.project.json','roblox_port/README.md',
 'roblox_port/TheWindowsill.rbxlx','roblox_port/TheWindowsillTests.rbxlx','chet/HANDOFF-v51.md',
 'docs/RARE_SIGHTINGS_PLAN.md','docs/reference/rare-sightings.md','docs/reference/rare-build-2-research.md','docs/DECISIONS.md','docs/MESHES.md',
 '.github/workflows/roblox-port.yml','data/notebook/pages.json']:
 p=repo/name;assert p.is_file(),name;files.add(p)
rows=[{'path':p.relative_to(repo).as_posix(),'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in sorted(files)]
manifest={'source_commit':receipt['source_commit'],
 'document_tip':subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip(),
 'evidence_id':receipt['evidence_id'],'place_version':receipt['place_version'],
 'scope':'Active Roblox source, builds, tests, assets and v51 handoff/receipts; one frozen notebook JSON input for its generator; no Godot runtime',
 'files':rows}
archive=Path('C:/Users/natha/claude-xfer')/f"Windowsill-v51-place{receipt['place_version']}-{receipt['evidence_id']}.zip"
assert not archive.exists(),f'Refusing to replace existing transfer: {archive}'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED) as z:
 for p in sorted(files):z.write(p,p.relative_to(repo).as_posix())
 z.writestr('HANDOFF-MANIFEST.json',json.dumps(manifest,indent=2)+'\n')
with zipfile.ZipFile(archive) as z:
 assert z.testzip() is None
 assert len(z.namelist())==len(set(z.namelist()))==len(rows)+1
 for row in rows:assert hashlib.sha256(z.read(row['path'])).hexdigest()==row['sha256'],row['path']
manifest.pop('files')
manifest.update(path=str(archive),bytes=archive.stat().st_size,file_count=len(rows)+1,
 payload_file_count=len(rows),sha256=hashlib.sha256(archive.read_bytes()).hexdigest(),verified_all_payload_sha256=True)
(out/'portable-package.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps(manifest,indent=2))
