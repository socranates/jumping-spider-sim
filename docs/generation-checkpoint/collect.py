"""Seal a closed, unpublished Studio generation-checkpoint run."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess
p=argparse.ArgumentParser()
p.add_argument('--stage',type=Path,required=True)
p.add_argument('--log',type=Path,required=True)
p.add_argument('--pid',type=int,required=True)
p.add_argument('--out',type=Path,required=True)
a=p.parse_args()
assert not a.out.exists()
r=subprocess.run(['powershell','-NoProfile','-Command',f'@(Get-Process -Id {a.pid} -ErrorAction SilentlyContinue).Count'],capture_output=True,text=True,check=True)
assert r.stdout.strip()=='0','Studio must exit before sealing'
sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((a.stage/'manifest.json').read_text(encoding='utf-8'))
assert sha(Path(m['place']).read_bytes())==m['place_sha256']
raw=a.log.read_bytes();text=raw.decode('utf-8',errors='replace')
guards=[l for l in text.splitlines()if '[FLog::CreatorOutput] [MATRIX_GUARD] 276 after full unbound memory_only'in l]
assert len(guards)==2
events=[]
for line in text.splitlines():
 hit=re.search(r'\[GENERATION_CHECKPOINT_([A-Z_]+)\] (\d+) (.+)$',line)
 if hit:events.append(dict(kind=hit[1],run=hit[2],utc=line.split(',')[0],data=json.loads(hit[3])))
assert len({e['run']for e in events})==1
assert len([e for e in events if e['kind']=='PASS'])==1 and not any(e['kind']=='FAIL'for e in events)
errors=[l for l in text.splitlines()if '[FLog::CreatorError]'in l]
warnings=[l for l in text.splitlines()if '[FLog::CreatorWarning]'in l]
assert not errors
queued=[e['data']for e in events if e['kind']=='QUEUED']
returned=[e['data']for e in events if e['kind']=='RETURNED']
assert len(queued)==len(returned)==3
assert [(v['mode'],v['easy'],v['choice'])for v in returned]==[('main',False,'Carry'),('main',True,'Carry'),('free',False,'Follow')]
for q,r in zip(queued,returned):
 assert r['generation']==1 and r['seed']==q['seed'] and r['attached'] and r['distance']<1
 assert r.get('zone')==q.get('zone') and r.get('region')==q.get('region')
assert returned[2]['zone']in ['hut_garden','meadow','pond_edge'] and returned[2]['region']
cleanup=[e['data']for e in events if e['kind']=='CLEANUP'];assert len(cleanup)==1
assert cleanup[0]['active']==cleanup[0]['gate']['scopes']==0 and cleanup[0]['optionsCreated']==cleanup[0]['optionsDestroyed']
a.out.mkdir(parents=True)
for name in ['manifest.json','compile.txt','strict.txt']:(a.out/name).write_bytes((a.stage/name).read_bytes())
(a.out/'playback.luau').write_bytes((a.stage/'src/Client/MatrixPlayback.luau').read_bytes())
kept=[l for l in text.splitlines()if any(marker in l for marker in ['[GENERATION_CHECKPOINT_','[FLog::CreatorOutput] [MATRIX_GUARD]','[FLog::CreatorError]','[FLog::CreatorWarning]'])]
(a.out/'native-output.txt').write_bytes(('\n'.join(kept)+'\n').encode())
result=dict(passed=True,source_commit=m['revision'],run=events[0]['run'],events=events,returns=len(returned),source_guards=2,creator_errors=errors,creator_warnings=warnings,model_sha256=m['place_sha256'],model_unchanged=True,log_sha256=sha(raw),original_log=str(a.log),studio_pid=a.pid,studio_exited=True,published=False,limits='Synthetic adult parents, prior Easy unlock, hatch records and safe initial placement. Ordinary Carry/Follow, wind ride, landing, asynchronous local storage and queued Back run in Studio with unbound yielding-memory storage. Not natural reproduction, online DataStore durability, performance or device comfort.')
(a.out/'result.json').write_bytes((json.dumps(result,indent=2)+'\n').encode())
print(json.dumps({k:result[k]for k in ['passed','run','returns','source_guards','studio_exited']},indent=2))
