from pathlib import Path
import tempfile,shutil,subprocess,runpy,json,hashlib
import argparse
a=argparse.ArgumentParser();a.add_argument("--air",action="store_true");args=a.parse_args()
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
TOOL=Path(r"C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe")
OUT=HERE/'air' if args.air else HERE;OUT.mkdir(exist_ok=True)
fixture_path=HERE/('air-trace.luau' if args.air else 'trace.luau')
source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
with tempfile.TemporaryDirectory() as folder:
 snap=Path(folder);shutil.copytree(ROOT/'roblox_port/src',snap/'roblox_port/src');shutil.copytree(ROOT/'roblox_port/tests',snap/'roblox_port/tests')
 inputs={p.relative_to(snap).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in (snap/'roblox_port/src').rglob('*.luau')}
 runner=runpy.run_path(str(snap/'roblox_port/tests/run.py'))
 rows=[]
 for barrier,fps in [(barrier,fps) for barrier in [False,True] for fps in [30,60,120]]:
  fixture=fixture_path.read_text(encoding='utf8').replace('__FPS__',str(fps)).replace('__BARRIER__',str(barrier).lower())
  (snap/'roblox_port/tests/activation_trace.luau').write_text(fixture,encoding='utf8',newline='\n')
  code=runner['bundle']('activation_trace.luau');bundle=snap/'bundle.luau';bundle.write_text(code,encoding='utf8',newline='\n')
  with (OUT/f'trace-{int(barrier)}-{fps}.txt').open('w',encoding='utf8',newline='\n') as log:r=subprocess.run([str(TOOL),str(bundle)],stdout=log,stderr=subprocess.STDOUT)
  log_path=OUT/f'trace-{int(barrier)}-{fps}.txt';log_path.write_bytes(log_path.read_bytes().replace(b'\r\n',b'\n'))
  rows.append(dict(barrier=barrier,fps=fps,exit_code=r.returncode,bundle_sha256=hashlib.sha256(code.encode()).hexdigest()));print(barrier,fps,'exit',r.returncode,flush=True)
  assert r.returncode==0
 (OUT/'process.json').write_text(json.dumps(dict(source=source,inputs=inputs,trials=rows,fixture_sha256=hashlib.sha256(fixture_path.read_bytes()).hexdigest()),indent=2)+'\n',encoding='utf8',newline='\n')
