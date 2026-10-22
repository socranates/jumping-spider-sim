from pathlib import Path
import hashlib,importlib.util,io,json,shutil,subprocess,tarfile,tempfile,time
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
BASE='ac898f40e84916ce0862214eb607cbbfba14034d'
TOOL=Path(r"C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe")
assert not (HERE/'candidate-cost.txt').exists() and not (HERE/'baseline-cost.txt').exists()
probe=(HERE/'paired-probe.luau').read_text(encoding='utf8')
for name in ['baseline','candidate']:
 with tempfile.TemporaryDirectory() as folder:
  snap=Path(folder)
  if name=='baseline':
   raw=subprocess.check_output(['git','archive','--format=tar',BASE,'roblox_port/src','roblox_port/tests'],cwd=ROOT)
   with tarfile.open(fileobj=io.BytesIO(raw)) as tree:
    for m in tree:
     if not m.isfile():continue
     p=snap/m.name;assert p.resolve().is_relative_to(snap.resolve());p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(tree.extractfile(m).read())
  else:
   shutil.copytree(ROOT/'roblox_port/src',snap/'roblox_port/src');shutil.copytree(ROOT/'roblox_port/tests',snap/'roblox_port/tests')
  inputs={p.relative_to(snap).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for subtree in ['roblox_port/src','roblox_port/tests'] for p in (snap/subtree).rglob('*') if p.is_file() and '__pycache__' not in p.parts}
  spec=importlib.util.spec_from_file_location('paired_runner_'+name,snap/'roblox_port/tests/run.py');runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
  code=runner.bundle('rest_storage.luau')+'\nlocal BASELINE='+('true' if name=='baseline' else 'false')+'\n'+probe
  path=snap/'cost.luau';path.write_text(code,encoding='utf8',newline='\n')
  at=time.time();r=subprocess.run([str(TOOL),str(path)],capture_output=True,text=True)
  (HERE/(name+'-cost.txt')).write_text(r.stdout+r.stderr,encoding='utf8',newline='\n')
  (HERE/(name+'-cost-process.json')).write_text(json.dumps(dict(exit_code=r.returncode,baseline=BASE,elapsed_seconds=time.time()-at,inputs=inputs,probe_sha256=hashlib.sha256(probe.encode()).hexdigest(),bundle_sha256=hashlib.sha256(code.encode()).hexdigest(),native=False,frame_time_measured=False,remote_transfer_measured=False),indent=2)+'\n',encoding='utf8',newline='\n')
  print(name,r.returncode,flush=True);print(r.stdout+r.stderr,flush=True);assert r.returncode==0
