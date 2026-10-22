from pathlib import Path
import hashlib,json,re,sys,subprocess,io,tarfile,xml.etree.ElementTree as ET
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
def read(n):return json.loads((HERE/n).read_text())
def sha(b):return hashlib.sha256(b).hexdigest()
SOURCE="6026d6c45fbad072c2bec14a3b893fb8e7abccc2"
old=read("baseline-process.json");new=read("candidate-process.json")
if SOURCE!="PENDING":
 archive=subprocess.check_output(["git","archive","--format=tar",SOURCE,"roblox_port/src","roblox_port/tests/state.luau"],cwd=ROOT)
 with tarfile.open(fileobj=io.BytesIO(archive)) as tree:
  for item in tree:
   if item.isfile():assert new["inputs"][item.name]==sha(tree.extractfile(item).read())
assert old["exit_code"]!=0 and new["exit_code"]==0
assert old["inputs"].keys()==new["inputs"].keys()
changed=[p for p in old["inputs"] if old["inputs"][p]!=new["inputs"][p]]
assert changed==["roblox_port/src/Shared/Persistence/SaveSession.luau"]
for p,h in new["inputs"].items():assert sha((ROOT/p).read_bytes())==h,p
assert "STATE passed=760 failed=9" in (HERE/"baseline.txt").read_text()
assert "STATE passed=769 failed=0" in (HERE/"candidate.txt").read_text()
rows=read("compile.json")["files"];assert len(rows)==216
for row in rows:assert row["exit_code"]==0 and row["sha256"]==new["inputs"][row["path"]]
for n in ["build","sourcemap","strict","runner"]:assert read(n+"-process.json")["exit_code"]==0
assert not re.search(r"TypeError|SyntaxError|Error:",(HERE/"strict.txt").read_text())
assert "Ran 5 tests" in (HERE/"runner.txt").read_text() and "OK" in (HERE/"runner.txt").read_text()
expected={}
for path,h in new["inputs"].items():
 if not path.startswith("roblox_port/src/"):continue
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
 assert len(rows)==64 and sum(int(r[1]) for r in rows)==443861 and all(int(r[2])==0 for r in rows)
 full=True
prepared=read("prepared-native-manifest.json")
assert prepared["source"]==SOURCE and prepared["persistence_disabled"]
scripts={r["path"]:r["sha256"] for r in prepared["scripts"]};assert len(scripts)==len(prepared["scripts"])==217
assert scripts.pop("StarterPlayer.StarterPlayerScripts.Client.SilkPlayback")==sha((HERE/"native-probe.luau").read_bytes())
assert scripts==expected and read("native-compile-process.json")["exit_code"]==0
native=False;native_checks=None;shadow_checks=None
if (HERE/"native-events.txt").exists():
 events=(HERE/"native-events.txt").read_text(encoding="utf8")
 assert re.search(r"\[FOUNDATION_NATIVE_GUARD\]\s+"+re.escape(SOURCE)+r"\s+217\s+persistence_disabled",events)
 assert not re.search(r"\[(?:OBSERVED_LIFE|SHADOW_CLEANUP)_FAIL\]|CreatorError",events)
 done=re.findall(r"\[OBSERVED_LIFE_DONE\]\s+(\d+)\s+8\s+45\s*$",events,re.M);assert len(done)==1
 rows=re.findall(r"\[OBSERVED_LIFE_CASE\]\s+(\d+)\s+(\d+)\s+(\d+)\s+(.+)$",events,re.M)
 assert len(rows)==8 and [int(r[1]) for r in rows]==list(range(1,9)) and all(r[0]==done[0] for r in rows) and int(rows[-1][2])==45
 shadow=re.findall(r"\[SHADOW_CLEANUP_DONE\]\s+(\d+)\s+7\s+(\d+)\s*$",events,re.M);assert len(shadow)==1
 rows=re.findall(r"\[SHADOW_CLEANUP_CASE\]\s+(\d+)\s+(\d+)\s+(\d+)\s+(.+)$",events,re.M)
 assert len(rows)==7 and [int(r[1]) for r in rows]==list(range(1,8)) and all(r[0]==shadow[0][0] for r in rows)
 assert int(rows[-1][2])==int(shadow[0][1])>0
 native=True;native_checks=45;shadow_checks=int(shadow[0][1])
integration=False;integration_passed=None
if (HERE/"integration-process.json").exists():
 r=read("integration-process.json");assert r["exit_code"]==0
 for p,h in r["inputs"].items():assert sha((ROOT/p).read_bytes())==h,p
 rows=re.findall(r"^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)",(HERE/"integration.txt").read_text(),re.M)
 assert len(rows)==4 and all(int(r[2])==0 for r in rows)
 integration=True;integration_passed=sum(int(r[1]) for r in rows)
known=read("known-life-candidate-process.json")
assert known["exit_code"]==0
for p,h in known["inputs"].items():assert new["inputs"][p]==h
prior=json.loads((ROOT/"docs/unseen-life-retirement/known-life-baseline-process.json").read_text())
assert prior["exit_code"]!=0 and prior["probe_sha256"]==known["probe_sha256"]==sha((HERE/"known-life-probe.luau").read_bytes())
assert "preserved=true" in (HERE/"known-life-candidate.txt").read_text() and "ack=false" in (HERE/"known-life-candidate.txt").read_text()
ci=read("ci-final.json") if (HERE/"ci-final.json").exists() else None
if ci:
 assert ci["head_sha"]==SOURCE and ci["conclusion"]=="success" and ci["suites"]==64 and ci["passed"]==443861 and ci["failed"]==0
 for name,h in ci["logs_sha256"].items():assert sha((HERE/name).read_bytes())==h
receipt={"source":SOURCE,"paired_probe_test_hash_matches":True,"baseline_failed":9,"candidate_passed":769,"changed_production_modules":changed,"compiled":216,"integration_verified":integration,"integration_passed":integration_passed,"strict_clean":True,"runner_regressions":5,"windows_full_complete":full,"windows_full_passed":443861 if full else None,"linux_ci_verified":bool(ci),"native_preparation_verified":True,"native_verified":native,"native_save_checks":native_checks,"native_shadow_checks":shadow_checks,"release_sha256":release_hash,"published":False,"publication_ready":False,"foreign_lock_continue_ux_complete":False}
if "--require-full" in sys.argv:assert full and ci and native,"full Windows/Linux and actual guarded native execution required"
(HERE/"receipt.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf8",newline="\n")
print(json.dumps(receipt,indent=2))
