from pathlib import Path
import hashlib,importlib.util,json,subprocess,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
base=r.chunk;original=ROOT/'roblox_port/src/Shared/Persistence/SaveSession.luau';candidate=HERE/'session-fresh-candidate.luau'
r.chunk=lambda path:base(candidate if path.resolve()==original.resolve() else path)
fixture=(ROOT/'roblox_port/tests/state.luau').read_text(encoding='utf8');prefix=fixture[:fixture.index('-- ---------------------------------------------------------------------------------------------- sizes, measured')]
test=(HERE/'session-adapter-tests.luau').read_text(encoding='utf8')
text=r.bundle('state.luau');suffix=r.requires(fixture)+'\n';assert text.endswith(suffix)
text=text[:-len(suffix)]+'local Backend='+r.chunk(HERE/'fresh-read-backend-candidate.luau')+'\n'+r.requires(prefix+test)+'\n'
cli=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe')
with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
try:result=subprocess.run([str(cli),str(path)],capture_output=True,text=True)
finally:path.unlink(missing_ok=True)
output=result.stdout+result.stderr;assert not (HERE/'session-adapter-output.txt').exists()
(HERE/'session-adapter-output.txt').write_text(output,encoding='utf8',newline='\n')
(HERE/'session-adapter-receipt.json').write_text(json.dumps(dict(session_sha256=hashlib.sha256(candidate.read_bytes()).hexdigest(),backend_sha256=hashlib.sha256((HERE/'fresh-read-backend-candidate.luau').read_bytes()).hexdigest(),test_sha256=hashlib.sha256(test.encode()).hexdigest(),exit_code=result.returncode,output_sha256=hashlib.sha256(output.encode()).hexdigest(),production_changed=False,real_datastore_verified=False),indent=2)+'\n',encoding='utf8',newline='\n')
print(output);raise SystemExit(result.returncode)
