"""Join immutable native geometry, ordinary source hashes and local checks."""
from pathlib import Path
import ast,hashlib,json,subprocess
H=Path(__file__).resolve().parent;R=H.parents[1]
stage=Path('C:/Users/natha/claude-xfer/Windowsill-rig-hair-native1')
sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((stage/'manifest.json').read_text());n=json.loads((H/'native.json').read_text())
assert len(m['original_sources'])==273
for rel,digest in m['original_sources'].items():
 assert sha((R/'roblox_port/src'/rel).read_bytes().replace(b'\r\n',b'\n'))==digest,rel
reference=subprocess.check_output(['git','show','c5b61262:roblox_port/src/Shared/Rig/SpiderRig.luau'],cwd=R)
assert reference==(R/'roblox_port/tests/rig_hair_reference.luau').read_bytes()
changed=[]
for rel in m['original_sources']:
 before=subprocess.check_output(['git','show','c5b61262:roblox_port/src/'+rel],cwd=R)
 after=(R/'roblox_port/src'/rel).read_bytes()
 if before.replace(b'\r\n',b'\n')!=after.replace(b'\r\n',b'\n'):changed.append(rel)
assert changed==['Shared/Rig/SpiderRig.luau'],changed
assert sha(Path(m['place']).read_bytes())==m['place_sha256']==n['model_sha256']
assert n['passed']and n['source_guards']==2 and n['creator_errors']==0
assert json.loads((H/'compile.json').read_text())['passed']==273
strict=(H/'strict.txt').read_text().splitlines()
assert not [x for x in strict if x and not x.startswith('[INFO] Loading definitions file:')and not x.startswith('[WARN] client does not allow didChangeWatchedFiles')]
receipt=json.loads((R/'roblox_port/build-receipt.json').read_text())
assert receipt['evidence_id']=='032b5985ac17eeb2'and receipt['source_count']==273
record=dict(evidence_id=receipt['evidence_id'],source_commit='dd21210557990e0c0040b8028a714201de12e9d2',
 source_count=273,matched_original_source_hashes=273,changed_game_modules=changed,
 frozen_reference_sha256=sha(reference),native_checks=28,native_comparisons=n['result']['metrics']['parts'],
 compile_passed=273,strict_diagnostics=0,runner_passed=5,local_targeted_passed=11247,
 model_sha256=m['place_sha256'],native_passed=True,published=False,
 limits='Operation-saving and native fixture equivalence only; no paired FPS or broad audit completion.')
ci=H/'github-ci.json'
if ci.exists():
 data=json.loads(ci.read_text())
 assert data['run']['head_sha']==record['source_commit']and data['run']['conclusion']=='success'
 assert all(j['status']=='completed'and j['conclusion']=='success'for j in data['jobs'])
 steps={s['name']:s for j in data['jobs']for s in j['steps']}
 for name in ['Every module compiles','Strict types','All suites','Normal and self-test exports','Runner failure and cleanup regressions']:
  assert steps[name]['status']=='completed'and steps[name]['conclusion']=='success',name
 suites=[n for n in ast.walk(ast.parse((R/'roblox_port/tests/run.py').read_text()))if isinstance(n,ast.List)and len(n.elts)>70]
 assert len(suites)==1 and len(suites[0].elts)==80
 record.update(full_ci_run=data['run']['id'],full_ci_conclusion='success',full_ci_suites=80)
(H/'qualification.json').write_bytes((json.dumps(record,indent=2)+'\n').encode())
print(json.dumps(record))
