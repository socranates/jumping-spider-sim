"""Decode native memory records; distinguish a rehearsal, a long run and a growth screen."""
from pathlib import Path
import argparse,json,re,zlib,hashlib,math,statistics,sys
REGIONS=['sill','hut_desk','garden_b2','meadow_b2','pond_a2','hut_doorway','lamp_1']
def require(ok,why):
 if not ok:raise ValueError(why)
def finite(v):return isinstance(v,(int,float)) and not isinstance(v,bool) and math.isfinite(v) and v>=0
def collect(text,manifest,run_id=None):
 rows={};done=[];guards=[];failures=[]
 for line in text.splitlines():
  m=re.search(r'\[MEMTRACE_GUARD\]\s+([0-9a-f]{40})\s+(smoke|long)\s+(\d+)\s+217\s+persistence_disabled$',line)
  if m:guards.append(m.groups())
  if '[FLog::CreatorError]' in line or 'Script timeout' in line or ('[MEMTRACE_FAIL]' in line and (run_id is None or run_id in line)):failures.append(line)
  m=re.search(r'\[MEMTRACE_BEGIN\]\s+(\S+)\s+(\S+)\s+(\d+)\s+(\d+)\s+(\d+)$',line)
  if m:
   run,kind,size,n,crc=m.groups()
   if run_id and run!=run_id:continue
   key=(run,kind);require(key not in rows,'duplicate record start')
   require(0<int(size)<=524288 and 0<int(n)<=2098,'unreasonable record size')
   rows[key]={'size':int(size),'n':int(n),'crc':int(crc),'chunks':{},'end':False};continue
  m=re.search(r'\[MEMTRACE_DATA\]\s+(\S+)\s+(\S+)\s+(\d+)\s+(".*")$',line)
  if m:
   run,kind,i,data=m.groups()
   if run_id and run!=run_id:continue
   key=(run,kind);require(key in rows,'chunk without start');r=rows[key];i=int(i)
   require(i not in r['chunks'] and 1<=i<=r['n'],'duplicate/out-of-range chunk');r['chunks'][i]=json.loads(data);continue
  m=re.search(r'\[MEMTRACE_END\]\s+(\S+)\s+(\S+)$',line)
  if m:
   run,kind=m.groups()
   if run_id and run!=run_id:continue
   require((run,kind) in rows and not rows[(run,kind)]['end'],'missing/duplicate record end');rows[(run,kind)]['end']=True
  m=re.search(r'\[MEMTRACE_DONE\]\s+(\S+)\s+(smoke|long)\s+(\d+)$',line)
  if m and (run_id is None or m[1]==run_id):done.append(m.groups())
 records={};incomplete=[];runs=set()
 for (run,kind),r in rows.items():
  runs.add(run)
  if not r['end'] or set(r['chunks'])!=set(range(1,r['n']+1)):incomplete.append(kind);continue
  raw=''.join(r['chunks'][i] for i in range(1,r['n']+1)).encode()
  require(len(raw)==r['size'] and zlib.adler32(raw)==r['crc'],'record checksum/length mismatch')
  require(kind not in records,'multiple runs require --run-id');records[kind]=json.loads(raw)
 require(len(runs)<=1,'multiple runs require --run-id')
 result={'complete':False,'memory_gate_evidence':False,'growth_screen':'incomplete','failures':failures,'incomplete_records':incomplete,'records':records,
  'scope':'Desktop Studio, one Free life with explicit placements; not walking, phone, online-save or whole-game speedup evidence'}
 if not records or 'header' not in records or 'final' not in records or not done or incomplete or failures:return result
 require(len(done)==1 and len(runs)==1,'ambiguous completion')
 run=next(iter(runs));h=records['header'];f=records['final']
 profile=next((p for p in manifest['profiles'] if p['profile']==h['profile'] and p['tier']==h['tier']),None)
 require(profile is not None and h['source']==manifest['source'] and h['harness_version']==1,'wrong source/profile')
 require((h['source'],h['profile'],str(profile['duration'])) in guards,'missing exact source/config guard')
 require(done[0]==(run,h['profile'],str(profile['duration'])),'wrong completion marker')
 require(h['duration_seconds']==profile['duration'] and h['dwell_seconds']==profile['dwell'] and h['sample_seconds']==15,'configuration mismatch')
 script_hashes={r['path']:r['sha256'] for r in profile['scripts']}
 expected={r['instance']:r['native_sha256'] for r in manifest['source_rows']}
 require(len(expected)==216 and len(script_hashes)==217 and len(script_hashes)==len(profile['scripts']),'source set differs')
 require(script_hashes.pop('StarterPlayer.StarterPlayerScripts.Client.SilkPlayback')==manifest['driver_sha256'],'driver differs')
 require(script_hashes==expected and profile['persistence_disabled'] is True and profile['published'] is False,'production fingerprint/config mismatch')
 require(h['regions']==REGIONS and h['mode']=='Free' and h['memory_tracking_enabled'] is True and h['persistence_disabled'] is True,'workload differs')
 for k in ['fresh_calls_during_trace','recovery_calls_during_trace','forced_gc_calls']:
  require(h[k]==f[k]==0,'life reset/recovery/forced GC during trace')
 require(h['fresh_successes_before_trace']==1,'wrong life setup')
 require(all(finite(f[k]) for k in ['elapsed','frames','frame_seconds','sim_seconds']),'non-finite activity counter')
 require(f['elapsed']>=profile['duration'] and f['frames']>f['elapsed'],'duration/frame activity insufficient')
 require(isinstance(f['samples'],int) and 1<=f['samples']<=1000,'unreasonable sample count')
 require(isinstance(f['visits'],int) and 1<=f['visits']<=math.ceil(profile['duration']/profile['dwell'])+1,'unreasonable visit count')
 require(f['frame_seconds']>=f['elapsed']*.9 and f['sim_seconds']>=f['elapsed']*.5,'inactive render/simulation')
 require(abs((f['utc_ms']-h['began_utc_ms'])/1000-f['elapsed'])<5,'wall-clock duration differs')
 require(f['focus_losses']==0 and f['viewport']==h['viewport'],'focus or viewport changed')
 require(set(f['visited'])==set(REGIONS) and all(f['visited'].values()),'habitat coverage missing')
 samples=[records.get('sample_'+str(i)) for i in range(1,f['samples']+1)]
 require(samples and all(s is not None for s in samples),'missing sample')
 require(sum(s['frames']['count'] for s in samples)>=f['frames']*.95,'render coverage missing')
 tags=set(h['memory_tags']);require({'LuaHeap','Instances'}<=tags,'required tags absent')
 def memory(m):
  require(all(finite(m[k]) for k in ['engine_mb','lua_gc_mib','instances']) and m['engine_mb']>0 and m['instances']>0,'invalid memory counter')
  require(set(m['tags_mb'])==tags and all(finite(v) for v in m['tags_mb'].values()),'missing/invalid memory tags')
 def state(s):
  memory(s['memory']);require(s['focus_losses']==0 and s['viewport']==h['viewport'],'sample focus/viewport changed')
  require(s['mode_name']=='free' and s['rules']=='gentle','sample life mode changed')
  require(s['predator_enabled']=={k:True for k in ['wasp','cat','bird','frog','crab']},'predator disabled')
  require(len(s['pos'])==3 and all(isinstance(x,(int,float)) and math.isfinite(x) for x in s['pos']),'bad position')
  require(s['phase'] in ['transition','dwell'] and s['wanted'] in REGIONS,'invalid phase/region')
  if s['phase']=='dwell':require(s['region']==s['wanted'] and s['region_ready'] is True,'dwell not on ready fixture')
 for s in samples:state(s)
 for before,after in zip(samples,samples[1:]):
  require(0<after['elapsed']-before['elapsed']<=20,'sample gap/reordering')
  require(after['sim_seconds']>=before['sim_seconds'],'simulation clock reset')
 require(samples[0]['elapsed']<=5 and abs(samples[-1]['elapsed']-f['elapsed'])<2,'trace edges not sampled')
 state(f['state'])
 visits={r:[] for r in REGIONS}
 for i in range(1,f['visits']+1):
  v=records.get('visit_'+str(i));arrival=records.get('arrival_'+str(i))
  require(v is not None and arrival is not None,'missing visit/arrival')
  region=REGIONS[(i-1)%7]
  require(v['visit']==arrival['visit']==i and v['region']==arrival['region']==region,'visit order differs')
  require(v['dwell_seconds']>=profile['dwell'] and v['elapsed']-arrival['elapsed']>=profile['dwell']-.1,'dwell too short')
  memory(v['memory_min']);state(v['state']);visits[region].append(v)
 result.update({'complete':True,'run':run,'source':h['source'],'profile':h['profile'],'duration_seconds':f['elapsed'],
  'visits_by_region':{k:len(v) for k,v in visits.items()},'samples':len(samples),'source_guard_verified':True})
 gate=h['profile']=='long' and f['elapsed']>=1800 and all(len(v)>=6 for v in visits.values())
 result['memory_gate_evidence']=gate
 if not gate:result['growth_screen']='rehearsal_only' if h['profile']=='smoke' else 'insufficient_matched_visits';return result
 screen={};flagged=False;expanding=False
 for region,vs in visits.items():
  early=vs[2:4];late=vs[-2:]
  def median(group,key):return statistics.median(v['memory_min'][key] for v in group)
  changes={}
  for key,floor,fraction in [('engine_mb',64,.1),('lua_gc_mib',16,.25),('instances',500,.05)]:
   base=median(early,key);end=median(late,key);threshold=max(floor,base*fraction)
   changes[key]={'early':base,'late':end,'delta':end-base,'triage_threshold':threshold,'flagged':end-base>threshold}
   flagged|=changes[key]['flagged']
  grows=max(v['state']['initialized_regions'] for v in late)>max(v['state']['initialized_regions'] for v in early)
  expanding|=grows;screen[region]={'changes':changes,'initialized_regions_still_expanding':grows}
 result['matched_memory_screen']=screen
 result['growth_screen']='investigate_growth' if flagged else 'population_still_expanding' if expanding else 'no_large_growth_flag'
 result['interpretation']='Predeclared triage thresholds, not proof of no leaks. Inspect category curves, GC sawtooth, populations and asset/streaming changes.'
 return result
def main():
 p=argparse.ArgumentParser();p.add_argument('log');p.add_argument('--manifest',required=True);p.add_argument('--run-id');p.add_argument('--out',required=True);a=p.parse_args()
 target=Path(a.out);require(not target.exists(),'choose a new result file')
 data=Path(a.log).read_bytes();manifest=json.loads(Path(a.manifest).read_text(encoding='utf8'))
 result=collect(data.decode('utf8',errors='replace'),manifest,a.run_id)
 result['events_sha256']=hashlib.sha256(data).hexdigest();result['manifest_sha256']=hashlib.sha256(Path(a.manifest).read_bytes()).hexdigest()
 target.write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n')
 print(json.dumps({k:v for k,v in result.items() if k not in ['records','matched_memory_screen']},indent=2))
 return 0 if result['complete'] else 1
if __name__=='__main__':sys.exit(main())
