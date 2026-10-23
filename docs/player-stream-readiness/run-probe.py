"""Reproduce current player stream-out through the real client; no production edits."""
from pathlib import Path
import hashlib,importlib.util,json,subprocess,sys,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
prefix=sys.argv[1] if len(sys.argv)>1 else 'baseline-1';assert prefix.replace('-','').isalnum()
out=H/(prefix+'-output.txt');assert not out.exists(),'Preserve previous evidence'
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
text=r.bundle('world_client.luau');marker='-- First-arrival readiness must not survive missing collision.'
assert text.count(marker)==1
probe=(H/'probe.luau').read_text(encoding='utf-8-sig');text=text.replace(marker,probe+'\n'+marker)
sha=lambda b:hashlib.sha256(b).hexdigest();inputs={str(p.relative_to(ROOT)).replace('\\','/'):sha(p.read_bytes().replace(b'\r\n',b'\n')) for p in (ROOT/'roblox_port/src').rglob('*.luau')}
with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
try:result=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(path)],capture_output=True,text=True)
finally:path.unlink(missing_ok=True)
assert inputs=={str(p.relative_to(ROOT)).replace('\\','/'):sha(p.read_bytes().replace(b'\r\n',b'\n')) for p in (ROOT/'roblox_port/src').rglob('*.luau')}
output=result.stdout+result.stderr;out.write_text(output,encoding='utf8',newline='\n')
(H/(prefix+'-receipt.json')).write_text(json.dumps(dict(source=source,exit_code=result.returncode,inputs=inputs,bundle_sha256=sha(text.encode()),probe_sha256=sha(probe.encode()),output_sha256=sha(output.encode()),native_verified=False,production_changed=False),indent=2)+'\n',encoding='utf8',newline='\n')
print(output);raise SystemExit(result.returncode)
