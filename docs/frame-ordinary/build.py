"""Build an unbound ordinary-startup probe with isolated yielding memory storage."""
from pathlib import Path
import argparse,hashlib,io,json,subprocess,tarfile,xml.etree.ElementTree as ET,zlib,importlib.util
H=Path(__file__).resolve().parent;N=H.parent/'normal-startup';ROOT=H.parents[1]
TOOLS=Path('C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
SOURCE='bd67582b5d53473f067244fc1e2e1f94adde173b';sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--unavailable',action='store_true');p.add_argument('--ordinary-ui',action='store_true',default=True);p.add_argument('--before',action='store_true');p.add_argument('--optimized',action='store_true');p.add_argument('--types',default='normal-startup-types-4-types.json');a=p.parse_args();out=a.out.resolve();assert not a.before and not a.unavailable
assert out.parent.is_dir() and not out.exists();out.mkdir();src=out/'src';expected={}
raw=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src','roblox_port/default.project.json'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
 for member in archive:
  if not member.isfile():continue
  data=archive.extractfile(member).read()
  if member.name.endswith('default.project.json'):project=json.loads(data);continue
  expected[Path(member.name).relative_to('roblox_port/src').as_posix()]=data
assert len(expected)==224
spec=importlib.util.spec_from_file_location('startup_mounts',N/('check.py' if a.before else 'check-legacy.py'));m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
paths=m.checker.paths()
typed=json.loads((H.parent/'request-admission'/a.types).read_text(encoding='utf8'))
for rel,path in paths.items():
 data=path.read_bytes();assert sha(data)==typed['candidates'][path.relative_to(ROOT).as_posix()]
 code=data.decode('utf8').replace('\r\n','\n')
 if path.name in ['worker-v3.luau','operation.luau']:code=code.replace('require("./worker-facade")','require(script.Parent.RequestAdmissionFacade)')
 assert sha(code.encode())==typed['mounted'][rel]
 expected[rel]=code.encode()
if a.optimized:expected['Shared/World/LookPlan.luau']=(H/'look-plan.luau').read_bytes()
if a.ordinary_ui:
 expected['Client/NormalStartupObserver.luau']=(H/'playback.luau').read_bytes()
 expected['Client/SpiderClient.client.luau']+=b'''\n-- Unpublished observer only; ordinary title/menu and cat remain enabled.
if RunService:IsStudio() and Workspace:GetAttribute("NormalStartupDiagnostic")==true then
 task.spawn(function() require(script.Parent.NormalStartupObserver)(M.hooks()) end)
end
'''
else:expected['Client/SilkPlayback.luau']=(H/'playback.luau').read_bytes()
expected['Server/NormalStartupDiagnosticStorage.luau']=(N/'diagnostic-storage.luau').read_bytes()
expected['Client/StartupPerfProbe.luau']=(H/'probe.luau').read_bytes()
client=expected['Client/SpiderClient.client.luau'].decode('utf8')
assert client.startswith('--!strict\n')
client=client.replace('--!strict\n','--!strict\nrequire(script.Parent.StartupPerfProbe).begin()\n',1)
anchors={
 'local M = {':'require(script.Parent.StartupPerfProbe).mark("module-table")\nlocal M = {',
 'M.lock = M.LockOn.new()':'require(script.Parent.StartupPerfProbe).mark("module-table-complete")\nM.lock = M.LockOn.new()',
 'World = require(script.Parent.WorldClient).new(Workspace, Players.LocalPlayer),':'World = require(script.Parent.StartupPerfProbe).call("world-client",function()return require(script.Parent.WorldClient).new(Workspace, Players.LocalPlayer)end),',
 'local rig = SpiderRig.new(Workspace, M.World.root, appearance, detail)':'local rig = require(script.Parent.StartupPerfProbe).call("spider-rig",function()return SpiderRig.new(Workspace, M.World.root, appearance, detail)end)',
 'M.World:streamLooks(Workspace, detail)':'require(script.Parent.StartupPerfProbe).mark("looks-begin");M.World:streamLooks(Workspace, detail);require(script.Parent.StartupPerfProbe).mark("looks-end");require(script.Parent.StartupPerfProbe).watchLooks(M.World.looks)',
 'local flyBodies = FlyBodies.new(Workspace, detail)':'require(script.Parent.StartupPerfProbe).mark("animal-bodies-begin")\nlocal flyBodies = FlyBodies.new(Workspace, detail)',
 'M.meal=require(script.Parent.MealPresentation).new(Workspace,M.World.root)':'M.meal=require(script.Parent.MealPresentation).new(Workspace,M.World.root)\nrequire(script.Parent.StartupPerfProbe).mark("animal-bodies-end")',
 'local accumulator = 0':'require(script.Parent.StartupPerfProbe).mark("client-ready-to-render")\nlocal accumulator = 0'}
for old,new in anchors.items():assert client.count(old)==1,old;client=client.replace(old,new)
expected['Client/SpiderClient.client.luau']=client.encode()
normalPersistence=expected['Server/Persistence.server.luau'].decode('utf8')
start=normalPersistence.index('local function loadStore()');end=normalPersistence.index('local dataStore,available=loadStore()',start)
normalPersistence=normalPersistence[:start]+'local function loadStore(): (any,any) return require(script.Parent.NormalStartupDiagnosticStorage).loadStore() end\n'+normalPersistence[end:]
normalPersistence=normalPersistence.replace('local DataStores=game:GetService("DataStoreService")\n','').replace('local runTag=tostring(os.time())\n','')
old='local keyOf=if testPlace then function(player:any):string return `t{runTag}_{player.UserId}` end else nil'
assert normalPersistence.count(old)==1
normalPersistence=normalPersistence.replace(old,'local keyOf=function(_player:any):string return "qa_normal_startup" end')
old='composition=Composition.new(config);service=composition.service'
assert normalPersistence.count(old)==1
normalPersistence=normalPersistence.replace(old,old+';require(script.Parent.NormalStartupDiagnosticStorage).observe(composition)')
assert ':GetDataStore(' not in normalPersistence and 'GetRequestBudgetForRequestType' not in normalPersistence
expected['Server/Persistence.server.luau']=normalPersistence.encode()
# Timing-only server marks: no scheduling or world/saving behavior changes.
for rel,anchors in {
 'Server/Main.server.luau':{
  'local Habitat =':('main-modules-begin',None),
  'Players.CharacterAutoLoads = false':('main-modules-end',None),
  'local decorOk, decor, replaced = pcall(Scenery.decor, if litOk and sun.ok then sun.direction else nil, worldId)':('decor-begin','decor-end'),
  'local hidden: { [string]: boolean } = {}':('hidden-plan-begin',None),
  'WorldBuild.world(Workspace, WorldMap.SEED, hidden)':('physical-world-begin','physical-world-end')},
 'Server/Persistence.server.luau':{
  'local dataStore,available=loadStore()':('storage-begin','storage-end'),
  ' catalog,problem=Templates.new(root,function():boolean return not closing end)':('templates-begin','templates-end'),
  'if worldId==Worlds.PRESERVE then composition=Composition.new(config);service=composition.service;require(script.Parent.NormalStartupDiagnosticStorage).observe(composition)':('composition-begin',None)}
}.items():
 code=expected[rel].decode()
 for anchor,(before,after)in anchors.items():
  assert code.count(anchor)==1,anchor
  def marker(name):return 'print("[ORDINARY_SERVER_MARK]",game:GetService("HttpService"):JSONEncode({name="'+name+'",at=workspace:GetServerTimeNow(),clock=os.clock(),heap_kb=gcinfo()}))'
  code=code.replace(anchor,marker(before)+'\n'+anchor+('\n'+marker(after)if after else ''))
 expected[rel]=code.encode()
source_count=len(expected);assert source_count==(275 if a.before else 276)

for rel,data in expected.items():
 path=src/rel;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
for role,node in [('First',project['tree']['ReplicatedFirst']),('Shared',project['tree']['ReplicatedStorage']['Shared']),('Client',project['tree']['StarterPlayer']['StarterPlayerScripts']['Client'])]:node['$path']=str(src/role)
server={'$className':'Folder','$ignoreUnknownInstances':False}
for path in sorted((src/'Server').glob('*.luau')):
 name=path.name.removesuffix('.luau').removesuffix('.server');server[name]={'$path':str(path)}
 if name=='Persistence':server[name]['$properties']={'Disabled':False}
project['tree']['ServerScriptService']['Server']=server
project['name']='WindowsillOrdinaryFrameDiagnostic'
project['tree']['Workspace']['$attributes']={'World':'preserve','Detail':'full','SelfTest':False,'TestTarget':False,'SaveWait':True,'NormalStartupDiagnostic':True,'DiagnosticUnavailable':a.unavailable,'OrdinaryPerf':True}
config=out/'diagnostic.project.json';config.write_text(json.dumps(project,indent=2)+'\n',encoding='utf8',newline='\n')
errors=[]
for rel in expected:
 r=subprocess.run([str(TOOLS/'luau/luau-compile.exe'),'--null',str(src/rel)],capture_output=True,text=True)
 if r.returncode:errors.append(rel+'\n'+r.stdout+r.stderr)
(out/'compile.txt').write_text(f'compile {len(expected)-len(errors)}/{len(expected)}\n'+'\n'.join(errors),encoding='utf8',newline='\n');assert not errors,errors
for name,command in [('sourcemap',[str(TOOLS/'rojo/rojo.exe'),'sourcemap',str(config),'--output',str(out/'sourcemap.json')]),('strict',[str(TOOLS/'lsp/luau-lsp.exe'),'analyze','--sourcemap='+str(out/'sourcemap.json'),'--definitions='+str(TOOLS/'globalTypes.d.luau'),'--no-strict-dm-types',str(src)])]:
 r=subprocess.run(command,cwd=out,capture_output=True,text=True);text=r.stdout+r.stderr
 (out/(name+'.txt')).write_text(text,encoding='utf8',newline='\n');print(name,r.returncode,text[:1500],flush=True);assert r.returncode==0
place=out/'Windowsill-normal-startup.rbxlx';subprocess.run([str(TOOLS/'rojo/rojo.exe'),'build',str(config),'-o',str(place)],check=True)
def target(rel):
 parts=list(Path(rel).parts);leaf=parts[-1][:-5].removesuffix('.server').removesuffix('.client')
 prefixes={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
 return '.'.join([prefixes[parts[0]],*parts[1:-1],leaf])
actual={};disabled=[]
def walk(item,parent=''):
 props=item.find('Properties');name=props.findtext("string[@name='Name']");path=parent+'.'+name if parent else name
 code=props.find("*[@name='Source']")
 if code is not None:actual[path]=(code.text or '').replace('\r\n','\n').encode()
 if item.attrib['class'] in ['Script','LocalScript']:disabled.append([path,props.findtext("bool[@name='Disabled']")=='true'])
 for child in item.findall('Item'):walk(child,path)
for item in ET.parse(place).getroot().findall('Item'):walk(item)
wanted={target(rel):data.replace(b'\r\n',b'\n') for rel,data in expected.items()}
assert actual==wanted and sum(flag for _,flag in disabled)==0 and ['ServerScriptService.Server.Persistence',False] in disabled
rows=[[name,len(data),zlib.adler32(data)] for name,data in sorted(wanted.items())]
guard='assert(game.PlaceId==0 and game.GameId==0 and not game:GetService("RunService"):IsRunning());assert(workspace:GetAttribute("NormalStartupDiagnostic")==true and workspace:GetAttribute("Detail")=="full");local expected='+json.dumps(rows,separators=(',',':')).replace('[','{').replace(']','}')+';'
guard+='for _,r in expected do local it=game;for name in string.gmatch(r[1],"[^.]+") do it=assert(it:FindFirstChild(name),r[1]) end;local s=string.gsub(it.Source,"\\r\\n","\\n");local a,b=1,0;for i=1,#s do a=(a+string.byte(s,i))%65521;b=(b+a)%65521 end;assert(#s==r[2] and b*65536+a==r[3],r[1]) end;assert(not game.ServerScriptService.Server.Persistence.Disabled);print("[NORMAL_STARTUP_GUARD]",'+str(source_count)+',"unbound memory_only ordinary_workload measured_startup")'
(out/'guard.luau').write_text(guard+'\n',encoding='utf8',newline='\n')
manifest=dict(source=SOURCE,place=str(place),place_sha256=sha(place.read_bytes()),sources={name:sha(data) for name,data in wanted.items()},guard_sha256=sha((out/'guard.luau').read_bytes()),diagnostic_sha256=sha((H/'playback.luau').read_bytes()),probe_sha256=sha((H/'probe.luau').read_bytes()),source_count=source_count,private_targets=len(paths),legacy_seeded=False,ordinary_workload=True,early_client_measurement=True,optimized=a.optimized,extra_game_override=("Shared/World/LookPlan.luau" if a.optimized else None),before_fix=a.before,ordinary_ui=a.ordinary_ui,production_overrides=sorted(k for k in paths if k in {x.relative_to(ROOT/"roblox_port/src").as_posix() for x in (ROOT/"roblox_port/src").rglob("*.luau")}),storage="yielding-memory-injected-DataStoreBackend",diagnostic_unavailable=a.unavailable,executed=False,published=False)
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps({key:manifest[key] for key in ['place','place_sha256','source_count','private_targets']},indent=2))
