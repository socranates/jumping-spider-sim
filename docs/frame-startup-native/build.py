"""Make an unbound, storage-disabled frame probe over exact current production sources."""
from pathlib import Path
import argparse,hashlib,io,json,subprocess,tarfile,xml.etree.ElementTree as ET,zlib
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
TOOLS=Path('C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
SOURCE='bd67582b5d53473f067244fc1e2e1f94adde173b';sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args();out=a.out.resolve()
assert out.parent.is_dir() and not out.exists();out.mkdir();src=out/'src';expected={}
raw=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src','roblox_port/default.project.json'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
 for member in archive:
  if not member.isfile():continue
  data=archive.extractfile(member).read()
  if member.name.endswith('default.project.json'):project=json.loads(data);continue
  expected[Path(member.name).relative_to('roblox_port/src').as_posix()]=data
assert len(expected)==224
expected['Client/SilkPlayback.luau']=(H/'playback.luau').read_bytes()
for rel,data in expected.items():
 path=src/rel;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
for role,node in [('First',project['tree']['ReplicatedFirst']),('Shared',project['tree']['ReplicatedStorage']['Shared']),('Client',project['tree']['StarterPlayer']['StarterPlayerScripts']['Client'])]:node['$path']=str(src/role)
server={'$className':'Folder','$ignoreUnknownInstances':False}
for path in sorted((src/'Server').glob('*.luau')):
 name=path.name.removesuffix('.luau').removesuffix('.server');server[name]={'$path':str(path)}
 if name=='Persistence':server[name]['$properties']={'Disabled':True}
project['tree']['ServerScriptService']['Server']=server
project['name']='WindowsillFrameDiagnostic'
project['tree']['Workspace']['$attributes']={'World':'preserve','Detail':'full','SelfTest':False,'TestTarget':False,'SaveWait':False,'StartupPerf':True}
config=out/'diagnostic.project.json';config.write_text(json.dumps(project,indent=2)+'\n',encoding='utf8',newline='\n')
errors=[]
for rel in expected:
 r=subprocess.run([str(TOOLS/'luau/luau-compile.exe'),'--null',str(src/rel)],capture_output=True,text=True)
 if r.returncode:errors.append(rel+'\n'+r.stdout+r.stderr)
(out/'compile.txt').write_text(f'compile {len(expected)-len(errors)}/{len(expected)}\n'+'\n'.join(errors),encoding='utf8',newline='\n');assert not errors,errors
for name,command in [('sourcemap',[str(TOOLS/'rojo/rojo.exe'),'sourcemap',str(config),'--output',str(out/'sourcemap.json')]),('strict',[str(TOOLS/'lsp/luau-lsp.exe'),'analyze','--sourcemap='+str(out/'sourcemap.json'),'--definitions='+str(TOOLS/'globalTypes.d.luau'),'--no-strict-dm-types',str(src)])]:
 r=subprocess.run(command,cwd=out,capture_output=True,text=True);text=r.stdout+r.stderr
 (out/(name+'.txt')).write_text(text,encoding='utf8',newline='\n');print(name,r.returncode,text[:1500],flush=True);assert r.returncode==0
place=out/'Windowsill-frame-diagnostic.rbxlx';subprocess.run([str(TOOLS/'rojo/rojo.exe'),'build',str(config),'-o',str(place)],check=True)
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
assert actual==wanted and sum(flag for _,flag in disabled)==1 and ['ServerScriptService.Server.Persistence',True] in disabled
rows=[[name,len(data),zlib.adler32(data)] for name,data in sorted(wanted.items())]
guard='assert(game.PlaceId==0 and game.GameId==0 and not game:GetService("RunService"):IsRunning());assert(workspace:GetAttribute("StartupPerf")==true and workspace:GetAttribute("Detail")=="full");local expected='+json.dumps(rows,separators=(',',':')).replace('[','{').replace(']','}')+';'
guard+='for _,r in expected do local it=game;for name in string.gmatch(r[1],"[^.]+") do it=assert(it:FindFirstChild(name),r[1]) end;local s=string.gsub(it.Source,"\\r\\n","\\n");local a,b=1,0;for i=1,#s do a=(a+string.byte(s,i))%65521;b=(b+a)%65521 end;assert(#s==r[2] and b*65536+a==r[3],r[1]) end;assert(game.ServerScriptService.Server.Persistence.Disabled);print("[STARTUP_FRAME_GUARD]",225,"unbound storage_disabled full_detail")'
(out/'guard.luau').write_text(guard+'\n',encoding='utf8',newline='\n')
manifest=dict(source=SOURCE,place=str(place),place_sha256=sha(place.read_bytes()),sources={name:sha(data) for name,data in wanted.items()},guard_sha256=sha((out/'guard.luau').read_bytes()),diagnostic_sha256=sha((H/'playback.luau').read_bytes()),source_count=225,production_unchanged=224,storage_disabled=True,executed=False,published=False)
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps({key:manifest[key] for key in ['place','place_sha256','source_count','production_unchanged']},indent=2))
