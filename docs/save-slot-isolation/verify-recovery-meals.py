from pathlib import Path
import hashlib,importlib.util,json,re,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('meal_runner',H/'run-recovery-meals.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
for baseline in [False,True]:
 stem='recovery-meals-negative' if baseline else 'recovery-meals'
 receipt=json.loads((H/(stem+'-receipt.json')).read_text());output=(H/(stem+'-output.txt')).read_bytes();bundle,_=r.build(baseline)
 assert receipt['source']==source and receipt['exit_code']==int(baseline) and receipt['output_sha256']==sha(output) and receipt['bundle_sha256']==sha(bundle.encode())
 for name,digest in receipt['inputs'].items():assert sha((H/name).read_bytes())==digest
 assert ('portable validation unnecessarily copied reserve books' if baseline else 'RECOVERY_MEALS passed=49 failed=0 suspensions=7') in output.decode()
types=json.loads((H/'recovery-meals-types.json').read_text());assert len(types['candidates'])==3 and len(types['steps'])==3
for name,digest in types['candidates'].items():assert sha((H/name).read_bytes())==digest
for step in types['steps']:assert step['exit_code']==0 and step['output_sha256']==sha((H/('recovery-meals-'+step['name']+'.txt')).read_bytes())
policy=json.loads((H/'recovery-meals-fields.json').read_text());code=(H/'recovery-meals-prototype.luau').read_text()
for name in ['NEEDS','FEEDING']:
 body=code.split('local '+name+'={',1)[1].split('}',1)[0]
 assert set(policy['fields'][name.lower()])==set(re.findall(r'(\w+)=true',body))
assert policy['policy']=='unknown fields refuse'
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
result=dict(source=source,assertions=49,cooperative_suspensions=7,current_runtime_bundle_verified=True,strict_clean=True,recorded_test_garden_inspection=True,same_id_fresh_capture_tested=True,growth_counts_only_new_food=True,extra_ledger_copy_counterexample_reproduced=True,production_connected=False,native_verified=False,real_datastore_verified=False,complete_projection=False,destination_commit_authorized=False,published=False)
(H/'recovery-meals-verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
