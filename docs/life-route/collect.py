"""Collect the native capture-to-adult route; refuse partial or failed routes."""
from pathlib import Path
import argparse,hashlib,json,re
p=argparse.ArgumentParser();p.add_argument('--stage',type=Path,required=True);p.add_argument('--log',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
ROOT=Path(__file__).resolve().parents[2];sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((a.stage/'manifest.json').read_text());assert m['source_count']==276 and not m['published']and m['storage']=='unbound yielding memory only'
assert sha(Path(m['place']).read_bytes())==m['place_sha256']
assert sha((a.stage/'guard.luau').read_bytes())==m['guard_sha256']
assert(a.stage/'compile.txt').read_text().strip()=='compile 276/276'
assert 'strict 0 'in(ROOT/'docs/life-route/prepare3.txt').read_text()
assert(a.stage/'src/Client/MatrixPlayback.luau').read_bytes()==(ROOT/'docs/life-route/playback.luau').read_bytes()
for rel,digest in m['original_sources'].items():assert sha((ROOT/'roblox_port/src'/rel).read_bytes().replace(b'\r\n',b'\n'))==digest,rel
raw=a.log.read_bytes();kept=[];events=[];guards=[];errors=[];warnings=[]
for line in raw.decode().splitlines():
 hit=re.search(r'\[LIFE_ROUTE_(\w+)\]\s+(\d+)\s+(\{.*\}|\[.*\])$',line)
 if hit:events.append(dict(kind=hit[1],run=hit[2],value=json.loads(hit[3])));kept.append(line)
 elif '[MATRIX_GUARD] 276 after full unbound memory_only'in line:guards.append(line);kept.append(line)
 elif '[FLog::CreatorError]'in line:errors.append(line);kept.append(line)
 elif '[FLog::CreatorWarning]'in line:warnings.append(line);kept.append(line)
assert len({e['run']for e in events})==1 and len(guards)==2 and not errors
assert not any('[Windowsill]' in s for s in warnings),'Game warning prevents route qualification'
rows=lambda kind:[e['value']for e in events if e['kind']==kind]
assert len(rows('BEGIN'))==len(rows('CLEANUP'))==len(rows('PASS'))==1 and not rows('FAIL')and not rows('DEADLINE')
fresh=rows('FRESH');adults=rows('ADULT')
assert len(fresh)==len(adults)==3
expected=[('main','standard',[7,10,5]),('main','gentle',[7,10,3]),('free','gentle',[7,10,3])]
assert len(rows('MEAL'))==62 and len(rows('MOULT_START'))==len(rows('MOULT_END'))==len(rows('HARDENED'))==9
position=0
for mode,rules,targets in expected:
 while events[position]['kind']!='FRESH':position+=1
 first=events[position]['value'];position+=1
 assert first['mode']==mode and first['rules']==rules and first['stage']==0 and first['food']==first['meals']==0 and not first['can_run']and not first['can_lock']
 count=0
 for stage,goal in enumerate(targets,1):
  for i in range(1,goal+1):
   row=events[position];position+=1;assert row['kind']=='MEAL';v=row['value'];count+=1
   assert v['mode']==mode and v['rules']==rules and v['stage']==stage-1 and v['meals']==count and v['ready']==(i==goal)
   assert abs(v['food']-.3*i)<1e-6 and v['goal']==goal and not v['ended']
  start,end,hard=events[position:position+3];position+=3
  assert[start['kind'],end['kind'],hard['kind']]==['MOULT_START','MOULT_END','HARDENED']
  assert start['value']['moulting']>0 and not start['value']['can_run']and not start['value']['can_lock']
  assert end['value']['stage']==hard['value']['stage']==stage and end['value']['soft']>0 and hard['value']['soft']==0
  assert end['value']['can_run']==(stage>=1)and end['value']['can_lock']==(stage>=2)
  assert end['value']['food']==0 and not hard['value']['ended']
 adult=events[position];position+=1;assert adult['kind']=='ADULT'and adult['value']['stage']==3 and adult['value']['finished_main']and adult['value']['meals']==sum(targets)
cleanup=rows('CLEANUP')[0];assert cleanup['active']==cleanup['gate']['scopes']==cleanup['gate']['started']==cleanup['gate']['queued']==0 and cleanup['optionsCreated']==cleanup['optionsDestroyed']
assert not a.out.exists();a.out.mkdir(parents=True)
(a.out/'manifest.json').write_bytes((a.stage/'manifest.json').read_bytes())
for name in ['compile.txt','strict.txt']:(a.out/name).write_bytes((a.stage/name).read_bytes())
(a.out/'native-output.txt').write_bytes(('\n'.join(kept)+'\n').encode())
result=dict(passed=True,run=events[0]['run'],source_count=276,source_guards=2,ordinary_sources=273,
 complete_meals=62,completed_moults=9,adult_modes=3,events=events,model_sha256=m['place_sha256'],
 original_log=str(a.log),log_sha256=sha(raw),creator_errors=errors,creator_warnings=warnings,
 limits='Local unbound Studio/memory. Captures and safe Crack arrival are scripted; actual input-state taps drive struggle/feeding. Clock advances are accelerated for moult/hardening. No stage, energy or food counters assigned. Earned adult unlock and local retained-rest preparation; not natural hunts, full mating/generation, online saves/rejoin, physical devices or FPS proof.')
(a.out/'native.json').write_bytes((json.dumps(result,indent=2)+'\n').encode())
print(json.dumps({k:result[k]for k in ['passed','run','complete_meals','completed_moults','adult_modes','source_guards']}))
