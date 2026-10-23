from pathlib import Path
import argparse,tempfile,subprocess,json,hashlib,sys,time,io,tarfile
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--out',type=Path);a=p.parse_args()
if a.out is not None:
 HERE=a.out.resolve();assert HERE.is_relative_to(ROOT/'docs'),'Output must stay in the evidence tree'
 HERE.mkdir(parents=True,exist_ok=True)
TOOL=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe')
assert not (HERE/'windows-full.txt').exists(),'Preserve previous full-run evidence'
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
with tempfile.TemporaryDirectory() as folder:
 snap=Path(folder).resolve();raw=subprocess.check_output(['git','archive','--format=tar',source,'roblox_port/src','roblox_port/tests'],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
  for member in archive:
   if not member.isfile():continue
   path=(snap/member.name).resolve();assert path.is_relative_to(snap)
   path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(archive.extractfile(member).read())
 inputs={p.relative_to(snap).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for subtree in ['roblox_port/src','roblox_port/tests'] for p in (snap/subtree).rglob('*') if p.is_file() and '__pycache__' not in p.parts}
 (HERE/'windows-full-start.json').write_text(json.dumps(dict(source=source,inputs=inputs,status='running',expected_suites=76,expected_assertions=468880),indent=2)+'\n',encoding='utf8',newline='\n')
 at=time.time()
 with (HERE/'windows-full.txt').open('w',encoding='utf8',newline='\n') as log:r=subprocess.run([sys.executable,str(snap/'roblox_port/tests/run.py'),str(TOOL)],stdout=log,stderr=subprocess.STDOUT)
 p=HERE/'windows-full.txt';p.write_bytes(p.read_bytes().replace(b'\r\n',b'\n'))
 (HERE/'windows-full-process.json').write_text(json.dumps(dict(source=source,exit_code=r.returncode,elapsed_seconds=time.time()-at,inputs=inputs),indent=2)+'\n',encoding='utf8',newline='\n')
 print('full exit',r.returncode,flush=True);raise SystemExit(r.returncode)
