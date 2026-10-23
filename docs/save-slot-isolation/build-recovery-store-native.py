"""Server-context protocol/options checks; all production scripts disabled."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,zlib,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;PORT=ROOT/'roblox_port'
p=argparse.ArgumentParser();p.add_argument('--out',required=True);p.add_argument('--rojo',required=True);a=p.parse_args()
out=Path(a.out).resolve();assert not out.exists();out.mkdir(parents=True)
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
types=json.loads((HERE/'fresh-read-types.json').read_text());assert len(types['steps'])==4 and all(x['exit_code']==0 for x in types['steps'])
for name,digest in types['candidates'].items():assert hashlib.sha256((HERE/name).read_bytes()).hexdigest()==digest
for name,expected in [('recovery-archive-store',272),('fresh-read',32)]:
 receipt=json.loads((HERE/(name+'-receipt.json')).read_text());assert receipt['exit_code']==0
 assert 'passed='+str(expected)+' failed=0' in (HERE/(name+'-output.txt')).read_text()
def body(name):
 text=(HERE/name).read_text(encoding='utf8')
 return re.sub(r'require\("../src/Shared/Persistence/(\w+)"\)',r'require(Shared.Persistence.\1)',text)
store=body('recovery-archive-store-tests.luau')
fresh=body('fresh-read-tests.luau');start=fresh.index('do\n local ds=fakeStore();check(not pcall')
end=fresh.index('print("FRESH_RAW_READ',start)
fresh=fresh[:start]+'''do
 local ds=fakeStore()
 check(not pcall(function() Store.new({read=function() end,update=function() end},"u1") end),"cached-only backend admitted")
 local destroyed=0;local get=ds.GetAsync
 ds.GetAsync=function(self,key,options)
  assert(options~=nil and options.UseCache==false,"native uncached options absent")
  options.Destroying:Connect(function() destroyed+=1 end)
  return get(self,key,options)
 end
 local backend=Backend.new(ds)
 backend:readRawFresh("P_x");ds.failRead=true;backend:readRawFresh("P_x")
 task.wait()
 check(destroyed==2,"native options were not cleaned up on success and error")
end
'''+fresh[end:]
probe='''-- Private server correctness checks; no real DataStore calls. Never publish.
local Run=game:GetService("RunService")
assert(Run:IsStudio() and Run:IsServer() and game.PlaceId==0 and workspace:GetAttribute("RecoveryStoreProbe")==true)
local Shared=game.ReplicatedStorage.Shared
local __archivePrototype=require(script.Parent.RecoveryArchivePrototype)
local __archiveStorePrototype=require(script.Parent.RecoveryArchiveStorePrototype)
local __freshBackend=require(script.Parent.FreshReadBackendPrototype)
local id=tostring(DateTime.now().UnixTimestampMillis)
local ok,err=xpcall(function()
 print("[NATIVE_RECOVERY_STORE_BEGIN]",id)
 local function protocol()
'''+store+'''return passed end
 local function freshReads()
'''+fresh+'''return passed end
 local a,b=protocol(),freshReads()
 assert(a==272 and b==32,"unexpected native assertion count")
 print("[NATIVE_RECOVERY_STORE_PASS]",id,a+b)
end,debug.traceback)
if not ok then warn("[NATIVE_RECOVERY_STORE_FAIL]",id,tostring(err)) end
'''
probePath=HERE/'recovery-store-native-probe.server.luau';probePath.write_text(probe,encoding='utf8',newline='\n')
project=json.loads((PORT/'default.project.json').read_text())
def absolute(node):
 if isinstance(node,dict):
  for key,value in node.items():
   if key=='$path':node[key]=str(PORT/value)
   else:absolute(value)
absolute(project);tree=project['tree'];server=tree['ServerScriptService']['Server']
for name,path in {'RecoveryArchivePrototype':'recovery-archive-prototype.luau','RecoveryArchiveStorePrototype':'recovery-archive-store-prototype.luau','FreshReadBackendPrototype':'fresh-read-backend-candidate.luau','RecoveryStoreProbe':'recovery-store-native-probe.server.luau'}.items():server[name]={'$path':str(HERE/path)}
tree['Workspace']['$attributes']={'World':'preserve','Detail':'low','SelfTest':False,'RecoveryStoreProbe':True}
config=out/'native.project.json';config.write_text(json.dumps(project,indent=2),encoding='utf8',newline='\n')
place=out/'Windowsill-recovery-store-review.rbxlx';subprocess.run([a.rojo,'build',str(config),'-o',str(place)],check=True)
xml=ET.parse(place);rows=[];disabled=[]
def walk(item,parent=''):
 props=item.find('Properties');name=props.findtext("string[@name='Name']");path=parent+'.'+name if parent else name
 if item.attrib['class'] in ['Script','LocalScript']:
  flag=props.find("bool[@name='Disabled']")
  if flag is None:flag=ET.SubElement(props,'bool',{'name':'Disabled'})
  value=path!='ServerScriptService.Server.RecoveryStoreProbe';flag.text=str(value).lower();disabled.append([path,value])
 code=props.find("*[@name='Source']")
 if code is not None:
  data=(code.text or '').replace('\r\n','\n').encode();rows.append(dict(path=path,length=len(data),adler32=zlib.adler32(data),sha256=hashlib.sha256(data).hexdigest()))
 for child in item.findall('Item'):walk(child,path)
for item in xml.getroot().findall('Item'):walk(item)
assert len(rows)==226 and len({r['path'] for r in rows})==226 and sum(not r[1] for r in disabled)==1
xml.write(place,encoding='utf8',xml_declaration=False)
guard='assert(game.PlaceId==0 and not game:GetService("RunService"):IsRunning() and workspace:GetAttribute("RecoveryStoreProbe")==true and workspace:GetAttribute("SelfTest")==false);local expected={'
guard+=','.join('{'+json.dumps(r['path'])+','+str(r['length'])+','+str(r['adler32'])+'}' for r in rows)+'};'
guard+='for _,r in expected do local it=game;for name in string.gmatch(r[1],"[^.]+") do it=assert(it:FindFirstChild(name),r[1]) end;local s=string.gsub(it.Source,"\\r\\n","\\n");local a,b=1,0;for i=1,#s do a=(a+string.byte(s,i))%65521;b=(b+a)%65521 end;assert(#s==r[2] and b*65536+a==r[3],r[1]) end;local disabled='+json.dumps(disabled,separators=(',',':')).replace('[','{').replace(']','}')+';'
guard+='for _,r in disabled do local it=game;for name in string.gmatch(r[1],"[^.]+") do it=assert(it:FindFirstChild(name)) end;assert(it.Disabled==r[2],r[1]) end;local n=0;for _,root in {game.ReplicatedFirst,game.ReplicatedStorage.Shared,game.ServerScriptService.Server,game.StarterPlayer.StarterPlayerScripts.Client} do for _,it in root:GetDescendants() do if it:IsA("LuaSourceContainer") then n+=1 end end end;assert(n==#expected);print("[NATIVE_RECOVERY_STORE_GUARD]","'+source+'",n,"production_scripts_disabled")'
(out/'guard.luau').write_text(guard,encoding='utf8',newline='\n')
manifest=dict(source=source,scripts=rows,disabled_scripts=disabled,production_scripts_disabled=True,place_sha256=hashlib.sha256(place.read_bytes()).hexdigest(),candidates=types['candidates'],scope='Server-context MemoryBackend/fake cached datastore protocol and real DataStoreGetOptions lifecycle; production scripts disabled; no real DataStore or progress import proof; never publish')
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8',newline='\n')
(HERE/'prepared-recovery-store-native-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8',newline='\n')
(HERE/'prepared-recovery-store-native-guard.luau').write_text(guard,encoding='utf8',newline='\n')
print(json.dumps(dict(place=str(place),scripts=226,sha256=manifest['place_sha256'])))
