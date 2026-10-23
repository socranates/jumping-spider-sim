"""Build a guarded server-memory lifecycle fixture; all game scripts disabled."""
from pathlib import Path
import ast,hashlib,json,shutil,subprocess,tempfile,zlib,xml.etree.ElementTree as ET
H=Path(__file__).resolve().parent;ROOT=H.parents[1];PORT=ROOT/'roblox_port'
TOOLS=Path(r'C:/Users/natha/.codex/.chatgpt-projects/g-p-6ac2f32f82a48191b0c7151a11eab0fd/roblox_tools')
source=subprocess.check_output(['git','log','-1','--format=%H','--','roblox_port/src','roblox_port/tests'],cwd=ROOT,text=True).strip()
assert subprocess.run(['git','diff','--quiet','HEAD','--','roblox_port/src','roblox_port/tests'],cwd=ROOT).returncode==0
types=json.loads((H/'recovery-idle-types.json').read_text(encoding='utf8'))
assert len(types['candidates'])==24 and all(s['exit_code']==0 for s in types['steps'])
for name,digest in types['candidates'].items():assert hashlib.sha256((H/name).read_bytes()).hexdigest()==digest
receipt=json.loads((H/'recovery-idle-receipt.json').read_text(encoding='utf8'));assert receipt['source']==source and receipt['exit_code']==0
tree=ast.parse((H/'check-recovery-pipeline.py').read_text(encoding='utf8'))
names=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='names' for t in n.targets))
names.update({'Shared/Persistence/RecoveryProgressReconcilePrototype.luau':'recovery-progress-reconcile-prototype.luau','Server/RecoveryDeparturePrototype.luau':'recovery-departure-prototype.luau','Server/RecoveryIdlePrototype.luau':'recovery-idle-prototype.luau'})
out=Path(r'C:/Users/natha/claude-xfer/Windowsill-recovery-idle-441eaca');out.mkdir(exist_ok=False)
place=out/'Windowsill-recovery-idle-review.rbxlx'
with tempfile.TemporaryDirectory() as tmp:
 folder=Path(tmp);shutil.copytree(PORT/'src',folder/'src')
 for target,name in names.items():(folder/'src'/target).write_bytes((H/name).read_bytes())
 shutil.copy2(H/'recovery-idle-native-probe.server.luau',folder/'src/Server/RecoveryIdleProbe.server.luau')
 project=json.loads((PORT/'default.project.json').read_text(encoding='utf8'));project['tree']['Workspace']['$attributes']={'SelfTest':False,'RecoveryIdleProbe':True}
 (folder/'default.project.json').write_text(json.dumps(project),encoding='utf8')
 subprocess.run([str(TOOLS/'rojo/rojo.exe'),'build','default.project.json','-o',str(place)],cwd=folder,check=True)
xml=ET.parse(place);rows=[];disabled=[]
def walk(item,parent=''):
 props=item.find('Properties');name=props.findtext("string[@name='Name']");path=parent+'.'+name if parent else name
 if item.attrib['class'] in ['Script','LocalScript']:
  flag=props.find("bool[@name='Disabled']")
  if flag is None:flag=ET.SubElement(props,'bool',{'name':'Disabled'})
  value=path!='ServerScriptService.Server.RecoveryIdleProbe';flag.text=str(value).lower();disabled.append([path,value])
 code=props.find("*[@name='Source']")
 if code is not None:
  data=(code.text or '').replace('\r\n','\n').encode();rows.append(dict(path=path,length=len(data),adler32=zlib.adler32(data),sha256=hashlib.sha256(data).hexdigest()))
 for child in item.findall('Item'):walk(child,path)
for item in xml.getroot().findall('Item'):walk(item)
assert len(rows)==245 and sum(not r[1] for r in disabled)==1
xml.write(place,encoding='utf8',xml_declaration=False)
guard='assert(game.PlaceId==0 and not game:GetService("RunService"):IsRunning() and workspace:GetAttribute("RecoveryIdleProbe")==true and workspace:GetAttribute("SelfTest")==false);local expected={'
guard+=','.join('{'+json.dumps(r['path'])+','+str(r['length'])+','+str(r['adler32'])+'}' for r in rows)+'};'
guard+='for _,r in expected do local it=game;for name in string.gmatch(r[1],"[^.]+") do it=assert(it:FindFirstChild(name),r[1]) end;local s=string.gsub(it.Source,"\\r\\n","\\n");local a,b=1,0;for i=1,#s do a=(a+string.byte(s,i))%65521;b=(b+a)%65521 end;assert(#s==r[2] and b*65536+a==r[3],r[1]) end;local disabled='+json.dumps(disabled,separators=(',',':')).replace('[','{').replace(']','}')+';'
guard+='for _,r in disabled do local it=game;for name in string.gmatch(r[1],"[^.]+") do it=assert(it:FindFirstChild(name)) end;assert(it.Disabled==r[2],r[1]) end;local n=0;for _,root in {game.ReplicatedFirst,game.ReplicatedStorage.Shared,game.ServerScriptService.Server,game.StarterPlayer.StarterPlayerScripts.Client} do for _,it in root:GetDescendants() do if it:IsA("LuaSourceContainer") then n+=1 end end end;assert(n==#expected);print("[RECOVERY_IDLE_NATIVE_GUARD]","'+source+'",n,"production_scripts_disabled")'
manifest=dict(source=source,place=str(place),place_sha256=hashlib.sha256(place.read_bytes()).hexdigest(),scripts=rows,disabled_scripts=disabled,production_scripts_disabled=True,candidates=types['candidates'],scope='Native server MemoryBackend with controlled terminal metadata: closed scope, idle lease, yielded provider and global progress departure. Not actual discovery/pipeline migration, real DataStore, gameplay or performance proof; never publish')
for path in [out/'manifest.json',H/'prepared-recovery-idle-native-manifest.json']:path.write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf8',newline='\n')
for path in [out/'guard.luau',H/'prepared-recovery-idle-native-guard.luau']:path.write_text(guard,encoding='utf8',newline='\n')
print(json.dumps(dict(place=str(place),scripts=len(rows),sha256=manifest['place_sha256'])))
