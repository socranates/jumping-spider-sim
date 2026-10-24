"""Collect one native attempt without discarding failures or widening its scope."""
from pathlib import Path
import argparse,hashlib,json,re,xml.etree.ElementTree as ET
H=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser()
p.add_argument('--model',type=Path,required=True)
p.add_argument('--log',type=Path,required=True)
p.add_argument('--name',required=True)
a=p.parse_args()
assert re.fullmatch(r'[a-z0-9-]+',a.name)
prefix=H/a.name
assert not prefix.with_suffix('.json').exists()
manifest=json.loads((a.model.parent/'manifest.json').read_text(encoding='utf8'))
assert sha(a.model.read_bytes())==manifest['place_sha256']
actual={}
def walk(item,parent=''):
 props=item.find('Properties');name=props.findtext("string[@name='Name']")
 path=parent+'.'+name if parent else name
 code=props.find("*[@name='Source']")
 if code is not None:actual[path]=sha((code.text or '').replace('\r\n','\n').encode())
 for child in item.findall('Item'):walk(child,path)
for item in ET.parse(a.model).getroot().findall('Item'):walk(item)
assert actual==manifest['sources'] and len(actual)==274
lines=a.log.read_text(encoding='utf8',errors='replace').splitlines()
selected=[line for line in lines if '[FLog::CreatorOutput]' in line and (
 '[NORMAL_STARTUP_' in line and '> assert(' not in line or '[Windowsill] saves:' in line)]
guard=[line for line in selected if '[NORMAL_STARTUP_GUARD] 274 unbound memory_only normal_startup_enabled' in line]
terminal=[re.search(r'\[NORMAL_STARTUP_(PASS|FAIL)\]\s+(\d+)\s+(\{.*\})',line) for line in selected]
terminal=[m for m in terminal if m]
assert len(guard)==1 and len(terminal)==1,(len(guard),len(terminal))
kind,run,payload=terminal[0].groups();result=json.loads(payload)
if kind=='PASS':
 assert result['real_storage'] is False
 state=result['snapshot']
 assert state['active']==0 and state['gate']['scopes']==0
 assert state['optionsCreated']==state['optionsDestroyed']
 if manifest['diagnostic_unavailable']:
  assert result['mode']=='no_api' and state['archives']==0 and not state['rests'] and not state['lockReleased']
 else:
  assert result['mode']=='fresh-replace-continue-save'
  assert state['lockReleased'] and state['requests']==state['starts'] and state['rests']
  assert state['archives']==0 and len(state['owners'])==2
output=('\n'.join(selected)+'\n').encode()
prefix.with_suffix('.txt').write_bytes(output)
prefix.with_name(prefix.name+'-manifest.json').write_bytes((a.model.parent/'manifest.json').read_bytes())
receipt=dict(run=run,terminal='passed' if kind=='PASS' else 'failed',result=result,
 model_sha256=manifest['place_sha256'],source_count=len(actual),log=str(a.log),
 output_sha256=sha(output),diagnostic_unavailable=manifest['diagnostic_unavailable'],
 storage='yielding-memory',normal_entrypoints=True,real_storage=False,published=False)
prefix.with_suffix('.json').write_bytes((json.dumps(receipt,indent=2)+'\n').encode())
print(json.dumps(receipt,indent=2))
