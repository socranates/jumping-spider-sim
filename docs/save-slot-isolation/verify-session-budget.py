from pathlib import Path
import hashlib,json,subprocess,re
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((HERE/'session-budget-candidate-manifest.json').read_text())
original=subprocess.check_output(['git','show',m['base_source']+':roblox_port/src/Shared/Persistence/SaveSession.luau'],cwd=ROOT)
assert sha(original)==m['original_sha256'] and (ROOT/'roblox_port/src/Shared/Persistence/SaveSession.luau').read_bytes()==original
assert sha((HERE/'session-budget-candidate.luau').read_bytes())==m['candidate_sha256']
for kind,count,test in [('baseline',12,'session-budget-probe.luau'),('candidate',82,'session-budget-candidate-tests.luau')]:
 r=json.loads((HERE/('session-budget-'+kind+'-receipt.json')).read_text());output=(HERE/('session-budget-'+kind+'-output.txt')).read_bytes()
 assert r['source']==m['base_source'] and r['exit_code']==0 and r['test_sha256']==sha((HERE/test).read_bytes()) and r['output_sha256']==sha(output)
 assert r['session_sha256']==(m['original_sha256'] if kind=='baseline' else m['candidate_sha256'])
 assert 'passed='+str(count)+' failed=0' in output.decode()
reg=json.loads((HERE/'session-budget-regression.json').read_text());assert reg['candidate_sha256']==m['candidate_sha256'] and len(reg['suites'])==7
total=0
for row in reg['suites']:
 output=(HERE/('session-budget-regression-'+row['suite']+'.txt')).read_bytes()
 test=subprocess.check_output(['git','show',m['base_source']+':roblox_port/tests/'+row['suite']],cwd=ROOT)
 assert row['exit_code']==0 and row['test_sha256']==sha(test) and row['output_sha256']==sha(output)
 matches=re.findall(r'passed=(\d+) failed=(\d+)',output.decode());assert len(matches)==1 and matches[0][1]=='0';total+=int(matches[0][0])
assert total==1624
types=json.loads((HERE/'session-budget-types.json').read_text());assert types['candidates']['session-budget-candidate.luau']==m['candidate_sha256'] and len(types['steps'])==4
for name,digest in types['candidates'].items():assert sha((HERE/name).read_bytes())==digest
for row in types['steps']:assert row['exit_code']==0 and row['output_sha256']==sha((HERE/('session-budget-'+row['name']+'.txt')).read_bytes())
prior=json.loads((HERE/'v1-session-budget-regression.json').read_text());assert prior['candidate_sha256']==sha((HERE/'v1-session-budget-candidate.luau').read_bytes())
failed=next(x for x in prior['suites'] if x['suite']=='state.luau');assert failed['exit_code']!=0 and failed['output_sha256']==sha((HERE/'v1-session-budget-regression-state.luau.txt').read_bytes())
assert 'and told the client what is stored, merged with this visit' in (HERE/'v1-session-budget-regression-state.luau.txt').read_text()
r=dict(base_source=m['base_source'],candidate_sha256=m['candidate_sha256'],baseline_counterexample_assertions=12,candidate_assertions=82,regression_suites=7,regression_assertions=1624,strict_clean=True,production_changed=False,native_verified=False,real_datastore_verified=False,published=False)
(HERE/'session-budget-verification.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
