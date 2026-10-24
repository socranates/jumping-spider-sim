"""Retain bounded native profile results; full raw dumps remain local."""
from pathlib import Path
import hashlib, json, os

HERE=Path(__file__).resolve().parent
LOGS=Path(os.environ['LOCALAPPDATA'])/'Roblox/logs'
DOWNLOADS=Path.home()/'Downloads'
sha=lambda data:hashlib.sha256(data).hexdigest()
inputs={
 'client-paused':('microprofile-20261024-055335.html','client_summary.json','client.csv'),
 'server-request-paused':('log_F1893_microprofile_20261024-060133.html','server_summary.json','server.csv'),
}
captures={}
for role,(html,summary,csv) in inputs.items():
 raw=(DOWNLOADS/summary).read_bytes()
 result=json.loads(raw)
 # Keep timing results, not a full machine/driver inventory or private raw log.
 result.pop('platform_info',None)
 out=HERE/(role+'-summary.json')
 assert not out.exists(),'Do not replace a prior capture'
 out.write_bytes((json.dumps(result,indent=2)+'\n').encode())
 captures[role]=dict(raw_file='%LOCALAPPDATA%/Roblox/logs/'+html,
  raw_bytes=(LOGS/html).stat().st_size,raw_sha256=sha((LOGS/html).read_bytes()),
  exported_summary_sha256=sha(raw),retained_summary_sha256=sha(out.read_bytes()),
  marker_export_sha256=sha((DOWNLOADS/csv).read_bytes()),frames=result['num_frames'])
record=dict(source_evidence='105c83862d500f43',game_source_commit='c80548933395eed5f7ccdd227af70210d49cd03f',
 native_model='pair2/after-full',run='1792838564863',captures=captures,
 native_version='Studio 0.744.0.7441077',published=False,
 scope='Active garden endpoint after the matched benchmark PASS; profiler UI and dump export activity occurred after timed workloads.',
 server_qualification=False,
 server_limit='Server-tab request occurred while the native profiler was paused. The 60-frame export repeats client capture maxima and render/GPU content. Not independent server timing; retain as an overlapping/stale-buffer diagnostic.',
 limits='Profiler wall times include scheduling/UI/GC effects and nested scopes. Sleep is not busy CPU. Identical alias totals are not additive. Not a startup capture, statistical benchmark, or proof of a cause inside SpiderClient.')
(HERE/'initial-captures.json').write_bytes((json.dumps(record,indent=2)+'\n').encode())
print(json.dumps(dict(captures={k:v['frames']for k,v in captures.items()},server_qualification=False)))
