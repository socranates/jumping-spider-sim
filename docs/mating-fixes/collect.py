"""Collect a closed unbound native contact fixture; never overwrite evidence."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess
p=argparse.ArgumentParser();p.add_argument('--stage',type=Path,required=True);p.add_argument('--log',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--pid',type=int,required=True);p.add_argument('--failed',action='store_true');a=p.parse_args()
assert not a.out.exists(),'receipt already exists'
process=subprocess.run(['powershell','-NoProfile','-Command',f'@(Get-Process -Id {a.pid} -ErrorAction SilentlyContinue).Count'],capture_output=True,text=True,check=True)
assert process.stdout.strip()=='0','Studio must exit before sealing log'
sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((a.stage/'manifest.json').read_text(encoding='utf-8'));log=a.log.read_bytes();text=log.decode('utf-8',errors='replace')
assert sha(Path(m['place']).read_bytes())==m['place_sha256'],'model changed'
guards=[l for l in text.splitlines()if '[FLog::CreatorOutput] [MATRIX_GUARD] 276 after full unbound memory_only' in l]
assert len(guards)==2,'need before and after source guards'
events=[]
for line in text.splitlines():
 hit=re.search(r'\[MATING_CONTACT_([A-Z_]+)\] (\d+) (\{.*\})',line)
 if hit:events.append(dict(utc=line.split(',')[0],kind=hit[1],run=hit[2],data=json.loads(hit[3])))
assert len({e['run'] for e in events})==1
ending=[e for e in events if e['kind']in ['PASS','FAIL']];assert len(ending)==1
assert ending[0]['kind']==('FAIL'if a.failed else'PASS')
errors=[l for l in text.splitlines()if '[FLog::CreatorError]'in l]
warnings=[l for l in text.splitlines()if '[FLog::CreatorWarning]'in l]
routes=[e['data']for e in events if e['kind']=='ROUTE']
if not a.failed:
 assert not errors
 assert len(routes)==4 and {(r['player_sex'],r['skipped'])for r in routes}=={(s,k)for s in ['male','female']for k in [False,True]}
 assert all(r['samples']>0 and r['min_gap']>=r['radius']-.05 and r['lost_support']==0 and r['exit_gap']<=1.6 and r['reason']=='mated'for r in routes)
 assert len([e for e in events if e['kind']=='MALE_NO_SAC'])==2
 cleanup=[e['data']for e in events if e['kind']=='CLEANUP'];assert len(cleanup)==1
 assert cleanup[0]['active']==cleanup[0]['gate']['scopes']==0 and cleanup[0]['optionsCreated']==cleanup[0]['optionsDestroyed']
kept=[l for l in text.splitlines()if any(marker in l for marker in ['[MATING_CONTACT_','[FLog::CreatorOutput] [MATRIX_GUARD]','[FLog::CreatorError]','[FLog::CreatorWarning]'])]
a.out.mkdir(parents=True)
for filename in ['manifest.json','compile.txt','strict.txt']:(a.out/filename).write_bytes((a.stage/filename).read_bytes())
(a.out/'playback.luau').write_bytes((a.stage/'src/Client/MatrixPlayback.luau').read_bytes())
(a.out/'native-output.txt').write_bytes(('\n'.join(kept)+'\n').encode())
result=dict(passed=not a.failed,source_commit=m['revision'],run=events[0]['run'],events=events,routes=routes,source_guards=2,creator_errors=errors,creator_warnings=warnings,studio_pid=a.pid,studio_exited=True,model_unchanged=True,model_sha256=m['place_sha256'],log_sha256=sha(log),original_log=str(a.log),published=False,limits='Synthetic adults/pairs and scripted camera/Forward in unbound Studio/memory. Coplanar attached walking contact; not natural mating decisions, complete rig-overlap/whole-map seam proof, online persistence or performance.')
(a.out/'result.json').write_bytes((json.dumps(result,indent=2)+'\n').encode());print(json.dumps({k:result[k]for k in ['passed','source_commit','run','source_guards','studio_exited','model_unchanged']},indent=2))
