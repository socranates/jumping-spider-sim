from pathlib import Path
import hashlib,importlib.util,json,re,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('life_runner',H/'run-recovery-life.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
for baseline in [False,True]:
 stem='before-freeze-recovery-life' if baseline else 'recovery-life'
 receipt=json.loads((H/(stem+'-receipt.json')).read_text());output=(H/(stem+'-output.txt')).read_bytes();bundle,_=r.build(baseline)
 assert receipt['source']==source and receipt['exit_code']==int(baseline) and receipt['output_sha256']==sha(output) and receipt['bundle_sha256']==sha(bundle.encode())
 for name,digest in receipt['inputs'].items():
  if baseline and name=='recovery-life-prototype.luau':name='before-freeze-recovery-life-prototype.luau'
  if baseline and name=='recovery-life-tests.luau':name='before-origin-recovery-life-tests.luau'
  assert sha((H/name).read_bytes())==digest
 assert ('table is already frozen' if baseline else 'RECOVERY_LIFE passed=360 failed=0 suspensions=130') in output.decode()
 if not baseline:assert 'RECOVERY_MEALS passed=49 failed=0 suspensions=7' in output.decode()
types=json.loads((H/'recovery-life-types.json').read_text());assert len(types['candidates'])==4 and len(types['steps'])==3
for name,digest in types['candidates'].items():assert sha((H/name).read_bytes())==digest
for step in types['steps']:assert step['exit_code']==0 and step['output_sha256']==sha((H/('recovery-life-'+step['name']+'.txt')).read_bytes())
fields=dict(re.findall(r'(\w+)="(preserve|reset|rebind|derive|history|refuse)"',(H/'recovery-life-prototype.luau').read_text().split('local FIELDS={',1)[1].split('}',1)[0]))
assert json.loads((H/'recovery-life-fields.json').read_text())['fields']==fields
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
result=dict(source=source,life_assertions=360,meal_regression_assertions=49,cooperative_suspensions=130,current_runtime_bundle_verified=True,strict_clean=True,modes=3,mating_stages=6,moult_continuation_tested=True,generation_grace_preserved=True,rare_identity_data_preserved=True,old_actors_and_skins_history_only=True,frozen_subcapsule_failure_reproduced=True,production_connected=False,native_verified=False,real_datastore_verified=False,complete_projection=False,destination_commit_authorized=False,published=False)
(H/'recovery-life-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
