"""Frozen checkpoint fixtures + real adapter/session, all production scripts disabled."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,shutil,subprocess,tempfile,zlib,xml.etree.ElementTree as ET
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];PORT=ROOT/'roblox_port'
p=argparse.ArgumentParser();p.add_argument('--out',required=True);a=p.parse_args()
out=Path(a.out).resolve();assert not out.exists();out.mkdir(parents=True)
TOOLS=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
types=json.loads((HERE/'session-budget-yield-types.json').read_text());assert len(types['steps'])==4 and all(x['exit_code']==0 for x in types['steps'])
for name,digest in types['candidates'].items():assert hashlib.sha256((HERE/name).read_bytes()).hexdigest()==digest
assert json.loads((HERE/'session-budget-yield-fixed-receipt.json').read_text())['exit_code']==0
assert json.loads((HERE/'session-budget-yield-controls-receipt.json').read_text())['exit_code']==0
raw=(HERE/'session-native-fixtures.json').read_text(encoding='utf8').strip()
prior=json.loads((HERE/'prepared-session-budget-native-manifest.json').read_text())
assert hashlib.sha256((HERE/'session-native-fixtures.json').read_bytes()).hexdigest()==prior['fixtures_sha256']
assert ']==]' not in raw
fixtureModule='return game:GetService("HttpService"):JSONDecode([==['+raw+']==])\n'
(out/'SessionFixtures.luau').write_text(fixtureModule,encoding='utf8',newline='\n')
controls=(HERE/'session-budget-candidate-tests.luau').read_text(encoding='utf8')
yielded=(HERE/'session-budget-yield-tests.luau').read_text(encoding='utf8')
test='local function controls()\n'+controls+'\nreturn passedBudget end\nlocal function yielded()\n'+yielded+'\nreturn checksYield end\nlocal a,b=controls(),yielded();assert(a==82 and b==44);local checks=a+b\n' 
probe='''-- Private correctness checks. Never publish; no real DataStore requests.
local Run=game:GetService("RunService")
assert(Run:IsStudio() and Run:IsServer() and game.PlaceId==0 and workspace:GetAttribute("SessionBudgetProbe")==true)
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
 print("[NATIVE_SESSION_BUDGET_BEGIN]",id)
'''+test+'''
assert(checks==126,"unexpected assertion count")
print("[NATIVE_SESSION_BUDGET_PASS]",id,checks)
end,debug.traceback)
if not ok then warn("[NATIVE_SESSION_BUDGET_FAIL]",id,tostring(err)) end
'''
(HERE/'session-budget-native-probe.server.luau').write_text(probe,encoding='utf8',newline='\n')
shutil.copytree(PORT/'src',out/'src')
for target,name in {'Shared/Persistence/SaveSession.luau':'session-budget-yield-candidate.luau','Server/DataStoreBackend.luau':'fresh-read-backend-candidate.luau'}.items():
 shutil.copy2(HERE/name,out/'src'/target)
project=json.loads((PORT/'default.project.json').read_text())
def absolute(node):
 if isinstance(node,dict):
  for key,value in node.items():
   if key=='$path':node[key]=str(out/value) if value.startswith('src/') else str(PORT/value)
   else:absolute(value)
absolute(project);tree=project['tree'];server=tree['ServerScriptService']['Server']
server['SessionFixtures']={'$path':str(out/'SessionFixtures.luau')}
server['SessionBudgetProbe']={'$path':str(HERE/'session-budget-native-probe.server.luau')}
tree['Workspace']['$attributes']={'World':'preserve','Detail':'low','SelfTest':False,'SessionBudgetProbe':True}
config=out/'native.project.json';config.write_text(json.dumps(project,indent=2),encoding='utf8')
place=out/'Windowsill-session-budget-review.rbxlx';subprocess.run([str(TOOLS/'rojo/rojo.exe'),'build',str(config),'-o',str(place)],check=True)
xml=ET.parse(place);rows=[];disabled=[]
def walk(item,parent=''):
 props=item.find('Properties');name=props.findtext("string[@name='Name']");path=parent+'.'+name if parent else name
 if item.attrib['class'] in ['Script','LocalScript']:
  flag=props.find("bool[@name='Disabled']")
  if flag is None:flag=ET.SubElement(props,'bool',{'name':'Disabled'})
  value=path!='ServerScriptService.Server.SessionBudgetProbe';flag.text=str(value).lower();disabled.append([path,value])
 code=props.find("*[@name='Source']")
 if code is not None:
  data=(code.text or '').replace('\r\n','\n').encode();rows.append(dict(path=path,length=len(data),adler32=zlib.adler32(data),sha256=hashlib.sha256(data).hexdigest()))
 for child in item.findall('Item'):walk(child,path)
for item in xml.getroot().findall('Item'):walk(item)
assert len(rows)==224 and sum(not x[1] for x in disabled)==1
xml.write(place,encoding='utf8',xml_declaration=False)
guard='assert(game.PlaceId==0 and not game:GetService("RunService"):IsRunning() and workspace:GetAttribute("SessionBudgetProbe")==true and workspace:GetAttribute("SelfTest")==false);local expected={'
guard+=','.join('{'+json.dumps(row['path'])+','+str(row['length'])+','+str(row['adler32'])+'}' for row in rows)+'};'
guard+='for _,r in expected do local it=game;for name in string.gmatch(r[1],"[^.]+") do it=assert(it:FindFirstChild(name),r[1]) end;local s=string.gsub(it.Source,"\\r\\n","\\n");local a,b=1,0;for i=1,#s do a=(a+string.byte(s,i))%65521;b=(b+a)%65521 end;assert(#s==r[2] and b*65536+a==r[3],r[1]) end;local disabled='+json.dumps(disabled,separators=(',',':')).replace('[','{').replace(']','}')+';'
guard+='for _,r in disabled do local it=game;for name in string.gmatch(r[1],"[^.]+") do it=assert(it:FindFirstChild(name)) end;assert(it.Disabled==r[2],r[1]) end;local n=0;for _,root in {game.ReplicatedFirst,game.ReplicatedStorage.Shared,game.ServerScriptService.Server,game.StarterPlayer.StarterPlayerScripts.Client} do for _,it in root:GetDescendants() do if it:IsA("LuaSourceContainer") then n+=1 end end end;assert(n==#expected);print("[NATIVE_SESSION_BUDGET_GUARD]","'+source+'",n,"production_scripts_disabled")'
(out/'guard.luau').write_text(guard,encoding='utf8',newline='\n')
manifest=dict(source=source,scripts=rows,disabled_scripts=disabled,production_scripts_disabled=True,place_sha256=hashlib.sha256(place.read_bytes()).hexdigest(),candidates=types['candidates'],fixtures_sha256=hashlib.sha256((HERE/'session-native-fixtures.json').read_bytes()).hexdigest(),scope='Paced recovery, retained observations and actual coroutine suspension across close/demote/superseding load; MemoryBackend; no real DataStore or full-game transport; never publish')
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8',newline='\n')
(HERE/'prepared-session-budget-native-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8',newline='\n')
(HERE/'prepared-session-budget-native-guard.luau').write_text(guard,encoding='utf8',newline='\n')
print(json.dumps(dict(place=str(place),scripts=224,sha256=manifest['place_sha256'])))
