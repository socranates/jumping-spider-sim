"""Retain bounded CreatorOutput evidence, excluding unrelated local log data."""
from pathlib import Path
import argparse,hashlib,json,re
H=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--log',type=Path,required=True);p.add_argument('--out',required=True);p.add_argument('--model',type=Path,required=True);a=p.parse_args()
assert re.fullmatch(r'[a-z0-9-]+',a.out)
raw=a.log.read_text(encoding='utf8',errors='replace')
rows=[s for s in raw.splitlines() if '[FLog::CreatorOutput]' in s and ('[ONLINE_STARTUP_' in s or '[NORMAL_STARTUP_GUARD] 276 bound' in s) and '> assert' not in s]
assert rows
decoder=json.JSONDecoder();events=[]
for line in rows:
 m=re.search(r'\[ONLINE_STARTUP_(\w+)\]\s+(\d+)\s+(\{.*)',line)
 if m:
  value,end=decoder.raw_decode(m[3]);assert m[3][end:].strip() in ('','nil'),line
  events.append(dict(kind=m[1],run=m[2],value=value))
data=('\n'.join(rows)+'\n').encode();textPath=H/(a.out+'.txt');jsonPath=H/(a.out+'.json')
assert not textPath.exists() and not jsonPath.exists()
textPath.write_bytes(data)
sha=lambda v:hashlib.sha256(v).hexdigest()
manifest=a.model/'manifest.json';model=json.loads(manifest.read_text(encoding='utf8'))
assert sha(Path(model['place']).read_bytes())==model['place_sha256']
receipt=dict(events=events,raw_sha256=sha(data),manifest=str(manifest),manifest_sha256=sha(manifest.read_bytes()),
 model_sha256=model['place_sha256'],source_count=model['source_count'],private_targets=model['private_targets'],
 compile_sha256=sha((a.model/'compile.txt').read_bytes()),strict_sha256=sha((a.model/'strict.txt').read_bytes()),
 production_activated=False,published=False)
jsonPath.write_bytes((json.dumps(receipt,indent=2)+'\n').encode())
print(json.dumps(events,indent=2))
