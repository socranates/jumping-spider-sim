"""Summarize wall-clock frame intervals. Usage: python analyze_profile.py frames.csv."""
import csv, json, math, sys
from pathlib import Path
rows=list(csv.DictReader(Path(sys.argv[1]).open(encoding="utf-8")))
def percentile(v,p):
    v=sorted(v)
    return round(v[max(0, math.ceil(len(v)*p)-1)], 3)
def summarize(rr):
    f=[float(r["frame_ms"]) for r in rr]
    out={"frames":len(f),"mean_ms":round(sum(f)/len(f),3),"p50_ms":percentile(f,.5),"p95_ms":percentile(f,.95),"p99_ms":percentile(f,.99),"max_ms":max(f),"over_33_3ms":sum(x>33.3 for x in f),"over_50ms":sum(x>50 for x in f)}
    for col in ("process_ms","physics_ms","render_cpu_ms","render_gpu_ms"):
        out[col+"_p95"]=percentile([float(r[col]) for r in rr],.95)
    return out
result={"all":summarize(rows),"phases":{str(i):summarize([r for r in rows if r["phase"]==str(i)]) for i in range(5)}}
print(json.dumps(result,indent=2))
