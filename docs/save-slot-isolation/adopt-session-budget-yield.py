"""Adopt exact tested bytes only after the current freshness cohort fully closes."""
from pathlib import Path
import hashlib,json,subprocess
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
v=json.loads((HERE/'session-budget-yield-verification.json').read_text())
gate=ROOT/'docs/session-freshness-gates/verification.json'
assert gate.exists(),'Wait for the current Windows95443 cohort and root verification; do not overlap local full runs'
g=json.loads(gate.read_text());assert g['source']==v['base_source'] and g['current_workspace_inputs_verified'] and g['windows_passed']==g['linux_passed']==468225
assert v['native_assertions']==126 and v['strict_clean']
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
target=ROOT/'roblox_port/src/Shared/Persistence/SaveSession.luau';candidate=HERE/'session-budget-yield-candidate.luau'
original=subprocess.check_output(['git','show',v['base_source']+':roblox_port/src/Shared/Persistence/SaveSession.luau'],cwd=ROOT)
assert target.read_bytes()==original and sha(candidate.read_bytes())==v['candidate_sha256']
state=ROOT/'roblox_port/tests/state.luau';text=state.read_text(encoding='utf8');marker='print(`STATE passed={passed} failed={failed}`)';assert text.count(marker)==1
blocks=[]
for filename,name,counter,verify in [('session-budget-candidate-tests.luau','periodic recovery obeys request bounds and promptly delivers verified state','passedBudget','verifyBudget'),('session-budget-yield-tests.luau','suspended recovery cannot outlive departure demotion or a newer load','checksYield','verifyYield')]:
 test=(HERE/filename).read_text(encoding='utf8')
 test=test.replace('local '+counter+'=0\n','')
 old='local function '+verify+'(ok,why) assert(ok,why);'+counter+'+=1 end'
 assert test.count(old)==1
 test=test.replace(old,'local function '+verify+'(ok,why) check(ok,why);assert(ok,why) end')
 test='\n'.join(line for line in test.splitlines() if not ('print(' in line and counter in line))+'\n'
 blocks.append('case('+json.dumps(name)+',function()\n'+test+'end)\n\n')
target.write_bytes(candidate.read_bytes());state.write_text(text.replace(marker,''.join(blocks)+marker),encoding='utf8',newline='\n')
r=dict(base_source=v['base_source'],session_sha256=sha(target.read_bytes()),regression_sha256=sha(state.read_bytes()),added_assertions=126,expected_state_assertions=1250,expected_full_assertions=468351,native_assertions=126,full_gates='pending',published=False,progress_import_implemented=False)
(HERE/'session-budget-yield-adoption.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
