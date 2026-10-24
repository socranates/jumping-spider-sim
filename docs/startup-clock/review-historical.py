"""Bound the portion of the old first Heartbeat that predates its probe.

Does not reinterpret the original raw summaries or qualify a game speedup.
"""
from pathlib import Path
import hashlib,json
H=Path(__file__).resolve().parent;ROOT=H.parents[1];rows=[]
for filename in ['private13-final-player.json','private13-warm-player.json']:
 path=ROOT/'docs/integrated-release'/filename;raw=path.read_bytes();data=json.loads(raw)
 events=data['events'];summary=next(x['value']for x in events if x['kind']=='SUMMARY')
 gaps=[x['value']for x in events if x['kind']=='GAP'];largest=max(gaps,key=lambda x:x['ms'])
 assert largest['t']<.25 and largest['phase']=='initial-replication'
 lower=max(0,largest['ms']-largest['t']*1000)
 rows.append(dict(file=filename,sha256=hashlib.sha256(raw).hexdigest(),run=data['run'],
  largest_raw_dt_ms=largest['ms'],callback_since_probe_ms=largest['t']*1000,
  preprobe_span_lower_bound_ms=lower,initial_window_wall_seconds=summary['t'],
  initial_window_sum_raw_dt_seconds=summary['seconds']))
record=dict(rows=rows,limits='The first raw Heartbeat includes time before the probe began. The callback timestamp only bounds the observed interval; it does not locate the cause of earlier loading or prove there was no game/engine stall. Original metrics remain unchanged. No current native or standalone speedup claimed.')
target=H/'historical-clock-bounds.json';assert not target.exists();target.write_bytes((json.dumps(record,indent=2)+'\n').encode())
print(json.dumps(rows))
