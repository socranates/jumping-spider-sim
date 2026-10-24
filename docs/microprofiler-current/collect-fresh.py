"""Collect the completed one-scene fixture, not a benchmark/server capture."""
from pathlib import Path
import hashlib,json,re

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
STAGE=Path('C:/Users/natha/claude-xfer/Windowsill-microprofile-fresh-full1')
LOG=Path('C:/Users/natha/AppData/Local/Roblox/logs/0.744.0.7441077_20261024T112648Z_Studio_9A865_last.log')
sha=lambda data:hashlib.sha256(data).hexdigest()
manifest=json.loads((STAGE/'manifest.json').read_text())
assert sha(Path(manifest['place']).read_bytes())==manifest['place_sha256']
assert manifest['source_count']==276 and manifest['storage']=='unbound yielding memory only'
for rel,want in manifest['original_sources'].items():
 assert sha((ROOT/'roblox_port/src'/rel).read_bytes().replace(b'\r\n',b'\n'))==want,rel
lines=LOG.read_text(errors='replace').splitlines()
errors=[l for l in lines if '[FLog::CreatorError]'in l]
warnings=[l for l in lines if '[FLog::CreatorWarning]'in l]
guards=[l for l in lines if '[FLog::CreatorOutput] [MATRIX_GUARD] 276 after full unbound memory_only'in l]
events=[]
for line in lines:
 match=re.search(r'\[MATRIX_FRAME_([A-Z_]+)\] (\d+) (\{.*\})',line)
 if match:events.append(dict(kind=match[1],run=match[2],value=json.loads(match[3]),at=line[:24]))
runs={e['run']for e in events};assert len(runs)==1
assert len(guards)==2 and not errors
assert len([e for e in events if e['kind']=='PASS'])==1
assert not any(e['kind']=='FAIL'for e in events)
samples=[e['value']for e in events if e['kind']=='END']
assert [e['sample']for e in samples]==['client-startup','garden_rain']
sample=samples[1]
assert sample['frames']>2000 and sample['extra']['simulation_seconds']>=60
assert sample['extra']['live']and sample['extra']['mode']=='attached'and sample['extra']['rain']>.65
selected=[l for l in lines if '[FLog::CreatorOutput] [MATRIX_'in l or '[FLog::CreatorOutput] [MICROPROFILE_READY]'in l or '[FLog::CreatorWarning]'in l or '[FLog::CreatorError]'in l]
output=('\n'.join(selected)+'\n').encode()
out=HERE/'fresh-full1';out.mkdir(exist_ok=False)
(out/'native-output.txt').write_bytes(output)
(out/'manifest.json').write_bytes((STAGE/'manifest.json').read_bytes())
record=dict(run=next(iter(runs)),passed=True,source_guards=len(guards),creator_errors=len(errors),
 creator_warnings=len(warnings),model_sha256=manifest['place_sha256'],
 manifest_sha256=sha((out/'manifest.json').read_bytes()),native_output_sha256=sha(output),
 source_evidence='105c83862d500f43',events=events,
 first_ui_profiler_opened_during_sample=True,server_capture_obtained=False,published=False,
 limits='One rainy garden diagnostic. The native profiler was briefly opened during its 60-second lap sample; not part of the matched matrix. PASS includes asserted memory-save fixture cleanup. Subsequent live UI attempts did not produce a fresh server dump. A pointer-release command was not visibly entered and was never executed; both source guards pass. No ordinary source changes, online saves or standalone server qualification.')
(out/'native.json').write_bytes((json.dumps(record,indent=2)+'\n').encode())
parts=[e['value']for e in events if e['kind']=='PART'and e['value']['sample']=='garden_rain']
print(json.dumps(dict(run=record['run'],passed=True,guards=len(guards),errors=len(errors),warnings=len(warnings),top_parts=sorted(parts,key=lambda x:x['mean_ms'],reverse=True)[:6])))
