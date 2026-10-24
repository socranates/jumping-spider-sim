"""Collect complete bounded client-clock observations, including both guards."""
from pathlib import Path
import argparse,hashlib,json,re
p=argparse.ArgumentParser();p.add_argument('--stage',type=Path,required=True);p.add_argument('--log',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((a.stage/'manifest.json').read_text())
assert m['startup_clock']and m['source_count']==276 and m['variant']=='after'
assert sha(Path(m['place']).read_bytes())==m['place_sha256']and sha((a.stage/'guard.luau').read_bytes())==m['guard_sha256']
events=[];guards=[];diagnostics=[];lines=[];server=[]
for line in a.log.read_text(encoding='utf8').splitlines():
 if '[FLog::CreatorOutput]'in line and '[STARTUP_CLOCK_'in line:
  hit=re.search(r'\[STARTUP_CLOCK_(\w+)\]\s+(\d+)\s+(\{.*\})$',line);assert hit,'Truncated observer line'
  events.append(dict(kind=hit[1],run=hit[2],value=json.loads(hit[3])));lines.append(line)
 elif '[FLog::CreatorOutput]'in line and '[STARTUP_SERVER_MARK]'in line:
  hit=re.search(r'\[STARTUP_SERVER_MARK\]\s+(\{.*\})$',line);assert hit;server.append(json.loads(hit[1]));lines.append(line)
 elif '[FLog::CreatorOutput]'in line and '[MATRIX_GUARD]'in line:guards.append(line);lines.append(line)
 elif '[FLog::CreatorError]'in line or '[FLog::CreatorWarning]'in line:diagnostics.append(line);lines.append(line)
assert len({x['run']for x in events})==1
expected=f"[MATRIX_GUARD] 276 after {m['tier']} unbound memory_only"
assert len(guards)>=2 and all(x.endswith(expected)for x in guards)
def one(kind):
 values=[x['value']for x in events if x['kind']==kind];assert len(values)==1,(kind,len(values));return values[0]
assert not any(x['kind']=='FAIL'for x in events)and one('PASS')['unbound']
ready=one('READY');assert ready['title_ready']and ready['save_ready']and ready['navigation']=='ready'
cleanup=one('CLEANUP');assert cleanup['active']==cleanup['scopes']==cleanup['focus_lost']==0 and not cleanup['life_started']
first=one('FIRST');summary=one('SUMMARY');assert summary['frames']>=60 and summary['wall_seconds']>=10
assert summary['raw_after_first']['n']==summary['callback_after_first']['n']==summary['frames']-1
marks=[x['value']for x in events if x['kind']=='MARK']
required=['client-enter','direct-imports-done','world-client-begin','world-client-end','module-table-done','spider-rig-begin','spider-rig-end',
 'stream-looks-begin','stream-looks-end','hud-begin','hud-end','animal-bodies-begin','animal-bodies-end','render-binding-begin','client-hooks-ready','title-ready']
if m.get('startup_profile'):
 required[3:3]=['world-client-import-begin','world-client-dependencies-ready','world-client-import-end','world-client-new-begin',
  'world-map-selected','home-region-begin','home-region-end','world-bounds-ready','home-collision-begin','home-collision-end','world-client-new-end']
 assert [x['name']for x in server]==['imports-begin','imports-end','decor-begin','decor-end','hidden-plan-begin','physical-world-begin','physical-world-end']
if m.get('startup_waits'):required.insert(required.index('home-collision-end'),'home-pieces-ready')
assert [x['name']for x in marks]==required,[x['name']for x in marks]
assert all(b['t']>=a['t']for a,b in zip(marks,marks[1:]))
assert not any('[FLog::CreatorError]'in x for x in diagnostics)
raw=('\n'.join(lines)+'\n').encode();assert not a.out.exists();a.out.mkdir(parents=True)
(a.out/'native-output.txt').write_bytes(raw);(a.out/'manifest.json').write_bytes((a.stage/'manifest.json').read_bytes())
record=dict(run=events[0]['run'],tier=m['tier'],model_sha256=m['place_sha256'],source_guards=len(guards),
 manifest_sha256=sha((a.stage/'manifest.json').read_bytes()),native_output_sha256=sha(raw),events=events,server_marks=server,first=first,summary=summary,marks=marks,
 creator_errors=sum('[FLog::CreatorError]'in x for x in diagnostics),creator_warnings=sum('[FLog::CreatorWarning]'in x for x in diagnostics),
 limits='Unbound Studio ordinary startup/title only, memory backend and timing hooks. First raw dt and observed wall time are separate. After-first distributions span changing startup phases, not steady gameplay FPS. Not private Player startup, real storage or a before/after optimization claim.')
(a.out/'native.json').write_bytes((json.dumps(record,indent=2)+'\n').encode())
print(json.dumps(dict(run=record['run'],tier=m['tier'],first=first,summary=summary,marks=marks)))
