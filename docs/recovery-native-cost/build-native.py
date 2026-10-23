"""Build a fingerprinted, unpublished native application/real-remote fixture."""
from pathlib import Path
import argparse,ast,hashlib,io,json,subprocess,sys,tarfile,zlib,xml.etree.ElementTree as ET
H=Path(__file__).resolve().parent;ROOT=H.parents[1];P=ROOT/'docs/save-slot-isolation'
SOURCE='bd67582b5d53473f067244fc1e2e1f94adde173b'
TOOLS=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
sha=lambda b:hashlib.sha256(b).hexdigest()
parser=argparse.ArgumentParser();parser.add_argument('--out',required=True);a=parser.parse_args()
out=Path(a.out).resolve();assert out.parent.is_dir() and not out.exists(),'Dedicated new artifact directory required'
subprocess.run([sys.executable,str(ROOT/'docs/new-life-application/verify-private.py')],cwd=ROOT,check=True,capture_output=True)
types=json.loads((ROOT/'docs/new-life-policy/new-application-types-1-types.json').read_text())
assert types['source']==SOURCE and len(types['candidates'])==41
tree=ast.parse((P/'check-recovery-pipeline.py').read_text())
names=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='names' for t in n.targets))
for filename in ['check-recovery-game-entry.py','check-recovery-profile-owner.py']:
 for node in ast.parse((P/filename).read_text()).body:
  if isinstance(node,ast.Assign) and isinstance(node.targets[0],ast.Subscript) and isinstance(node.targets[0].value,ast.Name) and node.targets[0].value.id=='names':names[ast.literal_eval(node.targets[0].slice)]=ast.literal_eval(node.value)
names.update({'Shared/Persistence/ReplacementProtocolPrototype.luau':'replacement-protocol-prototype.luau','Server/ReplacementOwnerPrototype.luau':'replacement-owner-prototype.luau','Server/ReplacementServicePrototype.luau':'replacement-service-prototype.luau','Client/ReplacementClientPrototype.luau':'replacement-client-prototype.luau'})
candidates={target:P/name for target,name in names.items()};candidates['Server/RecoveryNewLifePolicyPrototype.luau']=ROOT/'docs/new-life-policy/new-life-policy-prototype.luau'
assert {p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in candidates.values()}==types['candidates']
out.mkdir();src=out/'src';expected={};production={}
raw=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src','roblox_port/default.project.json'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
 for member in archive:
  if not member.isfile():continue
  data=archive.extractfile(member).read()
  if member.name=='roblox_port/default.project.json':project=json.loads(data);continue
  rel=Path(member.name).relative_to('roblox_port/src').as_posix();path=(src/rel).resolve();assert path.is_relative_to(src)
  path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
  if rel.endswith('.luau'):production[rel]=data;expected[rel]=data
assert len(production)==224
for rel,path in candidates.items():
 target=src/rel;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(path.read_bytes());expected[rel]=path.read_bytes()
diagnostics={'Client/SilkPlayback.luau':H/'native-client.luau','Server/NewApplicationNative.server.luau':H/'native-server.server.luau'}
for rel,path in diagnostics.items():(src/rel).write_bytes(path.read_bytes());expected[rel]=path.read_bytes()
assert len(expected)==265 and sum(rel in production and expected[rel]==production[rel] for rel in expected)==222
for role,node in [('First',project['tree']['ReplicatedFirst']),('Shared',project['tree']['ReplicatedStorage']['Shared']),('Server',project['tree']['ServerScriptService']['Server']),('Client',project['tree']['StarterPlayer']['StarterPlayerScripts']['Client'])]:node['$path']=str(src/role)
project['tree']['Workspace']['$attributes']={'World':'preserve','Detail':'low','SelfTest':False,'TestTarget':False,'NewApplicationNative':True,'SaveWait':True,'Wasp':False,'Cat':False,'Bird':False,'Frog':False}
config=out/'native.project.json';config.write_text(json.dumps(project,indent=2)+'\n',encoding='utf8',newline='\n')
compile_errors=[]
for rel in expected:
 r=subprocess.run([str(TOOLS/'luau/luau-compile.exe'),'--null',str(src/rel)],capture_output=True,text=True)
 if r.returncode:compile_errors.append(rel+'\n'+r.stdout+r.stderr)
(out/'compile.txt').write_text('compile '+str(len(expected)-len(compile_errors))+'/265\n'+'\n'.join(compile_errors),encoding='utf8',newline='\n');assert not compile_errors,compile_errors
steps=[]
for name,command in [('sourcemap',[str(TOOLS/'rojo/rojo.exe'),'sourcemap',str(config),'--output',str(out/'sourcemap.json')]),('strict',[str(TOOLS/'lsp/luau-lsp.exe'),'analyze','--sourcemap='+str(out/'sourcemap.json'),'--definitions='+str(TOOLS/'globalTypes.d.luau'),'--no-strict-dm-types',str(src)])]:
 r=subprocess.run(command,cwd=out,capture_output=True,text=True);text=r.stdout+r.stderr
 (out/(name+'.txt')).write_text(text,encoding='utf8',newline='\n');steps.append(dict(name=name,exit_code=r.returncode,sha256=sha(text.encode())))
 print(name,r.returncode,text[:5000],flush=True)
 assert r.returncode==0,'Preserve diagnostic artifacts and repair before Play'
place=out/'Windowsill-native-new-application.rbxlx'
subprocess.run([str(TOOLS/'rojo/rojo.exe'),'build',str(config),'-o',str(place)],check=True)
xml=ET.parse(place);rows=[];disabled=[];by_path={}
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
def instance_path(rel):
 parts=list(Path(rel).parts);leaf=parts[-1][:-5]
 for suffix in ['.server','.client']:
  if leaf.endswith(suffix):leaf=leaf[:-len(suffix)]
 return '.'.join([prefix[parts[0]],*parts[1:-1],leaf])
want={instance_path(rel):value.replace(b'\r\n',b'\n') for rel,value in expected.items()}
def walk(item,parent=''):
 props=item.find('Properties');name=props.findtext("string[@name='Name']");path=parent+'.'+name if parent else name
 if item.attrib['class'] in ['Script','LocalScript']:
  flag=props.find("bool[@name='Disabled']")
  if flag is None:flag=ET.SubElement(props,'bool',{'name':'Disabled'})
  value=path=='ServerScriptService.Server.Persistence';flag.text=str(value).lower();disabled.append([path,value])
 code=props.find("*[@name='Source']")
 if code is not None:
  data=(code.text or '').replace('\r\n','\n').encode();by_path[path]=data;rows.append(dict(path=path,length=len(data),adler32=zlib.adler32(data),sha256=sha(data)))
 for child in item.findall('Item'):walk(child,path)
for item in xml.getroot().findall('Item'):walk(item)
assert len(rows)==265 and by_path==want and sum(row[1] for row in disabled)==1
xml.write(place,encoding='utf8',xml_declaration=False)
guard='assert(game.PlaceId==0 and not game:GetService("RunService"):IsRunning() and workspace:GetAttribute("NewApplicationNative")==true and workspace:GetAttribute("SelfTest")==false);local expected={'
guard+=','.join('{'+json.dumps(r['path'])+','+str(r['length'])+','+str(r['adler32'])+'}' for r in rows)+'};'
guard+='for _,r in expected do local it=game;for name in string.gmatch(r[1],"[^.]+") do it=assert(it:FindFirstChild(name),r[1]) end;local s=string.gsub(it.Source,"\\r\\n","\\n");local a,b=1,0;for i=1,#s do a=(a+string.byte(s,i))%65521;b=(b+a)%65521 end;assert(#s==r[2] and b*65536+a==r[3],r[1]) end;local disabled='+json.dumps(disabled,separators=(',',':')).replace('[','{').replace(']','}')+';'
guard+='for _,r in disabled do local it=game;for name in string.gmatch(r[1],"[^.]+") do it=assert(it:FindFirstChild(name)) end;assert(it.Disabled==r[2],r[1]) end;local n=0;for _,root in {game.ReplicatedFirst,game.ReplicatedStorage.Shared,game.ServerScriptService.Server,game.StarterPlayer.StarterPlayerScripts.Client} do for _,it in root:GetDescendants() do if it:IsA("LuaSourceContainer") then n+=1 end end end;assert(n==265);print("[NEW_APP_NATIVE_GUARD]","'+SOURCE+'",n,"memory_only unbound do_not_publish")'
(out/'guard.luau').write_text(guard,encoding='utf8',newline='\n')
manifest=dict(source=SOURCE,place=str(place),scripts=rows,script_count=265,untouched_production=222,production_overrides=['Shared/World/WorldMap.luau','Shared/Persistence/Checkpoint.luau'],private_candidates=types['candidates'],diagnostic_inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes()) for p in diagnostics.values()},disabled_scripts=disabled,place_sha256=sha(place.read_bytes()),guard_sha256=sha(guard.encode()),static_steps=steps,clock_scale=10,memory_store=True,engine_codec=True,production_persistence_disabled=True,executed=False,published=False)
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(dict(place=str(place),scripts=265,untouched_production=222,place_sha256=manifest['place_sha256']),indent=2))
