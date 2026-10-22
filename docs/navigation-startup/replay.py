from pathlib import Path
import tempfile,shutil,subprocess,json,hashlib,runpy
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
TOOL=Path(r"C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe")
OUT=HERE/'replay-v2';assert not OUT.exists(),'preserve previous replay before repeating';OUT.mkdir()
with tempfile.TemporaryDirectory() as folder:
 snap=Path(folder);shutil.copytree(ROOT/'roblox_port/src',snap/'roblox_port/src');shutil.copytree(ROOT/'roblox_port/tests',snap/'roblox_port/tests')
 inputs={p.relative_to(snap).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in (snap/'roblox_port/src').rglob('*.luau')}
 runner=runpy.run_path(str(snap/'roblox_port/tests/run.py'));runner['CLIENT_TESTS'].add('controller_replay.luau')
 rows=[]
 for fps in [30,60,120]:
  fixture=(HERE/'replay.luau').read_text(encoding='utf8').replace('__FPS__',str(fps));(snap/'roblox_port/tests/controller_replay.luau').write_text(fixture,encoding='utf8',newline='\n')
  code=runner['bundle']('controller_replay.luau');bundle=snap/'bundle.luau';bundle.write_text(code,encoding='utf8',newline='\n')
  log=OUT/f'{fps}.txt'
  with log.open('w',encoding='utf8',newline='\n') as f:r=subprocess.run([str(TOOL),str(bundle)],stdout=f,stderr=subprocess.STDOUT)
  log.write_bytes(log.read_bytes().replace(b'\r\n',b'\n'))
  rows.append(dict(fps=fps,exit_code=r.returncode,bundle_sha256=hashlib.sha256(code.encode()).hexdigest(),log_sha256=hashlib.sha256(log.read_bytes()).hexdigest()));print(fps,'exit',r.returncode,flush=True)
  (OUT/'process.json').write_text(json.dumps(dict(inputs=inputs,trials=rows),indent=2)+'\n',encoding='utf8',newline='\n')
  assert r.returncode==0
