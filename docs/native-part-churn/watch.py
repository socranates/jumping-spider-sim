"""Observe one native control through its log. Never launches/restarts/stops Studio."""
from pathlib import Path
import argparse,json,time
from collect import collect
p=argparse.ArgumentParser();p.add_argument('log');p.add_argument('--manifest',required=True);p.add_argument('--out',required=True);a=p.parse_args()
log=Path(a.log);out=Path(a.out);assert not out.exists();out.mkdir(parents=True)
manifest=json.loads(Path(a.manifest).read_text());last=None;deadline=time.monotonic()+300
while time.monotonic()<deadline:
 text=log.read_text(encoding='utf8',errors='replace')
 # A partially appended final line is not a complete native record yet.
 lines=text.splitlines()
 if text and not text.endswith('\n'):lines=lines[:-1]
 events='\n'.join(line for line in lines if '[PART_CHURN_' in line or 'CreatorError' in line)+'\n'
 try:result=collect(events,manifest)
 except ValueError as error:
  (out/'decode-error-events.txt').write_text(events,encoding='utf8',newline='\n')
  print('Observer decode error; native liveness not determined:',str(error),flush=True)
  raise
 samples=[r for r in result['records'] if r['kind']=='sample']
 if samples:
  row=samples[-1];key=(row['phase'],row['cycle'],int(row['phase_seconds']))
  if key!=last:
   last=key;progress={k:row[k] for k in ['phase','cycle','elapsed','live_parts','created','destroyed','focus_losses']}
   (out/'progress.json').write_text(json.dumps(progress,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(progress),flush=True)
 if result['complete'] or result['failures']:
  (out/'events.txt').write_text(events,encoding='utf8',newline='\n')
  (out/'result.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n')
  print(json.dumps({k:v for k,v in result.items() if k!='records'}),flush=True)
  raise SystemExit(0 if result['complete'] else 1)
 time.sleep(5)
print('Observer timeout; native termination unproven. Recheck the same log; do not restart.',flush=True)
raise SystemExit(3)
