from pathlib import Path
import tempfile,shutil,subprocess,json,hashlib,io,tarfile,sys
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
BASE='8e02b5ee5f443ab332cf7e70f5951a304cb89eea'
TOOL=Path(r"C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe")
with tempfile.TemporaryDirectory() as folder:
 snap=Path(folder)
 archive=subprocess.check_output(['git','archive','--format=tar',BASE,'roblox_port/src'],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(archive)) as tree:
  for t in tree:
   if not t.isfile():continue
   assert t.name.startswith('roblox_port/src/') and '..' not in Path(t.name).parts
   p=snap/t.name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(tree.extractfile(t).read())
 # New pure helper is test support only on baseline; the old controller never imports it.
 helper='roblox_port/src/Shared/World/NavigationPreparation.luau'
 shutil.copyfile(ROOT/helper,snap/helper)
 shutil.copytree(ROOT/'roblox_port/tests',snap/'roblox_port/tests')
 files=list((snap/'roblox_port/src').rglob('*.luau'))+list((snap/'roblox_port/tests').rglob('*'))
 inputs={p.relative_to(snap).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in files if p.is_file() and '__pycache__' not in p.parts}
 with (HERE/'baseline.txt').open('w',encoding='utf8',newline='\n') as log:r=subprocess.run([sys.executable,str(snap/'roblox_port/tests/run.py'),str(TOOL),'navigation_startup.luau'],stdout=log,stderr=subprocess.STDOUT)
 f=HERE/'baseline.txt';f.write_bytes(f.read_bytes().replace(b'\r\n',b'\n'))
 (HERE/'baseline-process.json').write_text(json.dumps(dict(base=BASE,test_only_added_module=helper,exit_code=r.returncode,inputs=inputs),indent=2)+'\n',encoding='utf8',newline='\n')
 print('baseline exit',r.returncode,flush=True);assert r.returncode!=0
