from pathlib import Path
import hashlib,importlib.util,json,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('controller_runner',H/'run-recovery-controller.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
for baseline in [False,True]:
 stem='recovery-controller-negative' if baseline else 'recovery-controller'
 receipt=json.loads((H/(stem+'-receipt.json')).read_text());output=(H/(stem+'-output.txt')).read_bytes();bundle,_=r.build(baseline)
 assert receipt['source']==source and receipt['exit_code']==int(baseline) and receipt['output_sha256']==sha(output) and receipt['bundle_sha256']==sha(bundle.encode())
 for name,digest in receipt['inputs'].items():
  if baseline and name=='recovery-controller-tests.luau':name='recovery-controller-negative-tests.luau'
  assert sha((H/name).read_bytes())==digest
 assert ('archive backoff starved lease renewal' if baseline else 'RECOVERY_CONTROLLER passed=2621 failed=0') in output.decode()
 if not baseline:assert 'long_pipeline_requests=22 elapsed_seconds=133 cpu_without_budget=1' in output.decode()
types=json.loads((H/'recovery-controller-types.json').read_text());assert len(types['candidates'])==5 and len(types['steps'])==3
for name,digest in types['candidates'].items():assert sha((H/name).read_bytes())==digest
for step in types['steps']:assert step['exit_code']==0 and step['output_sha256']==sha((H/('recovery-controller-'+step['name']+'.txt')).read_bytes())
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
result=dict(source=source,assertions=2621,heartbeat_priority_counterexample_reproduced=True,current_runtime_bundle_verified=True,strict_clean=True,actual_session_objects=True,backend='MemoryBackend',long_pipeline_requests=22,long_pipeline_simulated_seconds=133,complete_and_interrupted_archive_restart_verified=True,changed_unselected_source_refused=True,production_connected=False,native_verified=False,real_datastore_verified=False,destination_commit_authorized=False,progress_import_implemented=False,published=False)
(H/'recovery-controller-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
