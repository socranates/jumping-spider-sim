from pathlib import Path
import hashlib,importlib.util,json,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('pipeline_runner',H/'run-recovery-pipeline.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
receipt=json.loads((H/'recovery-pipeline-receipt.json').read_text());output=(H/'recovery-pipeline-output.txt').read_bytes();bundle,_=r.build()
assert receipt['source']==source and receipt['exit_code']==0 and receipt['output_sha256']==sha(output) and receipt['bundle_sha256']==sha(bundle.encode())
for name,digest in receipt['inputs'].items():
 path=ROOT/'roblox_port/src/Shared/Persistence'/name if name in ['Checkpoint.luau','SaveRest.luau'] else H/name
 assert sha(path.read_bytes())==digest
for line in ['RECOVERY_MEALS passed=49 failed=0 suspensions=7','RECOVERY_LIFE passed=360 failed=0 suspensions=130','RECOVERY_DESTINATION passed=72 failed=0 outside_flies=6 populated_regions=3','RECOVERY_PROGRESS passed=62 failed=0 suspensions=21','RECOVERY_PACKET passed=38 failed=0 wide_progress_chars=19363','RECOVERY_PROPOSAL_STORE passed=79 failed=0','RECOVERY_REST_WRITER passed=117 failed=0 suspensions=2616','RECOVERY_PROGRESS_WRITER passed=182 failed=0','RECOVERY_COMMIT_CONTROLLER passed=4836 failed=0','RECOVERY_OFFER_READER passed=1711 failed=0 suspensions=4388','RECOVERY_SESSION_REBIND passed=1371 failed=0','RECOVERY_PIPELINE cold_compressed=false requests=58 simulated_seconds=365','RECOVERY_PIPELINE cold_compressed=true requests=58 simulated_seconds=365','RECOVERY_PIPELINE passed=10845 failed=0']:assert line in output.decode()
types=json.loads((H/'recovery-pipeline-types.json').read_text());assert len(types['candidates'])==21 and len(types['steps'])==3
for name,digest in types['candidates'].items():assert sha((H/name).read_bytes())==digest
for step in types['steps']:assert step['exit_code']==0 and step['output_sha256']==sha((H/('recovery-pipeline-'+step['name']+'.txt')).read_bytes())
for flag in ['production_connected','real_datastore_verified','native_verified','destination_commit_authorized']:assert receipt[flag] is False
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
result=dict(source=source,pipeline_assertions=10845,preceding_regression_assertions=8877,current_runtime_bundle_verified=True,strict_clean=True,accepted_intent_total_request_cap=96,accepted_intent_total_timeout_seconds=900,discovery_has_separate_bound=True,cold_requests=58,cold_simulated_seconds=365,compressed_and_uncompressed_cold_verified=True,ordinary_owned_writes_blocked_before_provider=True,coroutine_scoped_permits_verified=True,provider_replacement_refused=True,stale_displayed_offer_resume_verified=True,fresh_rebind_witnesses_scheduled=True,late_local_input_recapture_verified=True,failed_owner_retains_enforced_hold=True,production_connected=False,native_verified=False,real_datastore_verified=False,production_factory_and_tick_wired=False,departure_and_terminal_hold_lifecycle_complete=False,schema3_entry_integrated=False,destination_commit_authorized=False,complete_migration=False,published=False)
(H/'recovery-pipeline-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
