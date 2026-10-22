"""Paired immutable snapshots of the same expanded state suite; offline only."""
from pathlib import Path
import hashlib,json,runpy,shutil,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
BASE='4ed6375d3fb05166739b7757fecffb8d0cb90cad'
TOOL=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe')
sha=lambda b:hashlib.sha256(b).hexdigest()
for label in ['baseline','candidate']:
 assert not (HERE/(label+'.txt')).exists(),'preserve prior attempts before rerunning'
 with tempfile.TemporaryDirectory() as folder:
  snap=Path(folder)
  for sub in ['src','tests']:shutil.copytree(ROOT/'roblox_port'/sub,snap/'roblox_port'/sub)
  if label=='baseline':
   path='roblox_port/src/Shared/Persistence/SaveSession.luau'
   (snap/path).write_bytes(subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT))
  test=snap/'roblox_port/tests/state.luau';text=test.read_text(encoding='utf8')
  marker='print(`STATE passed={passed} failed={failed}`)';assert text.count(marker)==1
  fixture=(HERE/'cases.luau').read_text(encoding='utf8')
  if fixture not in text:text=text.replace(marker,fixture+'\n'+marker)
  assert text.count(fixture)==1;test.write_text(text,encoding='utf8',newline='\n')
  inputs={p.relative_to(snap).as_posix():sha(p.read_bytes()) for sub in ['src','tests'] for p in (snap/'roblox_port'/sub).rglob('*.luau')}
  runner=runpy.run_path(str(snap/'roblox_port/tests/run.py'));code=runner['bundle']('state.luau')
  bundle=snap/'state.luau';bundle.write_text(code,encoding='utf8',newline='\n')
  log=HERE/(label+'.txt')
  with log.open('w',encoding='utf8',newline='\n') as out:r=subprocess.run([str(TOOL),str(bundle)],stdout=out,stderr=subprocess.STDOUT)
  log.write_bytes(log.read_bytes().replace(b'\r\n',b'\n'))
  meta=dict(base=BASE,label=label,exit_code=r.returncode,inputs=inputs,fixture_sha256=sha(fixture.encode()),expanded_test_sha256=sha(test.read_bytes()),bundle_sha256=sha(code.encode()),log_sha256=sha(log.read_bytes()))
  (HERE/(label+'-process.json')).write_text(json.dumps(meta,indent=2)+'\n',encoding='utf8',newline='\n')
  print(label,'exit',r.returncode,flush=True)
