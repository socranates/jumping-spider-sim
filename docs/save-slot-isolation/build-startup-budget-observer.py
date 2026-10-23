"""Build an unbound, read-only-budget Studio probe with exactly four project scripts."""
from pathlib import Path
import hashlib,json,subprocess,xml.etree.ElementTree as ET
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
TOOLS=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
sha=lambda b:hashlib.sha256(b).hexdigest()
paths={'SaveRules':ROOT/'roblox_port/src/Shared/Data/SaveRules.luau','SaveWork':ROOT/'roblox_port/src/Shared/Persistence/SaveWork.luau','StartupBudgetObserverModule':H/'recovery-startup-budget-prototype.luau'}
sources={name:p.read_text(encoding='utf8') for name,p in paths.items()}
digest=sha(sources['StartupBudgetObserverModule'].encode())
probe='''-- Read-only budget introspection, no DataStore name/key access or writes.
local report={kind="startup-budget-observer",pass=false,assertions=0,prototype_sha256="DIGEST",production_connected=false,real_datastore_verified=false}
local okay,why=pcall(function()
 local function check(value,message) assert(value,message);report.assertions+=1 end
 check(game.PlaceId==0 and game.GameId==0,"observer must be an unbound local diagnostic")
 local root=game:GetService("ServerScriptService")
 local Budget=require(root:WaitForChild("StartupBudgetObserverModule"))
 local gate=Budget.engine(os.time)
 check(type(gate.query)=="function","modern standard read/write budget observer unavailable")
 local co=coroutine.create(gate.query)
 local began=os.clock();local ok,read,write=coroutine.resume(co)
 check(ok,"budget observer raised: "..tostring(read))
 check(coroutine.status(co)=="dead","budget observer unexpectedly yielded")
 check(type(read)=="number" and read==read and read>=0 and read<math.huge,"read budget is not finite/nonnegative")
 check(type(write)=="number" and write==write and write>=0 and write<math.huge,"write budget is not finite/nonnegative")
 report.read_budget,report.write_budget,report.elapsed_seconds=read,write,os.clock()-began
 report.engine_version=version();report.place_id=game.PlaceId;report.game_id=game.GameId;report.pass=true
end)
if not okay then report.problem=tostring(why) end
print("WINDOWSILL_STARTUP_OBSERVER "..game:GetService("HttpService"):JSONEncode(report))
'''.replace('DIGEST',digest)
sources['StartupBudgetObserver']=probe
bundle=sha(''.join(name+'\n'+source for name,source in sorted(sources.items())).encode())
out=Path(r'C:/Users/natha/claude-xfer')/('Windowsill-startup-observer-'+bundle[:12]);out.mkdir(parents=True,exist_ok=True)
for name,source in sources.items():
 path=out/(name+('.server.luau' if name=='StartupBudgetObserver' else '.luau'))
 if path.exists():assert path.read_text(encoding='utf8')==source,'existing source differs: '+name
 else:path.write_text(source,encoding='utf8',newline='\n')
project={'name':'WindowsillStartupBudgetObserver','tree':{'$className':'DataModel','ReplicatedStorage':{'$className':'ReplicatedStorage','Shared':{'$className':'Folder','Data':{'$className':'Folder','SaveRules':{'$path':'SaveRules.luau'}},'Persistence':{'$className':'Folder','SaveWork':{'$path':'SaveWork.luau'}}}},'ServerScriptService':{'$className':'ServerScriptService','StartupBudgetObserverModule':{'$path':'StartupBudgetObserverModule.luau'},'StartupBudgetObserver':{'$path':'StartupBudgetObserver.server.luau'}},'Workspace':{'$className':'Workspace'}}}
projectPath=out/'default.project.json'
if projectPath.exists():assert json.loads(projectPath.read_text(encoding='utf8'))==project,'existing project differs'
else:projectPath.write_text(json.dumps(project,indent=2)+'\n',encoding='utf8',newline='\n')
model=out/'WindowsillStartupBudgetObserver.rbxlx'
if not model.exists():
 result=subprocess.run([str(TOOLS/'rojo/rojo.exe'),'build','default.project.json','--output',str(model)],cwd=out,capture_output=True,text=True);assert result.returncode==0,result.stdout+result.stderr
tree=ET.parse(model);found={}
for node in tree.iter('Item'):
 if node.attrib.get('class') not in ['Script','LocalScript','ModuleScript']:continue
 props=node.find('Properties');name=props.find("string[@name='Name']").text;source=props.find("*[@name='Source']").text or '';found[name]=source
assert set(found)==set(sources)
for name,source in sources.items():assert found[name]==source,name
receipt=dict(path=str(model),model_sha256=sha(model.read_bytes()),prototype_raw_sha256=sha(paths['StartupBudgetObserverModule'].read_bytes()),prototype_normalized_sha256=digest,sources={name:sha(source.encode()) for name,source in sources.items()},scripts=4,project_bound_to_experience=False,production_connected=False,data_store_record_access=False,native_observer_verified=False,published=False)
target=H/'startup-native-observer-build.json';assert not target.exists(),'preserve earlier evidence';target.write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(receipt,indent=2))
