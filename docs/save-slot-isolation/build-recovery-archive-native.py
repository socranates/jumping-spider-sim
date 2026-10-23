"""Private raw-value archive/engine JSON checks. Never publish this diagnostic."""
from pathlib import Path
import argparse,hashlib,json,subprocess,zlib,xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent;PORT=ROOT/'roblox_port'
p=argparse.ArgumentParser();p.add_argument('--out',required=True);p.add_argument('--rojo',required=True);a=p.parse_args()
out=Path(a.out).resolve();assert not out.exists();out.mkdir(parents=True)
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
candidate=HERE/'recovery-archive-prototype.luau'
receipt=json.loads((HERE/'recovery-archive-receipt.json').read_text());types=json.loads((HERE/'recovery-archive-types.json').read_text())
digest=hashlib.sha256(candidate.read_bytes()).hexdigest()
assert receipt['exit_code']==0 and receipt['candidate_sha256']==types['candidate_sha256']==digest
assert len(types['steps'])==3 and all(r['exit_code']==0 for r in types['steps'])
test=(HERE/'recovery-archive-tests.luau').read_text(encoding='utf8')
assert hashlib.sha256(test.encode()).hexdigest()==receipt['test_sha256']
test=test.replace('require("../src/Shared/Persistence/Json")','require(Shared.Persistence.Json)').replace('require("../src/Shared/Persistence/SaveWork")','require(Shared.Persistence.SaveWork)')
probe='''-- Private correctness test; no persistent read/write. Never publish.
local Run=game:GetService("RunService")
local Http=game:GetService("HttpService")
local Shared=game.ReplicatedStorage.Shared
local __archivePrototype=require(script.Parent.RecoveryArchivePrototype)
return function(d)
 assert(Run:IsStudio() and game.PlaceId==0 and workspace:GetAttribute("RecoveryArchiveProbe")==true)
 local id=tostring(DateTime.now().UnixTimestampMillis)
 local ok,err=xpcall(function()
  print("[NATIVE_RECOVERY_ARCHIVE_BEGIN]",id)
  local deadline=os.clock()+90
  while game.Players.LocalPlayer:GetAttribute("TitleReady")~=true and os.clock()<deadline do Run.Heartbeat:Wait() end
  assert(game.Players.LocalPlayer:GetAttribute("TitleReady")==true,"startup failed")
  d.title.seen=true;assert(d.fresh("main",false,nil),"fresh refused");d.openMenu()
  assert(d.menu:isShowing(),"test not paused")
'''+test+'''
 check(Archive.check(Http:JSONDecode(assert(Json.canonical(plan)))),"native plan JSON round trip")
 for _,slot in Archive.SLOTS do
  local raw=plan.entries[slot].raw
  local copy=if raw~=nil then Http:JSONDecode(Http:JSONEncode(raw)) else nil
  check(Json.canonical(copy)==Json.canonical(raw),"native raw JSON round trip "..slot)
 end
 local Checkpoint=require(Shared.Persistence.Checkpoint)
 local Rest=require(Shared.Persistence.SaveRest)
 local Progress=require(Shared.Persistence.SaveProgress)
 local Envelope=require(Shared.Persistence.SaveEnvelope)
 local world={motor=d.motor,prey=d.prey,sensor=d.sensor,memory=d.memory,needs=d.needs,life=d.life,garden=d.world.garden}
 local record=assert(Checkpoint.capture(world,0));local beforeWorld=assert(Json.canonical(record))
 assert(#Rest.check("main",record,world)==0,"actual client checkpoint invalid")
 local raw=sources()
 raw.progress.value=Envelope.make(Progress.SPEC,Progress.default(),0,nil)
 local prior=Envelope.make(Rest.SPECS.main,record,0,nil)
 raw.main.value=Envelope.make(Rest.SPECS.main,Json.copy(record),1,prior)
 local rawBefore=assert(Json.canonical(raw))
 local actual,problem=Archive.prepare("synthetic_native","raw-source-before-decode",raw)
 check(actual~=nil and Archive.check(actual),problem or "actual envelope archive refused")
 check(Json.canonical(actual.entries.main.raw)==Json.canonical(raw.main.value),"actual envelope/backup changed")
 check(Json.canonical(raw)==rawBefore,"actual raw sources changed")
 check(Json.canonical(assert(Checkpoint.capture(world,0)))==beforeWorld,"archive changed the live client")
 assert(passed==82,"unexpected native assertion count "..passed)
 print("[NATIVE_RECOVERY_ARCHIVE_PASS]",id,passed)
 end,debug.traceback)
 if not ok then warn("[NATIVE_RECOVERY_ARCHIVE_FAIL]",id,tostring(err)) end
end
'''
(HERE/'recovery-archive-native-probe.luau').write_text(probe,encoding='utf8',newline='\n')
project=json.loads((PORT/'default.project.json').read_text())
def absolute(node):
 if isinstance(node,dict):
  for key,value in node.items():
   if key=='$path':node[key]=str(PORT/value)
   else:absolute(value)
absolute(project);tree=project['tree'];client=tree['StarterPlayer']['StarterPlayerScripts']['Client']
client['RecoveryArchivePrototype']={'$path':str(candidate)};client['SilkPlayback']={'$path':str(HERE/'recovery-archive-native-probe.luau')}
tree['Workspace']['$attributes']={'World':'preserve','Detail':'full','SelfTest':False,'TestTarget':False,'RecoveryArchiveProbe':True}
config=out/'native.project.json';config.write_text(json.dumps(project,indent=2),encoding='utf8',newline='\n')
place=out/'Windowsill-recovery-archive-review.rbxlx';subprocess.run([a.rojo,'build',str(config),'-o',str(place)],check=True)
xml=ET.parse(place);rows=[]
def walk(item,parent=''):
 props=item.find('Properties');name=props.findtext("string[@name='Name']");path=parent+'.'+name if parent else name
 if path=='ServerScriptService.Server.Persistence':
  flag=props.find("bool[@name='Disabled']")
  if flag is None:flag=ET.SubElement(props,'bool',{'name':'Disabled'})
  flag.text='true'
 code=props.find("*[@name='Source']")
 if code is not None:
  text=(code.text or '').replace('\r\n','\n').encode();rows.append(dict(path=path,length=len(text),adler32=zlib.adler32(text),sha256=hashlib.sha256(text).hexdigest()))
 for child in item.findall('Item'):walk(child,path)
for item in xml.getroot().findall('Item'):walk(item)
assert len(rows)==224 and len({r['path'] for r in rows})==224
xml.write(place,encoding='utf8',xml_declaration=False)
guard='assert(game.PlaceId==0 and not game:GetService("RunService"):IsRunning() and workspace:GetAttribute("RecoveryArchiveProbe")==true and workspace:GetAttribute("SelfTest")==false and game.ServerScriptService.Server.Persistence.Disabled==true);local expected={'
guard+=','.join('{'+json.dumps(r['path'])+','+str(r['length'])+','+str(r['adler32'])+'}' for r in rows)+'};'
guard+='for _,r in expected do local it=game;for name in string.gmatch(r[1],"[^.]+") do it=assert(it:FindFirstChild(name),r[1]) end;local s=string.gsub(it.Source,"\\r\\n","\\n");local a,b=1,0;for i=1,#s do a=(a+string.byte(s,i))%65521;b=(b+a)%65521 end;assert(#s==r[2] and b*65536+a==r[3],r[1]) end;local n=0;for _,root in {game.ReplicatedFirst,game.ReplicatedStorage.Shared,game.ServerScriptService.Server,game.StarterPlayer.StarterPlayerScripts.Client} do for _,it in root:GetDescendants() do if it:IsA("LuaSourceContainer") then n+=1 end end end;assert(n==#expected);print("[NATIVE_RECOVERY_ARCHIVE_GUARD]","'+source+'",n,"persistence_disabled")'
(out/'guard.luau').write_text(guard,encoding='utf8',newline='\n')
manifest=dict(source=source,scripts=rows,persistence_disabled=True,place_sha256=hashlib.sha256(place.read_bytes()).hexdigest(),candidate_sha256=digest,scope='Private archive plan, native JSON round trips and unchanged actual client checkpoint; no DataStore/durable migration proof; never publish')
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8',newline='\n')
(HERE/'prepared-recovery-archive-native-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8',newline='\n')
(HERE/'prepared-recovery-archive-native-guard.luau').write_text(guard,encoding='utf8',newline='\n')
print(json.dumps(dict(place=str(place),scripts=224,sha256=manifest['place_sha256'])))
