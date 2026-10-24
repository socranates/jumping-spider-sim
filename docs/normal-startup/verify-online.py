"""Independently qualify two ordinary online startup receipts; never writes data."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,re,subprocess,sys
H=Path(__file__).resolve().parent;ROOT=H.parents[1]
sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--first');p.add_argument('--rejoin');p.add_argument('--check',action='store_true');a=p.parse_args()
target=H/'online-qualification.json'
if a.check:
 old=json.loads(target.read_text(encoding='utf8'));names=old['receipts']
else:
 assert a.first and a.rejoin and not target.exists();names=[a.first,a.rejoin]
subprocess.run([sys.executable,str(H/'prepare-online.py'),'--check'],check=True)
subprocess.run([sys.executable,str(H/'qualify-legacy.py'),'--check'],check=True,capture_output=True)
spec=importlib.util.spec_from_file_location('online_checked_sources',H/'check-legacy.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
paths=m.checker.paths();typed=json.loads((H.parent/'request-admission'/'normal-startup-types-4-types.json').read_text(encoding='utf8'))
results=[];manifests=[];inputs={}
for name,rejoining in zip(names,[False,True]):
 assert re.fullmatch(r'[a-z0-9-]+',name)
 file=H/(name+'.json');receipt=json.loads(file.read_text(encoding='utf8'));raw=(H/(name+'.txt')).read_bytes()
 assert sha(raw)==receipt['raw_sha256'];inputs[file.relative_to(ROOT).as_posix()]=sha(file.read_bytes());inputs[(H/(name+'.txt')).relative_to(ROOT).as_posix()]=sha(raw)
 modelFolder=Path(receipt['manifest']).parent;manifest=json.loads(Path(receipt['manifest']).read_text(encoding='utf8'));manifests.append(manifest)
 assert sha(Path(receipt['manifest']).read_bytes())==receipt['manifest_sha256']
 assert sha(Path(manifest['place']).read_bytes())==manifest['place_sha256']==receipt['model_sha256']
 assert manifest['source_count']==276 and manifest['private_targets']==56 and not manifest['published']
 assert (manifest['universe'],manifest['place_id'],manifest['synthetic_user'])==(10771634917,109879630247781,'qa_s_74c52a1d98ef430b')
 for key in ['compile','strict']:assert sha((modelFolder/(key+'.txt')).read_bytes())==receipt[key+'_sha256']
 assert (modelFolder/'compile.txt').read_text(encoding='utf8').strip()=='compile 276/276'
 assert 'TypeError:' not in (modelFolder/'strict.txt').read_text(encoding='utf8')
 actual={}
 prefixes={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'}
 for file2 in (modelFolder/'src').rglob('*.luau'):
  rel=file2.relative_to(modelFolder/'src');parts=rel.parts;leaf=parts[-1][:-5].removesuffix('.server').removesuffix('.client')
  key='.'.join([prefixes[parts[0]],*parts[1:-1],leaf]);actual[key]=sha(file2.read_bytes().replace(b'\r\n',b'\n'))
 assert actual==manifest['sources']
 for rel,path in paths.items():
  code=path.read_text(encoding='utf8')
  if path.name in ('worker-v3.luau','operation.luau'):code=code.replace('require("./worker-facade")','require(script.Parent.RequestAdmissionFacade)')
  assert sha(code.encode())==typed['mounted'][rel]
  if rel not in ['Server/Persistence.server.luau','Client/SpiderClient.client.luau']:assert (modelFolder/'src'/rel).read_bytes()==code.encode()
 for rel,source in [('Server/NormalStartupDiagnosticStorage.luau','online-storage.luau'),('Server/NormalStartupLegacySeed.luau','online-seed.luau'),('Client/NormalStartupObserver.luau','online-playback.luau')]:
  assert (modelFolder/'src'/rel).read_bytes()==(H/source).read_bytes()
 assert sha((modelFolder/'guard.luau').read_bytes())==manifest['guard_sha256']
 assert 'legacy runner still enabled' in (modelFolder/'guard.luau').read_text(encoding='utf8')
 events=receipt['events'];boots=[x for x in events if x['kind']=='BOOTSTRAP' and x['value']['user']==manifest['synthetic_user']]
 assert len(boots)==1 and boots[0]['value']['rejoining']==rejoining
 boot=boots[0];begin=events.index(boot);events=events[begin:]
 assert not any(x['kind']=='FAIL' for x in events)
 ends=[x for x in events if x['kind']=='DEPARTURE_PASS'];clients=[x for x in events if x['kind']=='CLIENT_PASS']
 assert len(ends)==len(clients)==1 and ends[0]['run']==boot['run']
 end=ends[0]['value'];client=clients[0]['value']
 assert end['user']==client['user']==manifest['synthetic_user'] and end['rejoining']==client['rejoining']==rejoining
 assert end['state']==('done' if rejoining else 'await_rejoin')
 assert end['actual_removals']==1 and end['scopes']==0 and end['lock_released'] and end['optionsCreated']==end['optionsDestroyed']
 assert client['ordinary_ui'] and client['real_storage']
 modes=[x['value'] for x in events if x['kind']=='MODE'];assert [x['mode'] for x in modes]==(['main'] if rejoining else ['main','free','easy'])
 assert all(x['stage']==1 and x['food']==.25 for x in modes)
 results.append(dict(run=boot['run'],client_run=clients[0]['run'],client_checks=client['checks'],server_checks=end['checks'],starts=end['starts'],options_destroyed=end['optionsDestroyed'],state=end['state'],actual_removals=1,modes=[x['mode']for x in modes]))
assert manifests[0]==manifests[1],'rejoin must use identical model/source manifest'
for name in ['online-storage.luau','online-playback.luau','online-seed.luau','prepare-online.py','build-online.py','collect-online.py']:
 inputs[(H/name).relative_to(ROOT).as_posix()]=sha((H/name).read_bytes())
qualification=dict(receipts=names,inputs=inputs,runs=results,model_sha256=manifests[0]['place_sha256'],typed_targets=56,source_count=276,
 storage='real WindowsillTest_v1',ordinary_startup=True,legacy_progress_preserved=True,current_schema3_rejoin=True,exact_archives=True,
 actual_departures=2,terminal_control='done',production_activated=False,published=False,goal_complete=False)
if a.check:assert qualification==old;print('Ordinary online startup and fresh-process schema3 rejoin evidence verified')
else:target.write_bytes((json.dumps(qualification,indent=2)+'\n').encode());print(json.dumps(qualification['runs'],indent=2))
