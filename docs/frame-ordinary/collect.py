"""Collect bounded exact native profiler output; fail on any truncated JSON."""
from pathlib import Path
import argparse,hashlib,json,re
H=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--log',type=Path,required=True);p.add_argument('--model',type=Path,required=True);p.add_argument('--out',required=True);a=p.parse_args()
assert re.fullmatch(r'[a-z0-9-]+',a.out)
raw=a.log.read_text(encoding='utf8',errors='replace');rows=[];events=[];server=[]
for line in raw.splitlines():
 if '[FLog::CreatorOutput]' not in line:continue
 sm=re.search(r'\[ORDINARY_SERVER_MARK\]\s+(\{.*)$',line)
 if sm:server.append(json.loads(sm[1]));rows.append(line);continue
 m=re.search(r'\[ORDINARY_FRAME_(\w+)\]\s+(\d+)\s+(\{.*)$',line)
 if not m:continue
 value=json.loads(m[3]);events.append(dict(kind=m[1],run=m[2],value=value));rows.append(line)
assert events and len({x['run']for x in events})==1
manifest=a.model/'manifest.json';model=json.loads(manifest.read_text(encoding='utf8'));sha=lambda b:hashlib.sha256(b).hexdigest()
assert sha(Path(model['place']).read_bytes())==model['place_sha256']
text=('\n'.join(rows)+'\n').encode();txt=H/(a.out+'-output.txt');receipt=H/(a.out+'-receipt.json')
assert not txt.exists() and not receipt.exists();txt.write_bytes(text)
complete=any(x['kind']=='PASS'for x in events) and not any(x['kind']=='FAIL'for x in events)
ends={x['value']['sample']:x['value']for x in events if x['kind']=='END'}
complete=complete and set(ends)=={'client-startup','startup-to-menu','home','garden_a1-arrival','garden_a1','pond_a1-arrival','pond_a1'}
for key in ['home','garden_a1','pond_a1']:
 if key not in ends:continue
 s=ends[key];complete=complete and s['frames']>1000 and s['extra']['simulation_seconds']>=29.9 and not s['extra']['ended'] and not s['extra']['loading']
for key in ['garden_a1-arrival','pond_a1-arrival']:
 if key in ends:complete=complete and ends[key]['frames']>0
data=dict(run=events[0]['run'],complete=complete,events=events,server_marks=server,output_sha256=sha(text),model=str(a.model),manifest_sha256=sha(manifest.read_bytes()),
 model_sha256=model['place_sha256'],source_count=model['source_count'],production_activated=False,published=False)
receipt.write_bytes((json.dumps(data,indent=2)+'\n').encode())
print(json.dumps(dict(run=data['run'],complete=complete,samples={name:{k:s[k]for k in ['frames','seconds','worst_ms','over50','render_mean_ms','render_worst_ms']}for name,s in ends.items()}),indent=2))
