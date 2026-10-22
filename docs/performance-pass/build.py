"""Build isolated matched baseline/candidate profiling places. Never publishes.
Usage: python docs/performance-pass/build.py --rojo ABS_EXE --out ABS_NEW_DIR
All source is verified against Git blobs. The baseline archive is read-only input thereafter.
"""
from pathlib import Path
import argparse,hashlib,json,subprocess,zipfile,zlib
ROOT=Path(__file__).resolve().parents[2]
BASE="14e60991c785c4293c3560e6d8b7ecded7e7ac75"
CAND="5cf7b4c0f212082342574763aaf5b19e00c4e323"
parser=argparse.ArgumentParser();parser.add_argument("--rojo",required=True);parser.add_argument("--out",required=True)
a=parser.parse_args();out=Path(a.out).resolve();assert out.is_absolute() and not out.exists(),"choose a new output directory"
out.mkdir(parents=True)
archive=out/"baseline-source.zip"
subprocess.run(["git","archive","--format=zip","--output="+str(archive),BASE,"roblox_port"],cwd=ROOT,check=True)
baseline=out/"baseline-source";baseline.mkdir()
with zipfile.ZipFile(archive) as z:
 for name in z.namelist():
  target=(baseline/name).resolve();assert baseline in target.parents or target==baseline,"archive path escapes source folder"
 z.extractall(baseline)
def verified(src,revision):
 data=subprocess.check_output(["git","ls-tree","-rz",revision,"roblox_port/src"],cwd=ROOT)
 rows=[]
 for line in data.split(b"\0"):
  if not line:continue
  header,name=line.split(b"\t",1);rel=name.decode("utf-8");mode,kind,oid=header.split()
  assert kind==b"blob" and mode in {b"100644",b"100755"},rel
  p=src/rel;b=p.read_bytes();actual=hashlib.sha1(b"blob "+str(len(b)).encode()+b"\0"+b).hexdigest()
  assert actual==oid.decode(),"source differs from Git: "+rel
  rows.append({"path":rel,"sha256":hashlib.sha256(b).hexdigest()})
 actual={p.relative_to(src).as_posix() for p in (src/"roblox_port/src").rglob("*.luau")}
 assert actual=={r["path"] for r in rows},"unexpected source files"
 return rows
sources={"baseline":(baseline,BASE),"candidate":(ROOT,CAND)}
base_config=json.loads((baseline/"roblox_port/default.project.json").read_text(encoding="utf-8"))["tree"]
cand_config=json.loads((ROOT/"roblox_port/default.project.json").read_text(encoding="utf-8"))["tree"]
for key in ["Workspace","Lighting","MaterialService","Players"]:
 assert base_config[key]==cand_config[key],"engine/lighting configuration changed: "+key

rows={role:verified(src,rev) for role,(src,rev) in sources.items()}
# Match fixture geometry, atmosphere and camera inputs. Prey readiness/save code is allowed to differ.
matched=[*sorted((ROOT/"roblox_port/src/Shared/World").glob("*.luau")),ROOT/"roblox_port/src/Client/SpiderCamera.luau",ROOT/"roblox_port/src/Shared/Habitat/WindowsillLayout.luau"]
for p in matched:
 rel=p.relative_to(ROOT);assert (baseline/rel).read_bytes()==p.read_bytes(),"fixture dependency changed: "+str(rel)
driver=ROOT/"docs/performance-pass/benchmark.luau"
def absolute_paths(node,port):
 if isinstance(node,dict):
  for k,v in node.items():
   if k=="$path":node[k]=str(port/v)
   else:absolute_paths(v,port)
manifest={"baseline":BASE,"candidate":CAND,"driver_sha256":hashlib.sha256(driver.read_bytes()).hexdigest(),"matched_fixture_dependencies":len(matched),"source_rows":rows,"profiles":[]}
for role,(src,revision) in sources.items():
 port=src/"roblox_port"
 for tier in ["full","low"]:
  project=json.loads((port/"default.project.json").read_text(encoding="utf-8"));absolute_paths(project,port)
  tree=project["tree"];tree["StarterPlayer"]["StarterPlayerScripts"]["Client"]["SilkPlayback"]={"$path":str(driver)}
  tree["Workspace"]["$attributes"]={"World":"preserve","Detail":tier,"SelfTest":False,"TestTarget":False,"Benchmark":True,"BenchmarkRole":role,"BenchmarkSource":revision,"BenchmarkWarmSeconds":15,"BenchmarkSampleSeconds":20,"BenchmarkTraceSeconds":0}
  target=out/(role+"-"+tier+".rbxlx");config=out/(role+"-"+tier+".project.json")
  config.write_text(json.dumps(project,indent=2),encoding="utf-8")
  subprocess.run([a.rojo,"build",str(config),"-o",str(target)],check=True)
  prefixes={"First":"ReplicatedFirst","Shared":"ReplicatedStorage.Shared","Client":"StarterPlayer.StarterPlayerScripts.Client","Server":"ServerScriptService.Server"}
  expected=[]
  for row in rows[role]:
   relative=Path(row["path"]).relative_to("roblox_port/src");names=list(relative.parts);prefix=prefixes[names.pop(0)]
   names[-1]=names[-1].removesuffix(".luau").removesuffix(".client").removesuffix(".server")
   b=(src/row["path"]).read_bytes().replace(b"\r\n",b"\n")
   expected.append([prefix+"."+".".join(names),len(b),zlib.adler32(b)])
  b=driver.read_bytes().replace(b"\r\n",b"\n");expected.append(["StarterPlayer.StarterPlayerScripts.Client.SilkPlayback",len(b),zlib.adler32(b)])
  guard='assert(game.PlaceId==0 and not game:GetService("RunService"):IsRunning());local expected={'
  guard+=','.join('{'+json.dumps(x[0])+','+str(x[1])+','+str(x[2])+'}' for x in expected)+'};'
  guard+='local n=0;for _,r in expected do local it=game;for part in string.gmatch(r[1],"[^.]+") do it=assert(it:FindFirstChild(part),r[1]) end;local text=string.gsub(it.Source,"\\r\\n","\\n");local a,b=1,0;for i=1,#text do a=(a+string.byte(text,i))%65521;b=(b+a)%65521 end;assert(#text==r[2] and b*65536+a==r[3],"SOURCE_MISMATCH "..r[1]);n+=1 end;'
  guard+='local total=0;for _,folder in {game.ReplicatedFirst,game.ReplicatedStorage.Shared,game.ServerScriptService.Server,game.StarterPlayer.StarterPlayerScripts.Client} do for _,it in folder:GetDescendants() do if it:IsA("LuaSourceContainer") then total+=1 end end end;assert(total==n);'
  guard+='assert(workspace:GetAttribute("SelfTest")==false and workspace:GetAttribute("TestTarget")==false and workspace:GetAttribute("BenchmarkSource")=='+json.dumps(revision)+' and workspace:GetAttribute("Detail")=='+json.dumps(tier)+');'
  guard+='print("[CHET_PERF_SOURCE_GUARD]",'+json.dumps(role)+','+json.dumps(revision)+','+json.dumps(tier)+',n,total,'+json.dumps(manifest['driver_sha256'])+')'
  target.with_suffix('.guard.luau').write_text(guard,encoding="utf-8",newline="\n")
  manifest["profiles"].append({"role":role,"tier":tier,"path":str(target),"sha256":hashlib.sha256(target.read_bytes()).hexdigest(),"production_modules":len(rows[role]),"extra_diagnostic_modules":1,"published":False})
(out/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n",encoding="utf-8")
print(json.dumps({"out":str(out),"profiles":manifest["profiles"],"matched_fixture_dependencies":len(matched)},indent=2))
