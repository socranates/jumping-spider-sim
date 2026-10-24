"""Bind legacy startup qualification to exact source, counterexamples and native behavior."""
from pathlib import Path
import argparse,gzip,hashlib,importlib.util,json,re,subprocess,sys
H=Path(__file__).resolve().parent;ROOT=H.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
def read(path):return json.loads(path.read_text(encoding='utf8'))
def output(prefix,code):
 r=read(H/(prefix+'-receipt.json'));data=(H/(prefix+'-output.txt')).read_bytes()
 assert r['exit_code']==code and sha(data)==r['output_sha256']
 return r,data.decode()
subprocess.run([sys.executable,str(H/'prepare-legacy.py'),'--check'],check=True)
for prefix,flag in [('legacy-before-policy-1','before_policy'),('legacy-before-flag-1','before_flag')]:
 r,text=output(prefix,1);assert r[flag] and 'protected recorded-world offer was rejected by actual continuation' in text
 assert sha(gzip.decompress((H/(prefix+'-bundle.luau.gz')).read_bytes()))==r['bundle_sha256']
 assert r['inputs']['docs/normal-startup/legacy-validation-tests.luau']==sha((H/'legacy-validation-tests-attempt1.luau').read_bytes())
fixed,text=output('legacy-fixed-2',0)
assert not fixed['before_flag'] and not fixed['before_policy'] and 'ACCOUNT_SERVICE passed=36 failed=0 groups=3' in text
assert len(re.findall(r'^ACCOUNT_SERVICE_CASE\s+legacy-incoming-',text,re.M))==3
full,alltext=output('legacy-full-1',0);assert full['full']
for r in [fixed,full]:
 for name,digest in r['inputs'].items():assert sha((ROOT/name).read_bytes())==digest,name
summaries=lambda s:dict((name,int(n)) for name,n in re.findall(r'^(\w+) passed=(\d+) failed=0',s,re.M))
prior=summaries((H/'ordinary-full-1-output.txt').read_text(encoding='utf8'));current=summaries(alltext)
assert sum(prior.values())==289785 and prior['ACCOUNT_SERVICE']==1754
assert set(prior)==set(current) and all(current[k]==v for k,v in prior.items() if k!='ACCOUNT_SERVICE')
assert current['ACCOUNT_SERVICE']==1790 and sum(current.values())==289821
typed=read(H.parent/'request-admission/normal-startup-types-4-types.json');old=read(H.parent/'request-admission/normal-startup-types-3-types.json')
assert len(typed['mounted'])==56
assert set(typed['mounted'])-set(old['mounted'])=={'Client/SaveContinuation.luau','Client/RecoveryOfferValidation.luau'}
assert [k for k,v in old['mounted'].items() if typed['mounted'][k]!=v]==['Client/SpiderClient.client.luau']
for name,digest in typed['candidates'].items():assert sha((ROOT/name).read_bytes())==digest
for step in typed['steps']:
 assert step['exit_code']==0 and sha((H.parent/'request-admission'/('normal-startup-types-4-'+step['name']+'.txt')).read_bytes())==step['sha256']
spec=importlib.util.spec_from_file_location('retained_startup_model',H/'verify.py');v=importlib.util.module_from_spec(spec);spec.loader.exec_module(v)
manifest=read(H/'legacy-native-attempt4-passed-manifest.json');actual=v.model(manifest)
earlier=read(H/'legacy-native-attempt2-failed-manifest.json')
assert set(actual)==set(earlier['sources'])
assert set(k for k in actual if actual[k]!=earlier['sources'][k])=={'StarterPlayer.StarterPlayerScripts.Client.NormalStartupObserver','ServerScriptService.Server.NormalStartupDiagnosticStorage','ServerScriptService.Server.NormalStartupLegacySeed'}
assert manifest['source_count']==276 and manifest['private_targets']==56 and manifest['ordinary_ui'] and manifest['legacy_seeded']
assert actual['StarterPlayer.StarterPlayerScripts.Client.SaveContinuation']==sha((H/'continuation-legacy.luau').read_bytes())
assert actual['StarterPlayer.StarterPlayerScripts.Client.RecoveryOfferValidation']==sha((H/'offer-validation.luau').read_bytes())
assert actual['StarterPlayer.StarterPlayerScripts.Client.NormalStartupObserver']==sha((H/'legacy-playback.luau').read_bytes())
receipt=read(H/'legacy-native-attempt4-passed.json');data=(H/'legacy-native-attempt4-passed.txt').read_bytes()
assert receipt['terminal']=='passed' and sha(data)==receipt['output_sha256']
supplement=receipt['supplement'];ui=(H/supplement['path']).read_bytes();raw=(H/'legacy-native-attempt4-passed-raw-log.txt').read_bytes()
assert sha(ui)==supplement['sha256'] and sha(raw)==supplement['raw_log_sha256']
cut=re.search(r'\[LEGACY_STARTUP_PASS\]\s+(\d+)\s+(\{[^\n]*)',raw.decode());assert cut
full_ui=re.search(r'\[LEGACY_STARTUP_PASS\]\s+(\d+)\s+(\{.*\})',ui.decode());assert full_ui
assert cut[1]==full_ui[1] and full_ui[2].startswith(cut[2]) and not cut[2].endswith('}')
found=re.findall(r'\[LEGACY_STARTUP_PASS\]\s+(\d+)\s+(\{.*\})',data.decode());assert len(found)==1
assert found[0][0]==receipt['run'] and json.loads(found[0][1])==receipt['result']
result=receipt['result'];s=result['snapshot']
assert result['checks']==47 and result['ordinary_ui'] and not result['real_storage']
assert all(s['originalExact'][mode] for mode in ['main','free','easy']) and s['archives']==8 and s['archiveComplete']
assert s['active']==s['gate']['scopes']==s['gate']['queued']==s['gate']['started']==0 and s['lockReleased']
assert s['requests']==s['starts'] and s['optionsCreated']==s['optionsDestroyed'] and all(o['closed'] for o in s['owners'])
modes=[json.loads(row) for row in re.findall(r'\[LEGACY_STARTUP_MODE\]\s+\d+\s+(\{.*\})',data.decode())]
assert [m['mode'] for m in modes]==['main','free','easy'] and all(m['stage']==1 and m['food']==.25 for m in modes)
qualified=dict(full_checks=289821,full_failures=0,legacy_checks=36,legacy_modes=3,typed_targets=56,
 native_run=receipt['run'],native_checks=result['checks'],backend_starts=s['starts'],options_destroyed=s['optionsDestroyed'],
 original_archives_exact=True,ordinary_ui=True,closed_owners=len(s['owners']),storage='yielding-memory',
 source_only_change_from_failed_native='diagnostic readiness, archive namespace and publication checks',
 studio_output_supplement_bound=True,real_storage_verified=False,published=False,goal_complete=False)
path=H/'legacy-qualification.json'
if a.check:assert read(path)==qualified
else:assert not path.exists();path.write_bytes((json.dumps(qualified,indent=2)+'\n').encode())
print(json.dumps(qualified,indent=2))
