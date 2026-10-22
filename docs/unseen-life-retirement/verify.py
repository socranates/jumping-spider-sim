from pathlib import Path
import hashlib,json,re,sys,subprocess,io,tarfile,xml.etree.ElementTree as ET
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
def read(n):return json.loads((HERE/n).read_text())
def sha(b):return hashlib.sha256(b).hexdigest()
SOURCE="5760c67627449de61fc18801007a3739ff0cc75b"
old=read("baseline-process.json");new=read("candidate-process.json")
archive=subprocess.check_output(["git","archive","--format=tar",SOURCE,"roblox_port/src","roblox_port/tests/state.luau"],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(archive)) as tree:
 for item in tree:
  if item.isfile():assert new["inputs"][item.name]==sha(tree.extractfile(item).read())
assert old["exit_code"]!=0 and new["exit_code"]==0
assert old["inputs"].keys()==new["inputs"].keys()
changed=[p for p in old["inputs"] if old["inputs"][p]!=new["inputs"][p]]
assert changed==["roblox_port/src/Shared/Persistence/SaveSession.luau"]
for p,h in new["inputs"].items():assert sha((ROOT/p).read_bytes())==h,p
assert "STATE passed=733 failed=8" in (HERE/"baseline.txt").read_text()
assert "STATE passed=741 failed=0" in (HERE/"candidate.txt").read_text()
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
 assert len(rows)==64 and sum(int(r[1]) for r in rows)==443833 and all(int(r[2])==0 for r in rows)
 full=True
ci=read("ci-final.json") if (HERE/"ci-final.json").exists() else None
if ci:
 assert ci["head_sha"]==SOURCE and ci["conclusion"]=="success" and ci["suites"]==64 and ci["passed"]==443833 and ci["failed"]==0
 for name,h in ci["logs_sha256"].items():assert sha((HERE/name).read_bytes())==h
receipt={"source":SOURCE,"paired_probe_test_hash_matches":True,"baseline_failed":8,"candidate_passed":741,"changed_production_modules":changed,"compiled":216,"strict_clean":True,"runner_regressions":5,"windows_full_complete":full,"windows_full_passed":443833 if full else None,"linux_ci_verified":bool(ci),"native_verified":False,"release_sha256":release_hash,"published":False,"publication_ready":False,"foreign_lock_continue_ux_complete":False}
(HERE/"receipt.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf8",newline="\n")
print(json.dumps(receipt,indent=2))
