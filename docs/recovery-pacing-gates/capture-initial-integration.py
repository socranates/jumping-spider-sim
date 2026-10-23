from pathlib import Path
import argparse,hashlib,importlib.util,json,subprocess,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];PRIVATE=HERE.parent/'save-slot-isolation'
spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
p=argparse.ArgumentParser();p.add_argument('--corrected',action='store_true');a=p.parse_args()
base=r.chunk;session=ROOT/'roblox_port/src/Shared/Persistence/SaveSession.luau';candidate=PRIVATE/('session-budget-verified-candidate.luau' if a.corrected else 'session-budget-yield-candidate.luau')
r.chunk=lambda path:base(candidate if path.resolve()==session.resolve() else path)
fixture=(ROOT/'roblox_port/tests/state.luau').read_text();test=(HERE/'initial-adopted-state.luau').read_text()
text=r.bundle('state.luau');suffix=r.requires(fixture)+'\n';assert text.endswith(suffix);text=text[:-len(suffix)]+r.requires(test)+'\n'
stem='corrected-integration' if a.corrected else 'initial-integration'
assert not (HERE/(stem+'-output.txt')).exists()
with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
try:result=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(path)],capture_output=True,text=True)
finally:path.unlink(missing_ok=True)
output=result.stdout+result.stderr;(HERE/(stem+'-output.txt')).write_text(output,encoding='utf8',newline='\n')
(HERE/(stem+'-receipt.json')).write_text(json.dumps(dict(session_sha256=hashlib.sha256(candidate.read_bytes()).hexdigest(),test_sha256=hashlib.sha256(test.encode()).hexdigest(),bundle_sha256=hashlib.sha256(text.encode()).hexdigest(),exit_code=result.returncode,output_sha256=hashlib.sha256(output.encode()).hexdigest()),indent=2)+'\n',encoding='utf8',newline='\n')
print(output[-2500:]);raise SystemExit(result.returncode)
