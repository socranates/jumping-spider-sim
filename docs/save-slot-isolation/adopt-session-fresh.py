"""Adopt only the exact private/native-verified modules and the adapter regression."""
from pathlib import Path
import hashlib,json,subprocess
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
v=json.loads((HERE/'session-cache-verification.json').read_text());assert v['native_assertions']==111 and v['strict_clean']
targets={'roblox_port/src/Shared/Persistence/SaveSession.luau':'session-fresh-candidate.luau','roblox_port/src/Server/DataStoreBackend.luau':'fresh-read-backend-candidate.luau'}
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
for target,name in targets.items():
 original=subprocess.check_output(['git','show',v['base_source']+':'+target],cwd=ROOT)
 assert (ROOT/target).read_bytes()==original and sha((HERE/name).read_bytes())==v['candidates'][name]
state=ROOT/'roblox_port/tests/state.luau';text=state.read_text(encoding='utf8')
test=(HERE/'session-adapter-tests.luau').read_text(encoding='utf8')
test=test.replace('local checks=0\nlocal function check(ok,why) assert(ok,why);checks+=1 end\n','')
test=test.replace('print("SESSION_ADAPTER passed="..checks.." failed=0")\n','')
block='case("fresh rest observations use uncached adapter reads before granting write authority",function()\nlocal Backend=DataStoreBackend\n'+test+'end)\n\n'
marker='print(`STATE passed={passed} failed={failed}`)';assert text.count(marker)==1
for target,name in targets.items():(ROOT/target).write_bytes((HERE/name).read_bytes())
state.write_text(text.replace(marker,block+marker),encoding='utf8',newline='\n')
receipt=dict(base_source=v['base_source'],adopted={target:sha((ROOT/target).read_bytes()) for target in targets},regression_file='roblox_port/tests/state.luau',regression_sha256=sha(state.read_bytes()),added_assertions=111,full_gates='pending',published=False,progress_import_implemented=False)
(HERE/'session-fresh-adoption.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(receipt,indent=2))
