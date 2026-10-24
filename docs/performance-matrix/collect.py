"""Collect complete bounded native probe events; refuse missing/truncated JSON.
The complete log stays local. Copy only this fixture's output and creator diagnostics.
"""
from pathlib import Path
import argparse,hashlib,json,re
p=argparse.ArgumentParser();p.add_argument('--stage',type=Path,required=True);p.add_argument('--log',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--allow-partial',action='store_true');p.add_argument('--require-methods',action='store_true');a=p.parse_args()
sha=lambda b:hashlib.sha256(b).hexdigest()
manifest=json.loads((a.stage/'manifest.json').read_text())
assert sha(Path(manifest['place']).read_bytes())==manifest['place_sha256']
assert sha((a.stage/'guard.luau').read_bytes())==manifest['guard_sha256']
lines=a.log.read_text(encoding='utf8',errors='strict').splitlines()
pattern=re.compile(r'\[MATRIX_FRAME_(\w+)\]\s+(\d+)\s+(\{.*\})$')
events=[];scenes=[];guards=[];diagnostics=[];kept=[];cameras=[];actors=[];trace=[]
for line in lines:
 if '[FLog::CreatorOutput]'in line and '[MATRIX_FRAME_'in line:
  m=pattern.search(line);assert m,'Malformed or truncated native event: '+line[:100]
  events.append(dict(kind=m[1],run=m[2],value=json.loads(m[3])));kept.append(line)
 elif '[FLog::CreatorOutput]'in line and '[MATRIX_SCENE]'in line:
  m=re.search(r'\[MATRIX_SCENE\]\s+(\{.*\})$',line);assert m,'Malformed scene event'
  scenes.append(json.loads(m[1]));kept.append(line)
 elif '[FLog::CreatorOutput]'in line and re.search(r'\[MATRIX_(CAMERA|ACTORS|CHOICE)\]',line):
  m=re.search(r'\[MATRIX_(CAMERA|ACTORS|CHOICE)\]\s+(\{.*\})$',line);assert m,'Malformed setup event'
  if m[1]=='CAMERA':cameras.append(json.loads(m[2]))
  elif m[1]=='ACTORS':actors.append(json.loads(m[2]))
  kept.append(line)
 elif '[FLog::CreatorOutput]'in line and '[MATRIX_TRACE_'in line:
  m=re.search(r'\[MATRIX_TRACE_(\w+)\]\s+(\d+)\s+(\{.*\})$',line);assert m,'Malformed/truncated trace event'
  trace.append(dict(kind=m[1],run=m[2],value=json.loads(m[3])));kept.append(line)
 elif '[FLog::CreatorOutput]'in line and re.search(r'\[MATRIX_GUARD\]\s+'+str(manifest['source_count'])+r'\s+',line):
  guards.append(line);kept.append(line)
 elif '[FLog::CreatorError]'in line or '[FLog::CreatorWarning]'in line:
  diagnostics.append(line);kept.append(line)
assert len({e['run']for e in events})==1,'Expected exactly one runtime probe'
run=events[0]['run']
ends=[e['value']for e in events if e['kind']=='END']
finishes=[e for e in events if e['kind']in ['PASS','FAIL']]
assert len(finishes)==1,'No authoritative runtime completion'
expected=['client-startup','sill_dawn','hut_lamp_night','garden_rain','meadow_wind','pond_active','can','doorway','bench_lamppost_night','three_region_walk']
passed=finishes[0]['kind']=='PASS'
if not a.allow_partial:
 assert passed,finishes[0]
 assert [e['sample']for e in ends]==expected,'Missing/duplicate/out-of-order samples'
 assert len(guards)>=2,'Require source guard before and after Play'
 assert not any('[FLog::CreatorError]'in line for line in diagnostics),'Native errors present'
 for row in ends[1:]:
  assert row['frames']>0 and row['render_frames']>0 and row['seconds']>0
  assert row['extra']['live'] and row['extra']['cat_enabled']is True and row['extra']['detail']==manifest['tier']
 for scene in scenes:
  assert scene['variant']==manifest['variant']
 assert len(scenes)==9
 assert len(cameras)==9
 assert len(actors)==1 and actors[0]['frog_here']and actors[0]['frog_on_screen']and actors[0]['frog_distance']<12 and actors[0]['damselflies']>0
 assert scenes[2]['state']['rain']>.65
 assert scenes[3]['state']['rain']<.01 and scenes[3]['state']['wind']>2.4
 assert all(ends[-1]['extra']['visited'].get(k)for k in ['garden_a1','garden_a2','garden_a3'])
 if a.require_methods:
  for sample in expected[1:]:
   assert any(e['kind']=='METHOD'and e['value']['sample']==sample and e['value']['name']in ['work','dew','replan']and e['value']['calls']>0 for e in events),'Missing native look-method observations: '+sample
 if manifest.get('long_trace_seconds',0):
  assert len({e['run']for e in trace})==1
  starts=[e for e in trace if e['kind']=='BEGIN'];endsTrace=[e for e in trace if e['kind']=='END']
  assert len(starts)==len(endsTrace)==1 and endsTrace[0]['value']['completed']
  assert endsTrace[0]['value']['elapsed']>=manifest['long_trace_seconds']
  assert len([e for e in trace if e['kind']=='ROW'])>=manifest['long_trace_seconds']//60
assert not a.out.exists(),'Do not replace retained native evidence'
a.out.mkdir(parents=True)
raw=('\n'.join(kept)+'\n').encode()
(a.out/'native-output.txt').write_bytes(raw)
record=dict(run=run,variant=manifest['variant'],tier=manifest['tier'],passed=passed,
 source_count=manifest['source_count'],model_sha256=manifest['place_sha256'],manifest_sha256=sha((a.stage/'manifest.json').read_bytes()),
 native_output_sha256=sha(raw),source_guards=len(guards),scenes=scenes,samples=ends,cameras=cameras,actors=actors,
 events=events,trace=trace,creator_errors=sum('[FLog::CreatorError]'in x for x in diagnostics),
 creator_warnings=sum('[FLog::CreatorWarning]'in x for x in diagnostics),
 complete_fixture_scope=not a.allow_partial,methods_instrumented=any(e['kind']=='METHOD'for e in events),original_log=str(a.log),
 limits='One local Studio workload. Free-play fixtures fix clock, use authored arrivals and memory storage. Not production FPS, a natural life, real network/storage or physical phone proof.')
(a.out/'native.json').write_bytes((json.dumps(record,indent=2)+'\n').encode())
print(json.dumps(dict(run=run,passed=passed,guards=len(guards),samples=[dict(scene=x['sample'],mean_ms=x.get('mean_ms'),p95_ms=x['p95_ms'],max_ms=x['worst_ms'])for x in ends])))
