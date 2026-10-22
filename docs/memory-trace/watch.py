"""Observe one existing native trace through its log. Never starts/stops/restarts Studio."""
from pathlib import Path
import argparse,json,time,sys
from collect import collect
p=argparse.ArgumentParser();p.add_argument('log');p.add_argument('--manifest',required=True);p.add_argument('--run-id',required=True);p.add_argument('--out',required=True);a=p.parse_args()
source=Path(a.log);out=Path(a.out);assert not out.exists();out.mkdir(parents=True)
manifest=json.loads(Path(a.manifest).read_text());deadline=time.monotonic()+2400;last=-1
while time.monotonic()<deadline:
 try:text=source.read_text(encoding='utf8',errors='replace')
 except OSError as e:
  print('observation error (not native termination):',str(e),flush=True);time.sleep(15);continue
 lines=[l for l in text.splitlines() if '[MEMTRACE_' in l or 'CreatorError' in l]
 events='\n'.join(lines)+'\n';result=collect(events,manifest,a.run_id);records=result['records']
 samples=[v for k,v in records.items() if k.startswith('sample_')]
 latest=max(samples,key=lambda v:v['elapsed']) if samples else None
 if latest is not None and latest['elapsed']>last:
  last=latest['elapsed'];progress={'run':a.run_id,'elapsed':last,'region':latest['region'],'sim_seconds':latest['sim_seconds'],
   'samples':len(samples),'focus_losses':latest['focus_losses'],'phase':latest['phase'],'native_complete':result['complete']}
  (out/'progress.json').write_text(json.dumps(progress,indent=2)+'\n',encoding='utf8',newline='\n')
  print(json.dumps(progress),flush=True)
 terminal=('[MEMTRACE_DONE] '+a.run_id) in events or ('[MEMTRACE_FAIL] '+a.run_id) in events or bool(result['failures'])
 if terminal:
  (out/'events.txt').write_text(events,encoding='utf8',newline='\n')
  (out/'result.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n')
  print(json.dumps({k:v for k,v in result.items() if k not in ['records','matched_memory_screen']}),flush=True)
  sys.exit(0 if result['complete'] and result['memory_gate_evidence'] else 1)
 time.sleep(15)
(out/'monitor-timeout.json').write_text(json.dumps({'monitor_timeout':True,'native_termination_unproven':True,'run':a.run_id},indent=2)+'\n',encoding='utf8',newline='\n')
print('Observer timed out; recheck this same native run. Do not infer termination or restart.',flush=True)
sys.exit(2)
