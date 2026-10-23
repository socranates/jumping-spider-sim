from pathlib import Path
import argparse,hashlib,importlib.util,json,subprocess,tempfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
spec=importlib.util.spec_from_file_location('runner',ROOT/'roblox_port/tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
p=argparse.ArgumentParser();p.add_argument('--budget',action='store_true');a=p.parse_args()
stem='session-budget' if a.budget else 'session-fresh'
original=ROOT/'roblox_port/src/Shared/Persistence/SaveSession.luau';candidate=HERE/(stem+'-candidate.luau');base=r.chunk
r.chunk=lambda path:base(candidate if path.resolve()==original.resolve() else path)
cli=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe')
suites=['save_observation.luau','save_intent.luau','save_offers.luau','state.luau','state_client.luau','state_offline.luau','save_continuation.luau'];rows=[]
assert not (HERE/(stem+'-regression.json')).exists(),'Retain earlier run'
for suite in suites:
 text=r.bundle(suite)
 with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
 try:result=subprocess.run([str(cli),str(path)],capture_output=True,text=True)
 finally:path.unlink(missing_ok=True)
 output=result.stdout+result.stderr;(HERE/(stem+'-regression-'+suite+'.txt')).write_text(output,encoding='utf8',newline='\n')
 rows.append(dict(suite=suite,bundle_sha256=hashlib.sha256(text.encode()).hexdigest(),test_sha256=hashlib.sha256((ROOT/'roblox_port/tests'/suite).read_bytes()).hexdigest(),exit_code=result.returncode,output_sha256=hashlib.sha256(output.encode()).hexdigest()))
 print(suite,result.returncode,output[-1800:],flush=True)
 if result.returncode:break
(HERE/(stem+'-regression.json')).write_text(json.dumps(dict(candidate_sha256=hashlib.sha256(candidate.read_bytes()).hexdigest(),suites=rows,production_changed=False,real_datastore_verified=False),indent=2)+'\n',encoding='utf8',newline='\n')
assert len(rows)==len(suites) and all(row['exit_code']==0 for row in rows)
