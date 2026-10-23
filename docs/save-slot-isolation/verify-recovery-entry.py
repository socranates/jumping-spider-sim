"""Verify the private entry handshake against exact input/output hashes."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
PREFIX='entry-attempt-3';TYPES='entry-types-3'
sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('current_runner',H/'run-recovery-entry.py');runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
receipt=json.loads((H/(PREFIX+'-receipt.json')).read_text(encoding='utf8'));output=(H/(PREFIX+'-output.txt')).read_bytes();bundle,_=runner.build()
assert receipt['source']==source and receipt['exit_code']==0 and receipt['output_sha256']==sha(output) and receipt['bundle_sha256']==sha(bundle.encode())
for name,digest in receipt['inputs'].items():
 path=ROOT/'roblox_port/src/Shared/Persistence'/name if name in ['Checkpoint.luau','SaveRest.luau'] else H/name
 assert sha(path.read_bytes())==digest,name
expected=dict(RECOVERY_MEALS=49,RECOVERY_LIFE=360,RECOVERY_DESTINATION=72,RECOVERY_PROGRESS=62,RECOVERY_PACKET=38,RECOVERY_PROPOSAL_STORE=79,RECOVERY_REST_WRITER=117,RECOVERY_PROGRESS_WRITER=182,RECOVERY_COMMIT_CONTROLLER=4836,RECOVERY_OFFER_READER=1711,RECOVERY_SESSION_REBIND=1373,RECOVERY_PIPELINE=12362,RECOVERY_DEPARTURE=3407,RECOVERY_IDLE=14134,RECOVERY_RUNTIME=11963,RECOVERY_REST_FORMAT=82,RECOVERY_CURRENT_WRITER=1127,RECOVERY_ENTRY=10322)
actual={name:(int(p),int(f)) for name,p,f in re.findall(r'^(RECOVERY_\w+) passed=(\d+) failed=(\d+)',output.decode(),re.M)}
assert actual=={name:(n,0) for name,n in expected.items()},actual
types=json.loads((H/(TYPES+'-types.json')).read_text(encoding='utf8'));assert len(types['candidates'])==30 and len(types['steps'])==3
for name,digest in types['candidates'].items():assert sha((H/name).read_bytes())==digest,name
for step in types['steps']:assert step['exit_code']==0 and step['output_sha256']==sha((H/(TYPES+'-'+step['name']+'.txt')).read_bytes())
assert 'ImportUnused:' not in (H/(TYPES+'-strict.txt')).read_text(encoding='utf8')
for flag in ['production_connected','real_datastore_verified','native_verified','destination_commit_authorized']:assert receipt[flag] is False
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
result=dict(source=source,entry_assertions=10322,preceding_regression_assertions=51954,total_assertions=sum(expected.values()),private_candidates=30,compile_entry_clean=True,strict_clean=True,
 actual_factory_discovery_archive_recovery_entry_composed=True,full_original_archive_and_current_rest_freshly_verified=True,
 all_three_slots_and_rest_mating_hatching_entry_verified=True,real_checkpoint_prepare_apply_and_actual_intent_grant=True,
 manual_test_only_grant_required=False,actual_entry_credential_used_by_continuation_writer=True,
 client_preparation_cooperative_and_nonmutating=True,client_application_single_use_and_selection_guarded=True,
 exact_client_receipt_and_final_uncached_rest_progress_proof=True,long_client_wait_retains_metadata_lease=True,
 normal_worker_and_ordinary_write_barrier_retained=True,recovered_idle_and_departure_verified=True,
 cancellation_retry_late_read_and_yielding_notification_close_verified=True,
 production_connected=False,schema3_entry_integrated_in_private_runtime=True,schema3_entry_integrated_in_production=False,
 production_saveservice_and_remote_menu_wired=False,native_verified=False,real_datastore_verified=False,
 cancelled_failed_and_completed_preparation_graphs_released=True,ordinary_recovered_progress_and_rest_coordinator_integrated=False,complete_migration=False,goal_complete=False,published=False)
assert result['total_assertions']==62276
(H/'recovery-entry-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
