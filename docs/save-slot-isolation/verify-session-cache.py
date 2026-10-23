from pathlib import Path
import hashlib,io,json,re,subprocess,tarfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((HERE/'prepared-session-cache-native-manifest.json').read_text());native=json.loads((HERE/'session-cache-native-receipt.json').read_text());closed=json.loads((HERE/'session-cache-native-close.json').read_text());types=json.loads((HERE/'session-fresh-types.json').read_text())
assert types['candidates']==m['candidates']==native['candidates']
for name,digest in m['candidates'].items():assert sha((HERE/name).read_bytes())==digest,name
raw=subprocess.check_output(['git','archive','--format=tar',m['source'],'roblox_port/src','roblox_port/tests'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:files={row.name:archive.extractfile(row).read() for row in archive if row.isfile()}
baseline=files['roblox_port/src/Shared/Persistence/SaveSession.luau']
for stem,count,test in [('baseline',30,'session-cache-probe.luau'),('candidate',27,'session-cache-probe.luau'),('matrix',150,'session-fresh-matrix.luau')]:
 receipt=json.loads((HERE/('session-cache-'+stem+'-receipt.json')).read_text());output=(HERE/('session-cache-'+stem+'-output.txt')).read_bytes()
 assert receipt['source']==m['source'] and receipt['exit_code']==0
 assert receipt['session_sha256']==(sha(baseline) if stem=='baseline' else m['candidates']['session-fresh-candidate.luau'])
 assert receipt['test_sha256']==sha((HERE/test).read_bytes()) and receipt['output_sha256']==sha(output)
 assert ('passed='+str(count)+' failed=0') in output.decode()
adapter=json.loads((HERE/'session-adapter-receipt.json').read_text())
assert adapter['exit_code']==0 and adapter['session_sha256']==m['candidates']['session-fresh-candidate.luau'] and adapter['backend_sha256']==m['candidates']['fresh-read-backend-candidate.luau']
assert adapter['test_sha256']==sha((HERE/'session-adapter-tests.luau').read_bytes()) and adapter['output_sha256']==sha((HERE/'session-adapter-output.txt').read_bytes())
assert 'SESSION_ADAPTER passed=111 failed=0' in (HERE/'session-adapter-output.txt').read_text()
reg=json.loads((HERE/'session-fresh-regression.json').read_text());assert reg['candidate_sha256']==m['candidates']['session-fresh-candidate.luau'] and len(reg['suites'])==7
total=0
for row in reg['suites']:
 output=(HERE/('session-fresh-regression-'+row['suite']+'.txt')).read_bytes()
 assert row['exit_code']==0 and row['output_sha256']==sha(output) and row['test_sha256']==sha(files['roblox_port/tests/'+row['suite']])
 matches=re.findall(r'passed=(\d+) failed=(\d+)',output.decode());assert len(matches)==1 and matches[0][1]=='0';total+=int(matches[0][0])
assert total==1513
assert len(types['steps'])==4
for step in types['steps']:assert step['exit_code']==0 and sha((HERE/('session-fresh-'+step['name']+'.txt')).read_bytes())==step['output_sha256']
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'};expected={}
for name,data in files.items():
 if not name.startswith('roblox_port/src/'):continue
 parts=list(Path(name).parts[2:]);stem=parts[-1][:-5]
 for suffix in ['.client','.server']:
  if stem.endswith(suffix):stem=stem[:-len(suffix)]
 expected['.'.join([prefix[parts[0]],*parts[1:-1],stem])]=sha(data.replace(b'\r\n',b'\n'))
expected['ReplicatedStorage.Shared.Persistence.SaveSession']=m['candidates']['session-fresh-candidate.luau']
expected['ServerScriptService.Server.DataStoreBackend']=m['candidates']['fresh-read-backend-candidate.luau']
raw=(HERE/'session-native-fixtures.json').read_text().strip();assert sha((HERE/'session-native-fixtures.json').read_bytes())==m['fixtures_sha256']
expected['ServerScriptService.Server.SessionFixtures']=sha(('return game:GetService("HttpService"):JSONDecode([==['+raw+']==])\n').encode())
expected['ServerScriptService.Server.SessionCacheProbe']=sha((HERE/'session-cache-native-probe.server.luau').read_bytes())
assert len(expected)==224 and {row['path']:row['sha256'] for row in m['scripts']}==expected
assert m['production_scripts_disabled'] and native['production_scripts_disabled']
assert [row[0] for row in m['disabled_scripts'] if not row[1]]==['ServerScriptService.Server.SessionCacheProbe']
assert native['source']==m['source'] and native['assertions']==111 and native['scripts']==224 and native['creator_errors']==0
assert sha((HERE/'session-cache-native-output.txt').read_bytes())==native['output_sha256']
assert '[NATIVE_SESSION_CACHE_PASS] '+native['run']+' 111' in (HERE/'session-cache-native-output.txt').read_text()
assert closed['playback_stopped'] and closed['place_closed'] and closed['diagnostic_window_closed'] and closed['prior_window_remained']
assert closed['original_restored_sha256']==m['place_sha256']==native['place_sha256']
r=dict(base_source=m['source'],baseline_counterexample_assertions=30,candidate_assertions=27,matrix_assertions=150,adapter_assertions=111,regression_assertions=1513,regression_suites=7,native_assertions=111,native_scripts=224,creator_errors=0,strict_clean=True,candidates=m['candidates'],real_datastore_verified=False,progress_import_implemented=False,published=False)
(HERE/'session-cache-verification.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
