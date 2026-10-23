"""Verify the current private factory/routing cohort; no native/release claim."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1];PREFIX='recovery-runtime-v4';sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('runtime_runner',H/'run-recovery-runtime.py');runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
receipt=json.loads((H/(PREFIX+'-receipt.json')).read_text(encoding='utf8'));output=(H/(PREFIX+'-output.txt')).read_bytes();bundle,_=runner.build()
assert receipt['source']==source and receipt['exit_code']==0 and receipt['output_sha256']==sha(output) and receipt['bundle_sha256']==sha(bundle.encode())
for name,digest in receipt['inputs'].items():
 path=ROOT/'roblox_port/src/Shared/Persistence'/name if name in ['Checkpoint.luau','SaveRest.luau'] else H/name
 assert sha(path.read_bytes())==digest,name
expected=dict(RECOVERY_MEALS=49,RECOVERY_LIFE=360,RECOVERY_DESTINATION=72,RECOVERY_PROGRESS=62,RECOVERY_PACKET=38,RECOVERY_PROPOSAL_STORE=79,RECOVERY_REST_WRITER=117,RECOVERY_PROGRESS_WRITER=182,RECOVERY_COMMIT_CONTROLLER=4836,RECOVERY_OFFER_READER=1711,RECOVERY_SESSION_REBIND=1373,RECOVERY_PIPELINE=12362,RECOVERY_DEPARTURE=3407,RECOVERY_IDLE=14134,RECOVERY_RUNTIME=11963)
actual={name:(int(p),int(f)) for name,p,f in re.findall(r'^(RECOVERY_\w+) passed=(\d+) failed=(\d+)',output.decode(),re.M)}
assert actual=={name:(n,0) for name,n in expected.items()},actual
types=json.loads((H/(PREFIX+'-types.json')).read_text(encoding='utf8'));assert len(types['candidates'])==26 and len(types['steps'])==3
for name,digest in types['candidates'].items():assert sha((H/name).read_bytes())==digest,name
for step in types['steps']:assert step['exit_code']==0 and step['output_sha256']==sha((H/(PREFIX+'-'+step['name']+'.txt')).read_bytes())
for flag in ['production_connected','real_datastore_verified','native_verified','destination_commit_authorized']:assert receipt[flag] is False
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
result=dict(source=source,routing_assertions=11963,preceding_regression_assertions=38782,total_assertions=sum(expected.values()),current_runtime_bundle_verified=True,private_candidates=26,compile_entry_clean=True,strict_clean=True,private_session_factory_and_tick_composed=True,baseline_installed_and_bound_before_load=True,discovery_offered_and_entry_leases_verified=True,one_request_per_routing_step_and_shared_quota_verified=True,post_rebind_enforced_entry_hold=True,explicit_cancel_rediscovery_retry_and_departure_verified=True,normal_healthy_worker_and_flush_preserved=True,late_close_result_regression_verified=True,changed_scope_before_direct_flush_refused=True,initial_load_drain_and_late_callback_fence_verified=True,production_connected=False,production_saveservice_and_remote_menu_wired=False,safe_session_replacement_integrated=False,native_verified=False,real_datastore_verified=False,schema3_entry_integrated=False,complete_migration=False,goal_complete=False,published=False)
assert result['total_assertions']==50745
(H/'recovery-runtime-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
