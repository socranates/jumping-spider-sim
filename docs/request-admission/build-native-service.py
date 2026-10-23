"""Build the exact qualified 51-target overlay in a new unbound native place."""
from pathlib import Path
import argparse,hashlib,importlib.util,io,json,subprocess,sys,tarfile,xml.etree.ElementTree as ET,zlib
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
TOOLS=Path('C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
SOURCE='bd67582b5d53473f067244fc1e2e1f94adde173b'
sha=lambda b:hashlib.sha256(b).hexdigest()
def load():
 spec=importlib.util.spec_from_file_location('native_service_types',H/'check-service.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m.checker().paths()
def normalized(rel,path):
 text=path.read_text(encoding='utf8')
 if path.name in ['worker-v3.luau','operation.luau']:
  assert text.count('require("./worker-facade")')==1
  text=text.replace('require("./worker-facade")','require(script.Parent.RequestAdmissionFacade)')
 return text.encode('utf8')
def instance_path(rel):
 p=list(Path(rel).parts);leaf=p[-1][:-5]
 for suffix in ['.server','.client']:
  if leaf.endswith(suffix):leaf=leaf[:-len(suffix)]
 prefixes={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
 return '.'.join([prefixes[p[0]],*p[1:-1],leaf])
def inputs():
 paths=load();production={};project=None
 raw=subprocess.check_output(['git','archive','--format=tar',SOURCE,'roblox_port/src','roblox_port/default.project.json'],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
  for member in archive:
   if not member.isfile():continue
   data=archive.extractfile(member).read()
   if member.name.endswith('default.project.json'):project=json.loads(data);continue
   production[Path(member.name).relative_to('roblox_port/src').as_posix()]=data
 assert len(production)==224
 overrides=sorted(rel for rel in paths if rel in production)
 expected=production.copy()
 for rel,path in paths.items():expected[rel]=normalized(rel,path)
 diagnostics={'Client/SilkPlayback.luau':H/'native-service-client.luau','Server/NewApplicationNative.server.luau':H/'native-service-server.server.luau'}
 for rel,path in diagnostics.items():assert rel not in expected;expected[rel]=path.read_bytes()
 return paths,production,project,overrides,diagnostics,expected
def main():
 p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args();out=a.out.resolve();assert out.parent.is_dir() and not out.exists()
 subprocess.run([sys.executable,str(H/'prepare-native-service.py'),'--check'],check=True)
 verification=json.loads((H/'service-verification.json').read_text(encoding='utf8'))
 assert verification['private_inputs_committed'] and verification['full_failed']==0 and verification['full_checks']==289497
 paths,production,project,overrides,diagnostics,expected=inputs()
 qualified=json.loads((H/'service-types-qualified-1-types.json').read_text(encoding='utf8'))
 assert qualified['mounted']=={rel:sha(normalized(rel,path)) for rel,path in paths.items()}
 for path in set(paths.values()):
  assert subprocess.check_output(['git','show',verification['private_commit']+':'+path.relative_to(ROOT).as_posix()],cwd=ROOT)==path.read_bytes()
 out.mkdir();src=out/'src'
 for rel,data in expected.items():
  path=src/rel;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
 for role,node in [('First',project['tree']['ReplicatedFirst']),('Shared',project['tree']['ReplicatedStorage']['Shared']),('Server',project['tree']['ServerScriptService']['Server']),('Client',project['tree']['StarterPlayer']['StarterPlayerScripts']['Client'])]:node['$path']=str(src/role)
 project['tree']['Workspace']['$attributes']={'World':'preserve','Detail':'low','SelfTest':False,'TestTarget':False,'NewApplicationNative':True,'SaveWait':True,'Wasp':False,'Cat':False,'Bird':False,'Frog':False}
 config=out/'native.project.json';config.write_text(json.dumps(project,indent=2)+'\n',encoding='utf8',newline='\n')
 errors=[]
 for rel in expected:
  r=subprocess.run([str(TOOLS/'luau/luau-compile.exe'),'--null',str(src/rel)],capture_output=True,text=True)
  if r.returncode:errors.append(rel+'\n'+r.stdout+r.stderr)
 (out/'compile.txt').write_text(f'compile {len(expected)-len(errors)}/{len(expected)}\n'+'\n'.join(errors),encoding='utf8');assert not errors,errors
 steps=[]
 for name,cmd in [('sourcemap',[str(TOOLS/'rojo/rojo.exe'),'sourcemap',str(config),'--output',str(out/'sourcemap.json')]),('strict',[str(TOOLS/'lsp/luau-lsp.exe'),'analyze','--sourcemap='+str(out/'sourcemap.json'),'--definitions='+str(TOOLS/'globalTypes.d.luau'),'--no-strict-dm-types',str(src)])]:
  r=subprocess.run(cmd,cwd=out,capture_output=True,text=True);text=r.stdout+r.stderr
  (out/(name+'.txt')).write_text(text,encoding='utf8',newline='\n');steps.append(dict(name=name,exit_code=r.returncode,sha256=sha(text.encode())))
  print(name,r.returncode,text[:4000],flush=True);assert r.returncode==0,'Preserve diagnostic artifacts; repair before Play'
 place=out/'Windowsill-native-service.rbxlx';subprocess.run([str(TOOLS/'rojo/rojo.exe'),'build',str(config),'-o',str(place)],check=True)
 tree=ET.parse(place);actual={};disabled=[]
 def walk(item,parent=''):
  props=item.find('Properties');name=props.findtext("string[@name='Name']");path=parent+'.'+name if parent else name
  if item.attrib['class'] in ['Script','LocalScript']:
   flag=props.find("bool[@name='Disabled']")
   if flag is None:flag=ET.SubElement(props,'bool',{'name':'Disabled'})
   value=path=='ServerScriptService.Server.Persistence';flag.text=str(value).lower();disabled.append([path,value])
  code=props.find("*[@name='Source']")
  if code is not None:actual[path]=(code.text or '').replace('\r\n','\n').encode()
  for child in item.findall('Item'):walk(child,path)
 for item in tree.getroot().findall('Item'):walk(item)
 wanted={instance_path(rel):data.replace(b'\r\n',b'\n') for rel,data in expected.items()}
 assert actual==wanted and sum(value for _,value in disabled)==1
 tree.write(place,encoding='utf8',xml_declaration=False)
 rows=[dict(path=path,length=len(data),adler32=zlib.adler32(data),sha256=sha(data)) for path,data in actual.items()]
 guard='assert(game.PlaceId==0 and not game:GetService("RunService"):IsRunning() and workspace:GetAttribute("NewApplicationNative")==true and workspace:GetAttribute("SelfTest")==false);local expected={'
 guard+=','.join('{'+json.dumps(row['path'])+','+str(row['length'])+','+str(row['adler32'])+'}' for row in rows)+'};'
 guard+='for _,r in expected do local it=game;for name in string.gmatch(r[1],"[^.]+") do it=assert(it:FindFirstChild(name),r[1]) end;local s=string.gsub(it.Source,"\\r\\n","\\n");local a,b=1,0;for i=1,#s do a=(a+string.byte(s,i))%65521;b=(b+a)%65521 end;assert(#s==r[2] and b*65536+a==r[3],r[1]) end;'
 guard+='local disabled='+json.dumps(disabled,separators=(',',':')).replace('[','{').replace(']','}')+';for _,r in disabled do local it=game;for name in string.gmatch(r[1],"[^.]+") do it=assert(it:FindFirstChild(name)) end;assert(it.Disabled==r[2],r[1]) end;'
 guard+='local n=0;for _,root in {game.ReplicatedFirst,game.ReplicatedStorage.Shared,game.ServerScriptService.Server,game.StarterPlayer.StarterPlayerScripts.Client} do for _,it in root:GetDescendants() do if it:IsA("LuaSourceContainer") then n+=1 end end end;assert(n=='+str(len(rows))+');print("[NATIVE_SERVICE_GUARD]","'+SOURCE+'",n,"memory_only unbound do_not_publish")'
 (out/'guard.luau').write_text(guard,encoding='utf8',newline='\n')
 unchanged=sum(rel in production and data==production[rel] for rel,data in expected.items())
 manifest=dict(source=SOURCE,place=str(place),scripts=rows,script_count=len(rows),untouched_production=unchanged,production_overrides=overrides,
  private_targets={rel:dict(path=path.relative_to(ROOT).as_posix(),source_sha256=sha(path.read_bytes()),mounted_sha256=sha(normalized(rel,path))) for rel,path in paths.items()},
  diagnostic_inputs={path.relative_to(ROOT).as_posix():sha(path.read_bytes()) for path in diagnostics.values()},disabled_scripts=disabled,
  place_sha256=sha(place.read_bytes()),guard_sha256=sha(guard.encode()),static_steps=steps,clock_scale=1,memory_store=True,engine_codec=True,production_persistence_disabled=True,executed=False,published=False)
 (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8',newline='\n')
 print(json.dumps({key:manifest[key] for key in ['place','script_count','untouched_production','production_overrides','place_sha256']},indent=2))
if __name__=='__main__':main()
