from pathlib import Path
import hashlib,json,subprocess
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
v=json.loads((HERE/'session-verified-native-qualification.json').read_text());g=json.loads((ROOT/'docs/session-freshness-gates/verification.json').read_text())
assert v['qualified_for_adoption'] and v['native_assertions']==127 and v['callback_aware_controls']==83
assert g['source']==v['base_source'] and g['current_workspace_inputs_verified'] and g['windows_passed']==g['linux_passed']==468225
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
target=ROOT/'roblox_port/src/Shared/Persistence/SaveSession.luau';candidate=HERE/'session-budget-verified-candidate.luau'
assert target.read_bytes()==subprocess.check_output(['git','show',v['base_source']+':roblox_port/src/Shared/Persistence/SaveSession.luau'],cwd=ROOT)
assert sha(candidate.read_bytes())==v['candidate_sha256']
state=ROOT/'roblox_port/tests/state.luau';text=state.read_text();marker='print(`STATE passed={passed} failed={failed}`)';assert text.count(marker)==1
blocks=[]
for filename,title,counter,verify in [('session-budget-checked-tests.luau','periodic recovery delivers only freshly loaded slots within request bounds','passedBudget','verifyBudget'),('session-budget-yield-tests.luau','suspended recovery is fenced after close demotion and superseding load','checksYield','verifyYield')]:
 test=(HERE/filename).read_text()
 if verify=='verifyBudget':
  old='local function verifyBudget(ok,why)\n';assert test.count(old)==1;test=test.replace(old,old+' check(ok,why)\n')
 else:
  old='local function verifyYield(ok,why) assert(ok,why);checksYield+=1 end';assert test.count(old)==1;test=test.replace(old,'local function verifyYield(ok,why) check(ok,why);assert(ok,why);checksYield+=1 end')
 test='\n'.join(line for line in test.splitlines() if not ('print(' in line and counter in line))+'\n'
 blocks.append('case('+json.dumps(title)+',function()\n'+test+'end)\n\n')
target.write_bytes(candidate.read_bytes());state.write_text(text.replace(marker,''.join(blocks)+marker),encoding='utf8',newline='\n')
r=dict(base_source=v['base_source'],session_sha256=sha(target.read_bytes()),regression_sha256=sha(state.read_bytes()),added_assertions=127,expected_state_assertions=1251,expected_full_assertions=468352,native_assertions=127,full_gates='pending',published=False,progress_import_implemented=False)
(HERE/'session-verified-adoption.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
