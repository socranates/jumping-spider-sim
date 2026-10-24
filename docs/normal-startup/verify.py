"""Verify retained startup/frame evidence and exact local diagnostic models."""
from pathlib import Path
import hashlib,json,re,xml.etree.ElementTree as ET
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
sha=lambda b:hashlib.sha256(b).hexdigest()
def read(path):return json.loads(path.read_text(encoding='utf8'))
def model(manifest):
 path=Path(manifest['place']);assert sha(path.read_bytes())==manifest['place_sha256']
 actual={}
 def walk(item,parent=''):
  props=item.find('Properties');name=props.findtext("string[@name='Name']")
  key=parent+'.'+name if parent else name;source=props.find("*[@name='Source']")
  if source is not None:actual[key]=sha((source.text or '').replace('\r\n','\n').encode())
  for child in item.findall('Item'):walk(child,key)
 for item in ET.parse(path).getroot().findall('Item'):walk(item)
 assert actual==manifest['sources'] and len(actual)==manifest['source_count']
 assert sha((path.parent/'guard.luau').read_bytes())==manifest['guard_sha256']
 assert manifest['published'] is False
 return actual

typed=read(H.parent/'request-admission/normal-startup-types-2-types.json')
assert len(typed['mounted'])==54
for path,digest in typed['candidates'].items():assert sha((ROOT/path).read_bytes())==digest,path
for step in typed['steps']:
 path=H.parent/'request-admission'/('normal-startup-types-2-'+step['name']+'.txt')
 assert step['exit_code']==0 and sha(path.read_bytes())==step['sha256']
for name,expected in [('attempt4-failed','FAIL'),('noapi-attempt4-passed','PASS')]:
 receipt=read(H/(name+'.json'));manifest=read(H/(name+'-manifest.json'))
 actual=model(manifest);data=(H/(name+'.txt')).read_bytes()
 assert sha(data)==receipt['output_sha256']
 found=re.findall(r'\[NORMAL_STARTUP_(PASS|FAIL)\]\s+(\d+)\s+(\{.*\})',data.decode())
 assert len(found)==1 and found[0][0]==expected and found[0][1]==receipt['run']
 assert json.loads(found[0][2])==receipt['result']
 assert actual['StarterPlayer.StarterPlayerScripts.Client.SilkPlayback']==sha((H/'playback.luau').read_bytes())
 assert receipt['model_sha256']==manifest['place_sha256'] and receipt['real_storage'] is False
 if expected=='PASS':
  result=receipt['result'];s=result['snapshot']
  assert result['checks']==11 and result['mode']=='no_api' and manifest['diagnostic_unavailable']
  assert s['active']==0 and s['gate']['scopes']==s['gate']['queued']==s['gate']['started']==0
  assert s['optionsCreated']==s['optionsDestroyed']==3 and s['requests']==s['starts']==4
  assert not s['rests'] and s['archives']==0 and not s['lockReleased']
 else:
  assert receipt['result']['checks']==11 and not manifest['diagnostic_unavailable']
  assert ':65' in receipt['result']['problem']
inspection=(H/'attempt4-inspection.txt').read_text(encoding='utf8')
state=json.loads(inspection.split('[NORMAL_STARTUP_INSPECT] ',1)[1])
assert state['phase']=='normal' and state['active']==0 and state['gate']['scopes']==1
assert state['requests']==state['starts']==16 and state['optionsCreated']==state['optionsDestroyed']==7
assert len(state['owners'])==1 and len(state['rests'])==1 and state['archives']==0
for number in (1,2):
 folder=H.parent/'frame-startup-native';manifest=read(folder/f'prepared-attempt{number}.json')
 actual=model(manifest);receipt=read(folder/f'attempt{number}-receipt.json')
 data=(folder/f'attempt{number}-output.txt').read_bytes()
 assert sha(data)==receipt['output_sha256'] and receipt['model_sha256']==manifest['place_sha256']
 assert len(actual)==225 and manifest['storage_disabled'] is True
 ends={}
 for run,payload in re.findall(r'\[STARTUP_FRAME_END\]\s+(\d+)\s+(\{.*\})',data.decode()):
  assert run==receipt['run'];row=json.loads(payload);ends[row['name']]=row
 if number==2:
  assert set(ends)=={'startup','main-home','garden'} and ends==receipt['scenes']
  assert ends['main-home']['over_50ms']==0 and ends['garden']['over_50ms']==1
  assert ends['startup']['worst_ms']>1800 and receipt['representative_fps_proved'] is False
 else:assert receipt['terminal']=='partial' and 'garden' not in ends
print('Retained v2 type inputs, original startup attempts and two frame models verified; this checks their historical scope only.')
