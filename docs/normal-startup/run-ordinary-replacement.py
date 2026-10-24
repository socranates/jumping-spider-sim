"""Exercise ordinary phase=normal through the actual account service/client."""
from pathlib import Path
import argparse,gzip,hashlib,importlib.util,json,subprocess,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
p=argparse.ArgumentParser();p.add_argument('prefix');p.add_argument('--candidate',action='store_true');p.add_argument('--full',action='store_true');p.add_argument('--routes',action='store_true');a=p.parse_args()
assert a.prefix.replace('-','').isalnum();out=H/(a.prefix+'-output.txt');assert not out.exists()
spec=importlib.util.spec_from_file_location('ordinary_service',H.parent/'request-admission/run-service.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
bundle,paths=m.build(not a.full)
if a.candidate:
 r=m.load('ordinary_bundle_helpers',ROOT/'roblox_port/tests/run.py')
 facade='(function()\n'+(m.H/'worker-facade.luau').read_text(encoding='utf8')+'\nend)()'
 operation='(function()\n'+(m.H/'operation.luau').read_text(encoding='utf8').replace('require("./worker-facade")',facade)+'\nend)()'
 ordinary='(function()\n'+r.requires(r.strict((m.H/'ordinary-io-service.luau').read_text(encoding='utf8').replace('require(script.Parent.RecoveryOperationAdmission)',operation)))+'\nend)()'
 def render(path):
  code=path.read_text(encoding='utf8').replace('require(Shared.Persistence.OrdinaryRequestAdmission)',ordinary)
  return r.requires(r.strict(code.replace('require(script.Parent.RecoveryProfileOwnerPrototype)','__profileOwnerPrototype')))
 old=render(m.H/'replacement-owner.luau');new=H/'ordinary-replacement-owner.luau'
 assert bundle.count(old)==1;bundle=bundle.replace(old,render(new));paths+=[new]
test=H/'ordinary-replacement-tests.luau';marker='print("ACCOUNT_SERVICE passed="..count.." failed=0 groups="..groups)'
assert bundle.count(marker)==1
cases=test.read_text(encoding='utf8')
if a.routes:
 route=H/'ordinary-route-tests.luau';cases+='\n'+route.read_text(encoding='utf8');paths+=[route]
bundle=bundle.replace(marker,cases+'\n'+marker)
paths+= [test,Path(__file__)]
sha=lambda b:hashlib.sha256(b).hexdigest()
inputs={x.relative_to(ROOT).as_posix():sha(x.read_bytes()) for x in paths}
with tempfile.TemporaryDirectory(prefix='windowsill-ordinary-replacement-') as temp:
 path=Path(temp)/'run.luau';path.write_bytes(bundle.encode())
 result=subprocess.run(['C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools/luau/luau.exe',str(path)],capture_output=True,text=True)
assert inputs=={x.relative_to(ROOT).as_posix():sha(x.read_bytes()) for x in paths}
output=result.stdout+result.stderr;out.write_bytes(output.encode())
receipt=dict(exit_code=result.returncode,inputs=inputs,candidate=a.candidate,full=a.full,routes=a.routes,bundle_sha256=sha(bundle.encode()),output_sha256=sha(output.encode()),
 provider='memory-injected-DataStoreBackend',clock='synthetic',native_verified=False,published=False)
(H/(a.prefix+'-receipt.json')).write_bytes((json.dumps(receipt,indent=2)+'\n').encode())
if result.returncode:(H/(a.prefix+'-bundle.luau.gz')).write_bytes(gzip.compress(bundle.encode(),mtime=0))
print(output[-4500:]);raise SystemExit(result.returncode)
