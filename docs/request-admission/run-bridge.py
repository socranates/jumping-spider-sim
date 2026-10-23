"""Fast portable gate/facade/bridge checks, with exact production memory dependencies."""
from pathlib import Path
import importlib.util,sys
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
def load():
 spec=importlib.util.spec_from_file_location('admission_base',H/'run.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def build(workerPath=None):
 base=load();bundle,inputs,paths=base.build(H/'worker-admission.luau')
 original=(H/'facade.luau').read_text();updated=(H/'worker-facade.luau').read_text();assert bundle.count(original)==1
 bundle=bundle.replace(original,updated)
 extra=[]
 def module(name,path,replacements={}):
  code=path.read_text()
  for a,b in replacements.items():assert a in code;code=code.replace(a,b)
  extra.append(path);return 'local '+name+'=(function()\n'+code+'\nend)()\n'
 source=ROOT/'roblox_port/src/Shared'
 bundle+=module('Work',source/'Persistence/SaveWork.luau')
 bundle+=module('Json',source/'Persistence/Json.luau',{'require(script.Parent.SaveWork)':'Work'})
 bundle+=module('Rules',source/'Data/SaveRules.luau')
 bundle+=module('Memory',source/'Persistence/MemoryBackend.luau',{'require(script.Parent.Json)':'Json','require(script.Parent.Parent.Data.SaveRules)':'Rules'})
 bundle+=module('Scheduler',source/'Persistence/SaveScheduler.luau',{'require(script.Parent.Parent.Data.SaveRules)':'Rules'})
 bundle+=module('Worker',workerPath or H/'worker.luau',{'require("./worker-facade")':'Facade'})
 tests=(H/'bridge-tests.luau').read_text().replace('__workerAdmission','Admission').replace('__workerBridge','Worker')
 tests=tests.replace('local Memory=require("../src/Shared/Persistence/MemoryBackend")','').replace('local Scheduler=require("../src/Shared/Persistence/SaveScheduler")','')
 bundle+=tests;extra+=[H/'worker-facade.luau',H/'bridge-tests.luau']
 paths=list(dict.fromkeys(paths+extra))
 import hashlib
 inputs={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
 return bundle,inputs,paths
if __name__=='__main__':
 bundle,inputs,paths=build();load().execute(sys.argv[1],bundle,inputs,paths)
