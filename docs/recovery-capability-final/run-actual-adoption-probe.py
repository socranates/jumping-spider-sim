"""Reproduce the missing actual-game recovery adapter through real restore code."""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
out=H/'actual-adoption-baseline-output.txt';assert not out.exists()
spec=importlib.util.spec_from_file_location('game_runner',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
text=r.bundle('local_return.luau');marker='fresh();local record=save();local originalStore='
assert text.count(marker)==1;text=text.split(marker,1)[0]+(H/'probe-actual-adoption.luau').read_text(encoding='utf8')
sha=lambda b:hashlib.sha256(b).hexdigest()
inputs={str(p.relative_to(ROOT)).replace('\\','/'):sha(p.read_bytes()) for folder in [ROOT/'roblox_port/src',ROOT/'roblox_port/tests'] for p in folder.rglob('*') if p.is_file() and '__pycache__' not in p.parts}
with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
try:run=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(path)],capture_output=True,text=True)
finally:path.unlink(missing_ok=True)
assert inputs=={str(p.relative_to(ROOT)).replace('\\','/'):sha(p.read_bytes()) for folder in [ROOT/'roblox_port/src',ROOT/'roblox_port/tests'] for p in folder.rglob('*') if p.is_file() and '__pycache__' not in p.parts}
output=run.stdout+run.stderr;out.write_text(output,encoding='utf8',newline='\n')
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
(H/'actual-adoption-baseline-receipt.json').write_text(json.dumps(dict(source=source,exit_code=run.returncode,inputs=inputs,bundle_sha256=sha(text.encode()),probe_sha256=sha((H/'probe-actual-adoption.luau').read_bytes()),output_sha256=sha(out.read_bytes()),expected_integration_counterexample=True,ordinary_local_returns_broken_claim=False,production_changed=False,native_verified=False,real_datastore_verified=False,published=False),indent=2)+'\n',encoding='utf8',newline='\n')
print(output);raise SystemExit(run.returncode)
