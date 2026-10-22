from pathlib import Path
import hashlib,json,re,copy
HERE=Path(__file__).resolve().parent;OUT=HERE/'replay-v2'
meta=json.loads((OUT/'process.json').read_text(encoding='utf8'));assert len(meta['trials'])==3
trials={}
def decode(raw):
 value,end=json.JSONDecoder().raw_decode(raw)
 assert raw[end:] in ['', '\tnil'], 'unexpected output after canonical JSON'
 return value

for row in meta['trials']:
 assert row['exit_code']==0
 p=OUT/f'{row["fps"]}.txt';b=p.read_bytes();assert hashlib.sha256(b).hexdigest()==row['log_sha256']
 samples={};rng=None;done=[]
 for line in b.decode().splitlines():
  if line.startswith('[CONTROLLER_REPLAY_SAMPLE]'):
   _,fps,second,boundary,raw=line.split('\t',4);assert int(fps)==row['fps'];samples[int(second)]=dict(boundary=boundary,state=decode(raw))
  elif line.startswith('[CONTROLLER_REPLAY_RNG]'):
   _,fps,raw=line.split('\t',2);assert int(fps)==row['fps'];rng=decode(raw)
  elif line.startswith('[CONTROLLER_REPLAY_DONE]'):done.append(line.split('\t'))
 assert sorted(samples)==list(range(21)) and rng is not None and len(done)==1 and int(done[0][3])==21
 trials[row['fps']]=dict(samples=samples,rng=rng,loading_frames=int(done[0][2]),preparation_slices=int(done[0][4]))
def differences(a,b,path='$',out=None):
 out=[] if out is None else out
 if len(out)>=40:return out
 if type(a)!=type(b):out.append(dict(path=path,left_type=type(a).__name__,right_type=type(b).__name__));return out
 if isinstance(a,dict):
  for k in sorted(set(a)|set(b)):
   if k not in a or k not in b:out.append(dict(path=path+'.'+k,left_present=k in a,right_present=k in b))
   else:differences(a[k],b[k],path+'.'+k,out)
 elif isinstance(a,list):
  if len(a)!=len(b):out.append(dict(path=path,left_length=len(a),right_length=len(b)))
  for i,(x,y) in enumerate(zip(a,b)):differences(x,y,path+f'[{i}]',out)
 elif a!=b:out.append(dict(path=path,left=a,right=b))
 return out
# These three fields are written from os.clock only for telemetry; preserve all
# raw snapshots and never normalize a movement, perception, RNG or actor field.
EXCLUDED={'PreyDirector':{'beforeCost'},'Sensor':{'cpuUsMax','cpuUsTotal'}}
def gameplay(sample):
 out=copy.deepcopy(sample)
 for obj in out['state']['checkpoint']['world']['objects']:
  for entry in obj.get('e',[]):
   if entry[0] in EXCLUDED.get(obj.get('c'),set()):entry[1]=0
 return out
# Regression guards: named telemetry may differ; adjacent operational state may not.
probe={'state':{'checkpoint':{'world':{'objects':[{'c':'Sensor','e':[['cpuUsMax',1],['raysTotal',7]]}]},'player':{'position':[0,0,0]}},'draws':3}}
changed=copy.deepcopy(probe);changed['state']['checkpoint']['world']['objects'][0]['e'][0][1]=9
assert gameplay(probe)==gameplay(changed)
changed['state']['checkpoint']['world']['objects'][0]['e'][1][1]=8
assert gameplay(probe)!=gameplay(changed)
changed=copy.deepcopy(probe);changed['state']['checkpoint']['player']['position'][0]=1
assert gameplay(probe)!=gameplay(changed)
changed=copy.deepcopy(probe);changed['state']['draws']=4
assert gameplay(probe)!=gameplay(changed)
base=trials[60];comparisons=[]
for fps in [30,120]:
 other=trials[fps];samples=[]
 for t in range(21):
  diff=differences(base['samples'][t],other['samples'][t]);samples.append(dict(second=t,exact_match=not diff,first_differences=diff,gameplay_projection_matches=not differences(gameplay(base['samples'][t]),gameplay(other['samples'][t]))))
 rdiff=differences(base['rng'],other['rng'])
 comparisons.append(dict(base_fps=60,other_fps=fps,matching_samples=sum(x['exact_match'] for x in samples),matching_gameplay_samples=sum(x['gameplay_projection_matches'] for x in samples),samples=samples,
  rng_sequence_exact_match=not rdiff,base_rng_draws=len(base['rng']),other_rng_draws=len(other['rng']),first_rng_differences=rdiff))
receipt=dict(trials=[dict(fps=fps,loading_frames=t['loading_frames'],preparation_slices=t['preparation_slices'],samples=21,rng_draws=len(t['rng'])) for fps,t in trials.items()],
 comparisons=comparisons,all_checkpoint_wasp_samples_match=all(c['matching_samples']==21 for c in comparisons),all_class_dispatched_rng_calls_match=all(c['rng_sequence_exact_match'] for c in comparisons),
 scope='Actual controller on shim, ordinary title menu through SelfTest hook,20 simulated seconds moving/aim-cancel input; canonical checkpoint graph and live wasp graph, observed PreyRandom.next calls only',
 all_gameplay_projection_samples_match=all(c['matching_gameplay_samples']==21 for c in comparisons),excluded_telemetry_fields={k:sorted(v) for k,v in EXCLUDED.items()},projection_regression_guards=4,physical_input=False,native_verified=False,online_verified=False,all_future_seeded_behaviour_proven=False)
(OUT/'comparison.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps({k:v for k,v in receipt.items() if k!='comparisons'},indent=2))
for c in comparisons:print(c['other_fps'],'matching_samples',c['matching_samples'],'gameplay_samples',c['matching_gameplay_samples'],'rng_equal',c['rng_sequence_exact_match'],'first_difference',next((s['first_differences'][:1] for s in c['samples'] if not s['exact_match']),[]))
