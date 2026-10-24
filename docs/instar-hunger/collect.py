"""Seal the bounded, unpublished Studio instar/hunger fixture after exit."""
from pathlib import Path
import argparse, hashlib, json, re, subprocess
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
 hit=re.search(r'\[INSTAR_HUNGER_([A-Z_]+)\] (\d+) (.+)$',line)
 if hit:events.append(dict(kind=hit[1],run=hit[2],utc=line.split(',')[0],data=json.loads(hit[3])))
assert len({e['run']for e in events})==1
assert len([e for e in events if e['kind']=='PASS'])==1 and not any(e['kind']=='FAIL'for e in events)
errors=[l for l in text.splitlines()if '[FLog::CreatorError]'in l]
warnings=[l for l in text.splitlines()if '[FLog::CreatorWarning]'in l]
assert not errors
rows=[e['data']for e in events if e['kind']=='MOULT']
assert len(rows)==17
for adult,mode,goals in [(8,'main',[4,6,8,11,15,20]),(7,'main',[4,6,8,15,20]),(8,'free',[2,3,4,6,8,10])]:
 case=[v for v in rows if v['adult']==adult and v['mode']==mode]
 assert [v['stage']for v in case]==list(range(1,adult-1))
 assert [v['goal']for v in case]==goals
 assert all(v['can_run']==(v['stage']>=2) and v['can_lock']==(v['stage']>=5) and v['skins']==v['stage'] and v['instar']==v['stage']+2 and v['adult_now']==(v['instar']==adult)for v in case)
assert len([e for e in events if e['kind']=='RESTORED'])==3
assert len([e for e in events if e['kind']=='ADULT'])==3
veils=[e['data']for e in events if e['kind']=='VEIL']
assert [v['food']for v in veils]==[1,.55,.1]
assert not veils[0]['shown'] and veils[1]['shown'] and veils[2]['shown']
assert veils[0]['extent']<veils[1]['extent']<veils[2]['extent']<.32
assert veils[0]['opacity']<veils[1]['opacity']<veils[2]['opacity']<.4
bar=[e['data']for e in events if e['kind']=='BAR'];assert len(bar)==1 and abs(bar[0]['fill']-bar[0]['reserve'])<1e-6
cleanup=[e['data']for e in events if e['kind']=='CLEANUP'];assert len(cleanup)==1
assert cleanup[0]['active']==cleanup[0]['gate']['scopes']==0 and cleanup[0]['optionsCreated']==cleanup[0]['optionsDestroyed']
a.out.mkdir(parents=True)
for name in ['manifest.json','compile.txt','strict.txt']:(a.out/name).write_bytes((a.stage/name).read_bytes())
(a.out/'playback.luau').write_bytes((a.stage/'src/Client/MatrixPlayback.luau').read_bytes())
kept=[l for l in text.splitlines()if any(marker in l for marker in ['[INSTAR_HUNGER_','[FLog::CreatorOutput] [MATRIX_GUARD]','[FLog::CreatorError]','[FLog::CreatorWarning]'])]
(a.out/'native-output.txt').write_bytes(('\n'.join(kept)+'\n').encode())
result=dict(passed=True,source_commit=m['revision'],run=events[0]['run'],events=events,moults=len(rows),restored_moults=3,adults=3,source_guards=2,creator_errors=errors,creator_warnings=warnings,model_sha256=m['place_sha256'],model_unchanged=True,log_sha256=sha(raw),original_log=str(a.log),studio_pid=a.pid,studio_exited=True,published=False,limits='Synthetic seed and swallowed-food/reserve credits, scripted safe placement and accelerated moult clock. Ordinary growth, rest, local return and presentation. Unbound Studio/memory; not hunting, natural difficulty, online persistence, FPS or physical-device comfort.')
(a.out/'result.json').write_bytes((json.dumps(result,indent=2)+'\n').encode())
print(json.dumps({k:result[k]for k in ['passed','run','moults','restored_moults','adults','source_guards','studio_exited']},indent=2))
