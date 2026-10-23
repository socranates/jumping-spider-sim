"""Bind terminal-held outcomes to current source, inputs and native evidence."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('idle_runner',H/'run-recovery-idle.py');runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
receipt=json.loads((H/'recovery-idle-receipt.json').read_text(encoding='utf8'));output=(H/'recovery-idle-output.txt').read_bytes();bundle,_=runner.build()
assert receipt['source']==source and receipt['exit_code']==0 and receipt['output_sha256']==sha(output) and receipt['bundle_sha256']==sha(bundle.encode())
for name,digest in receipt['inputs'].items():
 path=ROOT/'roblox_port/src/Shared/Persistence'/name if name in ['Checkpoint.luau','SaveRest.luau'] else H/name
 assert sha(path.read_bytes())==digest,name
expected=dict(RECOVERY_MEALS=49,RECOVERY_LIFE=360,RECOVERY_DESTINATION=72,RECOVERY_PROGRESS=62,RECOVERY_PACKET=38,RECOVERY_PROPOSAL_STORE=79,RECOVERY_REST_WRITER=117,RECOVERY_PROGRESS_WRITER=182,RECOVERY_COMMIT_CONTROLLER=4836,RECOVERY_OFFER_READER=1711,RECOVERY_SESSION_REBIND=1373,RECOVERY_PIPELINE=12362,RECOVERY_DEPARTURE=3407,RECOVERY_IDLE=14134)
actual={name:(int(p),int(f)) for name,p,f in re.findall(r'^(RECOVERY_\w+) passed=(\d+) failed=(\d+)',output.decode(),re.M)}
assert actual=={name:(n,0) for name,n in expected.items()},actual
types=json.loads((H/'recovery-idle-types.json').read_text(encoding='utf8'));assert len(types['candidates'])==24 and len(types['steps'])==3
for name,digest in types['candidates'].items():assert sha((H/name).read_bytes())==digest,name
for step in types['steps']:assert step['exit_code']==0 and step['output_sha256']==sha((H/('recovery-idle-'+step['name']+'.txt')).read_bytes())
for flag in ['production_connected','real_datastore_verified','native_verified','destination_commit_authorized']:assert receipt[flag] is False
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
native=json.loads((H/'recovery-idle-native-receipt.json').read_text(encoding='utf8'))
manifest=json.loads((H/'prepared-recovery-idle-native-manifest.json').read_text(encoding='utf8'))
assert native['source']==source and native['assertions']==22 and native['script_fingerprints']==245 and native['creator_errors']==0
assert native['production_scripts_disabled'] and native['controlled_terminal_metadata'] and not native['real_datastore_verified']
assert native['events_sha256']==sha((H/'recovery-idle-native-events.txt').read_bytes()) and native['manifest_sha256']==sha((H/'prepared-recovery-idle-native-manifest.json').read_bytes())
assert manifest['candidates']==types['candidates']
probe=next(r for r in manifest['scripts'] if r['path']=='ServerScriptService.Server.RecoveryIdleProbe')
assert sha((H/'recovery-idle-native-probe.server.luau').read_bytes().replace(b'\r\n',b'\n'))==probe['sha256']
closed=json.loads((H/'recovery-idle-native-close.json').read_text(encoding='utf8'))
assert not closed['process_present'] and not closed['window_present'] and closed['original_package_sha256']==native['place_sha256']
result=dict(source=source,idle_assertions=14134,preceding_regression_assertions=24648,total_assertions=sum(expected.values()),current_runtime_bundle_verified=True,private_candidates=24,compile_entry_clean=True,strict_clean=True,terminal_held_lease_maintenance=True,shared_rolling_request_quota_verified=True,metadata_only_payload_and_archive_unchanged=True,ordinary_writes_remain_blocked=True,expired_or_foreign_lease_requires_fresh_session=True,explicit_retry_and_departure_handoffs_verified=True,lost_acknowledgement_uncached_probe_verified=True,slow_acknowledgement_regression_verified=True,native_memory_assertions=22,native_script_fingerprints=245,native_diagnostic_closed=True,actual_discovery_pipeline_native_verified=False,production_connected=False,real_datastore_verified=False,production_factory_and_tick_wired=False,safe_session_replacement_integrated=False,departure_and_terminal_hold_lifecycle_complete=False,schema3_entry_integrated=False,complete_migration=False,goal_complete=False,published=False)
assert result['total_assertions']==38782
(H/'recovery-idle-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
