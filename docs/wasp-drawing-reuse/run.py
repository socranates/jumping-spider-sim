from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
text=r.bundle('wasp.luau')+'\nlocal __waspReuse='+r.chunk(H/'candidate.luau')+'\n'+(H/'tests.luau').read_text()
assert not (H/'output.txt').exists(),'Preserve previous evidence'
with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
try:p=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(path)],capture_output=True,text=True)
finally:path.unlink(missing_ok=True)
output=p.stdout+p.stderr;(H/'output.txt').write_text(output,encoding='utf8',newline='\n')
receipt=dict(exit_code=p.returncode,bundle_sha256=hashlib.sha256(text.encode()).hexdigest(),inputs={name:hashlib.sha256((H/name).read_bytes()).hexdigest() for name in ['candidate.luau','tests.luau']},production_changed=False,native_verified=False)
(H/'receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(p.returncode)
