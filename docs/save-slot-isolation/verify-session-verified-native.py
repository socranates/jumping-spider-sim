from pathlib import Path
import hashlib,io,json,runpy,subprocess,tarfile
HERE=Path(__file__).resolve().parent;ROOT=HERE.parents[1];sha=lambda b:hashlib.sha256(b).hexdigest()
runpy.run_path(str(HERE/'verify-session-verified.py'))
cli=json.loads((HERE/'session-verified-qualification.json').read_text());m=json.loads((HERE/'prepared-session-verified-native-manifest.json').read_text());native=json.loads((HERE/'session-verified-native-receipt.json').read_text());closed=json.loads((HERE/'session-verified-native-close.json').read_text());types=json.loads((HERE/'session-budget-verified-types.json').read_text())
assert types['candidates']==m['candidates']==native['candidates'] and cli['candidate_sha256']==m['candidates']['session-budget-verified-candidate.luau']
for name,digest in m['candidates'].items():assert sha((HERE/name).read_bytes())==digest
probe=(HERE/'session-verified-native-probe.server.luau').read_text()
assert (HERE/'session-budget-checked-tests.luau').read_text() in probe and (HERE/'session-budget-yield-tests.luau').read_text() in probe
assert 'local a,b=controls(),yielded();assert(a==83 and b==44);local checks=a+b' in probe
raw=subprocess.check_output(['git','archive','--format=tar',m['source'],'roblox_port/src'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(raw)) as archive:files={row.name:archive.extractfile(row).read() for row in archive if row.isfile()}
prefix={'First':'ReplicatedFirst','Shared':'ReplicatedStorage.Shared','Server':'ServerScriptService.Server','Client':'StarterPlayer.StarterPlayerScripts.Client'};expected={}
for name,data in files.items():
 parts=list(Path(name).parts[2:]);stem=parts[-1][:-5]
 for suffix in ['.client','.server']:
  if stem.endswith(suffix):stem=stem[:-len(suffix)]
 expected['.'.join([prefix[parts[0]],*parts[1:-1],stem])]=sha(data.replace(b'\r\n',b'\n'))
expected['ReplicatedStorage.Shared.Persistence.SaveSession']=cli['candidate_sha256']
assert expected['ServerScriptService.Server.DataStoreBackend']==m['candidates']['fresh-read-backend-candidate.luau']
raw=(HERE/'session-native-fixtures.json').read_text().strip();assert sha((HERE/'session-native-fixtures.json').read_bytes())==m['fixtures_sha256']
expected['ServerScriptService.Server.SessionFixtures']=sha(('return game:GetService("HttpService"):JSONDecode([==['+raw+']==])\n').encode())
expected['ServerScriptService.Server.SessionVerifiedProbe']=sha(probe.encode())
assert len(expected)==224 and {row['path']:row['sha256'] for row in m['scripts']}==expected
assert [row[0] for row in m['disabled_scripts'] if not row[1]]==['ServerScriptService.Server.SessionVerifiedProbe']
assert native['source']==m['source'] and native['assertions']==127 and native['creator_errors']==0 and native['scripts']==224 and native['production_scripts_disabled']
assert native['output_sha256']==sha((HERE/'session-verified-native-output.txt').read_bytes()) and '[NATIVE_SESSION_VERIFIED_PASS] '+native['run']+' 127' in (HERE/'session-verified-native-output.txt').read_text()
assert closed['playback_stopped'] and closed['place_closed'] and closed['diagnostic_window_closed'] and closed['prior_window_remained']
assert closed['original_restored_sha256']==m['place_sha256']==native['place_sha256']
r=dict(cli,qualified_for_adoption=True,native_verified=True,native_requalification_required=False,native_assertions=127,native_scripts=224,creator_errors=0,native_scope='Callback-aware controls and actual coroutine suspension; MemoryBackend; all production scripts disabled',real_datastore_verified=False,full_game_transport_verified=False)
(HERE/'session-verified-native-qualification.json').write_text(json.dumps(r,indent=2)+'\n',encoding='utf8',newline='\n');print(json.dumps(r,indent=2))
