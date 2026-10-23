"""Bind current qualification, historical input snapshots and the fixed race."""
from pathlib import Path
import hashlib,importlib.util,json,re,subprocess
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
spec=importlib.util.spec_from_file_location('admission_runner',H/'run.py');runner=importlib.util.module_from_spec(spec);spec.loader.exec_module(runner)
def check(prefix,admission='admission.luau',tests='tests.luau',aliases=False):
 r=json.loads((H/(prefix+'-receipt.json')).read_text());bundle,inputs,_=runner.build(H/admission,H/tests)
 if aliases:
  inputs={('docs/request-admission/admission.luau' if aliases is True and k=='docs/request-admission/'+admission else 'docs/request-admission/tests.luau' if k=='docs/request-admission/'+tests else k):v for k,v in inputs.items()}
 assert r['inputs']==inputs and r['bundle_sha256']==sha(bundle.encode()),prefix
 raw=(H/(prefix+'-output.txt')).read_bytes();assert r['output_sha256']==sha(raw),prefix
 for step in r['steps']:
  assert step['exit_code']==0 and sha((H/(prefix+'-'+step['name']+'.txt')).read_bytes())==step['sha256']
 assert (H/(prefix+'-strict.txt')).read_text()==''
 backend='roblox_port/src/Server/DataStoreBackend.luau'
 committed=subprocess.check_output(['git','show',r['source']+':'+backend],cwd=ROOT)
 assert sha(committed)==inputs[backend] and r['source']=='bd67582b5d53473f067244fc1e2e1f94adde173b'
 assert not r['policy_installed_in_production'] and r['backend_code_is_production'] and r['backend_provider_is_synthetic'] and not r['native_verified'] and not r['online_verified'] and not r['published']
 return r,raw.decode(),bundle
development,developmentText,_=check('development-1','development-1-admission.luau','development-1-tests.luau',True)
earlier,earlierText,_=check('qualified-1','qualified-1-admission.luau','qualified-1-tests.luau',True)
assert development['exit_code']==0 and 'REQUEST_ADMISSION passed=4752 failed=0 groups=19' in developmentText
assert earlier['exit_code']==0 and 'REQUEST_ADMISSION passed=4763 failed=0 groups=21' in earlierText
before,text,bundle=check('clock-before-fix','qualified-1-admission.luau','qualified-2-tests.luau','tests')
assert before['exit_code']!=0 and (H/'clock-before-fix-bundle.luau').read_bytes()==bundle.encode()
assert 'reentrant-clock-after-allowance-cannot-oversubscribe' in bundle and 'REQUEST_ADMISSION passed=' not in text
lines=bundle.splitlines();locations=[int(n) for n in re.findall(r'run\.luau:(\d+)',text)]
assert any('check(not g:dispatch(ta' in lines[n-1] for n in locations if n<=len(lines)),'Before-fix failure was not the intended stale-admission assertion'
current=(H/'qualified-2-admission.luau').read_text();old=(H/'qualified-1-admission.luau').read_text()
assert current.replace(' local observedVersion=self.version\n','').replace(' if self.version~=observedVersion then return nil,nil,"admission changed during final clock check" end\n','')==old
prior,priorText,_=check('qualified-2','qualified-2-admission.luau','qualified-2-tests.luau',True);assert prior['exit_code']==0 and 'REQUEST_ADMISSION passed=4769 failed=0 groups=22' in priorText
qualified,output,_=check('qualified-3');assert qualified['exit_code']==0
assert 'REQUEST_ADMISSION passed=4771 failed=0 groups=22' in output and 'ADMISSION_BACKEND passed=82 failed=0 groups=8 options=5' in output
assert len(re.findall(r'^ADMISSION_CASE\s',output,re.M))==22 and len(re.findall(r'^ADMISSION_BACKEND_CASE\s',output,re.M))==8
assert sum(int(n) for n in re.findall(r'^ADMISSION_CASE\s[^\n]+\s(\d+)$',output,re.M))==4771
assert 'ADMISSION_SYNTHETIC_MIX\t30\tread_units=30 write_units=6 legacy_wait=120 candidate_wait=0' in output
private={k:v for k,v in qualified['inputs'].items() if k.startswith('docs/')}
committed_private=all(subprocess.run(['git','cat-file','-e','HEAD:'+path],cwd=ROOT,capture_output=True).returncode==0 and sha(subprocess.check_output(['git','show','HEAD:'+path],cwd=ROOT))==digest for path,digest in private.items())
private_commit=subprocess.check_output(['git','log','-1','--format=%H','--',*private.keys()],cwd=ROOT,text=True).strip() if committed_private else None
result=dict(source=qualified['source'],groups=30,checks=4853,failed=0,policy_checks=4771,backend_checks=82,
 strict_modules=2,actual_production_backend=True,providers_and_clock_synthetic=True,
 before_fix_counterexample_bound=True,reentrant_clock_fence_fixed=True,private_inputs_committed=committed_private,private_commit=private_commit,
 policy_installed_in_production=False,actual_owner_scheduler_integration=False,native_verified=False,online_verified=False,published=False,goal_complete=False)
(H/'verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(result,indent=2))
