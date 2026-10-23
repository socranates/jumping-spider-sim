"""Strict-check the service-owned account gate and initial-load cancellation."""
from pathlib import Path
import hashlib,importlib.util,json,shutil,subprocess,sys,tempfile
H=Path(__file__).resolve().parent
ROOT=H.parents[1]
TOOLS=Path('C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
def checker():
 s=importlib.util.spec_from_file_location('service_types',H/'check-profile.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
 base=m.checker();old=base.paths
 def paths():
  out=old();out.update({'Server/SaveService.luau':H/'save-service.luau','Server/ReplacementServicePrototype.luau':H/'replacement-service.luau',
   'Server/ReplacementOwnerPrototype.luau':H/'replacement-owner.luau','Server/RecoveryAccountLifetimes.luau':H/'account-lifetimes.luau',
   'Shared/Persistence/OrdinaryRequestAdmission.luau':H/'ordinary-io-service.luau'});return out
 base.paths=paths;return base
def main():
 prefix=sys.argv[1];assert prefix.replace('-','').isalnum();assert not (H/(prefix+'-types.json')).exists()
 sources=checker().paths();sha=lambda b:hashlib.sha256(b).hexdigest()
 inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in sources.values()}
 production={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in (ROOT/'roblox_port/src').rglob('*.luau')}
 production['roblox_port/default.project.json']=sha((ROOT/'roblox_port/default.project.json').read_bytes())
 mounted={};steps=[]
 with tempfile.TemporaryDirectory(prefix='windowsill-service-types-') as tmp:
  folder=Path(tmp);shutil.copytree(ROOT/'roblox_port/src',folder/'src');shutil.copy2(ROOT/'roblox_port/default.project.json',folder/'default.project.json')
  for target,path in sources.items():
   code=path.read_text(encoding='utf8')
   if path in [H/'worker-v3.luau',H/'operation.luau']:
    assert code.count('require("./worker-facade")')==1;code=code.replace('require("./worker-facade")','require(script.Parent.RequestAdmissionFacade)')
   (folder/'src'/target).write_text(code,encoding='utf8',newline='\n');mounted[target]=sha(code.encode())
  errors=[]
  for target in sources:
   r=subprocess.run([str(TOOLS/'luau/luau-compile.exe'),'--null',str(folder/'src'/target)],capture_output=True,text=True)
   if r.returncode:errors.append(target+'\n'+r.stdout+r.stderr)
  output='compile '+str(len(sources)-len(errors))+'/'+str(len(sources))+'\n'+'\n'.join(errors)
  (H/(prefix+'-compile.txt')).write_text(output,encoding='utf8',newline='\n');steps.append(dict(name='compile',exit_code=int(bool(errors)),sha256=sha(output.encode())))
  for name,cmd in [('sourcemap',[str(TOOLS/'rojo/rojo.exe'),'sourcemap','default.project.json','--output','sourcemap.json']),
   ('strict',[str(TOOLS/'lsp/luau-lsp.exe'),'analyze','--sourcemap=sourcemap.json','--definitions='+str(TOOLS/'globalTypes.d.luau'),'--ignore=**/tests/**','--no-strict-dm-types','src'])]:
   r=subprocess.run(cmd,cwd=folder,capture_output=True,text=True);output=r.stdout+r.stderr
   (H/(prefix+'-'+name+'.txt')).write_text(output,encoding='utf8',newline='\n');steps.append(dict(name=name,exit_code=r.returncode,sha256=sha(output.encode())));print(name,r.returncode,output[:5000],flush=True)
 assert inputs=={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in sources.values()}
 receipt=dict(candidates=inputs,production_inputs=production,mounted=mounted,steps=steps,source_encoding='utf8',normal_startup_installed=False,native_verified=False,online_verified=False)
 (H/(prefix+'-types.json')).write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');assert all(x['exit_code']==0 for x in steps)
if __name__=='__main__':main()
