"""Summarize frozen candidate evidence. Does not run tests or publish.
Missing or incomplete receipts keep their gates false. Run after recording terminal exit.
"""
from pathlib import Path
import hashlib,json,re,runpy
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
SOURCE="dc1c4b8640014a5718b6dc17d31044aca070c6d7"
EVIDENCE="e50104232f063255"
def read(name):
    p=OUT/name
    return p.read_text(encoding="utf-8-sig",errors="replace") if p.exists() else ""
def obj(name):
    s=read(name)
    return json.loads(s) if s else None
manifest=obj("source-manifest.json")
compiled=obj("compile.json")
source_matches=bool(manifest and manifest["source_commit"]==SOURCE and len(manifest["files"])==216 and all(
    hashlib.sha256((ROOT/"roblox_port"/r["path"]).read_bytes().replace(b"\r\n",b"\n")).hexdigest()==r["sha256"] for r in manifest["files"]))
compile_matches=bool(compiled and compiled["source_commit"]==SOURCE and compiled["total"]==compiled["passed"]==216 and all(
    r["exit_code"]==0 and hashlib.sha256((ROOT/r["path"]).read_bytes()).hexdigest()==r["sha256"] for r in compiled["files"]))
h=hashlib.sha256();port=ROOT/"roblox_port"
for p in sorted([*port.glob("src/**/*.luau"),*port.glob("tests/**/*.luau"),*port.glob("*.project.json")]):
    if p.name!="BuildInfo.luau":h.update(p.relative_to(port).as_posix().encode()+b"\0"+p.read_bytes()+b"\0")
actual=h.hexdigest()[:16]
cli=read("cli-final.txt")
rows=re.findall(r"^([A-Z_0-9 ]+) passed=(\d+) failed=(\d+)",cli,re.M)
failures=[s for s in cli.splitlines() if re.search(r"\bfailed=[1-9]|^FAIL |\[SELFTEST\] FAIL|not enough memory",s)]
process=obj("cli-process.json");ci=obj("ci-final.json")
native_text=read("native-final.txt")
ends=re.findall(r"\[SELFTEST\] END pass=(\d+) fail=(\d+) skip=(\d+)",native_text)
native=None
retirement_probe_pass="[CHET_ADAPTER_NATIVE_PASS]" in native_text and "[CHET_ADAPTER_NATIVE_FAIL]" not in native_text
if ends:
    a,b,c=map(int,ends[-1]);native=dict(passed=a,failed=b,skipped=c,source_guard_matches=f"[CHET_ADAPTER_SOURCE_FINGERPRINTS] 216 216 {SOURCE}" in native_text)
offline=bool(retirement_probe_pass and source_matches and compile_matches and actual==EVIDENCE and len(rows)==62 and len({r[0] for r in rows})==62
    and sum(int(r[1]) for r in rows)==443235 and not failures and process and process.get("exit_code")==0 and process.get("source_commit")==SOURCE
    and ci and ci["conclusion"]=="success" and ci["head_sha"]==SOURCE and ci.get("suites")==62 and ci.get("passed")==443235 and ci.get("failed")==0 and native and native["source_guard_matches"] and native["passed"]==274 and native["failed"]==native["skipped"]==0)
try:
    build_preflight=runpy.run_path(str(OUT/"verify-build.py"))["verify"](port/"TheWindowsill.rbxlx")
except Exception as err:
    build_preflight={"error":str(err)}
offline=offline and build_preflight.get("matched_scripts")==216 and build_preflight.get("source_commit")==SOURCE
native_failures=[line for line in native_text.splitlines() if "CreatorError" in line or "Script timeout" in line or "[SELFTEST] FAIL" in line]
offline=bool(offline and not native_failures)
online=obj("online-store.json")
receipt=dict(candidate=dict(branch="codex/save-adapter-errors",source_commit=SOURCE,evidence_id=EVIDENCE),published=False,
    source_manifest_matches=source_matches,compile_fingerprints_match=compile_matches,computed_evidence_id=actual,
    local_cli=dict(completed_summaries=len(rows),passed=sum(int(r[1]) for r in rows),failed=sum(int(r[2]) for r in rows),failure_lines=failures),
    local_process=process,ci=ci,native=native,retirement_probe_pass=retirement_probe_pass,native_failure_lines=native_failures,build_preflight=build_preflight,offline_gates_pass=offline,online_store_attempt=online,online_store_gate_pass=bool(online and online.get("passed") and online.get("source_commit")==SOURCE),
    actual_client_rejoin_verified=False,performance_matrix_complete=False,physical_phone_tested=False,publication_ready=False,
    builds=[dict(path=p.relative_to(ROOT).as_posix(),bytes=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in [port/"TheWindowsill.rbxlx",port/"TheWindowsillTests.rbxlx"]])
(OUT/"receipt.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
print(json.dumps({k:receipt[k] for k in ["source_manifest_matches","compile_fingerprints_match","computed_evidence_id","local_cli","native","offline_gates_pass","publication_ready"]},indent=2))
