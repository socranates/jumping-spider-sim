from pathlib import Path
import hashlib,json,re
HERE=Path(__file__).resolve().parent
LOG=Path(r"C:/Users/natha/AppData/Local/Roblox/logs/0.744.0.7441077_20261022T224520Z_Studio_DB8B9_last.log")
m=json.loads((HERE/'prepared-native-manifest.json').read_text(encoding='utf8'));source=m['source']
lines=LOG.read_text(encoding='utf8').splitlines();guard='[NATIVE_STREAM_READY_GUARD] '+source+' 223 persistence_disabled'
start=[i for i,l in enumerate(lines) if guard in l and ' > ' not in l][-1]
ends=[i for i,l in enumerate(lines) if i>start and '[NATIVE_READINESS_PASS]' in l];assert len(ends)==1,'no unique successful native result'
span=lines[start:ends[0]+1];assert not any('[NATIVE_READINESS_FAIL]' in l or '[FLog::CreatorError]' in l for l in span)
rows=[l.split('[FLog::CreatorOutput] ',1)[1] for l in span if '[FLog::CreatorOutput]' in l and ('[NATIVE_READINESS_' in l or guard in l) and ' > ' not in l]
text='\n'.join(rows)+'\n';run=re.search(r'\[NATIVE_READINESS_PASS\] (\d+) 11',text);assert run
cost=re.search(r'\[NATIVE_READINESS_COST\] '+run[1]+r' 1000 ([\d.]+) ([\d.]+)',text);assert cost
sha=lambda b:hashlib.sha256(b).hexdigest()
(HERE/'native-output.txt').write_text(text,encoding='utf8',newline='\n')
r=dict(source=source,run=run[1],assertions=11,scripts=223,creator_errors=0,persistence_disabled=True,
 output_sha256=sha(text.encode()),place_sha256=m['place_sha256'],gate_calls=1000,gate_cpu_ms=float(cost[1]),max_100_call_chunk_ms=float(cost[2]),
 no_concurrent_cli=True,scope='Locally removed/restored engine instances through real client gate; not naturally induced network stream-out or FPS proof',published=False)
(HERE/'native-receipt.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
