"""Describe a completed native traversal; do not turn duration into a leak verdict."""
from pathlib import Path
import argparse,hashlib,json,statistics
p=argparse.ArgumentParser();p.add_argument('--input',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
raw=a.input.read_bytes();r=json.loads(raw)
assert r['passed']and r['complete_fixture_scope']and r['source_guards']>=2
assert r['creator_errors']==0 and r['methods_instrumented']
trace=r['trace'];begins=[e for e in trace if e['kind']=='BEGIN'];ends=[e for e in trace if e['kind']=='END']
assert len(begins)==len(ends)==1 and len({e['run']for e in trace})==1
begin,end=begins[0]['value'],ends[0]['value']
assert end['completed']and end['elapsed']>=begin['seconds']>=1800
rows=[e['value']for e in trace if e['kind']=='ROW'];assert len(rows)>=30
assert all(x['elapsed']<y['elapsed']for x,y in zip(rows,rows[1:]))
assert all(sum(x['modes'].values())==x['frames']for x in rows)
findings=[e['value']for e in trace if e['kind']=='FINDING']
assert len(findings)==end['findings']
def window(lo,hi):
 selected=[x for x in rows if lo<=x['elapsed']<hi];assert selected,(lo,hi)
 return dict(from_seconds=lo,to_seconds=hi,rows=len(selected),
  lua_kb={k:f([x['memory']['lua_kb']for x in selected])for k,f in [('min',min),('median',statistics.median),('max',max)]},
  engine_mb={k:f([x['memory']['engine_mb']for x in selected if x['memory'].get('engine_mb')is not None])for k,f in [('min',min),('median',statistics.median),('max',max)]},
  instances={k:f([x['memory']['instances']for x in selected if x['memory'].get('instances')is not None])for k,f in [('min',min),('median',statistics.median),('max',max)]})
windows=[window(i,i+300)for i in range(0,1800,300)]
stalls=[]
for x,y in zip(rows,rows[1:]):
 if y['turns']==x['turns']:stalls.append(dict(from_seconds=x['elapsed'],to_seconds=y['elapsed'],turns=y['turns']))
notes=[]
if any(k!='attached'and v for k,v in end['modes'].items()):notes.append('Nonattached frames recorded; review findings and predator context.')
if findings:notes.append('Movement findings require individual review.')
if end['loading_frames']or end['paused_frames']:notes.append('Loading or paused frames recorded; this is not uninterrupted active traversal.')
if end['focus_lost']:notes.append('Focus-loss signals recorded; review timing and throttling.')
if stalls:notes.append('Minute intervals without a completed turn are listed; inspect route continuity rather than assuming a stall.')
record=dict(input_sha256=hashlib.sha256(raw).hexdigest(),frame_run=r['run'],trace_run=begins[0]['run'],
 requested_seconds=begin['seconds'],actual=end,minute_rows=rows,five_minute_windows=windows,
 findings=findings,turnless_intervals=stalls,review_notes=notes,
 all_camera_fov_65=all(abs(x['fov']-65)<.001 for x in r['cameras']),
 limits='One Studio full-detail Free-play route at fixed clock in garden_a1/a2/a3, yielding-memory storage. Minute memory is sampled, modes/height/steps observed each Heartbeat. Paused frames mean menu/title/rest states, not all visual stutters; no long-trace frame-time percentiles were recorded. No forced GC. Stats engine memory includes Studio overhead; gcinfo is one Lua VM. Descriptive trend only, not proof of absence of leaks, every map seam, natural lives, real storage or physical-phone stability.')
assert not a.out.exists(),'Keep prior trace evidence'
a.out.write_bytes((json.dumps(record,indent=2)+'\n').encode())
lines=['# Native long-traversal observations','',record['limits'],'',
 f"Requested {begin['seconds']}s; completed {end['elapsed']:.3f}s wall / {end['simulation']:.3f}s simulation.",
 f"Frames {end['frames']}; turns {end['turns']}; modes {end['modes']}.",
 f"Loading {end['loading_frames']}; paused {end['paused_frames']}; findings {len(findings)}; focus losses {end['focus_lost']}.",
 f"Minimum Y {end['minimum_y']:.5f}; maximum frame step {end['max_step']:.5f}studs. All nine camera rows65: {record['all_camera_fov_65']}.",'',
 '| Minutes | Lua min/median/max KB | Engine min/median/max MB | Instance min/max |','|---|---:|---:|---:|']
for w in windows:
 l,e,i=w['lua_kb'],w['engine_mb'],w['instances']
 lines.append(f"| {w['from_seconds']//60}-{w['to_seconds']//60} | {l['min']:.0f}/{l['median']:.0f}/{l['max']:.0f} | {e['min']:.1f}/{e['median']:.1f}/{e['max']:.1f} | {i['min']}/{i['max']} |")
lines+=['','Review notes: '+('; '.join(notes)if notes else 'No mode/pause/loading/focus/finding flags in this bounded route. This is not a universal stability verdict.')]
a.out.with_suffix('.md').write_bytes(('\n'.join(lines)+'\n').encode())
print(json.dumps(dict(frames=end['frames'],wall_seconds=end['elapsed'],findings=len(findings),review_notes=notes)))
