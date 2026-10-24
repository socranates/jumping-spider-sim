"""Bind the ordinary departure fix to its counterexample, regressions and native runs."""
from pathlib import Path
import argparse,gzip,hashlib,importlib.util,json,re
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
def read(path):return json.loads(path.read_text(encoding='utf8'))
def output(prefix,code):
 r=read(H/(prefix+'-receipt.json'));data=(H/(prefix+'-output.txt')).read_bytes()
 assert r['exit_code']==code and sha(data)==r['output_sha256']
 return r,data.decode()
before,failed=output('ordinary-before-1',1)
assert 'ordinary normal replacement refused' in failed
bundle=gzip.decompress((H/'ordinary-before-1-bundle.luau.gz').read_bytes())
assert sha(bundle)==before['bundle_sha256']
for name in ['docs/request-admission/replacement-owner.luau','docs/normal-startup/ordinary-replacement-tests.luau']:
 assert sha((ROOT/name).read_bytes())==before['inputs'][name]
fixed,text=output('ordinary-candidate-routes-1',0)
assert fixed['candidate'] and fixed['routes'] and 'ACCOUNT_SERVICE passed=1754 failed=0 groups=48' in text
assert len(re.findall(r'^ACCOUNT_SERVICE_CASE\s+ordinary-',text,re.M))==12
full,alltext=output('ordinary-full-1',0)
assert full['candidate'] and full['full'] and full['routes']
for receipt in [fixed,full]:
 for name,digest in receipt['inputs'].items():assert sha((ROOT/name).read_bytes())==digest,name
summaries=lambda s:dict((name,int(count)) for name,count in re.findall(r'^(\w+) passed=(\d+) failed=0',s,re.M))
prior=summaries((H.parent/'request-admission/native-callback-full-1-output.txt').read_text(encoding='utf8'))
current=summaries(alltext)
assert sum(prior.values())==289497 and prior['ACCOUNT_SERVICE']==1466
assert set(prior)==set(current)
assert all(current[k]==v for k,v in prior.items() if k!='ACCOUNT_SERVICE')
assert current['ACCOUNT_SERVICE']==1754 and sum(current.values())==289785
typed=read(H.parent/'request-admission/normal-startup-types-3-types.json')
old=read(H.parent/'request-admission/normal-startup-types-2-types.json')
assert len(typed['mounted'])==54
assert [k for k,v in typed['mounted'].items() if old['mounted'][k]!=v]==['Server/ReplacementOwnerPrototype.luau']
for name,digest in typed['candidates'].items():assert sha((ROOT/name).read_bytes())==digest
for step in typed['steps']:
 assert step['exit_code']==0
 assert sha((H.parent/'request-admission'/('normal-startup-types-3-'+step['name']+'.txt')).read_bytes())==step['sha256']
spec=importlib.util.spec_from_file_location('old_startup_proof',H/'verify.py');v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
models={};runs=[]
for name in ['attempt5-passed','ordinary-ui-attempt6-passed']:
 manifest=read(H/(name+'-manifest.json'));actual=v.model(manifest)
 receipt=read(H/(name+'.json'));data=(H/(name+'.txt')).read_bytes()
 assert sha(data)==receipt['output_sha256'] and receipt['terminal']=='passed'
 found=re.findall(r'\[NORMAL_STARTUP_PASS\]\s+(\d+)\s+(\{.*\})',data.decode());assert len(found)==1
 assert found[0][0]==receipt['run'] and json.loads(found[0][1])==receipt['result']
 expected_checks=19 if name=='attempt5-passed' else 18
 assert receipt['result']['checks']==expected_checks and receipt['result']['mode']=='fresh-replace-continue-save'
 s=receipt['result']['snapshot'];assert s['active']==s['gate']['scopes']==s['gate']['started']==s['gate']['queued']==0
 assert s['requests']==s['starts'] and s['optionsCreated']==s['optionsDestroyed']
 assert s['lockReleased'] and s['archives']==0 and len(s['rests'])==1 and len(s['owners'])==2 and s['owners'][0]['closed']
 assert actual['ServerScriptService.Server.ReplacementOwnerPrototype']==typed['mounted']['Server/ReplacementOwnerPrototype.luau']
 models[name]=actual;runs.append(dict(run=receipt['run'],checks=expected_checks,starts=s['starts'],options=s['optionsDestroyed'],model_sha256=manifest['place_sha256']))
oldmodel=read(H/'attempt4-failed-manifest.json')['sources'];newmodel=models['attempt5-passed']
assert set(oldmodel)==set(newmodel)
assert [k for k in newmodel if newmodel[k]!=oldmodel[k]]==['ServerScriptService.Server.ReplacementOwnerPrototype']
ordinary=models['ordinary-ui-attempt6-passed']
assert 'StarterPlayer.StarterPlayerScripts.Client.SilkPlayback' not in ordinary
assert ordinary['StarterPlayer.StarterPlayerScripts.Client.NormalStartupObserver']==sha((H/'playback.luau').read_bytes())
assert read(H/'ordinary-ui-attempt6-passed-manifest.json')['ordinary_ui'] is True
noapi=read(H/'ordinary-ui-noapi-attempt6-passed.json')
manifest=read(H/'ordinary-ui-noapi-attempt6-passed-manifest.json');noapi_sources=v.model(manifest)
assert manifest['ordinary_ui'] and manifest['diagnostic_unavailable'] and noapi_sources==ordinary
data=(H/'ordinary-ui-noapi-attempt6-passed.txt').read_bytes()
assert sha(data)==noapi['output_sha256'] and noapi['terminal']=='passed'
found=re.findall(r'\[NORMAL_STARTUP_PASS\]\s+(\d+)\s+(\{.*\})',data.decode());assert len(found)==1
assert found[0][0]==noapi['run'] and json.loads(found[0][1])==noapi['result']
result=noapi['result'];s=result['snapshot'];assert result['checks']==10 and result['mode']=='no_api'
assert s['active']==s['gate']['scopes']==s['gate']['queued']==s['gate']['started']==0
assert not s['rests'] and s['archives']==0 and not s['lockReleased'] and s['requests']==s['starts']
assert s['optionsCreated']==s['optionsDestroyed']
result=dict(full_checks=289785,full_failures=0,service_checks=1754,service_cases=48,new_cases=12,
 new_case_checks=288,changed_target='Server/ReplacementOwnerPrototype.luau',
 candidate_sha256=sha((H/'ordinary-replacement-owner.luau').read_bytes()),native_runs=runs,
 no_api_run=dict(run=noapi['run'],checks=10,starts=s['starts'],options=s['optionsDestroyed']),
 storage='yielding-memory',real_storage_verified=False,legacy_startup_verified=False,
 production_activated=False,published=False,optimization_goal_complete=False)
path=H/'ordinary-qualification.json'
if a.check:assert read(path)==result
else:assert not path.exists();path.write_bytes((json.dumps(result,indent=2)+'\n').encode())
print(json.dumps(result,indent=2))
