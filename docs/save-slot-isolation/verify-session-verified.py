from pathlib import Path
import hashlib,json,re,subprocess
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((HERE/'session-budget-verified-manifest.json').read_text());assert sha((HERE/'session-budget-verified-candidate.luau').read_bytes())==m['candidate_sha256']
for stem,count,test in [('controls',83,'session-budget-checked-tests.luau'),('yield',44,'session-budget-yield-tests.luau')]:
 r=json.loads((HERE/('session-verified-'+stem+'-receipt.json')).read_text());output=(HERE/('session-verified-'+stem+'-output.txt')).read_bytes()
 assert r['exit_code']==0 and r['candidate_sha256']==m['candidate_sha256'] and r['test_sha256']==sha((HERE/test).read_bytes()) and r['output_sha256']==sha(output)
 assert 'passed='+str(count)+' failed=0' in output.decode()
assert sha((HERE/'session-budget-checked-tests.luau').read_bytes())==m['checked_test_sha256']
baseline=json.loads((HERE/'session-verified-baseline-receipt.json').read_text());assert baseline['exit_code']!=0 and baseline['candidate_sha256']==m['superseded_candidate_sha256']
assert baseline['test_sha256']==m['checked_test_sha256'] and baseline['output_sha256']==sha((HERE/'session-verified-baseline-output.txt').read_bytes())
assert 'callback failures were caught internally: 2' in (HERE/'session-verified-baseline-output.txt').read_text()
reg=json.loads((HERE/'session-budget-verified-regression.json').read_text());assert reg['candidate_sha256']==m['candidate_sha256'] and len(reg['suites'])==7
total=0
for row in reg['suites']:
 output=(HERE/('session-budget-verified-regression-'+row['suite']+'.txt')).read_bytes()
 test=subprocess.check_output(['git','show',m['base_source']+':roblox_port/tests/'+row['suite']],cwd=ROOT)
 assert row['exit_code']==0 and row['test_sha256']==sha(test) and row['output_sha256']==sha(output)
 matches=re.findall(r'passed=(\d+) failed=(\d+)',output.decode());assert len(matches)==1 and matches[0][1]=='0';total+=int(matches[0][0])
assert total==1624
types=json.loads((HERE/'session-budget-verified-types.json').read_text());assert types['candidates']['session-budget-verified-candidate.luau']==m['candidate_sha256'] and len(types['steps'])==4
for name,digest in types['candidates'].items():assert sha((HERE/name).read_bytes())==digest
for row in types['steps']:assert row['exit_code']==0 and row['output_sha256']==sha((HERE/('session-budget-verified-'+row['name']+'.txt')).read_bytes())
test=ROOT/'docs/recovery-pacing-gates/initial-adopted-state.luau'
for stem,code,passed,failed,source in [('initial',1,1250,2,m['superseded_candidate_sha256']),('corrected',0,1250,0,m['candidate_sha256'])]:
 r=json.loads((ROOT/('docs/recovery-pacing-gates/'+stem+'-integration-receipt.json')).read_text());output=(ROOT/('docs/recovery-pacing-gates/'+stem+'-integration-output.txt')).read_bytes()
 assert (r['exit_code']!=0 if code else r['exit_code']==0) and r['session_sha256']==source and r['test_sha256']==sha(test.read_bytes()) and r['output_sha256']==sha(output)
 assert 'STATE passed='+str(passed)+' failed='+str(failed) in output.decode()
withdrawn=json.loads((ROOT/'docs/recovery-pacing-gates/initial-adoption-withdrawn.json').read_text());assert not withdrawn['production_changes_committed'] and withdrawn['withdrawn_session_sha256']==m['superseded_candidate_sha256']
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
r=dict(base_source=m['base_source'],candidate_sha256=m['candidate_sha256'],callback_aware_controls=83,yielding_assertions=44,regression_suites=7,regression_assertions=1624,unchanged_integration_assertions=1250,integration_failed=0,strict_clean=True,production_changed=False,native_verified=False,native_requalification_required=True,full_gates_for_candidate=False,published=False)
(HERE/'session-verified-qualification.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
