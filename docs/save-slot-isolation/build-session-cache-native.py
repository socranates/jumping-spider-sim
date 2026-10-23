"""Frozen checkpoint fixtures + real adapter/session, all production scripts disabled."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,shutil,subprocess,tempfile,zlib,xml.etree.ElementTree as ET
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];PORT=ROOT/'roblox_port'
p=argparse.ArgumentParser();p.add_argument('--out',required=True);a=p.parse_args()
out=Path(a.out).resolve();assert not out.exists();out.mkdir(parents=True)
TOOLS=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
types=json.loads((HERE/'session-fresh-types.json').read_text());assert len(types['steps'])==4 and all(x['exit_code']==0 for x in types['steps'])
for name,digest in types['candidates'].items():assert hashlib.sha256((HERE/name).read_bytes()).hexdigest()==digest
assert json.loads((HERE/'session-adapter-receipt.json').read_text())['exit_code']==0
spec=importlib.util.spec_from_file_location('runner',PORT/'tests/run.py');r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)
fixture=(PORT/'tests/state.luau').read_text(encoding='utf8');prefix=fixture[:fixture.index('-- ---------------------------------------------------------------------------------------------- sizes, measured')]
export='''local records={};for _,mode in {"main","free","easy"} do records[mode]={};for ticks=1,2 do records[mode][tostring(ticks)]=realRest(ticks,mode) end end;print("SESSION_FIXTURES "..assert(Json.canonical(records)))'''
text=r.bundle('state.luau');suffix=r.requires(fixture)+'\n';assert text.endswith(suffix)
text=text[:-len(suffix)]+r.requires(prefix+export)+'\n'
with tempfile.NamedTemporaryFile('w',suffix='.luau',encoding='utf8',delete=False) as f:f.write(text);path=Path(f.name)
try:result=subprocess.run([str(TOOLS/'luau/luau.exe'),str(path)],capture_output=True,text=True,check=True)
finally:path.unlink(missing_ok=True)
raw=result.stdout.removeprefix('SESSION_FIXTURES ').strip();records=json.loads(raw);assert set(records)=={'main','free','easy'} and ']==]' not in raw
fixtureModule='return game:GetService("HttpService"):JSONDecode([==['+raw+']==])\n'
(HERE/'session-native-fixtures.json').write_text(raw+'\n',encoding='utf8',newline='\n')
(out/'SessionFixtures.luau').write_text(fixtureModule,encoding='utf8',newline='\n')
test=(HERE/'session-adapter-tests.luau').read_text(encoding='utf8')
probe='''-- Private correctness checks. Never publish; no real DataStore requests.
local Run=game:GetService("RunService")
assert(Run:IsStudio() and Run:IsServer() and game.PlaceId==0 and workspace:GetAttribute("SessionCacheProbe")==true)
local Shared=game.ReplicatedStorage.Shared
local Json=require(Shared.Persistence.Json)
local MemoryBackend=require(Shared.Persistence.MemoryBackend)
local SaveEnvelope=require(Shared.Persistence.SaveEnvelope)
local SaveProgress=require(Shared.Persistence.SaveProgress)
local SaveRest=require(Shared.Persistence.SaveRest)
local SaveSession=require(Shared.Persistence.SaveSession)
local Backend=require(script.Parent.DataStoreBackend)
local fixtures=require(script.Parent.SessionFixtures)
local function realRest(ticks,mode) return Json.copy(fixtures[mode][tostring(ticks)]) end
local id=tostring(DateTime.now().UnixTimestampMillis)
local ok,err=xpcall(function()
 print("[NATIVE_SESSION_CACHE_BEGIN]",id)
'''+test+'''
assert(checks==111,"unexpected assertion count")
print("[NATIVE_SESSION_CACHE_PASS]",id,checks)
end,debug.traceback)
if not ok then warn("[NATIVE_SESSION_CACHE_FAIL]",id,tostring(err)) end
'''
(HERE/'session-cache-native-probe.server.luau').write_text(probe,encoding='utf8',newline='\n')
shutil.copytree(PORT/'src',out/'src')
for target,name in {'Shared/Persistence/SaveSession.luau':'session-fresh-candidate.luau','Server/DataStoreBackend.luau':'fresh-read-backend-candidate.luau'}.items():
 shutil.copy2(HERE/name,out/'src'/target)
project=json.loads((PORT/'default.project.json').read_text())
def absolute(node):
 if isinstance(node,dict):
  for key,value in node.items():
   if key=='$path':node[key]=str(out/value) if value.startswith('src/') else str(PORT/value)
   else:absolute(value)
absolute(project);tree=project['tree'];server=tree['ServerScriptService']['Server']
server['SessionFixtures']={'$path':str(out/'SessionFixtures.luau')}
server['SessionCacheProbe']={'$path':str(HERE/'session-cache-native-probe.server.luau')}
tree['Workspace']['$attributes']={'World':'preserve','Detail':'low','SelfTest':False,'SessionCacheProbe':True}
config=out/'native.project.json';config.write_text(json.dumps(project,indent=2),encoding='utf8')
place=out/'Windowsill-session-cache-review.rbxlx';subprocess.run([str(TOOLS/'rojo/rojo.exe'),'build',str(config),'-o',str(place)],check=True)
xml=ET.parse(place);rows=[];disabled=[]
def walk(item,parent=''):
 props=item.find('Properties');name=props.findtext("string[@name='Name']");path=parent+'.'+name if parent else name
 if item.attrib['class'] in ['Script','LocalScript']:
  flag=props.find("bool[@name='Disabled']")
  if flag is None:flag=ET.SubElement(props,'bool',{'name':'Disabled'})
  value=path!='ServerScriptService.Server.SessionCacheProbe';flag.text=str(value).lower();disabled.append([path,value])
 code=props.find("*[@name='Source']")
 if code is not None:
  data=(code.text or '').replace('\r\n','\n').encode();rows.append(dict(path=path,length=len(data),adler32=zlib.adler32(data),sha256=hashlib.sha256(data).hexdigest()))
 for child in item.findall('Item'):walk(child,path)
for item in xml.getroot().findall('Item'):walk(item)
assert len(rows)==224 and sum(not x[1] for x in disabled)==1
xml.write(place,encoding='utf8',xml_declaration=False)
guard='assert(game.PlaceId==0 and not game:GetService("RunService"):IsRunning() and workspace:GetAttribute("SessionCacheProbe")==true and workspace:GetAttribute("SelfTest")==false);local expected={'
guard+=','.join('{'+json.dumps(row['path'])+','+str(row['length'])+','+str(row['adler32'])+'}' for row in rows)+'};'
guard+='for _,r in expected do local it=game;for name in string.gmatch(r[1],"[^.]+") do it=assert(it:FindFirstChild(name),r[1]) end;local s=string.gsub(it.Source,"\\r\\n","\\n");local a,b=1,0;for i=1,#s do a=(a+string.byte(s,i))%65521;b=(b+a)%65521 end;assert(#s==r[2] and b*65536+a==r[3],r[1]) end;local disabled='+json.dumps(disabled,separators=(',',':')).replace('[','{').replace(']','}')+';'
guard+='for _,r in disabled do local it=game;for name in string.gmatch(r[1],"[^.]+") do it=assert(it:FindFirstChild(name)) end;assert(it.Disabled==r[2],r[1]) end;local n=0;for _,root in {game.ReplicatedFirst,game.ReplicatedStorage.Shared,game.ServerScriptService.Server,game.StarterPlayer.StarterPlayerScripts.Client} do for _,it in root:GetDescendants() do if it:IsA("LuaSourceContainer") then n+=1 end end end;assert(n==#expected);print("[NATIVE_SESSION_CACHE_GUARD]","'+source+'",n,"production_scripts_disabled")'
(out/'guard.luau').write_text(guard,encoding='utf8',newline='\n')
manifest=dict(source=source,scripts=rows,disabled_scripts=disabled,production_scripts_disabled=True,place_sha256=hashlib.sha256(place.read_bytes()).hexdigest(),candidates=types['candidates'],fixtures_sha256=hashlib.sha256((HERE/'session-native-fixtures.json').read_bytes()).hexdigest(),scope='Real SaveSession/DataStoreBackend against cached fake DataStore; actual engine options; no real DataStore or progress migration; never publish')
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8',newline='\n')
(HERE/'prepared-session-cache-native-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8',newline='\n')
(HERE/'prepared-session-cache-native-guard.luau').write_text(guard,encoding='utf8',newline='\n')
print(json.dumps(dict(place=str(place),scripts=224,sha256=manifest['place_sha256'])))
