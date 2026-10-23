from pathlib import Path
import hashlib,importlib.util,json,re,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('progress_runner',H/'run-recovery-progress.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
receipt=json.loads((H/'recovery-progress-receipt.json').read_text());output=(H/'recovery-progress-output.txt').read_bytes();bundle,_=r.build()
assert receipt['source']==source and receipt['exit_code']==0 and receipt['output_sha256']==sha(output) and receipt['bundle_sha256']==sha(bundle.encode())
for name,digest in receipt['inputs'].items():
 path=ROOT/'roblox_port/src/Shared/Persistence'/name if name in ['Checkpoint.luau','SaveRest.luau'] else H/name
 assert sha(path.read_bytes())==digest
for line in ['RECOVERY_MEALS passed=49 failed=0 suspensions=7','RECOVERY_LIFE passed=360 failed=0 suspensions=130','RECOVERY_DESTINATION passed=72 failed=0 outside_flies=6 populated_regions=3','RECOVERY_PROGRESS passed=62 failed=0 suspensions=21']:assert line in output.decode()
types=json.loads((H/'recovery-progress-types.json').read_text());assert len(types['candidates'])==6 and len(types['steps'])==3
for name,digest in types['candidates'].items():assert sha((H/name).read_bytes())==digest
for step in types['steps']:assert step['exit_code']==0 and step['output_sha256']==sha((H/('recovery-progress-'+step['name']+'.txt')).read_bytes())
body=(H/'recovery-progress-prototype.luau').read_text().split('local FIELDS={',1)[1].split('}',1)[0]
assert set(json.loads((H/'recovery-progress-fields.json').read_text())['fields'])==set(re.findall(r'(\w+)=true',body))
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
result=dict(source=source,progress_assertions=62,destination_regression_assertions=72,life_regression_assertions=360,meal_regression_assertions=49,cooperative_suspensions=21,current_runtime_bundle_verified=True,strict_clean=True,schema1_preferences_mapped=True,notebook_and_rare_capacity_refusal_verified=True,rare_rewind_and_existing_visit_tested=True,global_and_destination_rare_identity_composed=True,production_connected=False,native_verified=False,real_datastore_verified=False,destination_commit_authorized=False,complete_migration=False,published=False)
(H/'recovery-progress-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
