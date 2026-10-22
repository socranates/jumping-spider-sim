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
# A complete v5 smoke does not prove the audit's eighth continuous-walk scene.
audit_routes=[]
for h in headers:
 run=h["run"];records={r["kind"]:r["value"] for r in results if r["run"]==run}
 route=records.get("continuous_route");walk=records.get("walk_continuous")
 good=False
 if route and walk and h["value"].get("harness_version")==6:
  path=route.get("path",[]);required=["pad_a2","pad_b2","pad_c2"]
  good=(route.get("regions")==required and route.get("required_regions")==required and route.get("elapsed",0)>=60
   and walk.get("elapsed",0)>=60 and sum(walk.get("frame_times_ms",[]))/1000>=58 and abs(walk["elapsed"]-route["elapsed"])<1
   and route.get("distance",0)>=169.5 and route.get("placement_calls_during_walk")==route.get("fresh_calls_during_walk")==0
   and walk.get("action_ok") is True and walk.get("focus_preserved") is True and walk.get("viewport_unchanged") is True
   and len(path)>=50 and path[0].get("elapsed",99)<=2 and abs(path[-1].get("elapsed",0)-route["elapsed"])<1)
  if good:
   for point in path:
    pos=point.get("pos",[])
    if len(pos)!=3 or not all(isinstance(v,(float,int)) and math.isfinite(v) for v in pos) or abs(pos[0]+60)>=1 or abs(pos[1]+84.29)>.5:good=False
   for before,after in zip(path,path[1:]):
    dt=after["elapsed"]-before["elapsed"]
    distance=math.dist(before["pos"],after["pos"])
    if not 0<dt<=2 or distance>5*dt+.5 or after["pos"][2]>before["pos"][2]+.1:good=False
  if good:good=path[0]["region"]=="pad_a2" and path[-1]["region"]=="pad_c2" and path[-1]["pos"][2]<=-720
 audit_routes.append({"run":run,"passed":bool(good)})
 if h["value"].get("harness_version",0)>=6:complete=complete and bool(good)
audit_scenes_complete=bool(audit_routes) and all(r["passed"] for r in audit_routes)
workloads=[]
for h in headers:
 records=[r["value"] for r in results if r["run"]==h["run"] and "frame_times_ms" in r["value"]]
 good=h["value"].get("predator_flags")=={name:True for name in ["Wasp","Cat","Bird","Frog"]} and bool(records)
 for value in records:
  for edge in ["before","after"]:
   predators=value.get(edge,{}).get("predators",{})
   if not all(predators.get(name,{}).get("enabled") is True for name in ["wasp","cat","bird","frog"]):good=False
 workloads.append({"run":h["run"],"passed":good})
 if h["value"].get("harness_version",0)>=6:complete=complete and good
workload_verified=bool(workloads) and all(r["passed"] for r in workloads)


result={"source_log":str(source.resolve()),"manifest":str(Path(a.manifest).resolve()),"guards":guard_rows,"source_guard_verified":source_guard_verified,"complete":complete,"comparison_config":comparison_config,"audit_scenes_complete":audit_scenes_complete,"audit_routes":audit_routes,"workload_verified":workload_verified,"workloads":workloads,"incomplete":incomplete,"failures":failures,"records":results}
target.write_text(json.dumps(result,indent=2)+"\n",encoding="utf-8")
print(json.dumps({"complete":complete,"comparison_config":comparison_config,"source_guard_verified":source_guard_verified,"records":len(results),"incomplete":incomplete,"failures":failures},indent=2))
