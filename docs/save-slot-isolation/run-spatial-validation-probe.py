from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
assert not (HERE/'spatial-baseline.txt').exists(),'preserve the completed baseline; do not overwrite it'
assert subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()=='032926fd6e02c68c3f257189d397cbdf2a116bba'
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0,'baseline needs exact committed production inputs'
spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
name='../../docs/save-slot-isolation/spatial-validation-probe.luau'
cli=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe')
with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:
 f.write(r.bundle(name));test=Path(f.name)
try:result=subprocess.run([str(cli),str(test)],capture_output=True,text=True)
finally:test.unlink(missing_ok=True)
text=result.stdout+result.stderr
(HERE/'spatial-baseline.txt').write_text(text,encoding='utf8',newline='\n')
receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),
 probe_sha256=hashlib.sha256((HERE/'spatial-validation-probe.luau').read_bytes()).hexdigest(),
 output_sha256=hashlib.sha256(text.encode()).hexdigest(),exit_code=result.returncode,
 scope='Synthetic standalone save-validation corruption probe; no live save changes or engine evidence')
(HERE/'spatial-baseline.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(text);raise SystemExit(result.returncode)
