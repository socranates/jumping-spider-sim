from pathlib import Path
import json,hashlib,re,subprocess,tarfile,io,sys,xml.etree.ElementTree as ET
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
BASE="6026d6c45fbad072c2bec14a3b893fb8e7abccc2";SOURCE="8e02b5ee5f443ab332cf7e70f5951a304cb89eea"
def read(n):return json.loads((HERE/n).read_text())
def sha(b):return hashlib.sha256(b).hexdigest()
def archive(commit):
 data=subprocess.check_output(["git","archive","--format=tar",commit,"roblox_port/src"],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(data)) as tree:return {m.name:tree.extractfile(m).read() for m in tree if m.isfile()}
base=archive(BASE);assert len(base)==216
expected_changes={"roblox_port/src/Client/WorldClient.luau","roblox_port/src/First/SplashScreen.luau","roblox_port/src/First/Splash.client.luau"}
all_new=None
for prefix,test,oldrow,newrow in [("","world_client.luau","WORLD_CLIENT passed=29 failed=4","WORLD_CLIENT passed=33 failed=0"),("title-","title.luau","TITLE passed=15 failed=6","TITLE passed=21 failed=0")]:
 old=read(prefix+"baseline-process.json");new=read(prefix+"candidate-process.json")
 assert old["exit_code"]!=0 and new["exit_code"]==0
 assert oldrow in (HERE/(prefix+"baseline.txt")).read_text() and newrow in (HERE/(prefix+"candidate.txt")).read_text()
 assert old["inputs"]["roblox_port/tests/"+test]==new["inputs"]["roblox_port/tests/"+test]==sha((ROOT/"roblox_port/tests"/test).read_bytes())
 for p,b in base.items():assert old["inputs"][p]==sha(b),p
 actual={p:new["inputs"][p] for p in base}
 assert {p for p in base if old["inputs"][p]!=actual[p]}==expected_changes
 if all_new is not None:assert actual==all_new
 all_new=actual
for p,h in all_new.items():assert sha((ROOT/p).read_bytes())==h,p
if SOURCE!="PENDING":
 assert {p:sha(b) for p,b in archive(SOURCE).items()}==all_new
 for name in ["world_client.luau","title.luau"]:
  data=subprocess.check_output(["git","show",SOURCE+":roblox_port/tests/"+name],cwd=ROOT)
  assert sha(data)==sha((ROOT/"roblox_port/tests"/name).read_bytes())
compile=read("compile.json");assert compile["total"]==compile["passed"]==216
for row in compile["files"]:assert row["exit_code"]==0 and row["sha256"]==all_new[row["path"]]
for name in ["build","sourcemap","strict","runner"]:assert read(name+"-process.json")["exit_code"]==0
assert not re.search(r"TypeError|SyntaxError|Error:",(HERE/"strict.txt").read_text())
assert "Ran 5 tests" in (HERE/"runner.txt").read_text() and "OK" in (HERE/"runner.txt").read_text()
integration=read("integration-process.json");assert integration["exit_code"]==0
for p,h in integration["inputs"].items():assert sha((ROOT/p).read_bytes())==h,p
rows=re.findall(r"^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)",(HERE/"integration.txt").read_text(),re.M)
assert rows==[("CLIENT","27","0"),("PRESERVE","1154","0")]
expected={}
for path in all_new:
 parts=list(Path(path).relative_to("roblox_port/src").parts)
 prefix={"First":"ReplicatedFirst","Client":"StarterPlayer.StarterPlayerScripts.Client","Server":"ServerScriptService.Server","Shared":"ReplicatedStorage.Shared"}[parts.pop(0)]
 parts[-1]=parts[-1].removesuffix(".luau").removesuffix(".client").removesuffix(".server")
 expected[prefix+"."+".".join(parts)]=sha((ROOT/path).read_bytes().replace(b"\r\n",b"\n"))
def release(path):
 found={}
 def walk(it,parent=""):
  name=it.findtext("./Properties/*[@name='Name']");full=parent+"."+name if parent else name
  if it.attrib["class"] in {"Script","LocalScript","ModuleScript"}:
   assert full not in found
   found[full]=sha(it.findtext("./Properties/*[@name='Source']").replace("\r\n","\n").encode())
  for child in it.findall("Item"):walk(child,full)
 for it in ET.parse(path).getroot().findall("Item"):walk(it)
 assert found==expected
 return sha(path.read_bytes())
release_hash=release(ROOT/"roblox_port/TheWindowsill.rbxlx")
try:release(ROOT/"roblox_port/TheWindowsillTests.rbxlx")
except AssertionError:pass
else:raise AssertionError("test artifact accepted")
full=False
if (HERE/"windows-full-process.json").exists():
 assert read("windows-full-process.json")["exit_code"]==0
 rows=re.findall(r"^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)",(HERE/"windows-full.txt").read_text(),re.M)
 assert len(rows)==64 and sum(int(r[1]) for r in rows)==443869 and all(int(r[2])==0 for r in rows)
 full=True
ci=read("ci-final.json") if (HERE/"ci-final.json").exists() else None
if ci:
 assert ci["head_sha"]==SOURCE and ci["conclusion"]=="success" and ci["suites"]==64 and ci["passed"]==443869 and ci["failed"]==0
 for n,h in ci["logs_sha256"].items():assert sha((HERE/n).read_bytes())==h
receipt={"source":SOURCE,"base_source":BASE,"evidence_id":"58063ec00de84212","changed_production_modules":sorted(expected_changes),"paired_baseline_failures":10,"world_passed":33,"title_passed":21,"integration_passed":1181,"targeted_passed":1235,"targeted_suites":4,"compiled":216,"strict_clean":True,"runner_regressions":5,"release_sha256":release_hash,"test_place_rejected":True,"windows_full_complete":full,"linux_ci_verified":bool(ci),"native_verified":False,"actual_network_streaming_verified":False,"native_phone_ui_verified":False,"published":False,"publication_ready":False}
(HERE/"receipt.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf8",newline="\n");print(json.dumps(receipt,indent=2))
