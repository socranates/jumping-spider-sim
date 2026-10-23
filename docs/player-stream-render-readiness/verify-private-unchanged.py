"""Reuse component evidence only when the whole executable bundle and inputs are identical."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1];OLD=ROOT/'docs/save-slot-isolation'
sha=lambda b:hashlib.sha256(b).hexdigest()
receipt=json.loads((OLD/'capability-attempt-2-receipt.json').read_text(encoding='utf8'))
spec=importlib.util.spec_from_file_location('recovery_cohort',OLD/'run-recovery-service-owner.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
bundle,inputs=m.build()
assert receipt['exit_code']==0 and receipt['focused'] is False
assert sha(bundle.encode())==receipt['bundle_sha256'],'Recovery executable changed; rerun it rather than carrying evidence forward'
assert {p.name:sha(p.read_bytes()) for p in inputs}==receipt['inputs']
output=(OLD/'capability-attempt-2-output.txt').read_bytes();assert sha(output)==receipt['output_sha256']
rows=re.findall(r'^(RECOVERY_\w+) passed=(\d+) failed=(\d+)',output.decode(),re.M)
assert len(rows)==25 and sum(int(p) for _,p,_ in rows)==187257 and all(int(f)==0 for _,_,f in rows)
context=json.loads((H/'private-type-inputs.json').read_text(encoding='utf8'))
types=json.loads((ROOT/context['private_types']).read_text(encoding='utf8'));assert len(types['candidates'])==34
for name,digest in types['candidates'].items():assert sha((OLD/name).read_bytes())==digest
prefix=Path(context['private_types']).name.removesuffix('-types.json')
for step in types['steps']:
 assert step['exit_code']==0 and step['output_sha256']==sha((OLD/(prefix+'-'+step['name']+'.txt')).read_bytes())
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
assert context['source']==source
for name,digest in context['production_inputs'].items():assert sha((ROOT/name).read_bytes().replace(b'\r\n',b'\n'))==digest
result=dict(current_production_source=source,component_execution_source=receipt['source'],executable_bundle_unchanged=True,all_explicit_inputs_unchanged=True,private_component_checks=187257,private_component_failures=0,current_overlay_candidates=34,current_overlay_compile_and_strict_clean=True,component_rerun=False,whole_game_private_recovery_proof=False,native_recovery_verified=False,real_datastore_verified=False,published=False)
(H/'private-unchanged.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
