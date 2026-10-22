"""Decode a bounded isolated native control. No synthetic result is native proof."""
from pathlib import Path
import argparse,hashlib,json,math,re,zlib
TAGS={'BaseParts','Instances','Signals','LuaHeap','Internal','GraphicsParts'}
def require(ok,message):
 if not ok:raise ValueError(message)
def finite(x):return isinstance(x,(int,float)) and not isinstance(x,bool) and math.isfinite(x) and x>=0
def collect(events,manifest):
 rows=[];runs=set();done=[];fail=[]
 for line in events.splitlines():
  if '[PART_CHURN_FAIL]' in line or 'CreatorError' in line:fail.append(line)
  m=re.search(r'\[PART_CHURN_RECORD\]\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\{.*\})$',line)
  if m:
   run,sequence,size,crc,data=m.groups();raw=data.encode()
   require(int(sequence)==len(rows)+1,'missing/duplicate/reordered record')
   require(len(raw)==int(size) and zlib.adler32(raw)==int(crc),'truncated or changed native record')
   require(len(raw)<900,'unexpected record size');rows.append(json.loads(data));runs.add(run)
  m=re.search(r'\[PART_CHURN_DONE\]\s+(\d+)\s+(\d+)\s*$',line)
  if m:done.append(m.groups())
 result={'complete':False,'failures':fail,'records':rows,'scope':manifest['scope'],'game_source_included':False,'published':False}
 if fail or not done:return result
 require(len(done)==len(runs)==1 and done[0][0] in runs and int(done[0][1])==len(rows),'ambiguous terminal/run')
 require(len(rows)==29 and rows[0]['kind']=='header' and rows[-1]['kind']=='final','record coverage differs')
 h,f=rows[0],rows[-1]
 require(h['probe_sha256']==manifest['probe_sha256'] and h['version']==1,'probe source differs')
 guard='[PART_CHURN_GUARD] '+h['probe_sha256']+' 1 no_game_no_persistence'
 require(guard in events,'exact authored-source guard missing')
 for k in ['parts','cycles','stationary_seconds','quiet_seconds','sample_seconds']:require(h[k]==manifest[k],'configuration differs: '+k)
 require(h['parts']==1000 and h['cycles']==60 and h['stationary_seconds']==h['quiet_seconds']==30 and h['sample_seconds']==5,'unsupported protocol')
 require(h['gc']=='natural; no forced collection','GC workload differs')
 samples=rows[1:-1];groups={key:[r for r in samples if r['phase']==key] for key in ['stationary','churn','quiet']}
 require([s['phase'] for s in samples]==['stationary']*7+['churn']*13+['quiet']*7,'phase coverage/order differs')
 for before,after in zip(samples,samples[1:]):
  require(after['elapsed']>before['elapsed'] and after['frames']>=before['frames'],'clock/frame reset')
 for s in samples:
  require(s['kind']=='sample' and s['focus_losses']==0,'sample failure/focus loss')
  require(all(finite(s[k]) for k in ['elapsed','phase_seconds','created','destroyed','live_parts','frames','frame_seconds']),'invalid activity counter')
  m=s['memory'];require(all(finite(m[k]) for k in ['total_mb','gc_mib','instances']) and m['total_mb']>0,'invalid memory counter')
  require(set(m['tags_mb'])==TAGS and all(finite(x) for x in m['tags_mb'].values()),'invalid/missing category')
  cycle=s['cycle'];require(isinstance(cycle,int) and 0<=cycle<=60,'invalid cycle')
  made=1000 if s['phase']=='stationary' else 1000+1000*cycle
  dead=0 if s['phase']=='stationary' else made if s['phase']=='quiet' else 1000*cycle
  require(s['created']==made and s['destroyed']==dead and s['live_parts']==made-dead,'part balance differs')
 require([s['cycle'] for s in groups['churn']]==list(range(0,61,5)),'churn cycles missing')
 require(groups['stationary'][-1]['phase_seconds']>=30 and groups['quiet'][-1]['phase_seconds']>=30,'hold shortened')
 require(all(finite(f[k]) for k in ['elapsed','stationary_seconds','churn_seconds','quiet_seconds','frames','frame_seconds']),'invalid final counter')
 require(f['stationary_seconds']>=30 and f['churn_seconds']>=60 and f['quiet_seconds']>=30 and f['elapsed']>=120,'short control')
 require(f['frames']>f['elapsed']*5 and f['frame_seconds']>=f['elapsed']*.9 and f['focus_losses']==0,'inactive or unfocused control')
 require(f['created']==f['destroyed']==61000 and f['live_parts']==0,'final cleanup differs')
 def tag(s,name):return s['memory']['tags_mb'][name]
 begin,base,end,quiet=groups['stationary'][0],groups['stationary'][-1],groups['churn'][-1],groups['quiet'][-1]
 changes={name:{'stationary_delta_mb':tag(base,name)-tag(begin,name),'churn_delta_mb':tag(end,name)-tag(base,name),
                'quiet_residual_mb':tag(quiet,name)-tag(base,name)} for name in sorted(TAGS)}
 threshold=max(8,4*max(0,changes['BaseParts']['stationary_delta_mb']))
 growth=changes['BaseParts']['churn_delta_mb']>threshold
 persists=growth and changes['BaseParts']['quiet_residual_mb']>=.8*changes['BaseParts']['churn_delta_mb']
 result.update(complete=True,run=done[0][0],probe_sha256=h['probe_sha256'],duration_seconds=f['elapsed'],changes=changes,
  part_category_investigation_threshold_mb=threshold,isolated_part_growth_observed=growth,persists_after_30_seconds=persists,
  interpretation='A single isolated Studio control can reproduce category growth without Windowsill code. It cannot establish a game leak, engine bug, production-client behavior or FPS benefit.')
 return result
def main():
 p=argparse.ArgumentParser();p.add_argument('events');p.add_argument('--manifest',required=True);p.add_argument('--out',required=True);a=p.parse_args()
 out=Path(a.out);require(not out.exists(),'preserve existing result')
 events=Path(a.events).read_bytes();manifest=Path(a.manifest).read_bytes();result=collect(events.decode('utf8'),json.loads(manifest))
 result.update(events_sha256=hashlib.sha256(events).hexdigest(),manifest_sha256=hashlib.sha256(manifest).hexdigest())
 out.write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n')
 print(json.dumps({k:v for k,v in result.items() if k!='records'},indent=2));return 0 if result['complete'] else 1
if __name__=='__main__':raise SystemExit(main())
