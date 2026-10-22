"""Verify retained offline experiment receipts; never infers native/performance success."""
from pathlib import Path
import hashlib,json,re,subprocess

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
def read(name):return json.loads((HERE/name).read_text(encoding='utf-8-sig'))
def normalized_hash(data):return hashlib.sha256(data.replace(b'\r\n',b'\n')).hexdigest()
manifest=read('manifest-v1d.json');receipt=read('offline-receipt.json');equiv=read('bundle-equivalence.json');compiled=read('compile-process.json')
source=manifest['source']
expected={'reference.luau':('RIG_REFERENCE',1478428),'look.luau':('LOOK',1442),'idle.luau':('IDLE',5719),
          'growth.luau':('GROWTH',571),'feeding_survival.luau':('MEALS',88),'client_rival.luau':('CLIENT_RIVAL',9),'inspect.luau':('INSPECT',37)}
assert receipt['source']==source and receipt['passed'] and len(receipt['rows'])==7
assert {r['suite'] for r in receipt['rows']}==set(expected)
for row in receipt['rows']:
    assert row['exit_code']==0
    name,n=expected[row['suite']]
    text=(HERE/('offline-'+row['suite']+'.txt')).read_text(encoding='utf-8')
    assert re.search(rf'^{name} passed={n} failed=0(?: |$)',text,re.M),row['suite']
text=(HERE/'offline-reference.luau.txt').read_text()
assert 'cases=14 frames=2800' in text and 'worst_position=0' in text and 'worst_size=0' in text
assert float(re.search(r'worst_axis=([0-9.e+-]+)',text)[1])<1e-8
assert equiv['passed'] and len(equiv['rows'])==7 and {r['suite'] for r in equiv['rows']}==set(expected)
assert all(r['working_tree_bundle_sha256']==r['frozen_bundle_sha256'] for r in equiv['rows'])
scripts={r['path']:r['sha256'] for r in manifest['scripts']}
assert len(scripts)==len(manifest['scripts'])==176
cached=scripts['ReplicatedStorage.Shared.Rig.RigCached']
assert receipt['cached_source_sha256']==cached
assert normalized_hash((HERE/'driver.client.luau').read_bytes())==scripts['StarterPlayer.StarterPlayerScripts.RigExperiment']
assert hashlib.sha256((HERE/'build-v1d.py').read_bytes()).hexdigest()==manifest['builder_sha256']
original=subprocess.check_output(['git','show',source+':roblox_port/src/Shared/Rig/SpiderRig.luau'],cwd=ROOT)
assert hashlib.sha256(original).hexdigest()==receipt['reference_source_sha256']
assert normalized_hash(original)==scripts['ReplicatedStorage.Shared.Rig.SpiderRig']
assert compiled['exit_code']==0 and len(compiled['files'])==3
for file in compiled['files']:
    path='StarterPlayer.StarterPlayerScripts.RigExperiment' if file['name']=='driver.client.luau' else 'ReplicatedStorage.Shared.Rig.'+file['name'].removesuffix('.luau')
    assert file['sha256']==scripts[path]
assert read('release-refusal.json')['refused'] is True
assert read('ui-attempt.json')['native_run_started'] is False
result={'source':source,'offline_verified':True,'cases':14,'pose_frames':2800,'existing_suites':6,'differential_checks':1478428,
        'existing_checks':7866,'cached_source_sha256':cached,'native_verified':False,'performance_gain_verified':False,
        'published':False,'scope':'Retained isolated prototype CLI checks only; game source remains unchanged in this experiment'}
(HERE/'verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps(result,indent=2))
