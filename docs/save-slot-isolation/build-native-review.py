"""Build a new, isolated local Studio review place. Never publish it."""
from pathlib import Path
import json,hashlib,subprocess,zlib
ROOT=Path(__file__).resolve().parents[2];HERE=Path(__file__).resolve().parent
OUT=Path(r"C:\Users\natha\claude-xfer\Windowsill-slot-isolation-1984-native-review")
assert not OUT.exists(),"use a new diagnostic directory"
OUT.mkdir(parents=True)
manifest=json.loads((HERE/"source-manifest.json").read_text(encoding="utf-8"))
for row in manifest["files"]:assert hashlib.sha256((ROOT/"roblox_port"/row["path"]).read_bytes().replace(b"\r\n",b"\n")).hexdigest()==row["sha256"]
project=json.loads((ROOT/"roblox_port/default.project.json").read_text(encoding="utf-8"))
def absolute(node):
 if isinstance(node,dict):
  for k,v in node.items():
   if k=="$path":node[k]=str(ROOT/"roblox_port"/v)
   else:absolute(v)
absolute(project)
tree=project["tree"]
tree["ServerScriptService"]["ChetSlotNativeSpec"]={"$path":str(HERE/"native-probe.server.luau")}
tree["Workspace"]["$attributes"]={"World":"preserve","Detail":"full","SelfTest":True,"TestTarget":False,"SlotIsolationProbe":True}
fixture=(ROOT/"docs/save-compaction/native-engine-capture.json").read_text(encoding="utf-8")
tree["ServerStorage"]={"$className":"ServerStorage","ChetSlotFixture":{"$className":"StringValue","$properties":{"Value":fixture}}}
config=OUT/"review.project.json";config.write_text(json.dumps(project,indent=2),encoding="utf-8")
rojo=Path(r"C:\Users\natha\.codex\.chatgpt-projects\g-p-6ac2f32f82a48191b0c7151a11eab0fd\roblox_tools\rojo\rojo.exe")
place=OUT/"Windowsill-slot-isolation-review.rbxlx"
subprocess.run([str(rojo),"build",str(config),"-o",str(place)],check=True)
expected=[[r["instance"],r["length"],r["adler32"]] for r in manifest["files"]]
helper=(HERE/"native-probe.server.luau").read_bytes()
expected.append(["ServerScriptService.ChetSlotNativeSpec",len(helper),zlib.adler32(helper)])
guard='assert(game.PlaceId==0 and not game:GetService("RunService"):IsRunning());local expected='+json.dumps(expected).replace('[','{').replace(']','}')+';local n=0;'
guard+='for _,r in expected do local it=game;for part in string.gmatch(r[1],"[^.]+") do it=assert(it:FindFirstChild(part),r[1]) end;local text=string.gsub(it.Source,"\\r\\n","\\n");local a,b=1,0;for i=1,#text do a=(a+string.byte(text,i))%65521;b=(b+a)%65521 end;assert(#text==r[2] and b*65536+a==r[3],"SOURCE_MISMATCH "..r[1]);n+=1 end;'
guard+='local total=0;for _,folder in {game.ReplicatedFirst,game.ReplicatedStorage.Shared,game.ServerScriptService.Server,game.StarterPlayer.StarterPlayerScripts.Client} do for _,it in folder:GetDescendants() do if it:IsA("LuaSourceContainer") then total+=1 end end end;assert(total==216 and n==217);'
guard+='local text=game.ServerStorage.ChetSlotFixture.Value;local a,b=1,0;for i=1,#text do a=(a+string.byte(text,i))%65521;b=(b+a)%65521 end;assert(#text=='+str(len(fixture.encode()))+' and b*65536+a=='+str(zlib.adler32(fixture.encode()))+');'
guard+='assert(workspace:GetAttribute("SelfTest")==true and workspace:GetAttribute("SlotIsolationProbe")==true and workspace:GetAttribute("World")=="preserve");print("[CHET_SLOT_SOURCE_GUARD]",216,total,"'+manifest['source_commit']+'");'
(OUT/"source-guard.luau").write_text(guard,encoding="utf-8",newline="\n")
receipt=dict(source_commit=manifest['source_commit'],evidence_id="1984fdd8e8dee0ad",path=str(place),sha256=hashlib.sha256(place.read_bytes()).hexdigest(),guard_path=str(OUT/"source-guard.luau"),helper_sha256=hashlib.sha256(helper).hexdigest(),fixture_sha256=hashlib.sha256(fixture.encode()).hexdigest(),diagnostic_only=True,never_publish=True)
(HERE/"native-review.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
print(json.dumps(receipt,indent=2))
