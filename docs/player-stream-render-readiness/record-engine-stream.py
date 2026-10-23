"""Collect bounded actual-engine observations; retention is not stream-out proof."""
from pathlib import Path
import argparse,hashlib,json,re
H=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--prepared',required=True);p.add_argument('--log',type=Path,required=True);p.add_argument('--prefix',required=True);a=p.parse_args()
assert re.fullmatch(r'[a-z0-9-]+',a.prefix)
out=H/(a.prefix+'-output.txt');receipt=H/(a.prefix+'-receipt.json');assert not out.exists() and not receipt.exists()
r=json.loads((H/a.prepared).read_text(encoding='utf8'));sha=lambda b:hashlib.sha256(b).hexdigest()
model=Path(r['path']);assert sha(model.read_bytes())==r['model_sha256']
manifest=json.loads((model.parent/'manifest.json').read_text(encoding='utf8'));assert sha((model.parent/'manifest.json').read_bytes())==r['manifest_sha256']
lines=a.log.read_text(encoding='utf8',errors='replace').splitlines()
lines=[s for s in lines if re.search(r'\[FLog::Creator(?:Output|Warning|Error)\].*\[(?:ENGINE_STREAM|PLAYER_STREAM_NATIVE_GUARD)',s) and len(s)<4000]
assert any('[PLAYER_STREAM_NATIVE_GUARD] '+r['source']+' 223 persistence_disabled' in s for s in lines)
begins=[s for s in lines if '[ENGINE_STREAM_BEGIN]' in s];assert begins
run=begins[-1].split('[ENGINE_STREAM_BEGIN] ',1)[1].strip()
ends=[s for s in lines if '[ENGINE_STREAM_PASS] '+run in s or '[ENGINE_STREAM_FAIL] '+run in s];assert len(ends)==1
passed='[ENGINE_STREAM_PASS]' in ends[0]
observations=[]
for s in lines:
 if '[ENGINE_STREAM_OBSERVATION]' in s:
  data=json.loads(s.split('[ENGINE_STREAM_OBSERVATION] ',1)[1]);
  if data['run']==run:observations.append(data)
summary=json.loads(ends[0].split('[ENGINE_STREAM_PASS] '+run+' ',1)[1]) if passed else None
returning=any(s['phase']=='return' and s.get('streamOutVerified') for s in observations)
text='\n'.join(lines)+'\n';out.write_text(text,encoding='utf8',newline='\n')
r.update(executed=True,experiment_passed=passed,terminal=True,stopped=True,run=run,summary=summary,observations=observations,
 engine_stream_out_observed=bool(summary and summary['engineStreamOutObserved']),
 engine_remove_and_rearrival_verified=passed and returning,
 player_hold_during_engine_gap_observed=bool(passed and returning and summary['heldFrames']>0),
 native_verified=passed and returning,
 stream_out_behavior=manifest['stream_out_behavior'],detail=manifest['tier'],collision_mutations_in_probe=False,
 studio_log=str(a.log),filtered_output_sha256=sha(out.read_bytes()),
 scope=manifest['scope'])
if not passed:r['failure']=ends[0].split('[ENGINE_STREAM_FAIL] '+run,1)[1].strip()
receipt.write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
