"""Collect a specified current private Player run, never surrounding account logs."""
from pathlib import Path
import argparse,hashlib,json,re
H=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--log',type=Path,required=True);p.add_argument('--run',required=True);p.add_argument('--published-version',type=int,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
assert a.run.isdecimal()and a.published_version>13 and not a.out.exists()
prepared=json.loads((H/'prepared.json').read_text());native=json.loads((H/'native.json').read_text())
assert prepared['evidence_id']==native['evidence_id']=='032b5985ac17eeb2'
assert native['source_guards']==2 and not native['creator_errors']
sha=lambda b:hashlib.sha256(b).hexdigest()
assert sha(Path(native['saved_editor']).read_bytes())==native['saved_editor_sha256']
raw=a.log.read_bytes();events=[];kept=[];warnings=[];errors=[];stacks=[]
for line in raw.decode('utf8',errors='strict').splitlines():
 hit=re.search(r'\[PRIVATE_CURRENT_(\w+)\]\s+(\d+)\s+(\{.*\})$',line)
 if hit and hit[2]==a.run:
  events.append(dict(kind=hit[1],value=json.loads(hit[3])));kept.append(line)
 if '[FLog::CreatorError]'in line:errors.append(line)
 if '[FLog::CreatorWarning]'in line:warnings.append(re.sub(r'(https?://[^\s?]+)\?[^\s]+',r'\1?<query omitted>',line))
 if '[FLog::Output]'in line and re.search(r'\bStack Begin\b|\bStack End\b|attempt to (?:index|call|perform)|Script .*, Line \d+',line):stacks.append(line)
def one(kind):
 rows=[x['value']for x in events if x['kind']==kind];assert len(rows)==1,(kind,len(rows));return rows[0]
begin=one('BEGIN');end=one('END');first=one('FIRST')
assert begin['readonly']and begin['universe']==prepared['universe']and begin['place']==prepared['place_id']
assert begin['place_version']==end['place_version']==a.published_version
assert end['evidence']==end['expected_evidence']==prepared['evidence_id']
assert end['store']==end['expected_store']==prepared['test_store']
assert end['t']>=90 and end['windows']==6 and end['skipped_windows']==0
assert end['phase']=='title-ready'and not end['world_failed']and not end['unavailable']
assert end['connections_disconnected']==7 and end['render_bindings_removed']
assert end['focus_lost']==0 and len(end['engine_phases'])==6 and all(x>0 for x in end['engine_phases'].values())
assert not errors and not stacks,'Inspect actual script errors before qualifying'
windows=[x['value']for x in events if x['kind']=='WINDOW']
assert[x['index']for x in windows]==list(range(1,7))
for w in windows:
 assert w['frames']>0 and not w['samples_truncated']and w['raw']['n']==w['callbacks']['n']==w['frames']
 assert abs(w['wall_seconds']-w['observed_seconds'])<.002
 assert w['store']==end['store']and w['evidence']==end['evidence']
phases=[x['value']for x in events if x['kind']=='PHASE']
ready=[x for x in phases if x['name']=='title-ready'];assert ready
engine_first=[x['value']for x in events if x['kind']=='ENGINE_FIRST'];assert len(engine_first)==6
record=dict(complete=True,run=a.run,published_version=a.published_version,
 universe=begin['universe'],place_id=begin['place'],evidence_id=end['evidence'],test_store=end['store'],
 saved_editor_sha256=native['saved_editor_sha256'],prepared_sha256=sha((H/'prepared.json').read_bytes()),
 original_log=str(a.log),log_sha256=sha(raw),events=events,
 creator_errors=errors,recognizable_script_errors=stacks,creator_warnings=warnings,
 title_ready_s=ready[0]['t'],first_callback=first,
 last30=dict(frames=sum(w['frames']for w in windows[-2:]),seconds=sum(w['wall_seconds']for w in windows[-2:])),
 limits='Bounded current private Player arrival, with read-only observer overhead. Windows can mix title, intro and gameplay; not a matched FPS comparison, full life, full save/rejoin or physical device qualification. Published asset bytes are not independently downloaded.')
a.out.mkdir(parents=True)
(a.out/'player.json').write_bytes((json.dumps(record,indent=2)+'\n').encode())
(a.out/'probe-output.txt').write_bytes(('\n'.join(kept)+'\n').encode())
print(json.dumps(dict(complete=True,run=a.run,version=a.published_version,title_ready_s=ready[0]['t'],last30=record['last30'])))
