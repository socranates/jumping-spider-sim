"""Verify the private returning schema3 session path against exact input/output hashes."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
PREFIX='rejoin-attempt-5';TYPES='rejoin-types-4'
sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('current_runner',H/'run-recovery-rejoin.py');runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
receipt=json.loads((H/(PREFIX+'-receipt.json')).read_text(encoding='utf8'));output=(H/(PREFIX+'-output.txt')).read_bytes();bundle,_=runner.build()
assert receipt['source']==source and receipt['exit_code']==0 and receipt['output_sha256']==sha(output) and receipt['bundle_sha256']==sha(bundle.encode())
for name,digest in receipt['inputs'].items():
 path=ROOT/'roblox_port/src/Shared/Persistence'/name if name in ['Checkpoint.luau','SaveRest.luau'] else H/name
 assert sha(path.read_bytes())==digest,name
expected=dict(RECOVERY_MEALS=49,RECOVERY_LIFE=360,RECOVERY_DESTINATION=72,RECOVERY_PROGRESS=62,RECOVERY_PACKET=38,RECOVERY_PROPOSAL_STORE=79,RECOVERY_REST_WRITER=117,RECOVERY_PROGRESS_WRITER=182,RECOVERY_COMMIT_CONTROLLER=4836,RECOVERY_OFFER_READER=1711,RECOVERY_SESSION_REBIND=1373,RECOVERY_PIPELINE=12362,RECOVERY_DEPARTURE=3407,RECOVERY_IDLE=14134,RECOVERY_RUNTIME=11963,RECOVERY_REST_FORMAT=82,RECOVERY_CURRENT_WRITER=1127,RECOVERY_ENTRY=10322,RECOVERY_SAVE_LOOP=22489,RECOVERY_REJOIN=42700)
actual={name:(int(p),int(f)) for name,p,f in re.findall(r'^(RECOVERY_\w+) passed=(\d+) failed=(\d+)',output.decode(),re.M)}
assert actual=={name:(n,0) for name,n in expected.items()},actual
types=json.loads((H/(TYPES+'-types.json')).read_text(encoding='utf8'));assert len(types['candidates'])==32 and len(types['steps'])==3
for name,digest in types['candidates'].items():assert sha((H/name).read_bytes())==digest,name
for step in types['steps']:assert step['exit_code']==0 and step['output_sha256']==sha((H/(TYPES+'-'+step['name']+'.txt')).read_bytes())
assert 'ImportUnused:' not in (H/(TYPES+'-strict.txt')).read_text(encoding='utf8')
for flag in ['production_connected','real_datastore_verified','native_verified','destination_commit_authorized']:assert receipt[flag] is False
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
before=(H/'rejoin-attempt-2-output.txt').read_text(encoding='utf8')
baseReceipt=json.loads((H/'rejoin-attempt-2-receipt.json').read_text(encoding='utf8'))
assert baseReceipt['exit_code']==0 and baseReceipt['output_sha256']==sha((H/'rejoin-attempt-2-output.txt').read_bytes())
pattern=r'^RECOVERY_REJOIN visit=(main|free|easy) compressed=(false|true) requests=(\d+) simulated_seconds=(\d+)'
baseline=re.findall(pattern,before,re.M);current=re.findall(pattern,output.decode(),re.M)
assert len(baseline)==6 and len(current)==6
assert all((int(n),int(t))==(25,126) for mode,packed,n,t in baseline)
assert all((int(n),int(t))==(20,72) for mode,packed,n,t in current)
assert 'LocalShadow:' not in (H/(TYPES+'-strict.txt')).read_text(encoding='utf8')
result=dict(source=source,rejoin_assertions=42700,preceding_regression_assertions=84765,total_assertions=sum(expected.values()),private_candidates=32,compile_entry_clean=True,strict_clean=True,
 actual_fresh_factory_load_discovery_entry_save_departure_composed=True,all_three_slots_and_plain_packed_current_rest_verified=True,
 three_separate_visits_preserve_latest_generation_elapsed_rare_and_choices=True,no_original_import_pipeline_or_non_progress_updates_on_rejoin=True,
 original_archive_and_proposal_unchanged=True,initial_packet_and_current_mating_hatching_rejoin_verified=True,
 current_primary_with_backup_origin_verified=True,retired_corrupt_missing_provenance_and_explicit_backup_refused=True,
 changed_selected_identity_and_replaced_choice_refused=True,unsupported_current_envelope_fields_refused_in_reader_and_writer=True,
 archive_cache_bound_to_actual_session_selection=True,full_archive_fetched_once_and_complete_index_rechecked=True,
 baseline_model_requests=25,current_model_requests=20,baseline_simulated_seconds=126,current_simulated_seconds=72,
 production_connected=False,continued_schema3_rejoin_integrated_privately=True,production_saveservice_and_remote_menu_wired=False,
 startup_latency_release_qualified=False,native_verified=False,real_datastore_verified=False,complete_migration=False,goal_complete=False,published=False)
assert result['total_assertions']==127465
(H/'recovery-rejoin-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
