from pathlib import Path
import argparse,hashlib,importlib.util,json,subprocess,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
p=argparse.ArgumentParser();p.add_argument('--candidate',action='store_true');p.add_argument('--matrix',action='store_true');a=p.parse_args()
assert not a.matrix or a.candidate,'The extended matrix is a candidate acceptance test'
spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
original=ROOT/'roblox_port/src/Shared/Persistence/SaveSession.luau';base=r.chunk
candidate=HERE/'session-fresh-candidate.luau'
if a.candidate:
 def chunk(path):return base(candidate if path.resolve()==original.resolve() else path)
 r.chunk=chunk
fixture=(ROOT/'roblox_port/tests/state.luau').read_text(encoding='utf8')
prefix=fixture[:fixture.index('-- ---------------------------------------------------------------------------------------------- sizes, measured')]
test=(HERE/('session-fresh-matrix.luau' if a.matrix else 'session-cache-probe.luau')).read_text(encoding='utf8')
text=r.bundle('state.luau');suffix=r.requires(fixture)+'\n';assert text.endswith(suffix)
text=text[:-len(suffix)]+'local EXPECT_FRESH='+str(a.candidate).lower()+'\n'+r.requires(prefix+test)+'\n'
cli=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe')
with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
try:result=subprocess.run([str(cli),str(path)],capture_output=True,text=True)
finally:path.unlink(missing_ok=True)
output=result.stdout+result.stderr;stem='session-cache-'+('matrix' if a.matrix else 'candidate' if a.candidate else 'baseline')
assert not (HERE/(stem+'-output.txt')).exists(),'Retain the earlier run'
(HERE/(stem+'-output.txt')).write_text(output,encoding='utf8',newline='\n')
receipt=dict(source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip(),candidate=a.candidate,session_sha256=hashlib.sha256((candidate if a.candidate else original).read_bytes()).hexdigest(),test_sha256=hashlib.sha256(test.encode()).hexdigest(),exit_code=result.returncode,output_sha256=hashlib.sha256(output.encode()).hexdigest(),production_changed=False,real_datastore_verified=False)
(HERE/(stem+'-receipt.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(output);raise SystemExit(result.returncode)
