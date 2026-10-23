"""Bind departure outcomes to exact current runtime/test/type-check inputs."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('departure_runner',H/'run-recovery-departure.py');runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
receipt=json.loads((H/'recovery-departure-receipt.json').read_text(encoding='utf8'))
output=(H/'recovery-departure-output.txt').read_bytes();bundle,_=runner.build()
assert receipt['source']==source and receipt['exit_code']==0 and receipt['output_sha256']==sha(output) and receipt['bundle_sha256']==sha(bundle.encode())
for name,digest in receipt['inputs'].items():
 path=ROOT/'roblox_port/src/Shared/Persistence'/name if name in ['Checkpoint.luau','SaveRest.luau'] else H/name
 assert sha(path.read_bytes())==digest,name
actual={name:(int(passed),int(failed)) for name,passed,failed in re.findall(r'^(RECOVERY_\w+) passed=(\d+) failed=(\d+)',output.decode(),re.M)}
expected=dict(RECOVERY_MEALS=49,RECOVERY_LIFE=360,RECOVERY_DESTINATION=72,RECOVERY_PROGRESS=62,RECOVERY_PACKET=38,RECOVERY_PROPOSAL_STORE=79,RECOVERY_REST_WRITER=117,RECOVERY_PROGRESS_WRITER=182,RECOVERY_COMMIT_CONTROLLER=4836,RECOVERY_OFFER_READER=1711,RECOVERY_SESSION_REBIND=1373,RECOVERY_PIPELINE=12362,RECOVERY_DEPARTURE=3407)
assert actual=={name:(count,0) for name,count in expected.items()},actual
types=json.loads((H/'recovery-departure-types.json').read_text(encoding='utf8'));assert len(types['candidates'])==23 and len(types['steps'])==3
for name,digest in types['candidates'].items():assert sha((H/name).read_bytes())==digest,name
for step in types['steps']:assert step['exit_code']==0 and step['output_sha256']==sha((H/('recovery-departure-'+step['name']+'.txt')).read_bytes())
for flag in ['production_connected','real_datastore_verified','native_verified','destination_commit_authorized']:assert receipt[flag] is False
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
result=dict(source=source,departure_assertions=3407,preceding_regression_assertions=21241,total_assertions=sum(expected.values()),current_runtime_bundle_verified=True,private_candidates=23,compile_entry_clean=True,strict_clean=True,closed_intake_and_inflight_drain_verified=True,atomic_three_way_progress_and_release_verified=True,normal_departure_requests=2,departure_max_requests=8,departure_timeout_seconds=24,uncached_readback_required=True,lost_acknowledgement_and_callback_replay_verified=True,archive_rest_and_proposal_unchanged=True,large_history_preserved_without_trimming=True,foreign_stale_changed_scope_and_deadline_refused=True,terminal_held_departure_verified=True,production_connected=False,native_verified=False,real_datastore_verified=False,production_factory_and_tick_wired=False,departure_and_terminal_hold_lifecycle_complete=False,schema3_entry_integrated=False,complete_migration=False,goal_complete=False,published=False)
assert result['total_assertions']==24648
(H/'recovery-departure-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
