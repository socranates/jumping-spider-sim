"""Retain only Creator diagnostic output, not the Studio log's account telemetry."""
from pathlib import Path
import argparse, hashlib, json, re

HERE = Path(__file__).resolve().parent
p = argparse.ArgumentParser()
p.add_argument('log', type=Path)
p.add_argument('folder', type=Path)
a = p.parse_args()
source = '8e02b5ee5f443ab332cf7e70f5951a304cb89eea'
manifest = json.loads((HERE/'prepared-native-manifest.json').read_text(encoding='utf8'))
assert manifest['source'] == source and len(manifest['scripts']) == 217
place = a.folder/'Windowsill-startup-component-review.rbxlx'
assert hashlib.sha256(place.read_bytes()).hexdigest() == manifest['place_sha256']
lines = a.log.read_text(encoding='utf8', errors='replace').splitlines()
creator = [s for s in lines if '[FLog::CreatorOutput]' in s or '[FLog::CreatorError]' in s]
assert not any('[FLog::CreatorError]' in s for s in creator), 'inspect and classify actual Creator errors'
guard = [s for s in creator if '[FLog::CreatorOutput] [STARTUP_COMPONENT_GUARD]' in s]
assert len(guard) == 1 and source+' 217 actor_splash_persistence_disabled' in guard[0]
begin = [s for s in creator if '[FLog::CreatorOutput] [STARTUP_COMPONENT_BEGIN]' in s]
assert len(begin) == 1
run = re.search(r'\[STARTUP_COMPONENT_BEGIN\] (\d+) ', begin[0])[1]
cases = [re.search(r'\[STARTUP_COMPONENT_CASE\] '+run+r' (\d+) (\d+) (.*)$',s) for s in creator]
cases = [m for m in cases if m]
assert [int(m[1]) for m in cases] == list(range(1,13))
assert [int(m[2]) for m in cases] == [2,4,7,11,14,17,20,24,30,33,35,38]
assert any('[FLog::CreatorOutput] [STARTUP_COMPONENT_DONE] '+run+' 12 38' in s for s in creator)
assert not any('[STARTUP_COMPONENT_FAIL]' in s for s in creator)
post = [s for s in creator if '[FLog::CreatorOutput] [STARTUP_COMPONENT_POST]' in s]
assert len(post)==1 and '[STARTUP_COMPONENT_POST] true true 1105 433 3' in post[0]
retained = ('\n'.join(creator)+'\n').encode()
(HERE/'native-output.txt').write_bytes(retained)
receipt = dict(source=source, run_id=run, cases=12, assertions=38,
  output_sha256=hashlib.sha256(retained).hexdigest(),
  place_sha256=manifest['place_sha256'], exact_guarded_scripts=217,
  creator_errors=0, post_viewport=[1105,433],
  begin_viewport=[1,1], signal_behavior_read='unavailable to diagnostic LocalScript',
  real_instances_gui_signals=True, controlled_transport=True, accelerated_splash_timing=True,
  whole_game_cold_load_verified=False, real_network_streaming_verified=False,
  phone_verified=False, performance_verified=False, online_saves_accessed=False, published=False)
(HERE/'native-component-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',encoding='utf8',newline='\n')
print(json.dumps(receipt,indent=2))
