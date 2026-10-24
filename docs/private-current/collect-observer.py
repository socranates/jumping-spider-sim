"""Qualify the observer's real-engine behavior in an unpublished memory fixture."""
from pathlib import Path
import argparse,hashlib,json,re,subprocess,sys
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
p=argparse.ArgumentParser();p.add_argument('--stage',type=Path,required=True);p.add_argument('--log',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((a.stage/'manifest.json').read_text())
original=(H/'player-probe.client.luau').read_bytes().replace(b'\r\n',b'\n')
gate=b'if Run:IsStudio()or game.GameId~=10771634917 or game.PlaceId~=109879630247781 then return end'
override=b'assert(Run:IsStudio()and game.GameId==0 and game.PlaceId==0);print("[PRIVATE_CURRENT_NATIVE_GATE]",game:GetService("HttpService"):JSONEncode({studio=Run:IsStudio(),place=game.PlaceId,universe=game.GameId,diagnostic_attribute_present=workspace:GetAttribute("PrivateCurrentObserverDiagnostic")~=nil,diagnostic_attribute_true=workspace:GetAttribute("PrivateCurrentObserverDiagnostic")==true}))'
assert m['private_current_probe_sha256']==sha(original)and m['source_count']==277
assert(a.stage/'src/First/PlayerArrivalProbe.client.luau').read_bytes()==original.replace(gate,override)
assert sha(Path(m['place']).read_bytes())==m['place_sha256']
for rel,digest in m['original_sources'].items():
 assert sha((ROOT/'roblox_port/src'/rel).read_bytes().replace(b'\r\n',b'\n'))==digest
events=[];lines=[]
for line in a.log.read_text(encoding='utf8').splitlines():
 hit=re.search(r'\[FLog::CreatorOutput\] \[PRIVATE_CURRENT_(\w+)\]\s+(\d+)\s+(\{.*\})$',line)
 if hit:events.append(dict(kind=hit[1],run=hit[2],value=json.loads(hit[3])));lines.append(line)
assert len({e['run']for e in events})==1
def one(kind):
 rows=[x['value']for x in events if x['kind']==kind];assert len(rows)==1,(kind,len(rows));return rows[0]
begin=one('BEGIN');end=one('END');first=one('FIRST')
assert begin['readonly']and begin['place']==begin['universe']==0
assert end['t']>=90 and end['windows']==6 and end['skipped_windows']==0
assert end['phase']=='title-ready'and not end['world_failed']and not end['unavailable']
assert end['evidence']==end['expected_evidence']=='032b5985ac17eeb2'
assert end['store']==end['expected_store']=='WindowsillTest_playerRig_20261024a1'
assert end['connections_disconnected']==7 and end['render_bindings_removed']
assert end['focus_lost']==0
assert len(end['engine_phases'])==6 and all(x>0 for x in end['engine_phases'].values())
assert len([x for x in events if x['kind']=='ENGINE_FIRST'])==6
windows=[x['value']for x in events if x['kind']=='WINDOW']
assert [x['index']for x in windows]==list(range(1,7))
for w in windows:
 assert w['frames']>0 and not w['samples_truncated']and w['raw']['n']==w['callbacks']['n']==w['frames']
 assert abs(w['wall_seconds']-w['observed_seconds'])<.002
 assert w['store']==end['store']and w['evidence']==end['evidence']
 for metric in [w['raw'],w['callbacks']]:assert 0<=metric['p50_ms']<=metric['p95_ms']<=metric['p99_ms']<=metric['max_ms']
assert not a.out.exists();a.out.mkdir()
# Companion collector checks both source guards, cleanup and authoritative PASS.
subprocess.run([sys.executable,str(ROOT/'docs/startup-clock/collect.py'),'--stage',str(a.stage),'--log',str(a.log),'--out',str(a.out/'startup')],check=True,capture_output=True,text=True)
raw=('\n'.join(lines)+'\n').encode();(a.out/'observer-output.txt').write_bytes(raw)
record=dict(passed=True,run=events[0]['run'],source_count=277,source_guards=2,
 model_sha256=m['place_sha256'],original_probe_sha256=sha(original),observer_output_sha256=sha(raw),
 guard_override_only=True,events=events,published=False,
 limits='Native observer/cleanup test in local Studio with yielding-memory storage and a Studio-only identity guard. No private publication, standalone Player timing or general FPS proof.')
(a.out/'observer.json').write_bytes((json.dumps(record,indent=2)+'\n').encode())
print(json.dumps(dict(passed=True,run=record['run'],windows=6,frames=sum(w['frames']for w in windows),callbacks_removed=7,bindings_removed=2)))
