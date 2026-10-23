"""Retain bounded Creator diagnostics and bind them to an immutable model.

Reads a Studio log, never drives Studio or accesses a real save store.
"""
from pathlib import Path
import argparse, hashlib, json, re

H = Path(__file__).resolve().parent
sha = lambda b: hashlib.sha256(b).hexdigest()
p = argparse.ArgumentParser()
p.add_argument('--artifact', type=Path, required=True)
p.add_argument('--log', type=Path, required=True)
p.add_argument('--run', required=True)
p.add_argument('--prefix', required=True)
a = p.parse_args()
assert re.fullmatch(r'native-attempt[0-9]+', a.prefix)
manifest = json.loads((a.artifact / 'manifest.json').read_text())
place = a.artifact / 'Windowsill-native-new-application.rbxlx'
assert sha(place.read_bytes()) == manifest['place_sha256']
rows = a.log.read_text(encoding='utf8', errors='replace').splitlines()
guard = [i for i, row in enumerate(rows) if '[FLog::CreatorOutput] [NEW_APP_NATIVE_GUARD]' in row]
begin = next(i for i, row in enumerate(rows) if '[FLog::CreatorOutput] [NEW_APP_NATIVE_SERVER_BEGIN] ' + a.run + ' ' in row)
preceding = [i for i in guard if i < begin]
assert preceding
first = preceding[-1]
following = [i for i in guard if i > begin]
last = following[0] if following else len(rows)
assert manifest['source'] + ' 265 memory_only unbound do_not_publish' in rows[first]
selected = []
stack = False
for row in rows[first:last]:
    creator = bool(re.search(r'\[FLog::Creator(?:Output|Warning|Error)\]', row))
    if creator and ' > ' not in row:
        selected.append(row)
        stack = True
    elif stack and row and not re.match(r'^\d{4}-\d\d-\d\dT', row):
        selected.append(row)
    else:
        stack = False
text = '\n'.join(selected) + '\n'
passed = re.findall(r'\[NEW_APP_NATIVE_CLIENT_PASS\] ' + a.run + r' (\d+) (\{.*\})', text)
failed = '[NEW_APP_NATIVE_CLIENT_FAIL] ' + a.run in text or '[NEW_APP_NATIVE_SERVER_FAIL] ' + a.run in text
assert passed or failed, 'Only collect a terminal diagnostic'
assert not (passed and failed)
stored = re.findall(r'\[NEW_APP_NATIVE_NEW_STORED\] ' + a.run + r' (main|free|easy) ', text)
result = dict(source=manifest['source'], run=a.run, artifact=str(a.artifact),
              place_sha256=manifest['place_sha256'], manifest_sha256=sha((a.artifact/'manifest.json').read_bytes()),
              scripts=265, untouched_production=222, diagnostics=manifest['diagnostic_inputs'],
              private_overrides=['WorldMap', 'Checkpoint'], clock_scale=10, memory_store=True,
              engine_codec=True, real_remote_events=True, terminal='passed' if passed else 'failed',
              native_verified=bool(passed), online_verified=False, published=False,
              stored_modes=stored, output_sha256=sha(text.encode()))
if passed:
    assert stored == ['main', 'free', 'easy']
    assert '[FLog::CreatorError]' not in text, 'Retain and investigate engine errors'
    result['client_checks'] = int(passed[0][0])
    result['client_summary'] = json.loads(passed[0][1])
    assert result['client_summary']['real_remote_events'] and not result['client_summary']['online']
for suffix, data in [('.txt', text), ('.json', json.dumps(result, indent=2)+'\n')]:
    out = H / (a.prefix + suffix)
    assert not out.exists(), 'Keep earlier evidence'
    out.write_text(data, encoding='utf8', newline='\n')
print(json.dumps(result, indent=2))
