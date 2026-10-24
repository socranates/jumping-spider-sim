"""Collect only the isolated rig fixture; reject missing guards or comparisons."""
from pathlib import Path
import hashlib,json,re
H=Path(__file__).resolve().parent
stage=Path('C:/Users/natha/claude-xfer/Windowsill-rig-hair-native1')
log=Path('C:/Users/natha/AppData/Local/Roblox/logs/0.744.0.7441077_20261024T115926Z_Studio_C6C23_last.log')
sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((stage/'manifest.json').read_text())
assert m['rig_hair_checks'] and m['source_count']==278 and not m['published']
assert sha(Path(m['place']).read_bytes())==m['place_sha256']
assert sha((stage/'guard.luau').read_bytes())==m['guard_sha256']
lines=log.read_text(encoding='utf8').splitlines()
kept=[x for x in lines if any(s in x for s in ['[MATRIX_','[RIG_HAIR_NATIVE_','[FLog::CreatorError]','[FLog::CreatorWarning]'])]
guards=[x for x in kept if '[MATRIX_GUARD] 278 after full unbound memory_only'in x]
checks=[];results=[];passes=[]
for line in kept:
 for tag,rows in [('RIG_HAIR_NATIVE_CHECK',checks),('RIG_HAIR_NATIVE_RESULT',results)]:
  if '['+tag+']'in line:
   found=re.search(r'\['+tag+r'\]\s+(\{.*\})$',line)
   assert found,'Malformed native JSON'
   rows.append(json.loads(found[1]))
 if '[MATRIX_FRAME_PASS]'in line:passes.append(line)
errors=[x for x in kept if '[FLog::CreatorError]'in x]
assert len(guards)==2 and len(passes)==1 and not errors
assert len(results)==1 and results[0]['passed']==28 and results[0]['failed']==0
assert len(checks)==28 and all(x['ok']for x in checks)
r=results[0]['metrics']
assert r['cases']==14 and r['frames']==560 and r['parts']==143800
assert r['worstPosition']<2e-5 and r['worstAxis']<2e-4 and r['worstSize']<1e-6
raw=('\n'.join(kept)+'\n').encode()
(H/'native-output.txt').write_bytes(raw)
record=dict(passed=True,source_count=278,source_guards=2,creator_errors=0,
 model_sha256=m['place_sha256'],manifest_sha256=sha((stage/'manifest.json').read_bytes()),
 native_output_sha256=sha(raw),result=results[0],original_log=str(log),
 run=re.search(r'\[MATRIX_FRAME_PASS\]\s+(\d+)',passes[0])[1],
 warnings=[x for x in kept if '[FLog::CreatorWarning]'in x],
 limits='Isolated old/new native geometry fixture. Profiler interaction follows PASS. No paired FPS, dedicated server, physical phone, whole-map or production save qualification.')
(H/'native.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps(record))
