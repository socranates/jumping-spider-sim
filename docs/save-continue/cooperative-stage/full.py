from pathlib import Path
import tempfile,shutil,subprocess,json,hashlib,sys,time
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
TOOL=Path(r"C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe")
assert not (HERE/'windows-full.txt').exists()
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
with tempfile.TemporaryDirectory() as folder:
 snap=Path(folder);shutil.copytree(ROOT/'roblox_port/src',snap/'roblox_port/src');shutil.copytree(ROOT/'roblox_port/tests',snap/'roblox_port/tests')
 inputs={p.relative_to(snap).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for subtree in ['roblox_port/src','roblox_port/tests'] for p in (snap/subtree).rglob('*') if p.is_file() and '__pycache__' not in p.parts}
 at=time.time()
 with (HERE/'windows-full.txt').open('w',encoding='utf8',newline='\n') as log:r=subprocess.run([sys.executable,str(snap/'roblox_port/tests/run.py'),str(TOOL)],stdout=log,stderr=subprocess.STDOUT)
 p=HERE/'windows-full.txt';p.write_bytes(p.read_bytes().replace(b'\r\n',b'\n'))
 (HERE/'windows-full-process.json').write_text(json.dumps(dict(source=source,exit_code=r.returncode,elapsed_seconds=time.time()-at,inputs=inputs),indent=2)+'\n',encoding='utf8',newline='\n')
 print('full exit',r.returncode,flush=True)
 raise SystemExit(r.returncode)
