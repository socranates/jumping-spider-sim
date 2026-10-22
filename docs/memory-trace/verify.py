"""Reconstruct retained memory receipts. A live origin file never proves completion."""
from pathlib import Path
import io,tarfile,subprocess,hashlib,json,re
from collect import collect
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1]
def read(name):return json.loads((HERE/name).read_text(encoding='utf8'))
def digest(data):return hashlib.sha256(data).hexdigest()
m=read('manifest-v1b.json');source=m['source']
archive=subprocess.check_output(['git','archive','--format=tar',source,'roblox_port/src'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(archive)) as t:
 data={i.name:t.extractfile(i).read() for i in t if i.isfile()}
assert set(data)=={r['path'] for r in m['source_rows']} and len(data)==216
for r in m['source_rows']:
 assert digest(data[r['path']])==r['sha256']
 assert digest(data[r['path']].replace(b'\r\n',b'\n'))==r['native_sha256']
assert digest((HERE/'driver.luau').read_bytes().replace(b'\r\n',b'\n'))==m['driver_sha256']
assert read('compile-process.json')['exit_code']==0
assert read('compile-process.json')['source_sha256']==digest((HERE/'driver.luau').read_bytes())
tests=(HERE/'collector-tests.txt').read_text();assert 'Ran 10 tests' in tests and re.search(r'^OK$',tests,re.M)
assert 'MEMORY_FIXTURES passed=7 failed=0' in (HERE/'fixtures.txt').read_text()
def retained(prefix,run):
 events=(HERE/(prefix+'-events.txt')).read_bytes();saved=read(prefix+'.json')
 assert saved['events_sha256']==digest(events) and saved['manifest_sha256']==digest((HERE/'manifest-v1b.json').read_bytes())
 rebuilt=collect(events.decode('utf8'),m,run)
 for k in ['events_sha256','manifest_sha256']:saved.pop(k)
 assert rebuilt==saved and rebuilt['complete'] and rebuilt['source_guard_verified']
 return rebuilt
smoke=retained('smoke-v1b','1792665646453');assert not smoke['memory_gate_evidence'] and smoke['growth_screen']=='rehearsal_only'
origin=read('long-v1b-origin.json');assert origin['source']==source and origin['persistence_disabled'] and origin['heavy_cli_suites_finished_before_start']
long=retained('long-v1b',origin['run']) if (HERE/'long-v1b.json').exists() else None
result={'source':source,'source_modules':216,'diagnostic_script_count':217,'smoke_verified':True,'collector_tests':10,
 'rehearsal_duration':smoke['duration_seconds'],'long_complete':bool(long and long['complete']),
 'memory_gate_evidence':bool(long and long['memory_gate_evidence']),'growth_screen':long['growth_screen'] if long else 'pending',
 'live_metadata_is_not_liveness_proof':True,'performance_speedup_claim':False,'phone_verified':False,'published':False,'publication_ready':False}
(HERE/'verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(result,indent=2))
