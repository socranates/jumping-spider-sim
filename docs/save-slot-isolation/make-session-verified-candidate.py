from pathlib import Path
import hashlib,json
HERE=Path(__file__).resolve().parent;sha=lambda b:hashlib.sha256(b).hexdigest()
prior=HERE/'session-budget-yield-candidate.luau';source=prior.read_text();assert sha(prior.read_bytes())=='20f59026a57a11bcdde02845963d51d6fb1657d58b72ff0510794d6ee35a32f1'
old='if self.rests[mode] ~= nil and (before[mode] == nil or (self.restReloading and not beforeLoaded[mode])) then'
assert source.count(old)==1
source=source.replace(old,'if self.restLoaded[mode] and self.rests[mode] ~= nil and (before[mode] == nil or (self.restReloading and not beforeLoaded[mode])) then')
candidate=HERE/'session-budget-verified-candidate.luau';candidate.write_text(source,encoding='utf8',newline='\n')
test=(HERE/'session-budget-candidate-tests.luau').read_text()
old='local function verifyBudget(ok,why) assert(ok,why);passedBudget+=1 end';assert test.count(old)==1
test=test.replace(old,'''local failedBudget=0
local function verifyBudget(ok,why)
 if not ok then failedBudget+=1;error(why,2) end
 passedBudget+=1
end''')
marker='print("SESSION_BUDGET_CANDIDATE passed="..passedBudget.." failed=0")';assert test.count(marker)==1
test=test.replace(marker,'verifyBudget(failedBudget==0,"callback failures were caught internally: "..failedBudget)\n'+marker)
(HERE/'session-budget-checked-tests.luau').write_text(test,encoding='utf8',newline='\n')
(HERE/'session-budget-verified-manifest.json').write_text(json.dumps(dict(base_source='f4053597d03b99a61cb97e2eef1ec64ed174f22a',superseded_candidate_sha256=sha(prior.read_bytes()),candidate_sha256=sha(candidate.read_bytes()),checked_test_sha256=sha(test.encode()),production_changed=False,native_verified=False,scope='Require actual restLoaded before callback; persistent failure count catches errors swallowed inside callback protection'),indent=2)+'\n',encoding='utf8',newline='\n')
print('Generated corrected private candidate and callback-aware acceptance harness')
