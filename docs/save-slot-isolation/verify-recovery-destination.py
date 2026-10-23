from pathlib import Path
import hashlib,importlib.util,json,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('destination_runner',H/'run-recovery-destination.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
receipt=json.loads((H/'recovery-destination-receipt.json').read_text());output=(H/'recovery-destination-output.txt').read_bytes();bundle,_=r.build()
assert receipt['source']==source and receipt['exit_code']==0 and receipt['output_sha256']==sha(output) and receipt['bundle_sha256']==sha(bundle.encode())
for name,digest in receipt['inputs'].items():
 path=ROOT/'roblox_port/src/Shared/Persistence'/name if name in ['Checkpoint.luau','SaveRest.luau'] else H/name
 assert sha(path.read_bytes())==digest
for line in ['RECOVERY_MEALS passed=49 failed=0 suspensions=7','RECOVERY_LIFE passed=360 failed=0 suspensions=130','RECOVERY_DESTINATION passed=72 failed=0 outside_flies=6 populated_regions=3']:assert line in output.decode()
negative=json.loads((H/'recovery-destination-ended-baseline-receipt.json').read_text());negativeOutput=(H/'recovery-destination-ended-baseline-output.txt').read_bytes();baseline,_=r.build(True)
assert negative['source']==source and negative['exit_code']==1 and negative['output_sha256']==sha(negativeOutput) and negative['bundle_sha256']==sha(baseline.encode())
for name,digest in negative['inputs'].items():
 path=ROOT/'roblox_port/src/Shared/Persistence'/name if name in ['Checkpoint.luau','SaveRest.luau'] else H/name
 assert sha(path.read_bytes())==digest
assert 'ended life was accepted as an ordinary rest' in negativeOutput.decode()
types=json.loads((H/'recovery-destination-types.json').read_text());assert len(types['candidates'])==5 and len(types['steps'])==3
for name,digest in types['candidates'].items():assert sha((H/name).read_bytes())==digest
for step in types['steps']:assert step['exit_code']==0 and step['output_sha256']==sha((H/('recovery-destination-'+step['name']+'.txt')).read_bytes())
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
result=dict(source=source,destination_assertions=72,life_regression_assertions=360,meal_regression_assertions=49,current_runtime_bundle_verified=True,strict_clean=True,production_validator_bodies_exercised=True,authored_preserve_fixture_regions=4,populated_outside_regions=3,outside_flies=6,late_region_feeding_identity_verified=True,checkpoint_restore_recapture_verified=True,memory_envelope_roundtrip_verified=True,ordinary_cross_world_continue_still_refused=True,scene_and_hatching_entry_explicit=True,ended_life_refused=True,ended_life_counterexample_reproduced=True,production_connected=False,native_verified=False,real_datastore_verified=False,global_progress_projected=False,scene_resume_integrated=False,destination_commit_authorized=False,complete_migration=False,published=False)
(H/'recovery-destination-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
