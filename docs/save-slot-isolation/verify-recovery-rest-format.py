"""Bind current schema3 continuation format to its complete regression cohort."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1];PREFIX='rest-format-attempt-4';sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('format_runner',H/'run-recovery-rest-format.py');runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
receipt=json.loads((H/(PREFIX+'-receipt.json')).read_text(encoding='utf8'));output=(H/(PREFIX+'-output.txt')).read_bytes();bundle,_=runner.build()
assert receipt['source']==source and receipt['exit_code']==0 and receipt['output_sha256']==sha(output) and receipt['bundle_sha256']==sha(bundle.encode())
for name,digest in receipt['inputs'].items():
 path=ROOT/'roblox_port/src/Shared/Persistence'/name if name in ['Checkpoint.luau','SaveRest.luau'] else H/name
 assert sha(path.read_bytes())==digest,name
expected=dict(RECOVERY_MEALS=49,RECOVERY_LIFE=360,RECOVERY_DESTINATION=72,RECOVERY_PROGRESS=62,RECOVERY_PACKET=38,RECOVERY_PROPOSAL_STORE=79,RECOVERY_REST_WRITER=117,RECOVERY_PROGRESS_WRITER=182,RECOVERY_COMMIT_CONTROLLER=4836,RECOVERY_OFFER_READER=1711,RECOVERY_SESSION_REBIND=1373,RECOVERY_PIPELINE=12362,RECOVERY_DEPARTURE=3407,RECOVERY_IDLE=14134,RECOVERY_RUNTIME=11963,RECOVERY_REST_FORMAT=82)
actual={name:(int(p),int(f)) for name,p,f in re.findall(r'^(RECOVERY_\w+) passed=(\d+) failed=(\d+)',output.decode(),re.M)}
assert actual=={name:(n,0) for name,n in expected.items()},actual
assert 'RECOVERY_REST_FORMAT passed=82 failed=0 suspensions=1107' in output.decode()
types=json.loads((H/'recovery-rest-format-types.json').read_text(encoding='utf8'));assert len(types['candidates'])==27 and len(types['steps'])==3
for name,digest in types['candidates'].items():assert sha((H/name).read_bytes())==digest,name
for step in types['steps']:assert step['exit_code']==0 and step['output_sha256']==sha((H/('recovery-rest-format-'+step['name']+'.txt')).read_bytes())
assert 'ImportUnused:' not in (H/'recovery-rest-format-strict.txt').read_text(encoding='utf8')
for flag in ['production_connected','real_datastore_verified','native_verified','destination_commit_authorized']:assert receipt[flag] is False
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
result=dict(source=source,format_assertions=82,preceding_regression_assertions=50745,total_assertions=sum(expected.values()),cooperative_suspensions=1107,current_runtime_bundle_verified=True,private_candidates=27,compile_entry_clean=True,strict_clean=True,initial_packet_and_ordinary_schema2_compatibility_verified=True,continued_active_and_retired_schema3_preparation=True,all_three_slots_verified=True,actual_checkpoint_restore_capture_and_five_save_round_trips=True,single_backup_and_unchanged_provenance_verified=True,current_mating_hatching_and_generation_progress_verified=True,ended_checkpoint_and_retired_revival_refused=True,old_reader_future_schema_refusal_verified=True,format_validation_grants_authority=False,production_connected=False,schema3_format_implemented_privately=True,schema3_authenticated_writer_integrated=False,schema3_gameplay_entry_integrated=False,production_saveservice_and_remote_menu_wired=False,native_verified=False,real_datastore_verified=False,complete_migration=False,goal_complete=False,published=False)
assert result['total_assertions']==50827
(H/'recovery-rest-format-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
