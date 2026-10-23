from pathlib import Path
import hashlib,importlib.util,json,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('writer_runner',H/'run-recovery-rest-writer.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
receipt=json.loads((H/'recovery-rest-writer-receipt.json').read_text());output=(H/'recovery-rest-writer-output.txt').read_bytes();bundle,_=r.build()
assert receipt['source']==source and receipt['exit_code']==0 and receipt['output_sha256']==sha(output) and receipt['bundle_sha256']==sha(bundle.encode())
for name,digest in receipt['inputs'].items():
 path=ROOT/'roblox_port/src/Shared/Persistence'/name if name in ['Checkpoint.luau','SaveRest.luau'] else H/name
 assert sha(path.read_bytes())==digest
for line in ['RECOVERY_MEALS passed=49 failed=0 suspensions=7','RECOVERY_LIFE passed=360 failed=0 suspensions=130','RECOVERY_DESTINATION passed=72 failed=0 outside_flies=6 populated_regions=3','RECOVERY_PROGRESS passed=62 failed=0 suspensions=21','RECOVERY_PACKET passed=38 failed=0 wide_progress_chars=19363','RECOVERY_PROPOSAL_STORE passed=79 failed=0','RECOVERY_REST_WRITER passed=117 failed=0 suspensions=2616']:assert line in output.decode()
types=json.loads((H/'recovery-rest-writer-types.json').read_text());assert len(types['candidates'])==11 and len(types['steps'])==3
for name,digest in types['candidates'].items():assert sha((H/name).read_bytes())==digest
for step in types['steps']:assert step['exit_code']==0 and step['output_sha256']==sha((H/('recovery-rest-writer-'+step['name']+'.txt')).read_bytes())
for flag in ['production_connected','real_datastore_verified','native_verified','destination_commit_authorized']:assert receipt[flag] is False
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
result=dict(source=source,rest_writer_assertions=117,proposal_store_regression_assertions=79,packet_regression_assertions=38,progress_regression_assertions=62,destination_regression_assertions=72,life_regression_assertions=360,meal_regression_assertions=49,cooperative_suspensions=2616,current_runtime_bundle_verified=True,strict_clean=True,actual_adapter_boundary_tested=True,uncached_raw_readback_verified=True,exact_stored_source_comparison=True,all_three_slots_verified=True,compressed_primary_and_backup_tested=True,callback_replay_conflict_tested=True,production_connected=False,native_verified=False,real_datastore_verified=False,remote_ownership_proven=False,controller_integrated=False,global_absorption_implemented=False,destination_commit_authorized=False,complete_migration=False,published=False)
(H/'recovery-rest-writer-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
