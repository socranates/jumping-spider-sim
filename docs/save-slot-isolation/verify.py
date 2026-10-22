"""Verify source-bound receipts without running tests or publishing."""
from pathlib import Path
import hashlib,json,re,runpy,subprocess
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
SOURCE="3647a94c67f83076a0c7be09d75ef4a60bb0b4d5"
FIRST="71b634cae272c0fab284be65995e23889c621006"
EVIDENCE="1984fdd8e8dee0ad"
def obj(name):
 p=OUT/name
 return json.loads(p.read_text(encoding="utf-8-sig")) if p.exists() else None
def read(name):
 p=OUT/name
 return p.read_text(encoding="utf-8-sig",errors="replace") if p.exists() else ""
def rows(text):return re.findall(r"^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)",text,re.M)
manifest=obj("source-manifest.json");compiled=obj("compile.json")
source_ok=bool(manifest and manifest["source_commit"]==SOURCE and len(manifest["files"])==216 and all(hashlib.sha256((ROOT/"roblox_port"/r["path"]).read_bytes().replace(b"\r\n",b"\n")).hexdigest()==r["sha256"] for r in manifest["files"]))
compile_ok=bool(compiled and compiled["source_commit"]==SOURCE and compiled["total"]==compiled["passed"]==216 and all(r["exit_code"]==0 and hashlib.sha256((ROOT/r["path"]).read_bytes()).hexdigest()==r["sha256"] for r in compiled["files"]))
h=hashlib.sha256();port=ROOT/"roblox_port"
for p in sorted([*port.glob("src/**/*.luau"),*port.glob("tests/**/*.luau"),*port.glob("*.project.json")]):
 if p.name!="BuildInfo.luau":h.update(p.relative_to(port).as_posix().encode()+b"\0"+p.read_bytes()+b"\0")
strict=read("strict.txt");strict_proc=obj("strict-process.json")
strict_ok=bool(strict_proc and strict_proc.get("exit_code")==0 and strict_proc.get("source_commit")==SOURCE and not re.search(r"TypeError|SyntaxError|Error:",strict))
runner=read("runner.txt");runner_ok="Ran 5 tests" in runner and bool(re.search(r"^OK$",runner,re.M))
target=rows(read("targeted-final.txt"));target_proc=obj("targeted-process.json")
target_ok=bool(target_proc and target_proc.get("exit_code")==0 and target_proc.get("source_commit")==SOURCE and {r[0]:int(r[1]) for r in target}=={"REST_STORAGE":14,"STATE":724,"STATE_CLIENT":162,"REST_COMPRESSION":57} and all(int(r[2])==0 for r in target))
first_rows=rows(read("windows-first-full.txt"));first_proc=obj("windows-first-process.json")
changed=subprocess.check_output(["git","diff","--name-only",FIRST,SOURCE],cwd=ROOT,text=True).splitlines()
assert changed==["roblox_port/tests/rest_storage.luau","roblox_port/tests/studio/BuildInfo.luau"],changed
preflight=runpy.run_path(str(OUT/"verify-build.py"))["verify"](port/"TheWindowsill.rbxlx")
ci=obj("ci-final.json");ci_rows=rows(read("ci-final-tests.txt"))
ci_ok=bool(ci and ci.get("head_sha")==SOURCE and ci.get("conclusion")=="success" and len(ci_rows)==len({r[0] for r in ci_rows})==62 and sum(int(r[1]) for r in ci_rows)==443398 and all(int(r[2])==0 for r in ci_rows))
receipt=dict(source_commit=SOURCE,evidence_id=EVIDENCE,computed_evidence=h.hexdigest()[:16],source_manifest_matches=source_ok,compile_matches=compile_ok,strict_clean=strict_ok,runner_regressions_pass=runner_ok,windows_targeted=dict(source_commit=SOURCE,suites=len(target),passed=sum(int(r[1]) for r in target),exit_code=target_proc.get("exit_code") if target_proc else None,pass_gate=target_ok),windows_first_full=dict(source_commit=FIRST,suites_with_successful_summaries=len(first_rows),passed=sum(int(r[1]) for r in first_rows),exit_code=first_proc.get("exit_code") if first_proc else None,known_failure="obsolete all-session-read-only expectation in rest_storage; fixed and targeted rerun passed",final_source_full_rerun=False),test_only_changes_after_first_run=changed,build_preflight=preflight,linux_ci=dict(suites=len(ci_rows),passed=sum(int(r[1]) for r in ci_rows),pass_gate=ci_ok,run=ci),offline_gates_pass=source_ok and compile_ok and strict_ok and runner_ok and target_ok and ci_ok and h.hexdigest()[:16]==EVIDENCE,native_studio_verified=bool(obj("native-gates.json") and obj("native-gates.json").get("source_commit")==SOURCE and obj("native-gates.json").get("passed")),actual_client_rejoin_verified=False,performance_matrix_complete=False,publication_ready=False,published=False)
(OUT/"receipt.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
print(json.dumps(receipt,indent=2))
