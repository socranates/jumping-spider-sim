"""Build unpublished unbound benchmark models from ordinary source.
The legacy before variant replaces LookPlan only. Startup-clock uses current
ordinary sources with isolated timing hooks. No upload or external save access.
"""
from pathlib import Path
import argparse,hashlib,json,subprocess,xml.etree.ElementTree as ET,zlib
H=Path(__file__).resolve().parent;ROOT=H.parents[1];PORT=ROOT/'roblox_port'
TOOLS=Path('C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--tier',choices=['full','low'],required=True);p.add_argument('--variant',choices=['before','after'],required=True);p.add_argument('--long-trace-seconds',type=int,default=0);p.add_argument('--playback-source',type=Path,default=H/'playback.luau');p.add_argument('--seam-group',choices=['northern','hut_perimeter']);p.add_argument('--startup-clock',action='store_true');a=p.parse_args()
assert not a.startup_clock or(a.variant=='after'and a.seam_group is None and not a.long_trace_seconds and a.playback_source.resolve()==(ROOT/'docs/startup-clock/playback.luau').resolve())
assert a.long_trace_seconds==0 or 60<=a.long_trace_seconds<=3600
assert not a.long_trace_seconds or (a.playback_source.resolve()==(H/'playback.luau').resolve()and a.seam_group is None)
out=a.out.resolve();assert out.parent.is_dir() and not out.exists();out.mkdir()
revision=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
original={f.relative_to(PORT/'src').as_posix():f.read_bytes().replace(b'\r\n',b'\n')for f in (PORT/'src').rglob('*.luau')}
assert len(original)==273
source=dict(original)
if a.variant=='before':
 source['Shared/World/LookPlan.luau']=subprocess.check_output(['git','show','bd67582b5d53473f067244fc1e2e1f94adde173b:roblox_port/src/Shared/World/LookPlan.luau'],cwd=ROOT).replace(b'\r\n',b'\n')
probe=(ROOT/'docs/frame-ordinary/probe.luau').read_text()
probe=probe.replace('ORDINARY_FRAME_','MATRIX_FRAME_').replace('"InstanceCount"}','"InstanceCount","DataReceiveKbps","DataSendKbps"}')
probe=probe.replace('p50_ms=percentile(.5),','mean_ms=s.duration/math.max(1,s.frames)*1000,p50_ms=percentile(.5),')
assert 'mean_ms=s.duration/'in probe and 'DataReceiveKbps'in probe
if a.startup_clock:probe=(ROOT/'docs/startup-clock/probe.luau').read_text()
source['Client/MatrixProbe.luau']=probe.encode()
source['Client/MatrixPlayback.luau']=a.playback_source.read_bytes()
if a.long_trace_seconds:
 source['Client/MatrixLongTrace.luau']=(H/'long-trace.luau').read_bytes()
 anchor=b'  local final=inspect("finish")'
 assert source['Client/MatrixPlayback.luau'].count(anchor)==1
 source['Client/MatrixPlayback.luau']=source['Client/MatrixPlayback.luau'].replace(anchor,
  f'  require(script.Parent.MatrixLongTrace)(d,{a.long_trace_seconds})\n'.encode()+anchor)
client=source['Client/SpiderClient.client.luau'].decode()
assert client.startswith('--!strict\n')
client=client.replace('--!strict\n','--!strict\nrequire(script.Parent.MatrixProbe).begin()\n',1)
if a.startup_clock:
 mark='require(script.Parent.MatrixProbe)'
 anchors={
  'local M = {':mark+'.mark("direct-imports-done")\nlocal M = {',
  'M.lock = M.LockOn.new()':mark+'.mark("module-table-done")\nM.lock = M.LockOn.new()',
  'World = require(script.Parent.WorldClient).new(Workspace, Players.LocalPlayer),':'World = '+mark+'.call("world-client",function()local module='+mark+'.call("world-client-import",function()return require(script.Parent.WorldClient)end);return '+mark+'.call("world-client-new",function()return module.new(Workspace, Players.LocalPlayer)end)end),',
  'local rig = SpiderRig.new(Workspace, M.World.root, appearance, detail)':'local rig = '+mark+'.call("spider-rig",function()return SpiderRig.new(Workspace, M.World.root, appearance, detail)end)',
  'M.World:streamLooks(Workspace, detail)':mark+'.call("stream-looks",function()M.World:streamLooks(Workspace, detail)end)',
  'local hud = SpiderHud.new(player:WaitForChild("PlayerGui"))':'local hud = '+mark+'.call("hud",function()return SpiderHud.new(player:WaitForChild("PlayerGui"))end)',
  'local flyBodies = FlyBodies.new(Workspace, detail)':mark+'.mark("animal-bodies-begin")\nlocal flyBodies = FlyBodies.new(Workspace, detail)',
  'M.meal=require(script.Parent.MealPresentation).new(Workspace,M.World.root)':'M.meal=require(script.Parent.MealPresentation).new(Workspace,M.World.root)\n'+mark+'.mark("animal-bodies-end")',
  'local accumulator = 0':mark+'.mark("render-binding-begin")\nlocal accumulator = 0'}
 for old,new in anchors.items():assert client.count(old)==1,old;client=client.replace(old,new)
client+='\nif RunService:IsStudio() and Workspace:GetAttribute("MatrixPerf")==true then task.spawn(function()require(script.Parent.MatrixPlayback)(M.hooks())end)end\n'
source['Client/SpiderClient.client.luau']=client.encode()
if a.startup_clock:
 code=source['Client/WorldClient.luau'].decode()
 anchors={
  'local WorldClient = {}':'local StartupTrace=require(script.Parent.MatrixProbe)\nStartupTrace.mark("world-client-dependencies-ready")\nlocal WorldClient = {}',
  'WorldMap.use(Worlds.choose(named))':'WorldMap.use(Worlds.choose(named))\nStartupTrace.mark("world-map-selected")',
  'local home = m.region(m.HOME) :: WorldMap.Region':'local home = StartupTrace.call("home-region",function()return m.region(m.HOME)end) :: WorldMap.Region',
  'local lo, hi = m.bounds()':'local lo, hi = m.bounds();StartupTrace.mark("world-bounds-ready")',
  'local flat = ws:FindFirstChild(name)':'StartupTrace.mark("home-collision-begin")\nlocal flat = ws:FindFirstChild(name)',
  'if remaining>0 then child=parent:WaitForChild(childName,remaining) end':'if remaining>0 then local started=StartupTrace.elapsed();child=parent:WaitForChild(childName,remaining);StartupTrace.note("REQUIRED_WAIT",{parent=parent.Name,child=childName,began=started,elapsed_ms=(StartupTrace.elapsed()-started)*1000,found=child~=nil})end',
  ' -- Optional visuals arrive independently; only essential collision gates startup.':'StartupTrace.mark("home-pieces-ready")\n -- Optional visuals arrive independently; only essential collision gates startup.',
  'pcall(function() player:SetAttribute(WorldClient.FAIL_ATTRIBUTE,false) end)':'StartupTrace.mark("home-collision-end")\npcall(function() player:SetAttribute(WorldClient.FAIL_ATTRIBUTE,false) end)'}
 for old,new in anchors.items():assert code.count(old)==1,old;code=code.replace(old,new)
 source['Client/WorldClient.luau']=code.encode()
 code=source['Server/Main.server.luau'].decode()
 anchors={'local Habitat =':('imports-begin',None),'Players.CharacterAutoLoads = false':('imports-end',None),
  'local decorOk, decor, replaced = pcall(Scenery.decor, if litOk and sun.ok then sun.direction else nil, worldId)':('decor-begin','decor-end'),
  'local hidden: { [string]: boolean } = {}':('hidden-plan-begin',None),
  'WorldBuild.world(Workspace, WorldMap.SEED, hidden)':('physical-world-begin','physical-world-end')}
 for anchor,(before,after)in anchors.items():
  assert code.count(anchor)==1,anchor
  def server_mark(label):return 'print("[STARTUP_SERVER_MARK]",game:GetService("HttpService"):JSONEncode({name="'+label+'",at=workspace:GetServerTimeNow(),clock=os.clock(),heap_kb=gcinfo()}))'
  code=code.replace(anchor,server_mark(before)+'\n'+anchor+('\n'+server_mark(after)if after else ''))
 source['Server/Main.server.luau']=code.encode()
source['Server/NormalStartupDiagnosticStorage.luau']=(ROOT/'docs/normal-startup/diagnostic-storage.luau').read_bytes()
persistence=source['Server/Persistence.server.luau'].decode()
start=persistence.index('local function loadStore()');end=persistence.index('local dataStore,available=loadStore()',start)
persistence=persistence[:start]+'local function loadStore(): (any,any) return require(script.Parent.NormalStartupDiagnosticStorage).loadStore() end\n'+persistence[end:]
persistence=persistence.replace('local DataStores=game:GetService("DataStoreService")\n','').replace('local runTag=tostring(os.time())\n','')
old='local keyOf=if testPlace then function(player:any):string return '+chr(96)+'t{runTag}_{player.UserId}'+chr(96)+' end else nil'
assert persistence.count(old)==1
persistence=persistence.replace(old,'local keyOf=function(_player:any):string return "qa_normal_startup" end')
old='composition=Composition.new(config);service=composition.service'
assert persistence.count(old)==1
persistence=persistence.replace(old,old+';require(script.Parent.NormalStartupDiagnosticStorage).observe(composition)')
assert 'DataStoreService'not in persistence and ':GetDataStore('not in persistence and 'GetRequestBudgetForRequestType'not in persistence
source['Server/Persistence.server.luau']=persistence.encode()
source_count=276+(1 if a.long_trace_seconds else 0)
assert len(source)==source_count and not any('SilkPlayback'in k for k in source)
for rel,data in source.items():
 f=out/'src'/rel;f.parent.mkdir(parents=True,exist_ok=True);f.write_bytes(data)
project=json.loads((PORT/'default.project.json').read_text())
project['name']='WindowsillMatrix_'+a.variant+'_'+a.tier
for role,node in [('First',project['tree']['ReplicatedFirst']),('Shared',project['tree']['ReplicatedStorage']['Shared']),('Client',project['tree']['StarterPlayer']['StarterPlayerScripts']['Client'])]:node['$path']=str(out/'src'/role)
project['tree']['ServerScriptService']['Server']={'$path':str(out/'src/Server'),'$ignoreUnknownInstances':False}
assert 'PortTests'not in project['tree']['ServerScriptService']
attrs=project['tree']['Workspace']['$attributes']
attrs.update(World='preserve',Detail=a.tier,SelfTest=False,TestTarget=False,SaveWait=True,NormalStartupDiagnostic=True,DiagnosticUnavailable=False,OrdinaryPerf=True,MatrixPerf=True,MatrixVariant=a.variant)
if a.startup_clock:attrs['StartupClock']=True
if a.seam_group:attrs['SeamGroup']=a.seam_group
config=out/'matrix.project.json';config.write_bytes((json.dumps(project,indent=2)+'\n').encode())
errors=[]
for rel in source:
 r=subprocess.run([str(TOOLS/'luau/luau-compile.exe'),'--null',str(out/'src'/rel)],capture_output=True,text=True)
 if r.returncode:errors.append(rel+'\n'+r.stdout+r.stderr)
(out/'compile.txt').write_bytes((f'compile {len(source)-len(errors)}/{len(source)}\n'+'\n'.join(errors)).encode());assert not errors,errors
for name,command in [('sourcemap',[str(TOOLS/'rojo/rojo.exe'),'sourcemap',str(config),'--output',str(out/'sourcemap.json')]),('strict',[str(TOOLS/'lsp/luau-lsp.exe'),'analyze','--sourcemap='+str(out/'sourcemap.json'),'--definitions='+str(TOOLS/'globalTypes.d.luau'),'--no-strict-dm-types',str(out/'src')])]:
 r=subprocess.run(command,cwd=out,capture_output=True,text=True);text=r.stdout+r.stderr
 (out/(name+'.txt')).write_bytes(text.encode());print(name,r.returncode,text[:1400],flush=True);assert r.returncode==0
place=out/'Windowsill-matrix.rbxlx';subprocess.run([str(TOOLS/'rojo/rojo.exe'),'build',str(config),'-o',str(place)],check=True)
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
def name(rel):
 parts=Path(rel).parts;return '.'.join([prefix[parts[0]],*parts[1:-1],parts[-1][:-5].removesuffix('.server').removesuffix('.client')])
expected={name(k):v.replace(b'\r\n',b'\n')for k,v in source.items()};actual={};disabled=[]
def walk(item,parent=''):
 props=item.find('Properties');path=(parent+'.'if parent else '')+props.findtext("string[@name='Name']")
 text=props.find("*[@name='Source']")
 if text is not None:actual[path]=(text.text or '').replace('\r\n','\n').encode()
 if item.attrib['class']in ['Script','LocalScript']:disabled.append(props.findtext("bool[@name='Disabled']")=='true')
 for child in item.findall('Item'):walk(child,path)
for item in ET.parse(place).getroot().findall('Item'):walk(item)
assert expected==actual and not any(disabled)
rows=[[key,len(data),zlib.adler32(data)]for key,data in sorted(expected.items())]
guard='assert(game.PlaceId==0 and game.GameId==0 and not game:GetService("RunService"):IsRunning());assert(workspace:GetAttribute("MatrixPerf")==true and workspace:GetAttribute("Detail")=="'+a.tier+'");local expected='+json.dumps(rows,separators=(',',':')).replace('[','{').replace(']','}')+';'
if a.seam_group:guard='assert(workspace:GetAttribute("SeamGroup")=='+json.dumps(a.seam_group)+');'+guard
guard+='for _,r in expected do local it=game;for n in string.gmatch(r[1],"[^.]+")do it=assert(it:FindFirstChild(n),r[1])end;local s=string.gsub(it.Source,"\\r\\n","\\n");local x,y=1,0;for i=1,#s do x=(x+string.byte(s,i))%65521;y=(y+x)%65521 end;assert(#s==r[2] and y*65536+x==r[3],r[1])end;assert(not game.ServerScriptService.Server.Persistence.Disabled);print("[MATRIX_GUARD]",'+str(source_count)+',"'+a.variant+'","'+a.tier+'","unbound memory_only")'
(out/'guard.luau').write_bytes((guard+'\n').encode())
manifest=dict(revision=revision,variant=a.variant,tier=a.tier,seam_group=a.seam_group,startup_clock=a.startup_clock,startup_profile=a.startup_clock,startup_waits=a.startup_clock,decor_nonblocking=True,playback_source=str(a.playback_source.resolve()),place=str(place),place_sha256=sha(place.read_bytes()),sources={k:sha(v)for k,v in expected.items()},original_sources={k:sha(v)for k,v in original.items()},guard_sha256=sha((out/'guard.luau').read_bytes()),source_count=source_count,long_trace_seconds=a.long_trace_seconds,published=False,storage='unbound yielding memory only',limits='Controlled scene fixtures, not natural lives, online saves or physical phones.')
(out/'manifest.json').write_bytes((json.dumps(manifest,indent=2)+'\n').encode())
print(json.dumps(dict(place=str(place),sha256=manifest['place_sha256'],sources=source_count,variant=a.variant,tier=a.tier)),flush=True)
