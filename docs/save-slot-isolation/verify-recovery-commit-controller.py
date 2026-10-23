from pathlib import Path
import hashlib,importlib.util,json,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('commit_runner',H/'run-recovery-commit-controller.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
receipt=json.loads((H/'recovery-commit-controller-receipt.json').read_text());output=(H/'recovery-commit-controller-output.txt').read_bytes();bundle,_=r.build()
assert receipt['source']==source and receipt['exit_code']==0 and receipt['output_sha256']==sha(output) and receipt['bundle_sha256']==sha(bundle.encode())
for name,digest in receipt['inputs'].items():
 path=ROOT/'roblox_port/src/Shared/Persistence'/name if name in ['Checkpoint.luau','SaveRest.luau'] else H/name
 assert sha(path.read_bytes())==digest
for line in ['RECOVERY_MEALS passed=49 failed=0 suspensions=7','RECOVERY_LIFE passed=360 failed=0 suspensions=130','RECOVERY_DESTINATION passed=72 failed=0 outside_flies=6 populated_regions=3','RECOVERY_PROGRESS passed=62 failed=0 suspensions=21','RECOVERY_PACKET passed=38 failed=0 wide_progress_chars=19363','RECOVERY_PROPOSAL_STORE passed=79 failed=0','RECOVERY_REST_WRITER passed=117 failed=0 suspensions=2616','RECOVERY_PROGRESS_WRITER passed=182 failed=0','RECOVERY_COMMIT_CONTROLLER completed_requests=31 simulated_seconds=186','RECOVERY_COMMIT_CONTROLLER passed=4836 failed=0']:assert line in output.decode()
types=json.loads((H/'recovery-commit-controller-types.json').read_text());assert len(types['candidates'])==15 and len(types['steps'])==3
for name,digest in types['candidates'].items():assert sha((H/name).read_bytes())==digest
for step in types['steps']:assert step['exit_code']==0 and step['output_sha256']==sha((H/('recovery-commit-controller-'+step['name']+'.txt')).read_bytes())
for flag in ['production_connected','real_datastore_verified','native_verified','destination_commit_authorized']:assert receipt[flag] is False
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
baseline=json.loads((H/'late-lease-negative-recovery-commit-controller-receipt.json').read_text());old_output=(H/'late-lease-negative-recovery-commit-controller-output.txt').read_bytes()
old_module=H/'late-lease-negative-recovery-commit-controller-prototype.luau';old_test=H/'late-lease-negative-recovery-commit-controller-tests.luau'
old_bundle,_=r.build(old_module,old_test)
assert baseline['source']==source and baseline['exit_code']!=0 and baseline['bundle_sha256']==sha(old_bundle.encode()) and baseline['output_sha256']==sha(old_output)
for name,digest in baseline['inputs'].items():
 path=old_module if name=='recovery-commit-controller-prototype.luau' else old_test if name=='recovery-commit-controller-tests.luau' else ROOT/'roblox_port/src/Shared/Persistence'/name if name in ['Checkpoint.luau','SaveRest.luau'] else H/name
 assert sha(path.read_bytes())==digest
assert b'final rest read crossed a remote lease takeover' in old_output
result=dict(source=source,commit_controller_assertions=4836,preceding_regression_assertions=959,current_runtime_bundle_verified=True,strict_clean=True,actual_session_guard_and_scheduler=True,post_archive_composition=True,completed_requests=31,completed_simulated_seconds=186,diagnostic_original_offer_bridge=True,production_legacy_offer_reader=False,same_session_and_new_diagnostic_session_restart_verified=True,late_lease_counterexample_reproduced=True,final_owned_lease_acknowledgement=True,archive_retry_heartbeat_priority_verified=True,request_cap_and_deadline_verified=True,ordinary_worker_reentry_refused=True,archive_and_unselected_rest_unchanged=True,production_connected=False,native_verified=False,real_datastore_verified=False,session_rebind_integrated=False,destination_commit_authorized=False,complete_migration=False,published=False)
(H/'recovery-commit-controller-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
