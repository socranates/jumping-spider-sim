"""Verify the private recovered routine save loop against exact input/output hashes."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
PREFIX='save-loop-attempt-3';TYPES='save-loop-types-3'
sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('current_runner',H/'run-recovery-save-loop.py');runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
receipt=json.loads((H/(PREFIX+'-receipt.json')).read_text(encoding='utf8'));output=(H/(PREFIX+'-output.txt')).read_bytes();bundle,_=runner.build()
assert receipt['source']==source and receipt['exit_code']==0 and receipt['output_sha256']==sha(output) and receipt['bundle_sha256']==sha(bundle.encode())
for name,digest in receipt['inputs'].items():
 path=ROOT/'roblox_port/src/Shared/Persistence'/name if name in ['Checkpoint.luau','SaveRest.luau'] else H/name
 assert sha(path.read_bytes())==digest,name
expected=dict(RECOVERY_MEALS=49,RECOVERY_LIFE=360,RECOVERY_DESTINATION=72,RECOVERY_PROGRESS=62,RECOVERY_PACKET=38,RECOVERY_PROPOSAL_STORE=79,RECOVERY_REST_WRITER=117,RECOVERY_PROGRESS_WRITER=182,RECOVERY_COMMIT_CONTROLLER=4836,RECOVERY_OFFER_READER=1711,RECOVERY_SESSION_REBIND=1373,RECOVERY_PIPELINE=12362,RECOVERY_DEPARTURE=3407,RECOVERY_IDLE=14134,RECOVERY_RUNTIME=11963,RECOVERY_REST_FORMAT=82,RECOVERY_CURRENT_WRITER=1127,RECOVERY_ENTRY=10322,RECOVERY_SAVE_LOOP=22489)
actual={name:(int(p),int(f)) for name,p,f in re.findall(r'^(RECOVERY_\w+) passed=(\d+) failed=(\d+)',output.decode(),re.M)}
assert actual=={name:(n,0) for name,n in expected.items()},actual
types=json.loads((H/(TYPES+'-types.json')).read_text(encoding='utf8'));assert len(types['candidates'])==32 and len(types['steps'])==3
for name,digest in types['candidates'].items():assert sha((H/name).read_bytes())==digest,name
for step in types['steps']:assert step['exit_code']==0 and step['output_sha256']==sha((H/(TYPES+'-'+step['name']+'.txt')).read_bytes())
assert 'ImportUnused:' not in (H/(TYPES+'-strict.txt')).read_text(encoding='utf8')
for flag in ['production_connected','real_datastore_verified','native_verified','destination_commit_authorized']:assert receipt[flag] is False
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
counter=json.loads((H/'save-loop-envelope-counterexample-receipt.json').read_text(encoding='utf8'))
failed=(H/'save-loop-envelope-counterexample-output.txt').read_bytes()
assert counter['exit_code']!=0 and counter['output_sha256']==sha(failed)
assert 'routine callback erased unsupported envelope fields after its lease probe' in failed.decode()
result=dict(source=source,save_loop_assertions=22489,preceding_regression_assertions=62276,total_assertions=sum(expected.values()),private_candidates=32,compile_entry_clean=True,strict_clean=True,
 actual_factory_entry_routine_progress_rest_idle_departure_composed=True,all_three_slots_verified=True,
 ordinary_worker_and_enforced_write_barrier_retained=True,real_rare_generation_progress_saved_before_current_checkpoint=True,
 exact_rest_readback_and_cache_adoption_verified=True,shared_quota_debounce_and_rest_interval_preserved=True,
 acknowledged_global_baseline_advanced_without_releasing_hold=True,inflight_choice_reversal_and_ambiguous_commit_verified=True,
 same_tick_choice_reversal_verified=True,unresolved_progress_reservation_replayed_on_departure=True,
 provider_yield_drain_and_final_local_choice_verified=True,foreign_ownership_fences_actual_credential=True,
 later_notebook_progress_does_not_starve_checkpoint=True,later_progress_remains_dirty_until_durable=True,
 unsupported_envelope_counterexample_reproduced_and_fixed=True,
 production_connected=False,ordinary_recovered_progress_and_rest_coordinator_integrated_privately=True,
 production_saveservice_and_remote_menu_wired=False,continued_schema3_rejoin_integrated=False,
 native_verified=False,real_datastore_verified=False,complete_migration=False,goal_complete=False,published=False)
assert result['total_assertions']==84765
(H/'recovery-save-loop-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
