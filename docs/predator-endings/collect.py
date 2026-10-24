"""Collect bounded real-engine ending/survival evidence, never online-save proof."""
from pathlib import Path
import argparse,hashlib,json,re
p=argparse.ArgumentParser();p.add_argument('--stage',type=Path,required=True);p.add_argument('--log',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
ROOT=Path(__file__).resolve().parents[2]
sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((a.stage/'manifest.json').read_text())
assert m['source_count']==276 and m['storage']=='unbound yielding memory only'and not m['published']
assert sha(Path(m['place']).read_bytes())==m['place_sha256']
assert sha((a.stage/'guard.luau').read_bytes())==m['guard_sha256']
for rel,digest in m['original_sources'].items():
 assert sha((ROOT/'roblox_port/src'/rel).read_bytes().replace(b'\r\n',b'\n'))==digest,rel
assert (a.stage/'src/Client/MatrixPlayback.luau').read_bytes()==(ROOT/'docs/predator-endings/playback.luau').read_bytes()
assert not re.search(r'TypeError|SyntaxError', (a.stage/'strict.txt').read_text())
raw=a.log.read_bytes();events=[];kept=[];guards=[];errors=[];warnings=[]
for line in raw.decode().splitlines():
 hit=re.search(r'\[LIFE_END_(\w+)\]\s+(\d+)\s+(\{.*\}|\[.*\])$',line)
 if hit:events.append(dict(kind=hit[1],run=hit[2],value=json.loads(hit[3])));kept.append(line)
 elif '[MATRIX_GUARD] 276 after full unbound memory_only'in line:guards.append(line);kept.append(line)
 elif '[FLog::CreatorError]'in line:errors.append(line);kept.append(line)
 elif '[FLog::CreatorWarning]'in line:warnings.append(line);kept.append(line)
assert len(guards)==2 and not errors and len({e['run']for e in events})==1
rows=lambda kind:[e['value']for e in events if e['kind']==kind]
assert len(rows('PASS'))==len(rows('BEGIN'))==len(rows('CLEANUP'))==1 and not rows('FAIL')
causes=['cat','crab_spider','bird','frog','drowned']
assert[x['cause']for x in rows('ENDING')]==[x['cause']for x in rows('ANOTHER')]==causes
assert all(x['duplicate_refused'] for x in rows('ENDING'))and all(x['resumed']for x in rows('ANOTHER'))
start,starved=rows('SURVIVAL_START'),rows('STARVED');assert len(start)==len(starved)==1
assert start[0]['energy']>.5 and start[0]['streak']==0 and start[0]['meals']==0
assert starved[0]['energy']==0 and starved[0]['streak']>=12 and starved[0]['meals']==0 and starved[0]['ended']and starved[0]['life_over']
gentle=rows('GENTLE');assert len(gentle)==2 and {x['mode']for x in gentle}=={'main','free'}
assert all(x['rules']=='gentle'and not x['ended']and not x['life_over']and x['streak']==0 and x['energy']>=.1-1e-9 for x in gentle)
cleanup=rows('CLEANUP')[0];assert cleanup['active']==cleanup['gate']['scopes']==cleanup['gate']['started']==cleanup['gate']['queued']==0 and cleanup['optionsCreated']==cleanup['optionsDestroyed']
assert not a.out.exists();a.out.mkdir(parents=True)
(a.out/'manifest.json').write_bytes((a.stage/'manifest.json').read_bytes())
(a.out/'native-output.txt').write_bytes(('\n'.join(kept)+'\n').encode())
record=dict(passed=True,source_count=276,original_sources=273,source_guards=2,events=events,
 model_sha256=m['place_sha256'],original_log=str(a.log),log_sha256=sha(raw),creator_errors=errors,creator_warnings=warnings,
 limits='Local unbound Studio with yielding memory storage. Deliberately invoked predator ending boundaries; not natural sensing/strikes. Hunger accumulates through real client ticks at120x clock; Easy unlocked as fixture setup. Not feeding/mating/generation, real storage, native device comfort or published game qualification.')
(a.out/'native.json').write_bytes((json.dumps(record,indent=2)+'\n').encode())
print(json.dumps(dict(passed=True,run=events[0]['run'],endings=causes,starvation=starved[0],gentle=gentle,errors=len(errors))))
