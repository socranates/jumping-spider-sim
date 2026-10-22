from pathlib import Path
import argparse,hashlib,json,re
HERE=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--log',required=True);a=p.parse_args()
m=json.loads((HERE/'prepared-current-manifest.json').read_text(encoding='utf8'))
lines=Path(a.log).read_text(encoding='utf8').splitlines()
guard='[NATIVE_ANIMAL_COST_GUARD] '+m['source']+' 223 persistence_disabled'
start=[i for i,l in enumerate(lines) if guard in l and ' > ' not in l][-1]
end=[i for i,l in enumerate(lines) if i>start and '[NATIVE_ANIMAL_COST_PASS]' in l]
assert len(end)==1
span=lines[start:end[0]+1]
assert not any('[NATIVE_ANIMAL_COST_FAIL]' in l or '[FLog::CreatorError]' in l for l in span)
rows=[l.split('[FLog::CreatorOutput] ',1)[1] for l in span if '[FLog::CreatorOutput]' in l and '[NATIVE_ANIMAL_COST_' in l and ' > ' not in l]
text='\n'.join(rows)+'\n';passed=re.search(r'\[NATIVE_ANIMAL_COST_PASS\] (\d+) 2 9',text)
assert passed and len(rows)==27;run=passed[1];scenes={}
for line in rows:
 fields=line.split();tag=fields[0]
 if tag=='[NATIVE_ANIMAL_COST_SCENE]':
  assert fields[1]==run
  scenes[fields[2]]=dict(frames=int(fields[3]),elapsed_seconds=float(fields[4]),
   lua_callback_mean_ms=float(fields[5]),lua_callback_worst_ms=float(fields[6]),
   viewport=[int(fields[7]),int(fields[8])],components=[])
for line in rows:
 fields=line.split();tag=fields[0]
 if tag=='[NATIVE_ANIMAL_COST_ROW]':
  assert fields[1]==run
  scene=scenes[fields[2]];calls=int(fields[4]);cpu=float(fields[5]);heap=float(fields[7])
  scene['components'].append(dict(name=fields[3],calls=calls,total_cpu_ms=cpu,
   worst_call_ms=float(fields[6]),cpu_ms_per_frame=cpu/scene['frames'],
   cpu_ms_per_call=cpu/calls if calls else None,positive_heap_growth_kb=heap,
   positive_heap_growth_kb_per_frame=heap/scene['frames']))
 if tag=='[NATIVE_ANIMAL_COST_FRAME]':
  assert fields[1]==run
  scenes[fields[2]].update(observed_render_frames=int(fields[3]),observed_render_interval_mean_ms=float(fields[4]),
   observed_render_interval_worst_ms=float(fields[5]))
assert set(scenes)=={'sill_noon','garden_mate'}
for scene in scenes.values():
 assert len(scene['components'])==9 and scene['frames']>=120 and scene['observed_render_frames']>=120
 assert abs(scene['observed_render_frames']-scene['frames'])<=2
 scene['components'].sort(key=lambda row:row['total_cpu_ms'],reverse=True)
(HERE/'native-output.txt').write_text(text,encoding='utf8',newline='\n')
receipt=dict(source=m['source'],run=run,scripts=223,creator_errors=0,persistence_disabled=True,
 place_sha256=m['place_sha256'],output_sha256=hashlib.sha256(text.encode()).hexdigest(),scenes=scenes,
 scope='Instrumented foreground full-detail desktop attribution; advancing Free life/all predators enabled; instrumentation adds overhead; no paired FPS gain, allocation-rate, leak or device proof',
 production_optimization_adopted=False,goal_complete=False,published=False)
(HERE/'native-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(receipt,indent=2))
