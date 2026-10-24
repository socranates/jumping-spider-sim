"""Exercise incoming legacy observations through the actual continuation policy."""
from pathlib import Path
import argparse,gzip,hashlib,importlib.util,json,subprocess,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
p=argparse.ArgumentParser();p.add_argument('prefix');p.add_argument('--full',action='store_true');p.add_argument('--before-policy',action='store_true');p.add_argument('--before-flag',action='store_true');a=p.parse_args()
assert a.prefix.replace('-','').isalnum();out=H/(a.prefix+'-output.txt');assert not out.exists()
spec=importlib.util.spec_from_file_location('legacy_service',H.parent/'request-admission/run-service.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
bundle,paths=m.build(not a.full);r=m.load('legacy_helpers',ROOT/'roblox_port/tests/run.py')
facade='(function()\n'+(m.H/'worker-facade.luau').read_text(encoding='utf8')+'\nend)()'
operation='(function()\n'+(m.H/'operation.luau').read_text(encoding='utf8').replace('require("./worker-facade")',facade)+'\nend)()'
ordinary='(function()\n'+r.requires(r.strict((m.H/'ordinary-io-service.luau').read_text(encoding='utf8').replace('require(script.Parent.RecoveryOperationAdmission)',operation)))+'\nend)()'
def owner(path):return r.requires(r.strict(path.read_text(encoding='utf8').replace('require(Shared.Persistence.OrdinaryRequestAdmission)',ordinary).replace('require(script.Parent.RecoveryProfileOwnerPrototype)','__profileOwnerPrototype')))
old=owner(m.H/'replacement-owner.luau');assert bundle.count(old)==1
bundle=bundle.replace(old,owner(H/'ordinary-replacement-owner.luau'));paths+=[H/'ordinary-replacement-owner.luau']
if not a.before_flag:
 old=r.requires(r.strict((ROOT/'roblox_port/src/Client/SaveContinuation.luau').read_text(encoding='utf8')))
 assert bundle.count(old)==1;path=H/'continuation-legacy.luau'
 bundle=bundle.replace(old,r.requires(r.strict(path.read_text(encoding='utf8'))));paths+=[path]
marker='print("ACCOUNT_SERVICE passed="..count.." failed=0 groups="..groups)';assert bundle.count(marker)==1
test=H/'legacy-validation-tests.luau';policy=H/'offer-validation.luau'
code=r.requires(r.strict(policy.read_text(encoding='utf8').replace('require(Shared.Persistence.RecoveryLifePrototype)','__lifePrototype')))
cases='local LEGACY_BEFORE_POLICY='+str(a.before_policy).lower()+'\nlocal LegacyOfferValidation=(function()\n'+code+'\nend)()\n'+test.read_text(encoding='utf8')
if a.full:
 for name in ['ordinary-replacement-tests.luau','ordinary-route-tests.luau']:
  path=H/name;cases=path.read_text(encoding='utf8')+'\n'+cases;paths+=[path]
else:
 # Keep the real service fixture/test helpers; do not repeatedly run the old
 # service cases in focused incoming-offer counterexamples.
 first='test("initial-owner-and-normal-removal-use-one-account-lane",function()'
 start=bundle.index(first,bundle.index('local function runAccountServiceChecks'))
 end=bundle.index(marker,start);bundle=bundle[:start]+bundle[end:]
bundle=bundle.replace(marker,r.requires(cases)+'\n'+marker);paths += [test,policy,Path(__file__)]
sha=lambda b:hashlib.sha256(b).hexdigest();inputs={x.relative_to(ROOT).as_posix():sha(x.read_bytes()) for x in paths}
with tempfile.TemporaryDirectory(prefix='windowsill-legacy-validation-') as temp:
 path=Path(temp)/'run.luau';path.write_bytes(bundle.encode())
 result=subprocess.run(['C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(path)],capture_output=True,text=True)
assert inputs=={x.relative_to(ROOT).as_posix():sha(x.read_bytes()) for x in paths}
output=result.stdout+result.stderr;out.write_bytes(output.encode())
receipt=dict(exit_code=result.returncode,inputs=inputs,before_policy=a.before_policy,before_flag=a.before_flag,full=a.full,
 bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),clock='synthetic',native_verified=False,published=False)
(H/(a.prefix+'-receipt.json')).write_bytes((json.dumps(receipt,indent=2)+'\n').encode())
if result.returncode:(H/(a.prefix+'-bundle.luau.gz')).write_bytes(gzip.compress(bundle.encode(),mtime=0))
print(output[-4500:]);raise SystemExit(result.returncode)
