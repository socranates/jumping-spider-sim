from pathlib import Path
import hashlib,io,json,re,subprocess,tarfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
m=json.loads((HERE/'prepared-session-budget-native-manifest.json').read_text());native=json.loads((HERE/'session-budget-native-receipt.json').read_text());closed=json.loads((HERE/'session-budget-native-close.json').read_text());types=json.loads((HERE/'session-budget-yield-types.json').read_text())
assert types['candidates']==m['candidates']==native['candidates']
for name,digest in m['candidates'].items():assert sha((HERE/name).read_bytes())==digest
for stem,count,test in [('yield-controls',82,'session-budget-candidate-tests.luau'),('yield-fixed',44,'session-budget-yield-tests.luau')]:
 r=json.loads((HERE/('session-budget-'+stem+'-receipt.json')).read_text());output=(HERE/('session-budget-'+stem+'-output.txt')).read_bytes()
 assert r['source']==m['source'] and r['exit_code']==0 and r['test_sha256']==sha((HERE/test).read_bytes()) and r['output_sha256']==sha(output)
 assert r['session_sha256']==m['candidates']['session-budget-yield-candidate.luau'] and ('passed='+str(count)+' failed=0') in output.decode()
failed=json.loads((HERE/'session-budget-yield-baseline-receipt.json').read_text())
assert failed['exit_code']!=0 and failed['session_sha256']==sha((HERE/'session-budget-candidate.luau').read_bytes())
assert failed['test_sha256']==sha((HERE/'session-budget-yield-tests.luau').read_bytes()) and failed['output_sha256']==sha((HERE/'session-budget-yield-baseline-output.txt').read_bytes())
assert 'late callback: read/close' in (HERE/'session-budget-yield-baseline-output.txt').read_text()
assert len(types['steps'])==4
for row in types['steps']:assert row['exit_code']==0 and row['output_sha256']==sha((HERE/('session-budget-yield-'+row['name']+'.txt')).read_bytes())
raw=subprocess.check_output(['git','archive','--format=tar',m['source'],'roblox_port/src','roblox_port/tests'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:files={row.name:archive.extractfile(row).read() for row in archive if row.isfile()}
reg=json.loads((HERE/'session-budget-yield-regression.json').read_text());assert reg['candidate_sha256']==m['candidates']['session-budget-yield-candidate.luau'] and len(reg['suites'])==7
total=0
for row in reg['suites']:
 output=(HERE/('session-budget-yield-regression-'+row['suite']+'.txt')).read_bytes()
 assert row['exit_code']==0 and row['test_sha256']==sha(files['roblox_port/tests/'+row['suite']]) and row['output_sha256']==sha(output)
 matches=re.findall(r'passed=(\d+) failed=(\d+)',output.decode());assert len(matches)==1 and matches[0][1]=='0';total+=int(matches[0][0])
assert total==1624
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'};expected={}
for name,data in files.items():
 if not name.startswith('roblox_port/src/'):continue
 parts=list(Path(name).parts[2:]);stem=parts[-1][:-5]
 for suffix in ['.client','.server']:
  if stem.endswith(suffix):stem=stem[:-len(suffix)]
 expected['.'.join([prefix[parts[0]],*parts[1:-1],stem])]=sha(data.replace(b'\r\n',b'\n'))
expected['ReplicatedStorage.Shared.Persistence.SaveSession']=m['candidates']['session-budget-yield-candidate.luau']
assert expected['ServerScriptService.Server.DataStoreBackend']==m['candidates']['fresh-read-backend-candidate.luau']
raw=(HERE/'session-native-fixtures.json').read_text().strip();assert sha((HERE/'session-native-fixtures.json').read_bytes())==m['fixtures_sha256']
expected['ServerScriptService.Server.SessionFixtures']=sha(('return game:GetService("HttpService"):JSONDecode([==['+raw+']==])\n').encode())
expected['ServerScriptService.Server.SessionBudgetProbe']=sha((HERE/'session-budget-native-probe.server.luau').read_bytes())
assert len(expected)==224 and {row['path']:row['sha256'] for row in m['scripts']}==expected
assert [row[0] for row in m['disabled_scripts'] if not row[1]]==['ServerScriptService.Server.SessionBudgetProbe']
assert native['source']==m['source'] and native['assertions']==126 and native['creator_errors']==0 and native['scripts']==224 and native['production_scripts_disabled']
assert native['output_sha256']==sha((HERE/'session-budget-native-output.txt').read_bytes()) and '[NATIVE_SESSION_BUDGET_PASS] '+native['run']+' 126' in (HERE/'session-budget-native-output.txt').read_text()
assert closed['playback_stopped'] and closed['place_closed'] and closed['diagnostic_window_closed'] and closed['prior_window_remained']
assert closed['original_restored_sha256']==m['place_sha256']==native['place_sha256']
initial=json.loads((HERE/'session-budget-native-initial-failure.json').read_text());initialManifest=json.loads((HERE/'prepared-session-budget-native-initial-manifest.json').read_text());initialClose=json.loads((HERE/'session-budget-native-initial-close.json').read_text())
assert initial['candidates']==m['candidates']==initialManifest['candidates'] and initial['status']=='failed-fixture-setup'
assert initial['output_sha256']==sha((HERE/'session-budget-native-initial-failure-output.txt').read_bytes()) and initial['place_sha256']==initialManifest['place_sha256']==initialClose['original_restored_sha256']
r=dict(base_source=m['source'],candidate_sha256=m['candidates']['session-budget-yield-candidate.luau'],focused_assertions=82,yielding_assertions=44,regression_suites=7,regression_assertions=1624,native_assertions=126,native_scripts=224,creator_errors=0,strict_clean=True,production_changed=False,qualified_for_adoption=not (ROOT/'docs/recovery-pacing-gates/initial-adoption-withdrawn.json').exists(),qualification_note='Integrated callback audit supersedes the earlier callback assertion harness; native execution counts do not erase that failure',real_datastore_verified=False,full_game_transport_verified=False,published=False)
(HERE/'session-budget-yield-verification.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
