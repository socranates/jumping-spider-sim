"""Retain only the menu measurement events from one specified Studio log."""
from pathlib import Path
import argparse,hashlib,json,re
H=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--log',type=Path,required=True);p.add_argument('--check',action='store_true');a=p.parse_args()
raw=a.log.read_bytes();rows=[];events={};before=[]
for line in raw.decode('utf8',errors='replace').splitlines():
 if '[FLog::CreatorOutput]'not in line:continue
 old=re.search(r'\[MENU_LAYOUT\]\s+(\{.*\})$',line)
 item=re.search(r'\[MENU_NATIVE_(SAMPLE|END)\]\s+(\d+)\s+(\{.*\})$',line)
 if old:before.append(json.loads(old[1]));rows.append(line)
 if item:
  events.setdefault(item[2],[]).append(dict(kind=item[1],run=item[2],value=json.loads(item[3])));rows.append(line)
assert len(before)==1 and len(events)==2 and len(rows)==9
copied=json.loads((H/'before-bounds.json').read_text())
assert all(copied[k]==v for k,v in before[0].items())
for file in ['native-short.json','native-regular.json']:
 captured=json.loads((H/file).read_text())['events'];assert events[captured[0]['run']]==captured
data=('\n'.join(rows)+'\n').encode();sha=lambda b:hashlib.sha256(b).hexdigest()
record=dict(log_sha256=sha(raw),output_sha256=sha(data),before=before[0],events=events,
 scope='Only nine menu geometry events retained; unrelated account/network/client log data excluded')
text=H/'native-output.txt';target=H/'native-log.json'
if a.check:
 assert text.read_bytes()==data and json.loads(target.read_text())==record
else:
 assert not text.exists()and not target.exists();text.write_bytes(data);target.write_bytes((json.dumps(record,indent=2)+'\n').encode())
print('Native geometry log independently matches both UI captures and the original clipping measurement')
