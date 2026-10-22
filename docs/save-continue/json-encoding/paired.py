"""Evaluate an encoder in a private bundle; leave production Json unchanged."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,subprocess,tempfile
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
SOURCE='ab8ca9577129e3d9583a0a8ab6824dae1a8cd014'
TOOLS=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau')
parser=argparse.ArgumentParser();parser.add_argument('--out',type=Path,default=HERE/'attempt-1');parser.add_argument('--compile-only',action='store_true');args=parser.parse_args()
spec=importlib.util.spec_from_file_location('encoder_runner',ROOT/'roblox_port/tests/run.py')
runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
path=ROOT/'roblox_port/src/Shared/Persistence/Json.luau'
raw=subprocess.check_output(['git','show',SOURCE+':roblox_port/src/Shared/Persistence/Json.luau'],cwd=ROOT)
assert path.read_bytes()==raw,'measure against the unchanged baseline'
original=raw.decode();start=original.index('function Json.canonical(');end=original.index('-- A deep copy of a storable value',start)
candidate=original[:start]+(HERE/'canonical.luau').read_text(encoding='utf8')+'\n'+original[end:]
source=runner.bundle('local_rest_client.luau');marker='-- Real client loop on shim services; not native rendering/network evidence.'
assert source.count(marker)==1
source=source.split(marker)[0]+'\n__mods.JsonCandidate=(function()\n'+runner.requires(runner.strict(candidate))+'\nend)()\n'+runner.requires((HERE/'paired.luau').read_text(encoding='utf8'))
inputs={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
 for base in ['roblox_port/src','roblox_port/tests'] for p in (ROOT/base).rglob('*') if p.is_file() and '__pycache__' not in p.parts}
with tempfile.TemporaryDirectory() as folder:
 bundle=Path(folder)/'paired.luau';bundle.write_text(source,encoding='utf8',newline='\n')
 if args.compile_only:raise SystemExit(subprocess.call([str(TOOLS/'luau-compile.exe'),'-O0','--null',str(bundle)]))
 out=args.out.resolve();out.mkdir(parents=True,exist_ok=False)
 (out/'candidate-Json.luau').write_text(candidate,encoding='utf8',newline='\n')
 with (out/'output.txt').open('w',encoding='utf8',newline='\n') as log:
  result=subprocess.run([str(TOOLS/'luau.exe'),str(bundle)],stdout=log,stderr=subprocess.STDOUT)
 p=out/'output.txt';p.write_bytes(p.read_bytes().replace(b'\r\n',b'\n'))
 (out/'receipt.json').write_text(json.dumps(dict(source=SOURCE,exit_code=result.returncode,inputs=inputs,
  reference_sha256=hashlib.sha256(raw).hexdigest(),candidate_sha256=hashlib.sha256(candidate.encode()).hexdigest(),
  probe_sha256=hashlib.sha256((HERE/'paired.luau').read_bytes()).hexdigest(),bundle_sha256=hashlib.sha256(source.encode()).hexdigest(),
  output_sha256=hashlib.sha256(p.read_bytes()).hexdigest(),production_changed=False,native_verified=False,
  scope='CLI differential and alternating cooperative encode CPU/heap observations, not native FPS'),indent=2)+'\n',encoding='utf8',newline='\n')
 print('paired encoder exit',result.returncode,flush=True)
 raise SystemExit(result.returncode)
