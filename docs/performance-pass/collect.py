"""Collect complete CRC-checked profiling records from a native Studio log.
Usage: python collect.py LOG --out NEW_JSON
Incomplete/failed runs remain explicitly incomplete; never filled with zeroes.
"""
from pathlib import Path
import argparse,json,re,zlib,math,hashlib
p=argparse.ArgumentParser();p.add_argument("log");p.add_argument("--out",required=True);p.add_argument("--manifest",required=True);p.add_argument("--run-id");a=p.parse_args()
manifest=json.loads(Path(a.manifest).read_text(encoding="utf-8"))
source=Path(a.log);target=Path(a.out);assert not target.exists(),"choose a new result file"
rows={};completed=set();failures=[];guards=[]
for line in source.read_text(encoding="utf-8",errors="replace").splitlines():
 if "[FLog::CreatorOutput] [CHET_PERF_SOURCE_GUARD]" in line:guards.append(line)
 match=re.search(r"\[CHET_PERF_BEGIN\]\s+(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)$",line)
 if match:
  run,kind,n,chunks,adler=match.groups();
  if a.run_id and run!=a.run_id:continue
  key=(run,kind);assert key not in rows,"duplicate record start"
  rows[key]={"bytes":int(n),"count":int(chunks),"adler32":int(adler),"chunks":{},"ended":False};continue
 match=re.search(r"\[CHET_PERF_DATA\]\s+(\S+)\s+(\S+)\s+(\d+)\s+(\".*\")$",line)
 if match:
  run,kind,i,payload=match.groups();
  if a.run_id and run!=a.run_id:continue
  key=(run,kind);assert key in rows,"chunk has no start"
  i=int(i);assert i not in rows[key]["chunks"],"duplicate chunk";rows[key]["chunks"][i]=json.loads(payload);continue
 match=re.search(r"\[CHET_PERF_END\]\s+(\S+)\s+(\S+)$",line)
 if match:
  if not a.run_id or match.group(1)==a.run_id:rows[match.groups()]["ended"]=True
  continue
 match=re.search(r"\[CHET_PERF_DONE\]\s+(\S+)\s+",line)
 if match and (not a.run_id or match.group(1)==a.run_id):completed.add(match.group(1))
 if ("[CHET_PERF_FAIL]" in line and (not a.run_id or a.run_id in line)) or "[FLog::CreatorError]" in line or "Script timeout" in line:failures.append(line)
results=[];incomplete=[]
for (run,kind),row in rows.items():
 if not row["ended"] or set(row["chunks"])!=set(range(1,row["count"]+1)):
  incomplete.append({"run":run,"kind":kind,"chunks":len(row["chunks"]),"expected":row["count"]});continue
 raw="".join(row["chunks"][i] for i in range(1,row["count"]+1)).encode("utf-8")
 assert len(raw)==row["bytes"] and zlib.adler32(raw)==row["adler32"],"corrupt/truncated log record"
 value=json.loads(raw)
 if "frame_times_ms" in value:
  values=value["frame_times_ms"];s=sorted(values);n=len(s);summary=value["frames"]
  assert n==summary["frames"] and n>0
  for key,expected in {"mean_ms":sum(values)/n,"median_ms":s[math.ceil(n*.5)-1],"p95_ms":s[math.ceil(n*.95)-1],"max_ms":max(s)}.items():
   assert math.isclose(summary[key],expected,rel_tol=1e-10,abs_tol=1e-8),(kind,key,summary[key],expected)
 results.append({"run":run,"kind":kind,"sha256":hashlib.sha256(raw).hexdigest(),"value":value})
run_ids={r["run"] for r in results}
headers=[r for r in results if r["kind"]=="header"]
comparison_config=bool(headers) and all(r["value"]["warm_seconds"]>=15 and r["value"]["sample_seconds"]>=20 for r in headers)
expected={"header","sill_dawn","hut_lamp_night","garden_rain","meadow_wind","pond","can_doorway","lamppost_night","walk_1","walk_2","walk_3"}
complete=bool(run_ids) and all(run in completed and expected.issubset({r["kind"] for r in results if r["run"]==run}) for run in run_ids) and not incomplete and not failures
guard_rows=[]
for line in guards:
 m=re.search(r"\[CHET_PERF_SOURCE_GUARD\]\s+(\S+)\s+(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s+([0-9a-f]{64})$",line)
 if m:
  role,revision,tier,n,total,driver_hash=m.groups()
  matching=[x for x in manifest["profiles"] if x["role"]==role and x["tier"]==tier]
  good=bool(matching) and driver_hash==manifest["driver_sha256"] and revision==manifest[role] and int(n)==int(total)==matching[0]["production_modules"]+matching[0]["extra_diagnostic_modules"]
  guard_rows.append({"role":role,"source":revision,"tier":tier,"passed":good,"modules":int(n),"driver_sha256":driver_hash})
source_guard_verified=bool(headers) and all(any(g["passed"] and all(g[k]==h["value"][k] for k in ["role","source","tier"]) for g in guard_rows) for h in headers)
complete=complete and source_guard_verified
result={"source_log":str(source.resolve()),"manifest":str(Path(a.manifest).resolve()),"guards":guard_rows,"source_guard_verified":source_guard_verified,"complete":complete,"comparison_config":comparison_config,"incomplete":incomplete,"failures":failures,"records":results}
target.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
print(json.dumps({"complete":complete,"comparison_config":comparison_config,"source_guard_verified":source_guard_verified,"records":len(results),"incomplete":incomplete,"failures":failures},indent=2))
