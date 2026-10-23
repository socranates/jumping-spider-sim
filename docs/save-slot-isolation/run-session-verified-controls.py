from pathlib import Path
import argparse,hashlib,importlib.util,json,subprocess,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
p=argparse.ArgumentParser();p.add_argument('--baseline',action='store_true');p.add_argument('--yielding',action='store_true');a=p.parse_args()
spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
original=ROOT/'roblox_port/src/Shared/Persistence/SaveSession.luau';candidate=HERE/('session-budget-yield-candidate.luau' if a.baseline else 'session-budget-verified-candidate.luau');base=r.chunk
r.chunk=lambda path:base(candidate if path.resolve()==original.resolve() else path)
fixture=(ROOT/'roblox_port/tests/state.luau').read_text();prefix=fixture[:fixture.index('-- ---------------------------------------------------------------------------------------------- sizes, measured')]
test=(HERE/('session-budget-yield-tests.luau' if a.yielding else 'session-budget-checked-tests.luau')).read_text();text=r.bundle('state.luau');suffix=r.requires(fixture)+'\n';assert text.endswith(suffix)
text=text[:-len(suffix)]+r.requires(prefix+test)+'\n';stem='session-verified-'+('yield' if a.yielding else 'baseline' if a.baseline else 'controls')
assert not (HERE/(stem+'-output.txt')).exists(),'Retain earlier run'
with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
try:result=subprocess.run([r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(path)],capture_output=True,text=True)
finally:path.unlink(missing_ok=True)
output=result.stdout+result.stderr;(HERE/(stem+'-output.txt')).write_text(output,encoding='utf8',newline='\n')
(HERE/(stem+'-receipt.json')).write_text(json.dumps(dict(source='f4053597d03b99a61cb97e2eef1ec64ed174f22a',candidate_sha256=hashlib.sha256(candidate.read_bytes()).hexdigest(),test_sha256=hashlib.sha256(test.encode()).hexdigest(),bundle_sha256=hashlib.sha256(text.encode()).hexdigest(),exit_code=result.returncode,output_sha256=hashlib.sha256(output.encode()).hexdigest(),production_changed=False,native_verified=False),indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(result.returncode)
