"""Bind the narrow callback fix to full regression, counterexample and strict inputs."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,re,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
def read(name):return json.loads((H/name).read_text(encoding='utf8'))
def bound(prefix,exit_code):
 r=read(prefix+'-receipt.json');assert r['exit_code']==exit_code
 output=(H/(prefix+'-output.txt')).read_bytes();assert sha(output)==r['output_sha256']
 return r,output.decode('utf8')
full,output=bound('native-callback-full-1',0)
prior=(H/'service-qualified-2-output.txt').read_text(encoding='utf8')
summaries=lambda text:re.findall(r'^\w+ passed=\d+ failed=\d+[^\n]*',text,re.M)
assert summaries(output)==summaries(prior)
assert sum(int(x) for x in re.findall(r'^\w+ passed=(\d+) failed=0',output,re.M))==289497
fixed,focused=bound('native-callback-fixed-2',0)
assert not fixed['before_fix']
assert len(re.findall(r'^ACCOUNT_SERVICE_CASE\s+native-callback-',focused,re.M))==6
assert 'failed=0 groups=42' in focused
before,failing=bound('native-callback-before-fix-2',1)
assert before['before_fix'] and 'native callback New refused: New write scope ended' in failing
old=read('service-types-qualified-1-types.json');typed=read('native-callback-types-1-types.json')
changed=[key for key,value in typed['candidates'].items() if old['candidates'][key]!=value]
assert changed==['docs/request-admission/new-policy-profile.luau']
for key,value in typed['candidates'].items():assert sha((ROOT/key).read_bytes())==value
for step in typed['steps']:
 assert step['exit_code']==0 and sha((H/('native-callback-types-1-'+step['name']+'.txt')).read_bytes())==step['sha256']
for r in [full,fixed]:
 for key,value in r['inputs'].items():assert sha((ROOT/key.replace('\\','/')).read_bytes())==value,key
commit=subprocess.check_output(['git','log','-1','--format=%H','--',changed[0]],cwd=ROOT,text=True).strip()
for key in typed['candidates']:
 assert subprocess.check_output(['git','show',commit+':'+key],cwd=ROOT)==(ROOT/key).read_bytes()
result=dict(private_commit=commit,private_inputs_committed=True,full_failed=0,full_checks=289497,
 callback_cases=6,callback_service_checks=int(re.search(r'ACCOUNT_SERVICE passed=(\d+)',focused)[1]),
 qualified_types='native-callback-types-1-types.json',changed=changed,
 full_receipt_sha256=sha((H/'native-callback-full-1-receipt.json').read_bytes()),
 callback_receipt_sha256=sha((H/'native-callback-fixed-2-receipt.json').read_bytes()),
 counterexample_receipt_sha256=sha((H/'native-callback-before-fix-2-receipt.json').read_bytes()),
 online_verified=False,published=False)
path=H/'native-callback-qualification.json'
if a.check:assert read(path.name)==result
else:assert not path.exists();path.write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(result,indent=2))
