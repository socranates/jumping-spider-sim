from pathlib import Path
import hashlib,importlib.util,json,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('proposal_runner',H/'run-recovery-proposal-store.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
receipt=json.loads((H/'recovery-proposal-store-receipt.json').read_text());output=(H/'recovery-proposal-store-output.txt').read_bytes();bundle,_=r.build()
assert receipt['source']==source and receipt['exit_code']==0 and receipt['output_sha256']==sha(output) and receipt['bundle_sha256']==sha(bundle.encode())
for name,digest in receipt['inputs'].items():
 path=ROOT/'roblox_port/src/Shared/Persistence'/name if name in ['Checkpoint.luau','SaveRest.luau'] else H/name
 assert sha(path.read_bytes())==digest
for line in ['RECOVERY_MEALS passed=49 failed=0 suspensions=7','RECOVERY_LIFE passed=360 failed=0 suspensions=130','RECOVERY_DESTINATION passed=72 failed=0 outside_flies=6 populated_regions=3','RECOVERY_PROGRESS passed=62 failed=0 suspensions=21','RECOVERY_PACKET passed=38 failed=0 wide_progress_chars=19363','RECOVERY_PROPOSAL_STORE passed=79 failed=0']:assert line in output.decode()
types=json.loads((H/'recovery-proposal-store-types.json').read_text());assert len(types['candidates'])==9 and len(types['steps'])==3
for name,digest in types['candidates'].items():assert sha((H/name).read_bytes())==digest
for step in types['steps']:assert step['exit_code']==0 and step['output_sha256']==sha((H/('recovery-proposal-store-'+step['name']+'.txt')).read_bytes())
for flag in ['production_connected','real_datastore_verified','native_verified','destination_commit_authorized']:assert receipt[flag] is False
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
baseline=json.loads((H/'before-retry-recovery-proposal-store-receipt.json').read_text());old_output=(H/'before-retry-recovery-proposal-store-output.txt').read_bytes()
old_module=H/'before-retry-recovery-proposal-store-prototype.luau';old_test=H/'before-retry-recovery-proposal-store-tests.luau'
old_bundle,_=r.build(old_module,old_test)
legacy_progress=H/'before-absorption-recovery-progress-prototype.luau'
current_progress=H/'recovery-progress-prototype.luau'
if baseline['inputs']['recovery-progress-prototype.luau']!=sha(current_progress.read_bytes()):
 assert sha(legacy_progress.read_bytes())==baseline['inputs']['recovery-progress-prototype.luau']
 runner_spec=importlib.util.spec_from_file_location('bundle_tools',ROOT/'roblox_port/tests/run.py');bundle_tools=importlib.util.module_from_spec(runner_spec);runner_spec.loader.exec_module(bundle_tools)
 def transformed(path):return bundle_tools.requires(bundle_tools.strict(path.read_text().replace('require(script.Parent.RecoveryLifePrototype)','__lifePrototype')))
 current_code=transformed(current_progress);assert old_bundle.count(current_code)==1
 old_bundle=old_bundle.replace(current_code,transformed(legacy_progress),1)
assert baseline['source']==source and baseline['exit_code']!=0 and baseline['output_sha256']==sha(old_output) and baseline['bundle_sha256']==sha(old_bundle.encode())
for name,digest in baseline['inputs'].items():
 path=old_module if name=='recovery-proposal-store-prototype.luau' else old_test if name=='recovery-proposal-store-tests.luau' else legacy_progress if name=='recovery-progress-prototype.luau' and digest!=sha(current_progress.read_bytes()) else ROOT/'roblox_port/src/Shared/Persistence'/name if name in ['Checkpoint.luau','SaveRest.luau'] else H/name
 assert sha(path.read_bytes())==digest
assert b'retry did not publish' in old_output
result=dict(source=source,proposal_store_assertions=79,packet_regression_assertions=38,progress_regression_assertions=62,destination_regression_assertions=72,life_regression_assertions=360,meal_regression_assertions=49,current_runtime_bundle_verified=True,strict_clean=True,immutable_restart_bytes_verified=True,competing_proposals_verified=True,lost_acknowledgements_verified=True,failed_retry_counterexample_reproduced=True,production_connected=False,native_verified=False,real_datastore_verified=False,controller_integrated=False,destination_commit_authorized=False,complete_migration=False,published=False)
(H/'recovery-proposal-store-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
