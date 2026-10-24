"""Verify the one-source correction, complete targeted cohort and native bounds."""
from pathlib import Path
import argparse, hashlib, json, re, subprocess, sys, xml.etree.ElementTree as ET
H=Path(__file__).resolve().parent; ROOT=H.parents[1]; sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
base=Path('C:/Users/natha/claude-xfer/Windowsill-integrated-attempt3')
clean=Path('C:/Users/natha/claude-xfer/Windowsill-menu-overflow-attempt1')
player=Path('C:/Users/natha/claude-xfer/Windowsill-menu-player-attempt1')
inputs={}
def bind(path): inputs[path.relative_to(ROOT).as_posix()]=sha(path.read_bytes())
subprocess.run([sys.executable,str(H/'prepare.py'),'--check'],check=True)
def model(folder):
 m=json.loads((folder/'manifest.json').read_text());assert sha(Path(m['place']).read_bytes())==m['place_sha256']
 actual={}
 def walk(node,parent=''):
  props=node.find('Properties');name=props.findtext("string[@name='Name']");path=parent+'.'+name if parent else name
  source=props.find("*[@name='Source']")
  if source is not None: actual[path]=sha((source.text or '').replace('\r\n','\n').encode())
  if node.attrib['class'] in ['Script','LocalScript']:assert props.findtext("bool[@name='Disabled']")!='true'
  for child in node.findall('Item'):walk(child,path)
 for node in ET.parse(m['place']).getroot().findall('Item'):walk(node)
 assert actual==m['sources'] and sha((folder/'guard.luau').read_bytes())==m['guard_sha256']
 assert 'TypeError:' not in (folder/'strict.txt').read_text()
 return m
old=model(base);new=model(clean);test=model(player)
key='StarterPlayer.StarterPlayerScripts.Client.CaughtPanel'
assert set(old['sources'])==set(new['sources']) and len(new['sources'])==273
assert [k for k in old['sources'] if old['sources'][k]!=new['sources'][k]]==[key]
assert new['sources'][key]==sha((H/'caught-panel.luau').read_bytes())
assert (clean/'compile.txt').read_text().strip()=='compile 273/273'
assert len(new['overlays'])==58 and all(new['overlays'][k]==v for k,v in old['overlays'].items())
assert len(test['sources'])==274 and test['universe']==10771634917 and test['place_id']==109879630247781
assert test['candidate_manifest_sha256']==sha((clean/'manifest.json').read_bytes())
assert {k:v for k,v in test['sources'].items()if k!='ReplicatedFirst.PlayerArrivalProbe'}==new['sources']
assert test['readonly_probe_sha256']==sha((ROOT/'docs/integrated-release/player-probe.client.luau').read_bytes())
config=json.loads((player/'player-test.project.json').read_text())
assert config['servePlaceIds']==[109879630247781]
assert config['tree']['Workspace']['$attributes']=={'World':'preserve','SelfTest':False,'TestTarget':False,'SaveWait':True,'SaveStore':'WindowsillTest_player57_20261023a1'}
assert config['tree']['ServerScriptService']['PortTests']=={'$className':'Folder','$ignoreUnknownInstances':False}
run_path=ROOT/'docs/integrated-release/menu1-receipt.json';bind(run_path);run=json.loads(run_path.read_text())
base_run=json.loads((ROOT/'docs/integrated-release/full2-receipt.json').read_text())
assert run['all_passed'] and len(run['results'])==8
assert run['requested']==['menu_overflow.luau','title.luau','hud.luau','continuation_menu.luau','recovery_application.luau','settings.luau','client_smoke.luau','client_mating.luau']
assert [row['suite']for row in run['results']]==run['requested'] and not run['full']
assert run['module_aliases']==base_run['module_aliases']
assert run['test_inputs']=={**base_run['test_inputs'],'menu_overflow.luau':sha((H/'menu_overflow.luau').read_bytes())}
assert run['runner_sha256']==sha((ROOT/'docs/integrated-release/run-cli.py').read_bytes())
assert run['inputs']=={f.relative_to(clean/'roblox_port/src').as_posix():sha(f.read_bytes())for f in (clean/'roblox_port/src').rglob('*.luau')}
total=0
for row in run['results']:
 path=ROOT/'docs/integrated-release'/row['output'];bind(path)
 assert row['exit_code']==0 and sha(path.read_bytes())==row['output_sha256']
 counts=re.findall(r'passed=(\d+) failed=(\d+)',path.read_text());assert counts and all(int(f)==0 for _,f in counts)
 total+=sum(int(n)for n,_ in counts)
assert total==1427
before=json.loads((H/'before-bounds.json').read_text());assert before['lineTop']<before['boxTop'] and before['canvasY']==0
log=json.loads((H/'native-log.json').read_text())
assert sha((H/'native-output.txt').read_bytes())==log['output_sha256']
assert all(before[k]==v for k,v in log['before'].items())
native=[]
for name in ['native-short.json','native-regular.json']:
 data=json.loads((H/name).read_text());events=data['events'];ends=[e for e in events if e['kind']=='END']
 assert events==log['events'][events[0]['run']]
 assert len(events)==4 and len(ends)==1 and ends[0]['value']=={'ok':True,'restored':True,'problem':''}
 rows=[e['value']for e in events if e['kind']=='SAMPLE'];assert [r['bounds']['name']for r in rows]==['normal','large','restored']
 for row in rows:
  b=row['bounds'];assert b['alignment']=='Enum.VerticalAlignment.Top' and b['canvas']==0
  assert b['line_top']>=b['box_top']-.5 and abs(row['footer_bottom']-row['visible_bottom'])<=.5
 assert rows[1]['bounds']['content']>rows[0]['bounds']['content'] and rows[2]['bounds']['content']==rows[0]['bounds']['content']
 assert [r['bounds']['text_size']for r in rows]==[58,72,58]
 native.append(dict(run=events[0]['run'],window=rows[0]['bounds']['window'],cases=3))
assert native[0]['window']<200 and 320<native[1]['window']<340
editor=json.loads((H/'editor-check.json').read_text())
assert editor['guard_sha256']==test['guard_sha256'] and editor['source_count']==274
assert sha(Path(editor['saved_editor']).read_bytes())==editor['saved_editor_sha256']
assert not editor['uploaded'] and not editor['published']
for f in H.iterdir():
 if f.is_file() and f.name!='qualification.json':bind(f)
result=dict(inputs=inputs,changed_game_source=key,game_sources=273,targeted_suites=8,passed=total,failed=0,native=native,
 clean_place_sha256=new['place_sha256'],player_place_sha256=test['place_sha256'],
 clean_manifest_sha256=sha((clean/'manifest.json').read_bytes()),player_manifest_sha256=sha((player/'manifest.json').read_bytes()),
 production_activated=False,published=False,standalone_player_tested=False,goal_complete=False)
target=H/'qualification.json'
if a.check:assert json.loads(target.read_text())==result
else:assert not target.exists();target.write_bytes((json.dumps(result,indent=2)+'\n').encode())
print('Menu fix verified: one game source, 1427 targeted passes, six real native reflow/scroll cases')
