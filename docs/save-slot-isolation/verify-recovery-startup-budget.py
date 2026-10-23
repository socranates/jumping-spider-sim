"""Verify the private bounded startup admission and preceding recovery cohort against exact input/output hashes."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
PREFIX='startup-attempt-2';TYPES='startup-types-2'
sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('current_runner',H/'run-recovery-startup-budget.py');runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
receipt=json.loads((H/(PREFIX+'-receipt.json')).read_text(encoding='utf8'));output=(H/(PREFIX+'-output.txt')).read_bytes();bundle,_=runner.build()
assert receipt['source']==source and receipt['exit_code']==0 and receipt['output_sha256']==sha(output) and receipt['bundle_sha256']==sha(bundle.encode())
for name,digest in receipt['inputs'].items():
 path=ROOT/'roblox_port/src/Shared/Persistence'/name if name in ['Checkpoint.luau','SaveRest.luau'] else H/name
 assert sha(path.read_bytes())==digest,name
expected=dict(RECOVERY_MEALS=49,RECOVERY_LIFE=360,RECOVERY_DESTINATION=72,RECOVERY_PROGRESS=62,RECOVERY_PACKET=38,RECOVERY_PROPOSAL_STORE=79,RECOVERY_REST_WRITER=117,RECOVERY_PROGRESS_WRITER=182,RECOVERY_COMMIT_CONTROLLER=4836,RECOVERY_OFFER_READER=1711,RECOVERY_SESSION_REBIND=1373,RECOVERY_PIPELINE=12362,RECOVERY_DEPARTURE=3407,RECOVERY_IDLE=14134,RECOVERY_RUNTIME=11963,RECOVERY_REST_FORMAT=82,RECOVERY_CURRENT_WRITER=1127,RECOVERY_ENTRY=10322,RECOVERY_SAVE_LOOP=22489,RECOVERY_REJOIN=42700,RECOVERY_STARTUP=1382)
actual={name:(int(p),int(f)) for name,p,f in re.findall(r'^(RECOVERY_\w+) passed=(\d+) failed=(\d+)',output.decode(),re.M)}
assert actual=={name:(n,0) for name,n in expected.items()},actual
types=json.loads((H/(TYPES+'-types.json')).read_text(encoding='utf8'));assert len(types['candidates'])==33 and len(types['steps'])==3
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
performance=re.findall(r'^RECOVERY_STARTUP case=(healthy|low|unknown) requests=(\d+) simulated_seconds=(\d+) startup_requests=(\d+)',output.decode(),re.M)
assert performance==[('healthy','19','17','19'),('low','20','72','0'),('unknown','20','72','0')],performance
native=json.loads((H/'startup-native-observer-receipt.json').read_text(encoding='utf8'));build=json.loads((H/'startup-native-observer-build.json').read_text(encoding='utf8'))
assert native['build_receipt_sha256']==sha((H/'startup-native-observer-build.json').read_bytes())
assert native['filtered_output_sha256']==sha((H/'startup-native-observer-output.txt').read_bytes())
probe=native['observation'];assert probe['pass'] and probe['assertions']==6 and probe['game_id']==probe['place_id']==0
assert probe['prototype_sha256']==build['prototype_raw_sha256']==sha((H/'recovery-startup-budget-prototype.luau').read_bytes())
assert native['native_observer_verified'] and native['studio_stopped_and_closed']
assert native['full_recovery_native_verified'] is False and native['real_datastore_verified'] is False
assert build['scripts']==4 and build['data_store_record_access'] is False and build['project_bound_to_experience'] is False
assert native['original_model_sha256']==build['model_sha256']
# Local binary paths are optional on another machine; retained evidence hashes remain portable.
if Path(build['path']).exists():assert sha(Path(build['path']).read_bytes())==build['model_sha256']
if Path(native['editor_copy_path']).exists():assert sha(Path(native['editor_copy_path']).read_bytes())==native['editor_copy_sha256']
result=dict(source=source,startup_assertions=1382,preceding_regression_assertions=127465,total_assertions=sum(expected.values()),private_candidates=33,compile_entry_clean=True,strict_clean=True,
 healthy_model_requests=19,healthy_simulated_seconds=17,low_or_unknown_model_requests=20,low_or_unknown_simulated_seconds=72,
 bounded_startup_session_requests=20,bounded_startup_shared_requests_per_minute=40,startup_deadline_seconds=45,
 gameplay_budget_per_minute=10,failed_startup_retains_ordinary_debt=True,full_raw_scheduler_history_retained=True,
 native_observer_verified=True,native_observer_assertions=6,native_observer_unbound_place=True,
 production_connected=False,production_saveservice_and_remote_menu_wired=False,startup_latency_release_qualified=False,
 full_recovery_native_verified=False,real_datastore_verified=False,complete_migration=False,goal_complete=False,published=False)
assert result['total_assertions']==128847
(H/'recovery-startup-budget-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
