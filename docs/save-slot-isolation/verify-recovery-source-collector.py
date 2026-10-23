from pathlib import Path
import hashlib,json,re,subprocess
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
candidate=sha((HERE/'recovery-source-collector-prototype.luau').read_bytes());archive=sha((HERE/'recovery-archive-prototype.luau').read_bytes());store=sha((HERE/'recovery-archive-store-prototype.luau').read_bytes())
for stem,count,test in [('recovery-source-collector',3571,'recovery-source-collector-tests.luau'),('recovery-source-integration',311,'recovery-source-integration-tests.luau'),('recovery-source-aggregate-candidate',2,'recovery-source-aggregate-probe.luau')]:
 r=json.loads((HERE/(stem+'-receipt.json')).read_text());output=(HERE/(stem+'-output.txt')).read_bytes()
 assert r['source']==source and r['exit_code']==0 and r['candidate_sha256']==candidate and r['archive_sha256']==archive
 assert r['test_sha256']==sha((HERE/test).read_bytes()) and r['output_sha256']==sha(output) and 'passed='+str(count)+' failed=0' in output.decode()
 if stem=='recovery-source-integration':
  assert r['store_sha256']==store and r['backend_sha256']==sha((ROOT/'roblox_port/src/Server/DataStoreBackend.luau').read_bytes())
  assert 'requests=20 heartbeat_writes=2 simulated_seconds=135' in output.decode()
baseline=json.loads((HERE/'recovery-source-aggregate-baseline-receipt.json').read_text())
assert baseline['candidate_sha256']==sha((HERE/'before-aggregate-recovery-source-collector-prototype.luau').read_bytes()) and baseline['test_sha256']==sha((HERE/'recovery-source-aggregate-probe.luau').read_bytes()) and baseline['exit_code']==0
assert baseline['output_sha256']==sha((HERE/'recovery-source-aggregate-baseline-output.txt').read_bytes())
assert 'retained_nodes=646 allowance=500 bounded=false' in (HERE/'recovery-source-aggregate-baseline-output.txt').read_text()
assert 'retained_nodes=323 allowance=500 bounded=true' in (HERE/'recovery-source-aggregate-candidate-output.txt').read_text()
types=json.loads((HERE/'recovery-source-types.json').read_text());assert types['candidates']=={'recovery-archive-prototype.luau':archive,'recovery-source-collector-prototype.luau':candidate,'recovery-archive-store-prototype.luau':store} and len(types['steps'])==3
for step in types['steps']:assert step['exit_code']==0 and step['output_sha256']==sha((HERE/('recovery-source-'+step['name']+'.txt')).read_bytes())
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
r=dict(source=source,candidate_sha256=candidate,collector_assertions=3571,integration_assertions=311,aggregate_candidate_assertions=2,baseline_aggregate_overrun_reproduced=True,strict_clean=True,simulated_pipeline_requests=20,simulated_heartbeat_writes=2,simulated_elapsed_seconds=135,production_changed=False,native_verified=False,real_datastore_verified=False,real_session_authority_integrated=False,progress_import_implemented=False,published=False)
(HERE/'recovery-source-verification.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
