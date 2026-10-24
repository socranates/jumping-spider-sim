"""Collect native route evidence, preserving failures without calling them passed."""
from pathlib import Path
import argparse,hashlib,json,re
p=argparse.ArgumentParser();p.add_argument('--stage',type=Path,required=True);p.add_argument('--log',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--allow-failure',action='store_true');a=p.parse_args()
sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((a.stage/'manifest.json').read_text())
assert sha(Path(m['place']).read_bytes())==m['place_sha256']
assert sha((a.stage/'guard.luau').read_bytes())==m['guard_sha256']
events=[];guards=[];diagnostics=[];completions=[];kept=[]
for line in a.log.read_text(encoding='utf8').splitlines():
 if '[FLog::CreatorOutput]'in line and '[SEAM_'in line:
  hit=re.search(r'\[SEAM_(\w+)\]\s+(\d+)\s+(\{.*\})$',line);assert hit,'Truncated seam event: '+line[:100]
  events.append(dict(kind=hit[1],run=hit[2],value=json.loads(hit[3])));kept.append(line)
 elif '[FLog::CreatorOutput]'in line and re.search(r'\[MATRIX_FRAME_(PASS|FAIL)\]',line):
  hit=re.search(r'\[MATRIX_FRAME_(PASS|FAIL)\]\s+(\d+)\s+(\{.*\})$',line);assert hit,'Truncated probe completion'
  completions.append(dict(kind=hit[1],run=hit[2],value=json.loads(hit[3])));kept.append(line)
 elif '[FLog::CreatorOutput]'in line and '[MATRIX_GUARD]'in line:guards.append(line);kept.append(line)
 elif '[FLog::CreatorError]'in line or '[FLog::CreatorWarning]'in line:diagnostics.append(line);kept.append(line)
assert len({e['run']for e in events})==1 and len(completions)==1
ends=[e['value']for e in events if e['kind']=='END'];assert len(ends)==1
end=ends[0];passed=end['completed']and completions[0]['kind']=='PASS'
walks=[e['value']for e in events if e['kind']=='WALK'];hops=[e['value']for e in events if e['kind']=='HOP']
names=['hut_south','hut_east','hut_east_inner','hut_north']if m.get('seam_group')=='hut_perimeter'else ['path_west','path_east','path_north','pad_meadow','mown_north','mown_south']
assert len(guards)>=2,'Both source guards required, including failed fixture collection'
expected_guard=f"[MATRIX_GUARD] {m['source_count']} {m['variant']} {m['tier']} unbound memory_only"
assert all(line.endswith(expected_guard)for line in guards),'Source guard cohort mismatch'
assert end['detail']==m['tier']
if not a.allow_failure:
 assert passed and end['failures']==0 and end['focus_lost']==0,end
 assert [x['route']for x in walks]==[x['route']for x in hops]==names
 assert not any('[FLog::CreatorError]'in x for x in diagnostics)
 assert all(x['reached']and x['frames']>0 and x['min_y']>=-88.6 and x['max_step']<=5 and not x.get('returned_home')for x in walks)
 assert all(x['result']=='launched'and x['fresh']and x['left_support']for x in hops)
 states=[e['value']['state']for e in events if e['kind']=='STATE'and e['value']['when']in ['walk_end','hop_end']]
 assert len(states)==2*len(names) and all(x['live']and x['mode']=='attached'and x['up'][1]>.5 and x['detail']==m['tier']and abs(x['fov']-65)<.001 for x in states)
assert not a.out.exists(),'Retain prior native evidence'
a.out.mkdir(parents=True)
raw=('\n'.join(kept)+'\n').encode();(a.out/'native-output.txt').write_bytes(raw)
record=dict(run=events[0]['run'],passed=passed,tier=m['tier'],source_count=m['source_count'],source_guards=len(guards),
 model_sha256=m['place_sha256'],manifest_sha256=sha((a.stage/'manifest.json').read_bytes()),
 native_output_sha256=sha(raw),events=events,walks=walks,hops=hops,completion=end,probe_completion=completions[0],
 creator_errors=sum('[FLog::CreatorError]'in x for x in diagnostics),creator_warnings=sum('[FLog::CreatorWarning]'in x for x in diagnostics),
 limits=f'{len(names)} authored arrivals and ordinary input walks/tap hops in unbound Studio Free play. Screenshots may be taken; no FPS comparison. Not every map surface, physical controller/phone, natural life or real-store proof.')
(a.out/'native.json').write_bytes((json.dumps(record,indent=2)+'\n').encode())
(a.out/'manifest.json').write_bytes((a.stage/'manifest.json').read_bytes())
print(json.dumps(dict(run=record['run'],passed=passed,walks=len(walks),hops=len(hops),completion=end)))
