"""Verify the private current-rest writer against exact input/output hashes."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
PREFIX='current-writer-attempt-1';TYPES='current-writer-types-1'
sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('current_runner',H/'run-recovery-current-writer.py');runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
receipt=json.loads((H/(PREFIX+'-receipt.json')).read_text(encoding='utf8'));output=(H/(PREFIX+'-output.txt')).read_bytes();bundle,_=runner.build()
assert receipt['source']==source and receipt['exit_code']==0 and receipt['output_sha256']==sha(output) and receipt['bundle_sha256']==sha(bundle.encode())
for name,digest in receipt['inputs'].items():
 path=ROOT/'roblox_port/src/Shared/Persistence'/name if name in ['Checkpoint.luau','SaveRest.luau'] else H/name
 assert sha(path.read_bytes())==digest,name
expected=dict(RECOVERY_MEALS=49,RECOVERY_LIFE=360,RECOVERY_DESTINATION=72,RECOVERY_PROGRESS=62,RECOVERY_PACKET=38,RECOVERY_PROPOSAL_STORE=79,RECOVERY_REST_WRITER=117,RECOVERY_PROGRESS_WRITER=182,RECOVERY_COMMIT_CONTROLLER=4836,RECOVERY_OFFER_READER=1711,RECOVERY_SESSION_REBIND=1373,RECOVERY_PIPELINE=12362,RECOVERY_DEPARTURE=3407,RECOVERY_IDLE=14134,RECOVERY_RUNTIME=11963,RECOVERY_REST_FORMAT=82,RECOVERY_CURRENT_WRITER=1127)
actual={name:(int(p),int(f)) for name,p,f in re.findall(r'^(RECOVERY_\w+) passed=(\d+) failed=(\d+)',output.decode(),re.M)}
assert actual=={name:(n,0) for name,n in expected.items()},actual
types=json.loads((H/(TYPES+'-types.json')).read_text(encoding='utf8'));assert len(types['candidates'])==28 and len(types['steps'])==3
for name,digest in types['candidates'].items():assert sha((H/name).read_bytes())==digest,name
for step in types['steps']:assert step['exit_code']==0 and step['output_sha256']==sha((H/(TYPES+'-'+step['name']+'.txt')).read_bytes())
assert 'ImportUnused:' not in (H/(TYPES+'-strict.txt')).read_text(encoding='utf8')
for flag in ['production_connected','real_datastore_verified','native_verified','destination_commit_authorized']:assert receipt[flag] is False
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
result=dict(source=source,writer_assertions=1127,preceding_regression_assertions=50827,total_assertions=sum(expected.values()),private_candidates=28,compile_entry_clean=True,strict_clean=True,
 actual_factory_discovery_recovery_fixture=True,readonly_entry_refuses_writer_capture=True,test_only_intent_grant_explicit=True,
 frozen_single_use_owned_preparation=True,actual_continue_credential_and_exact_rest_cas=True,immutable_proposal_and_archive_index_rechecked=True,
 metadata_only_fresh_owned_lease=True,durable_rare_progress_coverage_required=True,uncached_rest_readback_and_final_ownership_required=True,
 subsequent_continuation_and_exact_noop_backup_preservation=True,ambiguous_write_and_read_failures_verified=True,
 changed_scope_deadline_quota_and_cap_checks=True,yielding_close_fences_verified=True,post_write_takeover_suppresses_receipt_without_rollback=True,
 production_connected=False,schema3_authenticated_writer_implemented_privately=True,schema3_authenticated_writer_integrated=False,
 schema3_gameplay_entry_integrated=False,production_saveservice_and_remote_menu_wired=False,native_verified=False,real_datastore_verified=False,
 complete_migration=False,goal_complete=False,published=False)
assert result['total_assertions']==51954
(H/'recovery-current-writer-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
