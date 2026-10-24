"""Assemble the complete playable candidate, without diagnostic overrides/publishing."""
from pathlib import Path
import argparse,hashlib,importlib.util,io,json,subprocess,tarfile,xml.etree.ElementTree as ET,zlib
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
TOOLS=Path('C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
BASE='bd67582b5d53473f067244fc1e2e1f94adde173b';sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args();out=a.out.resolve()
assert out.parent.is_dir() and not out.exists();out.mkdir();port=out/'roblox_port';port.mkdir();expected={}
raw=subprocess.check_output(['git','archive','--format=tar',BASE,'roblox_port/src','roblox_port/default.project.json'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw))as archive:
 for member in archive:
  if not member.isfile():continue
  data=archive.extractfile(member).read()
  if member.name.endswith('default.project.json'):project=json.loads(data);continue
  expected[Path(member.name).relative_to('roblox_port/src').as_posix()]=data
assert len(expected)==224
spec=importlib.util.spec_from_file_location('integrated_mounts',H.parent/'normal-startup/check-legacy.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
paths=m.checker.paths();assert len(paths)==56
paths['Shared/World/LookPlan.luau']=H.parent/'frame-ordinary/look-plan.luau'
for rel,path in paths.items():
 code=path.read_text(encoding='utf8')
 if path.name in ['worker-v3.luau','operation.luau']:code=code.replace('require("./worker-facade")','require(script.Parent.RequestAdmissionFacade)')
 expected[rel]=code.encode()
assert len(expected)==273
for rel,data in expected.items():
 path=port/'src'/rel;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
tip=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
raw=subprocess.check_output(['git','archive','--format=tar',tip,'roblox_port/tests','roblox_port/tools','roblox_port/tests.project.json'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw))as archive:
 for member in archive:
  if not member.isfile():continue
  path=out/member.name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(archive.extractfile(member).read())
for role,node in [('First',project['tree']['ReplicatedFirst']),('Shared',project['tree']['ReplicatedStorage']['Shared']),('Client',project['tree']['StarterPlayer']['StarterPlayerScripts']['Client'])]:node['$path']=str(port/'src'/role)
server={'$className':'Folder','$ignoreUnknownInstances':False}
for path in sorted((port/'src/Server').glob('*.luau')):
 name=path.name.removesuffix('.luau').removesuffix('.server');server[name]={'$path':str(path)}
 if name=='Persistence':server[name]['$properties']={'Disabled':False}
project['tree']['ServerScriptService']['Server']=server
project['name']='TheWindowsillIntegratedCandidate'
project['tree']['Workspace']['$attributes']={'World':'preserve','SelfTest':False,'TestTarget':False,'SaveWait':True}
config=port/'default.project.json';config.write_bytes((json.dumps(project,indent=2)+'\n').encode())
errors=[]
for rel in expected:
 r=subprocess.run([str(TOOLS/'luau/luau-compile.exe'),'--null',str(port/'src'/rel)],capture_output=True,text=True)
 if r.returncode:errors.append(rel+'\n'+r.stdout+r.stderr)
(out/'compile.txt').write_bytes((f'compile {len(expected)-len(errors)}/{len(expected)}\n'+'\n'.join(errors)).encode());assert not errors,errors
for name,cmd in [('sourcemap',[str(TOOLS/'rojo/rojo.exe'),'sourcemap',str(config),'--output',str(port/'sourcemap.json')]),('strict',[str(TOOLS/'lsp/luau-lsp.exe'),'analyze','--sourcemap='+str(port/'sourcemap.json'),'--definitions='+str(TOOLS/'globalTypes.d.luau'),'--no-strict-dm-types',str(port/'src')])]:
 r=subprocess.run(cmd,cwd=port,capture_output=True,text=True);text=r.stdout+r.stderr;(out/(name+'.txt')).write_bytes(text.encode());print(name,r.returncode,text[:1000],flush=True);assert r.returncode==0
place=out/'TheWindowsill-candidate.rbxlx';subprocess.run([str(TOOLS/'rojo/rojo.exe'),'build',str(config),'-o',str(place)],check=True)
actual={};disabled=[]
def walk(item,parent=''):
 props=item.find('Properties');name=props.findtext("string[@name='Name']");path=parent+'.'+name if parent else name
 source=props.find("*[@name='Source']")
 if source is not None:actual[path]=(source.text or '').replace('\r\n','\n').encode()
 if item.attrib['class']in ['Script','LocalScript']:disabled.append([path,props.findtext("bool[@name='Disabled']")=='true'])
 for child in item.findall('Item'):walk(child,path)
for item in ET.parse(place).getroot().findall('Item'):walk(item)
def target(rel):
 parts=Path(rel).parts;prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}[parts[0]]
 return '.'.join([prefix,*parts[1:-1],parts[-1][:-5].removesuffix('.server').removesuffix('.client')])
wanted={target(rel):data.replace(b'\r\n',b'\n')for rel,data in expected.items()}
assert actual==wanted and not any(flag for _,flag in disabled)
assert not any(word in '\n'.join(actual)for word in ['Diagnostic','SilkPlayback','StartupPerfProbe','PortTests'])
guard='assert(not game:GetService("RunService"):IsRunning() and game.PlaceId==0 and game.GameId==0);local expected='+json.dumps([[k,len(v),zlib.adler32(v)]for k,v in sorted(wanted.items())],separators=(',',':')).replace('[','{').replace(']','}')+';'
guard+='for _,r in expected do local it=game;for n in string.gmatch(r[1],"[^.]+")do it=assert(it:FindFirstChild(n),r[1])end;local s=string.gsub(it.Source,"\\r\\n","\\n");local a,b=1,0;for i=1,#s do a=(a+string.byte(s,i))%65521;b=(b+a)%65521 end;assert(#s==r[2]and b*65536+a==r[3],r[1])end;assert(not game.ServerScriptService.Server.Persistence.Disabled);print("[INTEGRATED_PLAYABLE_GUARD]",273,"clean_unbound_candidate_no_diagnostics")'
(out/'guard.luau').write_bytes(guard.encode())
manifest=dict(base=BASE,source_tip=tip,place=str(place),place_sha256=sha(place.read_bytes()),source_count=273,
 sources={name:sha(data)for name,data in wanted.items()},overlays={rel:dict(source=path.relative_to(ROOT).as_posix(),sha256=sha(path.read_bytes()))for rel,path in paths.items()},
 guard_sha256=sha(guard.encode()),diagnostics=False,detail='automatic device tier',storage='normal engine selection',published=False,executed=False)
(out/'manifest.json').write_bytes((json.dumps(manifest,indent=2)+'\n').encode());print(json.dumps({k:manifest[k]for k in ['place','source_count','place_sha256','diagnostics']},indent=2))
