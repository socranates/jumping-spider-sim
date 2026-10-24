"""Extract only this test probe's bounded events from one specified player log.

Does not copy the surrounding account, connection, or Roblox client log data.
Collection records measurements; it never declares the game or goal complete.
"""
from pathlib import Path
import argparse, hashlib, json, re

H = Path(__file__).resolve().parent
p = argparse.ArgumentParser()
p.add_argument('--log', type=Path, required=True)
p.add_argument('--player', type=Path, required=True)
p.add_argument('--run', required=True)
p.add_argument('--prefix', required=True)
a = p.parse_args()
assert a.prefix.replace('-', '').isalnum() and a.run.isdecimal()
target = H/(a.prefix+'-player.json')
assert not target.exists()
raw = a.log.read_bytes()
manifest_path = a.player/'manifest.json'
manifest = json.loads(manifest_path.read_text())
assert manifest['universe'] == 10771634917 and manifest['place_id'] == 109879630247781
events = []
for line in raw.decode('utf8', errors='replace').splitlines():
    match = re.search(r'\[PLAYER_ARRIVAL_(\w+)\]\s+(\d+)\s+(\{.*\})', line)
    if match and match[2] == a.run:
        events.append(dict(kind=match[1], value=json.loads(match[3])))
begins = [e['value'] for e in events if e['kind'] == 'BEGIN']
ends = [e['value'] for e in events if e['kind'] == 'END']
assert len(begins) == 1 and len(ends) <= 1
assert begins[0]['universe'] == manifest['universe'] and begins[0]['place'] == manifest['place_id']
assert begins[0]['readonly'] is True and begins[0]['detail'] == 'auto'
summaries = [e['value'] for e in events if e['kind'] == 'SUMMARY']
assert all(e['store'] == manifest['test_store'] for e in summaries), 'wrong/missing test-store identity'
complete = bool(ends) and len(summaries) == 6 and ends[0]['t'] >= 90
if complete:
    assert ends[0]['world_failed'] is False
    assert ends[0]['phase'] == 'title-ready'
    assert all(row['frames'] > 0 and row['seconds'] > 0 for row in summaries)
sha = lambda data: hashlib.sha256(data).hexdigest()
record = dict(run=a.run, complete=complete, log_sha256=sha(raw),
    manifest_sha256=sha(manifest_path.read_bytes()), model_sha256=manifest['place_sha256'],
    universe=manifest['universe'], place_id=manifest['place_id'], events=events,
    source_identity_verified_in_studio=False, published_version=None,
    manual_play_verified=False, broad_fps_improvement_proved=False)
target.write_bytes((json.dumps(record, indent=2)+'\n').encode())
print(f'Player probe: {len(events)} events; complete={complete}; receipt={target}')
