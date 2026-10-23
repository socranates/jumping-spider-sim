"""Exercise the real legacy StartupBudget bookkeeping callback and bridge fence."""
from pathlib import Path
import hashlib,importlib.util,sys
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
def load(name,file):
 spec=importlib.util.spec_from_file_location(name,H/file);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def build(workerPath=None):
 base=load('startup_dispatch_bridge','run-bridge.py');bundle,_,paths=base.build(workerPath or H/'worker-v2.luau')
 source=ROOT/'docs/save-slot-isolation/recovery-startup-budget-prototype.luau';code=source.read_text()
 header='local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")\n';assert code.count(header)==1;code=code.replace(header,'')
 code=code.replace('require(Shared.Data.SaveRules)','Rules').replace('require(Shared.Persistence.SaveWork)','Work')
 tests=H/'startup-dispatch-tests.luau'
 bundle+='\nlocal Startup=(function()\n'+code+'\nend)()\n'+tests.read_text();paths+=[source,tests]
 return bundle,{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},paths
if __name__=='__main__':
 module=H/(sys.argv[2] if len(sys.argv)>2 else 'worker-v2.luau');assert module.parent==H
 bundle,inputs,paths=build(module);load('startup_dispatch_execute','run.py').execute(sys.argv[1],bundle,inputs,paths)
