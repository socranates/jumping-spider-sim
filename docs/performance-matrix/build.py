"""Build unpublished unbound benchmark models from ordinary source.
Only LookPlan differs between before/after. No upload or external save access.
"""
from pathlib import Path
import argparse,hashlib,json,subprocess,xml.etree.ElementTree as ET,zlib
H=Path(__file__).resolve().parent;ROOT=H.parents[1];PORT=ROOT/'roblox_port'
TOOLS=Path('C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);p.add_argument('--tier',choices=['full','low'],required=True);p.add_argument('--variant',choices=['before','after'],required=True);p.add_argument('--long-trace-seconds',type=int,default=0);p.add_argument('--playback-source',type=Path,default=H/'playback.luau');p.add_argument('--seam-group',choices=['northern','hut_perimeter']);a=p.parse_args()
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
client+='\nif RunService:IsStudio() and Workspace:GetAttribute("MatrixPerf")==true then task.spawn(function()require(script.Parent.MatrixPlayback)(M.hooks())end)end\n'
source['Client/SpiderClient.client.luau']=client.encode()
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
manifest=dict(revision=revision,variant=a.variant,tier=a.tier,seam_group=a.seam_group,playback_source=str(a.playback_source.resolve()),place=str(place),place_sha256=sha(place.read_bytes()),sources={k:sha(v)for k,v in expected.items()},original_sources={k:sha(v)for k,v in original.items()},guard_sha256=sha((out/'guard.luau').read_bytes()),source_count=source_count,long_trace_seconds=a.long_trace_seconds,published=False,storage='unbound yielding memory only',limits='Controlled scene fixtures, not natural lives, online saves or physical phones.')
(out/'manifest.json').write_bytes((json.dumps(manifest,indent=2)+'\n').encode())
print(json.dumps(dict(place=str(place),sha256=manifest['place_sha256'],sources=source_count,variant=a.variant,tier=a.tier)),flush=True)
