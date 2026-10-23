from pathlib import Path
import argparse,hashlib,importlib.util,json,subprocess,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
p=argparse.ArgumentParser();p.add_argument('--candidate',action='store_true');p.add_argument('--yielding',action='store_true');p.add_argument('--yield-fixed',action='store_true');p.add_argument('--controls',action='store_true');a=p.parse_args()
assert not (a.yielding or a.yield_fixed) or a.candidate
session=ROOT/'roblox_port/src/Shared/Persistence/SaveSession.luau'
if a.candidate:
 original=session;session=HERE/('session-budget-yield-candidate.luau' if a.yield_fixed else 'session-budget-candidate.luau');base=r.chunk
 r.chunk=lambda path:base(session if path.resolve()==original.resolve() else path)
fixture=(ROOT/'roblox_port/tests/state.luau').read_text(encoding='utf8');prefix=fixture[:fixture.index('-- ---------------------------------------------------------------------------------------------- sizes, measured')]
test=(HERE/('session-budget-yield-tests.luau' if (a.yielding or a.yield_fixed) and not a.controls else 'session-budget-candidate-tests.luau' if a.candidate else 'session-budget-probe.luau')).read_text(encoding='utf8')
text=r.bundle('state.luau');suffix=r.requires(fixture)+'\n';assert text.endswith(suffix)
text=text[:-len(suffix)]+r.requires(prefix+test)+'\n'
cli=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe')
stem='session-budget-'+('yield-controls' if a.controls else 'yield-fixed' if a.yield_fixed else 'yield-baseline' if a.yielding else 'candidate' if a.candidate else 'baseline')
assert not (HERE/(stem+'-output.txt')).exists(),'Retain earlier evidence'
with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
try:result=subprocess.run([str(cli),str(path)],capture_output=True,text=True)
finally:path.unlink(missing_ok=True)
output=result.stdout+result.stderr;(HERE/(stem+'-output.txt')).write_text(output,encoding='utf8',newline='\n')
receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),session_sha256=hashlib.sha256(session.read_bytes()).hexdigest(),test_sha256=hashlib.sha256(test.encode()).hexdigest(),bundle_sha256=hashlib.sha256(text.encode()).hexdigest(),exit_code=result.returncode,output_sha256=hashlib.sha256(output.encode()).hexdigest(),production_changed=False,scope='Simulated request history; actual periodic SaveSession recovery; no service traffic')
(HERE/(stem+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(result.returncode)
