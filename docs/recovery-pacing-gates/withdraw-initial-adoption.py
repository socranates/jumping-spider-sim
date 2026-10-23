from pathlib import Path
import hashlib,json,subprocess
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
m=json.loads((HERE/'initial-adoption.json').read_text());sha=lambda b:hashlib.sha256(b).hexdigest()
targets={'roblox_port/src/Shared/Persistence/SaveSession.luau':m['session_sha256'],'roblox_port/tests/state.luau':m['regression_sha256']}
for path,digest in targets.items():assert sha((ROOT/path).read_bytes())==digest,'Unexpected intervening change: '+path
for path in targets:(ROOT/path).write_bytes(subprocess.check_output(['git','show',m['base_source']+':'+path],cwd=ROOT))
r=dict(base_source=m['base_source'],withdrawn_session_sha256=m['session_sha256'],reason='Regular suite exposed unverified retained-slot callbacks; candidate and smaller callback harness need correction',production_changes_committed=False,published=False,restored={path:sha((ROOT/path).read_bytes()) for path in targets})
(HERE/'initial-adoption-withdrawn.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(r,indent=2))
