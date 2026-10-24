"""Run unchanged game suites against the complete staged source tree.

Lazy module loading follows actual require order. New modules need no fragile
hand-maintained topological list; identically named facades remain separate.
"""
from pathlib import Path
import argparse,ast,gzip,hashlib,importlib.util,json,re,subprocess,tempfile
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
TOOLS=Path('C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
p=argparse.ArgumentParser();p.add_argument('--stage',type=Path,required=True);p.add_argument('--prefix',required=True);p.add_argument('--suite',action='append');a=p.parse_args()
assert a.prefix.replace('-','').isalnum();stage=a.stage.resolve();port=stage/'roblox_port';src=port/'src';tests=port/'tests';source=tests/'run.py'
assert not (H/(a.prefix+'-receipt.json')).exists()
spec=importlib.util.spec_from_file_location('complete_staged_cli',source);r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
aliases={};paths={}
for file in src.rglob('*.luau'):
 if file.name.endswith(('.server.luau','.client.luau')):continue
 name=file.stem
 if name=='RequestAdmissionFacade':name=file.relative_to(src).parts[0]+'_'+name
 assert name not in paths,(name,paths.get(name),file)
 paths[name]=file;aliases[name]=file.relative_to(src).as_posix()
originalChunk=r.chunk;originalRequires=r.requires
def requires(text):
 old='assert(pcall(function() require("../src/Client/SpiderClient.client") end),"client failed to load")'
 new='do local okay,problem=pcall(function() require("../src/Client/SpiderClient.client") end);assert(okay,"client failed to load: "..tostring(problem))end'
 return originalRequires(text.replace(old,new))
r.requires=requires
def chunk(file):
 code=file.read_text(encoding='utf8')
 if file.is_relative_to(src):
  side=file.relative_to(src).parts[0]
  if side in ['Server','Shared']:
   code=code.replace('require(script.Parent.RequestAdmissionFacade)','__mods.'+side+'_RequestAdmissionFacade')
 code=r.requires(r.strict(code))
 assert not re.search(r'require\([^\n]*RequestAdmissionFacade',code),file
 return '(function()\n'+code+'\nend)()'
r.chunk=chunk;r.MODULES=[(name,str(path.relative_to(r.SRC)))if path.is_relative_to(r.SRC)else(name,str(path))for name,path in sorted(paths.items())]
r.CLIENT_MODULES=[];r.NAMES=set(paths)
lazy='''local __refs, __mods = {}, {}
local __loaders, __loading = {}, {}
setmetatable(__mods,{__index=function(self,key)
 local load=assert(__loaders[key],"missing bundled module: "..tostring(key))
 assert(not __loading[key],"circular eager module load: "..tostring(key))
 __loading[key]=true;local value=load();__loading[key]=nil
 assert(value~=nil,"nil bundled module: "..tostring(key));rawset(self,key,value);return value
end})'''
def bundle(suite):
 text=r.bundle(suite)
 assert text.count('local __refs, __mods = {}, {}')==1
 text=text.replace('local __refs, __mods = {}, {}',lazy)
 for name,path in r.MODULES:
  code=chunk(r.SRC/path);old='__mods.'+name+' = '+code;assert text.count(old)==1,name
  text=text.replace(old,'__loaders.'+name+' = function() return '+code+' end')
 return text
if a.suite:suites=a.suite
else:
 tree=ast.parse(source.read_text(encoding='utf8'));main=next(n for n in tree.body if isinstance(n,ast.FunctionDef)and n.name=='main')
 loop=next(n for n in main.body if isinstance(n,ast.For));suites=ast.literal_eval(loop.iter.values[1])
sha=lambda b:hashlib.sha256(b).hexdigest();inputs={path.relative_to(src).as_posix():sha(path.read_bytes())for path in src.rglob('*.luau')}
testInputs={path.relative_to(tests).as_posix():sha(path.read_bytes())for path in tests.rglob('*')if path.is_file()and '__pycache__'not in path.parts}
results=[]
with tempfile.TemporaryDirectory(prefix='windowsill-integrated-cli-')as temp:
 for suite in suites:
  assert suite.endswith('.luau')and '/'not in suite
  text=bundle(suite);path=Path(temp)/'run.luau';path.write_bytes(text.encode())
  result=subprocess.run([str(TOOLS/'luau/luau.exe'),str(path)],capture_output=True,text=True)
  output=result.stdout+result.stderr;filename=a.prefix+'-'+suite[:-5]+'-output.txt';(H/filename).write_bytes(output.encode())
  results.append(dict(suite=suite,exit_code=result.returncode,bundle_sha256=sha(text.encode()),output=filename,output_sha256=sha(output.encode())))
  print(suite,result.returncode,output[-1200:],flush=True)
  if result.returncode:
   (H/(a.prefix+'-'+suite[:-5]+'-bundle.luau.gz')).write_bytes(gzip.compress(text.encode(),mtime=0));break
assert inputs=={path.relative_to(src).as_posix():sha(path.read_bytes())for path in src.rglob('*.luau')}
assert testInputs=={path.relative_to(tests).as_posix():sha(path.read_bytes())for path in tests.rglob('*')if path.is_file()and '__pycache__'not in path.parts}
receipt=dict(stage=str(stage),inputs=inputs,test_inputs=testInputs,runner_sha256=sha(Path(__file__).read_bytes()),module_aliases=aliases,
 requested=suites,results=results,all_passed=len(results)==len(suites)and all(x['exit_code']==0 for x in results),full=a.suite is None)
(H/(a.prefix+'-receipt.json')).write_bytes((json.dumps(receipt,indent=2)+'\n').encode())
raise SystemExit(0 if receipt['all_passed']else 1)
