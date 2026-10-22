"""Reconstruct the isolated native result without interpreting it as a game fix."""
from pathlib import Path
import hashlib,json,re
from collect import collect
HERE=Path(__file__).resolve().parent
def read(name):return json.loads((HERE/name).read_text())
def digest(data):return hashlib.sha256(data).hexdigest()
manifest_bytes=(HERE/'manifest-v1.json').read_bytes();manifest=json.loads(manifest_bytes)
assert digest((HERE/'probe.client.luau').read_bytes())==manifest['probe_sha256']
assert manifest['scripts']=={'StarterPlayer.StarterPlayerScripts.PartChurn':manifest['probe_sha256']}
assert not manifest['game_source_included'] and not manifest['persistence_included'] and not manifest['published']
assert read('prepared.json')['compile_exit_code']==0 and read('prepared.json')['probe_sha256']==manifest['probe_sha256']
assert 'Compiled' in (HERE/'compile.txt').read_text()
tests=(HERE/'collector-tests.txt').read_text();assert 'Ran 8 tests' in tests and re.search(r'^OK$',tests,re.M)
events=(HERE/'native-v1-events.txt').read_bytes();saved=read('native-v1.json')
assert saved.pop('events_sha256')==digest(events) and saved.pop('manifest_sha256')==digest(manifest_bytes)
rebuilt=collect(events.decode('utf8'),manifest);assert rebuilt==saved and rebuilt['complete']
assert rebuilt['run']=='1792669956410' and rebuilt['isolated_part_growth_observed'] and rebuilt['persists_after_30_seconds']
origin=read('origin-v1.json');assert origin['probe_sha256']==manifest['probe_sha256'] and origin['windows_full_terminal_before_start']
heap=read('post-run-heap-summary.json')
native_nodes=[json.loads(re.search(r'\[PART_CHURN_HEAP_NODE\] (\{.*\})$',line)[1]) for line in (HERE/'post-run-heap-events.txt').read_text().splitlines() if '[PART_CHURN_HEAP_NODE]' in line]
assert native_nodes==heap['nodes'] and len(native_nodes)==heap['tree_nodes']==22
assert native_nodes[0]['size']==heap['root_count']==42 and native_nodes[0]['children']==heap['host_groups']==10
for node in native_nodes:
 children=[child for child in native_nodes if child['path'].rsplit('/',1)[0]==node['path']]
 assert len(children)==node['children']
 if children:assert sum(child['size'] for child in children)==node['size']
assert not any('PartChurn' in node['path'] for node in native_nodes)
result={'native_complete':True,'native_run':rebuilt['run'],'probe_sha256':manifest['probe_sha256'],
 'native_duration_seconds':rebuilt['duration_seconds'],'records':len(rebuilt['records']),'fixture_created':61000,'fixture_destroyed':61000,
 'final_live_fixture_parts':0,'isolated_category_growth_reproduced':True,'growth_persists_after_30_seconds':True,
 'post_run_client_reference_tree_verified':True,'post_run_probe_group_listed':False,
 'game_memory_leak_proven':False,'absence_of_game_leaks_proven':False,'engine_bug_proven':False,
 'standalone_client_verified':False,'phone_verified':False,'fps_benefit_claimed':False,'published':False}
(HERE/'receipt.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(result,indent=2))
